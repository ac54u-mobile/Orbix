#!/usr/bin/env python3
"""翻译代理 + 快速语音转文字 → 中文字幕生成"""

import json, os, tempfile, time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import Request, urlopen
from concurrent.futures import ThreadPoolExecutor, as_completed

PORT = int(os.environ.get("TRANSLATE_PORT", "8899"))
DEEPSEEK_KEY = os.environ["DEEPSEEK_API_KEY"]
DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == "/translate":
            self.handle_translate()
        elif self.path == "/pipeline":
            self.handle_pipeline()
        else:
            self.send_error(404)

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"status": "ok"})
        else:
            self.send_error(404)

    def handle_translate(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            req = json.loads(body)
        except json.JSONDecodeError:
            self.send_json(400, {"error": "invalid json"})
            return
        text = req.get("text", "")
        if not text:
            self.send_json(400, {"error": "empty"})
            return
        try:
            result = self.ds(text)
            self.send_json(200, {"translated": result})
        except Exception as e:
            self.send_json(500, {"error": str(e)})

    def handle_pipeline(self):
        length = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(length)
        t_start = time.time()

        with tempfile.NamedTemporaryFile(suffix=".m4a", delete=False) as f:
            f.write(raw)
            audio_path = f.name

        try:
            self.log_message("Whisper", "transcribing...")
            from faster_whisper import WhisperModel
            model = WhisperModel("turbo", device="cpu", compute_type="int8", cpu_threads=6)
            segments, _ = model.transcribe(audio_path, language="ja", beam_size=3)

            ja_lines = []
            srt_entries = []
            idx = 1
            for seg in segments:
                start_ms = int(seg.start * 1000)
                end_ms = int(seg.end * 1000)
                start_ts = f"{start_ms//3600000:02d}:{(start_ms%3600000)//60000:02d}:{(start_ms%60000)//1000:02d},{start_ms%1000:03d}"
                end_ts = f"{end_ms//3600000:02d}:{(end_ms%3600000)//60000:02d}:{(end_ms%60000)//1000:02d},{end_ms%1000:03d}"

                text = seg.text.strip()
                if not text:
                    continue

                ja_lines.append(text)
                srt_entries.append({
                    "idx": idx,
                    "start": start_ts,
                    "end": end_ts,
                    "ja": text
                })
                idx += 1

            whisper_time = time.time() - t_start
            self.log_message("Whisper done", f"{len(ja_lines)} segments in {whisper_time:.1f}s")

            if not ja_lines:
                self.send_json(200, {"srt": ""})
                return

            # Batch translate: 25 lines per request, 5 concurrent
            batch_size = 25
            batches = [ja_lines[i:i+batch_size] for i in range(0, len(ja_lines), batch_size)]
            translations = [None] * len(ja_lines)

            with ThreadPoolExecutor(max_workers=5) as pool:
                futures = {}
                for bi, batch in enumerate(batches):
                    start_idx = bi * batch_size
                    prompt = "将以下日文字幕逐行翻译成简体中文。严格按编号对应输出，格式「编号. 中文」，不要加解释：\n\n"
                    for li, line in enumerate(batch):
                        prompt += f"{li+1}. {line}\n"
                    futures[pool.submit(self.ds, prompt)] = start_idx

                for future in as_completed(futures):
                    start_idx = futures[future]
                    try:
                        result = future.result(timeout=60)
                        for line in result.split("\n"):
                            if "." in line:
                                dot = line.index(".")
                                try:
                                    num = int(line[:dot].strip())
                                    if 1 <= num <= len(batches[futures[future] // batch_size]):
                                        text = line[dot+1:].strip()
                                        if text:
                                            translations[start_idx + num - 1] = text
                                except ValueError:
                                    pass
                    except Exception:
                        pass

            # Fill untranslated with original
            for i in range(len(translations)):
                if translations[i] is None:
                    translations[i] = ja_lines[i]

            # Build SRT
            srt_lines = []
            for entry, cn in zip(srt_entries, translations):
                srt_lines.append(f"{entry['idx']}\n{entry['start']} --> {entry['end']}\n{cn or entry['ja']}\n")

            total_time = time.time() - t_start
            self.log_message("Pipeline done", f"{total_time:.1f}s total")
            self.send_json(200, {"srt": "\n".join(srt_lines)})
        except Exception as e:
            self.send_json(500, {"error": str(e)})
        finally:
            os.unlink(audio_path)

    def ds(self, text):
        payload = json.dumps({
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": "你是专业日语翻译助手。将输入的日文翻译成简体中文，只输出翻译结果，不要任何解释。"},
                {"role": "user", "content": text}
            ],
            "temperature": 0.1,
            "max_tokens": 2048
        }).encode()
        req = Request(DEEPSEEK_URL, data=payload)
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {DEEPSEEK_KEY}")
        with urlopen(req, timeout=90) as resp:
            data = json.loads(resp.read())
            return data["choices"][0]["message"]["content"].strip()

    def send_json(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print(f"[{self.log_date_time_string()}] {fmt} {' '.join(map(str, args))}")


if __name__ == "__main__":
    print(f"Server starting on 0.0.0.0:{PORT}")
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
