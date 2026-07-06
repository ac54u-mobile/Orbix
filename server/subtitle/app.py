"""
Orbix 字幕服务

流程：ffmpeg 提取音频 → faster-whisper 语音识别 → DeepSeek 翻译成中文
     → 在视频旁边生成 <视频名>.zh.srt（Infuse 自动识别同名外挂字幕）

配置（环境变量，见 orbix-subtitle.env）：
  ORBIX_API_KEY      app 调用本服务的鉴权 key（必填，自定义一串随机字符）
  DEEPSEEK_API_KEY   DeepSeek 平台的 API Key（必填）
  WHISPER_MODEL      whisper 模型，默认 small（可选 tiny/base/small/medium/large-v3）
  LANGUAGE           源语言，默认 ja（日语）；设为 auto 则自动检测
  PORT               监听端口，默认 8788
  PATH_MAP           路径映射，qBittorrent 在 Docker 里时必填。
                     格式：容器路径=宿主机路径，多组用逗号分隔。
                     例：PATH_MAP=/downloads=/mnt/user/downloads
"""

import gc
import os
import re
import json
import time
import uuid
import queue
import threading
import subprocess
from dataclasses import dataclass, field, asdict

import requests
from fastapi import FastAPI, HTTPException, Header
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel
import uvicorn

ORBIX_API_KEY = os.environ.get("ORBIX_API_KEY", "")
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "small")
LANGUAGE = os.environ.get("LANGUAGE", "ja")
PORT = int(os.environ.get("PORT", "8788"))

# 单条字幕显示上限（秒），防止"话说完了字幕还挂在屏幕上"
MAX_SUB_DURATION = 6.0
MIN_SUB_DURATION = 0.5
PATH_MAP = os.environ.get("PATH_MAP", "")


def map_path(path: str) -> str:
    """把 qBittorrent（容器内）路径映射为本机实际路径"""
    for pair in PATH_MAP.split(","):
        if "=" not in pair:
            continue
        src, dst = pair.split("=", 1)
        src, dst = src.strip().rstrip("/"), dst.strip().rstrip("/")
        if src and (path == src or path.startswith(src + "/")):
            return dst + path[len(src):]
    return path

DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"
TRANSLATE_BATCH = 30

app = FastAPI(title="Orbix Subtitle Service")

# ---------------------------------------------------------------- job store


@dataclass
class Job:
    id: str
    video_path: str
    stage: str = "queued"  # queued/extract/transcribe/translate/write/done/error
    progress: int = 0      # 当前阶段进度 0-100
    message: str = ""
    error: str = ""
    srt_path: str = ""
    created_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)

    def update(self, **kw):
        stage_changed = "stage" in kw and kw["stage"] != self.stage
        for k, v in kw.items():
            setattr(self, k, v)
        self.updated_at = time.time()
        if stage_changed:
            save_jobs()


JOBS: dict[str, Job] = {}
JOBS_LOCK = threading.Lock()

# ------------------------------------------------------------- cancellation


class JobCancelled(Exception):
    pass


CANCEL_LOCK = threading.Lock()
CANCEL_REQUESTED: set[str] = set()


def request_cancel(job_id: str):
    with CANCEL_LOCK:
        CANCEL_REQUESTED.add(job_id)


def clear_cancel(job_id: str):
    with CANCEL_LOCK:
        CANCEL_REQUESTED.discard(job_id)


def check_cancel(job: Job):
    with CANCEL_LOCK:
        cancelled = job.id in CANCEL_REQUESTED
    if cancelled:
        raise JobCancelled()

# 任务记录落盘，服务重启后仍能查看历史
JOBS_FILE = os.environ.get("JOBS_FILE", os.path.join(os.path.dirname(os.path.abspath(__file__)), "jobs.json"))


def save_jobs():
    try:
        with JOBS_LOCK:
            data = [asdict(j) for j in JOBS.values()]
        tmp = JOBS_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
        os.replace(tmp, JOBS_FILE)
    except OSError:
        pass


