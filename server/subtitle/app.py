"""
Orbix 字幕服务

流程：ffmpeg 提取音频 → faster-whisper 语音识别 → DeepSeek 翻译成中文
     → 在视频旁边生成 <视频名>.zh.srt（Infuse 自动识别同名外挂字幕）

配置（环境变量，见 orbix-subtitle.env）：
  ORBIX_API_KEY      app 调用本服务的鉴权 key（必填，自定义一串随机字符）
  DEEPSEEK_API_KEY   DeepSeek 平台的 API Key（必填）
  WHISPER_MODEL      whisper 模型，默认 small（可选 tiny/base/small/medium/large-v3）
  PORT               监听端口，默认 8788
  PATH_MAP           路径映射，qBittorrent 在 Docker 里时必填。
                     格式：容器路径=宿主机路径，多组用逗号分隔。
                     例：PATH_MAP=/downloads=/mnt/user/downloads
"""

import os
import re
import json
import time
import uuid
import threading
import subprocess
from dataclasses import dataclass, field, asdict

import requests
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
import uvicorn

ORBIX_API_KEY = os.environ.get("ORBIX_API_KEY", "")
DEEPSEEK_API_KEY = os.environ.get("DEEPSEEK_API_KEY", "")
WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "small")
PORT = int(os.environ.get("PORT", "8788"))
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
        for k, v in kw.items():
            setattr(self, k, v)
        self.updated_at = time.time()


JOBS: dict[str, Job] = {}
JOBS_LOCK = threading.Lock()

_whisper_model = None
_whisper_lock = threading.Lock()


def get_whisper():
    global _whisper_model
    with _whisper_lock:
        if _whisper_model is None:
            from faster_whisper import WhisperModel
            _whisper_model = WhisperModel(WHISPER_MODEL, device="cpu", compute_type="int8")
        return _whisper_model


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
    segments_iter, _info = model.transcribe(wav, vad_filter=True, beam_size=5)
    segments = []
    for seg in segments_iter:
        text = seg.text.strip()
        if text:
            segments.append({"start": seg.start, "end": seg.end, "text": text})
        if duration > 0:
            job.update(progress=min(99, int(seg.end / duration * 100)))
    job.update(progress=100)
    return segments


def deepseek_translate_batch(lines: list[str]) -> list[str]:
    numbered = "\n".join(f"{i + 1}|{t}" for i, t in enumerate(lines))
    payload = {
        "model": "deepseek-chat",
        "temperature": 1.3,
        "messages": [
            {
                "role": "system",
                "content": (
                    "你是专业字幕翻译。把下面每行竖线后的台词翻译成简体中文，"
                    "口语自然、简洁。严格保持行数和行号不变，"
                    "输出格式与输入相同：行号|译文。不要输出任何其他内容。"
                ),
            },
            {"role": "user", "content": numbered},
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
        batch = texts[i:i + TRANSLATE_BATCH]
        try:
            out.extend(deepseek_translate_batch(batch))
        except Exception:
            # 单批失败重试一次，再失败保留原文
            try:
                out.extend(deepseek_translate_batch(batch))
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


def run_pipeline(job: Job):
    wav = f"/tmp/orbix-sub-{job.id}.wav"
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
    except Exception as e:  # noqa: BLE001
        job.update(stage="error", error=str(e)[:500], message="失败")
    finally:
        if os.path.exists(wav):
            os.remove(wav)


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
        # 同一视频若已有进行中的任务，直接返回它
        for job in JOBS.values():
            if job.video_path == video_path and job.stage not in ("done", "error"):
                return asdict(job)
        job = Job(id=uuid.uuid4().hex[:12], video_path=video_path)
        JOBS[job.id] = job
    threading.Thread(target=run_pipeline, args=(job,), daemon=True).start()
    return asdict(job)


@app.get("/api/jobs/{job_id}")
def get_job(job_id: str, x_api_key: str | None = Header(default=None)):
    check_auth(x_api_key)
    job = JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    return asdict(job)


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