def load_jobs():
    if not os.path.isfile(JOBS_FILE):
        return
    try:
        with open(JOBS_FILE, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        return
    for d in data:
        try:
            job = Job(**d)
        except TypeError:
            continue
        # 重启后进行中的任务自动重新排队（从头处理）；已暂停的保持暂停
        if job.stage not in ("done", "error", "paused"):
            job.stage = "queued"
            job.progress = 0
            job.message = "服务重启，已自动重新排队"
        JOBS[job.id] = job


load_jobs()

_whisper_model = None
_whisper_lock = threading.Lock()


def get_whisper():
    global _whisper_model
    with _whisper_lock:
        if _whisper_model is None:
            from faster_whisper import WhisperModel
            # 限制线程数，避免和其他服务抢资源
            _whisper_model = WhisperModel(
                WHISPER_MODEL, device="cpu", compute_type="int8",
                cpu_threads=max(2, (os.cpu_count() or 4) // 2),
            )
        return _whisper_model


def release_whisper():
    """任务做完释放模型，空闲时不占着 1GB 内存（服务器内存紧张，OOM 会被内核杀掉）"""
    global _whisper_model
    with _whisper_lock:
        _whisper_model = None
    gc.collect()


# ---------------------------------------------------------------- pipeline


def probe_duration(path: str) -> float:
    out = subprocess.run(
        ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
         "-of", "csv=p=0", path],
        capture_output=True, text=True, timeout=60,
    )
    try:
        return float(out.stdout.strip())
    except ValueError:
        return 0.0


def extract_audio(job: Job, video: str, wav: str, duration: float):
    job.update(stage="extract", progress=0, message="提取音频中")
    proc = subprocess.Popen(
        ["ffmpeg", "-y", "-i", video, "-vn", "-ac", "1", "-ar", "16000",
         "-f", "wav", "-progress", "pipe:1", "-loglevel", "error", wav],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    for line in proc.stdout:
        with CANCEL_LOCK:
            cancelled = job.id in CANCEL_REQUESTED
        if cancelled:
            proc.kill()
            proc.wait()
            raise JobCancelled()
        m = re.match(r"out_time_ms=(\d+)", line.strip())
        if m and duration > 0:
            pct = min(99, int(int(m.group(1)) / 1_000_000 / duration * 100))
            job.update(progress=pct)
    proc.wait()
    if proc.returncode != 0:
        raise RuntimeError(f"ffmpeg 提取音频失败: {proc.stderr.read()[:300]}")
    job.update(progress=100)


def transcribe(job: Job, wav: str, duration: float) -> list[dict]:
    job.update(stage="transcribe", progress=0, message="Whisper 语音识别中")
    model = get_whisper()
    # beam_size=1 贪心解码，CPU 上速度和内存都友好，字幕场景质量足够；
    # word_timestamps 用词级时间修正段落边界；condition_on_previous_text=False
    # 避免幻觉复读；VAD 靠短静音切分，字幕不会一直挂着
    segments_iter, _info = model.transcribe(
        wav,
        language=None if LANGUAGE == "auto" else LANGUAGE,
        vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 400, "speech_pad_ms": 150},
        beam_size=1,
        word_timestamps=True,
        condition_on_previous_text=False,
    )
    segments = []
    for seg in segments_iter:
        check_cancel(job)
        text = seg.text.strip()
        if text:
            start, end = seg.start, seg.end
            # 用词级时间戳收紧边界：话说完字幕就消失
            if seg.words:
                start = seg.words[0].start
                end = seg.words[-1].end
            segments.append({"start": start, "end": end, "text": text})
        if duration > 0:
            job.update(progress=min(99, int(seg.end / duration * 100)))
    job.update(progress=100)
    return postprocess_segments(segments)


def postprocess_segments(segments: list[dict]) -> list[dict]:
    """时间轴修正：限制单条时长、去重复读、消除重叠"""
    cleaned: list[dict] = []
    for seg in segments:
        # Whisper 幻觉常表现为同一句连续复读，只保留第一条
        if cleaned and seg["text"] == cleaned[-1]["text"] and seg["start"] - cleaned[-1]["end"] < 3.0:
            continue
        seg["end"] = min(seg["end"], seg["start"] + MAX_SUB_DURATION)
        seg["end"] = max(seg["end"], seg["start"] + MIN_SUB_DURATION)
        # 与下一条重叠时提前结束（循环后处理）
        cleaned.append(seg)
    for cur, nxt in zip(cleaned, cleaned[1:]):
        if cur["end"] > nxt["start"]:
            cur["end"] = max(cur["start"] + MIN_SUB_DURATION, nxt["start"] - 0.05)
    return cleaned


TRANSLATE_SYSTEM_PROMPT = (
    "你是资深的日译中影视字幕翻译，正在翻译日本影片的对白字幕（逐条、带行号）。要求：\n"
    "1. 译成地道的简体中文口语，简短干脆，符合字幕阅读习惯，避免书面腔和直译腔；\n"
    "2. 结合上下文语境翻译：人称、称呼、语气要前后连贯，省略的主语按语境补全或保持省略；\n"
    "3. 日语语气词、感叹词（あっ、んっ、はぁ、うん、ね、よ 等）译成自然的中文语气词（啊、嗯、哈、好、呢、哟等），"
    "单独成句的短语气词直接给出对应中文，不要展开脑补；\n"
    "4. 识别错误、无意义的音节或听不清的内容，输出最接近语境的合理短句，实在无法翻译就原样保留；\n"
    "5. 不要合并、拆分或跳过任何一行；严格保持行数与行号不变；\n"
    "6. 输出格式：行号|译文。除译文行外不要输出任何说明、注释或空行。"
)


def deepseek_translate_batch(lines: list[str], context: list[str] | None = None) -> list[str]:
    numbered = "\n".join(f"{i + 1}|{t}" for i, t in enumerate(lines))
    user_content = numbered
    if context:
        ctx = "\n".join(context[-6:])
        user_content = (
            f"【上文（前几条字幕的译文，仅供语境参考，禁止输出、禁止编号）】\n{ctx}\n\n"
            f"【待翻译字幕】\n{numbered}"
        )
    payload = {
        "model": "deepseek-chat",
        "temperature": 1.3,
        "messages": [
            {"role": "system", "content": TRANSLATE_SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ],
    }
    resp = requests.post(
        DEEPSEEK_URL,
        headers={"Authorization": f"Bearer {DEEPSEEK_API_KEY}"},
        json=payload,
        timeout=120,
    )
    resp.raise_for_status()
    content = resp.json()["choices"][0]["message"]["content"]

    result = dict()
    for line in content.splitlines():
        m = re.match(r"\s*(\d+)\s*\|(.*)", line)
        if m:
            result[int(m.group(1))] = m.group(2).strip()
    # 缺行时回退原文，保证字幕条数不变
    return [result.get(i + 1, lines[i]) for i in range(len(lines))]


def translate(job: Job, segments: list[dict]) -> list[str]:
    job.update(stage="translate", progress=0, message="DeepSeek 翻译中")
    texts = [s["text"] for s in segments]
    out: list[str] = []
    total = len(texts)
    for i in range(0, total, TRANSLATE_BATCH):
        check_cancel(job)
        batch = texts[i:i + TRANSLATE_BATCH]
        # 把前一批的译文尾部作为上下文，保证跨批次语境连贯
        context = out[-6:] if out else None
        try:
            out.extend(deepseek_translate_batch(batch, context))
        except Exception:
            # 单批失败重试一次，再失败保留原文
            try:
                out.extend(deepseek_translate_batch(batch, context))
            except Exception:
                out.extend(batch)
        job.update(progress=min(99, int(len(out) / total * 100)))
    job.update(progress=100)
    return out


def format_ts(sec: float) -> str:
    ms = int(round(sec * 1000))
    h, ms = divmod(ms, 3600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def write_srt(job: Job, segments: list[dict], translated: list[str], video: str) -> str:
    job.update(stage="write", progress=0, message="写入字幕文件")
    base, _ = os.path.splitext(video)
    srt_path = f"{base}.zh.srt"
    lines = []
    for i, (seg, zh) in enumerate(zip(segments, translated), start=1):
        lines.append(f"{i}\n{format_ts(seg['start'])} --> {format_ts(seg['end'])}\n{zh}\n")
    with open(srt_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    job.update(progress=100)
    return srt_path


# /tmp 常为 tmpfs（内存盘），440MB 的 wav 会直接吃内存，必须放磁盘目录
WORK_DIR = os.environ.get("WORK_DIR", "/var/tmp/orbix-subtitle")
os.makedirs(WORK_DIR, exist_ok=True)


def cleanup_workdir():
    for name in os.listdir(WORK_DIR):
        try:
            os.remove(os.path.join(WORK_DIR, name))
        except OSError:
            pass


cleanup_workdir()


def run_pipeline(job: Job):
    wav = os.path.join(WORK_DIR, f"orbix-sub-{job.id}.wav")
    try:
        if not os.path.isfile(job.video_path):
            hint = "（qBittorrent 在 Docker 里时，请在 /etc/orbix-subtitle.env 配置 PATH_MAP 路径映射）" \
                if not PATH_MAP else ""
            raise RuntimeError(f"视频文件不存在: {job.video_path} {hint}")

        duration = probe_duration(job.video_path)
        extract_audio(job, job.video_path, wav, duration)
        segments = transcribe(job, wav, duration)
        if not segments:
            raise RuntimeError("未识别到语音内容")
        translated = translate(job, segments)
        srt_path = write_srt(job, segments, translated, job.video_path)
        job.update(stage="done", progress=100, srt_path=srt_path,
                   message=f"完成，共 {len(segments)} 条字幕")
    except JobCancelled:
        job.update(stage="paused", progress=0, message="已暂停", error="")
    except Exception as e:  # noqa: BLE001
        job.update(stage="error", error=str(e)[:500], message="失败")
    finally:
        clear_cancel(job.id)
        if os.path.exists(wav):
            os.remove(wav)
        # 队列空了就释放模型，把内存还给系统
        if JOB_QUEUE.empty():
            release_whisper()


# ------------------------------------------------------------ serial worker
# 内存有限（whisper 模型 1GB+），任务串行执行，同一时间只跑一个

JOB_QUEUE: "queue.Queue[str]" = queue.Queue()


def worker_loop():
    while True:
        job_id = JOB_QUEUE.get()
        job = JOBS.get(job_id)
        if job is not None and job.stage == "queued":
            run_pipeline(job)
        JOB_QUEUE.task_done()


def enqueue(job: Job):
    JOB_QUEUE.put(job.id)


threading.Thread(target=worker_loop, daemon=True).start()

# 服务启动时，把上次中断后重新排队的任务塞回队列自动继续
for _j in list(JOBS.values()):
    if _j.stage == "queued":
        enqueue(_j)


# ---------------------------------------------------------------- HTTP API


class CreateJobRequest(BaseModel):
    video_path: str


def check_auth(x_api_key: str | None):
    if not ORBIX_API_KEY or x_api_key != ORBIX_API_KEY:
        raise HTTPException(status_code=401, detail="invalid api key")


@app.get("/api/health")
def health():
    return {"status": "ok", "whisper_model": WHISPER_MODEL}


@app.post("/api/jobs", status_code=202)
def create_job(req: CreateJobRequest, x_api_key: str | None = Header(default=None)):
    check_auth(x_api_key)
    video_path = map_path(req.video_path)
    with JOBS_LOCK:
        # 同一视频若已有进行中的任务，直接返回它；已暂停的自动恢复排队
        for existing in JOBS.values():
            if existing.video_path == video_path and existing.stage not in ("done", "error"):
                if existing.stage == "paused":
                    existing.stage = "queued"
                    existing.progress = 0
                    existing.message = "排队中"
                    enqueue(existing)
                return asdict(existing)
        job = Job(id=uuid.uuid4().hex[:12], video_path=video_path)
        JOBS[job.id] = job
    save_jobs()
    enqueue(job)
    return asdict(job)


@app.get("/api/jobs/{job_id}")
def get_job(job_id: str, x_api_key: str | None = Header(default=None)):
    check_auth(x_api_key)
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    return asdict(job)


@app.post("/api/jobs/{job_id}/pause")
def pause_job(job_id: str, x_api_key: str | None = Header(default=None)):
    check_auth(x_api_key)
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    if job.stage == "queued":
        job.update(stage="paused", progress=0, message="已暂停")
    elif job.stage in ("extract", "transcribe", "translate", "write"):
        # 运行中的任务：置取消标记，工作线程停下后自动接着跑队列里的下一个
        request_cancel(job_id)
        job.update(message="正在暂停…")
    return asdict(job)


@app.post("/api/jobs/{job_id}/resume")
def resume_job(job_id: str, x_api_key: str | None = Header(default=None)):
    check_auth(x_api_key)
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    if job.stage == "paused":
        job.update(stage="queued", progress=0, message="排队中", error="")
        enqueue(job)
    return asdict(job)


@app.delete("/api/jobs/{job_id}")
def delete_job(job_id: str, delete_file: bool = False, x_api_key: str | None = Header(default=None)):
    check_auth(x_api_key)
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    if job.stage in ("extract", "transcribe", "translate", "write"):
        request_cancel(job_id)
    if delete_file and job.srt_path and os.path.isfile(job.srt_path):
        try:
            os.remove(job.srt_path)
        except OSError:
            pass
    with JOBS_LOCK:
        JOBS.pop(job_id, None)
    save_jobs()
    return {"ok": True}


@app.get("/api/jobs/{job_id}/srt", response_class=PlainTextResponse)
def get_srt(job_id: str, x_api_key: str | None = Header(default=None)):
    check_auth(x_api_key)
    job = JOBS.get(job_id)
    if job is None or job.stage != "done" or not os.path.isfile(job.srt_path):
        raise HTTPException(status_code=404, detail="srt not found")
    with open(job.srt_path, encoding="utf-8") as f:
        return f.read()


@app.get("/api/jobs")
def list_jobs(video_path: str | None = None, x_api_key: str | None = Header(default=None)):
    check_auth(x_api_key)
    jobs = sorted(JOBS.values(), key=lambda j: j.created_at, reverse=True)
    if video_path:
        mapped = map_path(video_path)
        jobs = [j for j in jobs if j.video_path == mapped]
    return [asdict(j) for j in jobs[:50]]


if __name__ == "__main__":
    if not ORBIX_API_KEY:
        raise SystemExit("请设置 ORBIX_API_KEY 环境变量")
    if not DEEPSEEK_API_KEY:
        raise SystemExit("请设置 DEEPSEEK_API_KEY 环境变量")
    uvicorn.run(app, host="0.0.0.0", port=PORT)
