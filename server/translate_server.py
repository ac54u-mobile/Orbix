#!/usr/bin/env python3
"""DeepSeek 翻译代理服务器 — Run on your VPS"""

import json
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import Request, urlopen
from urllib.error import URLError

PORT = int(os.environ.get("TRANSLATE_PORT", "8899"))
DEEPSEEK_KEY = os.environ["DEEPSEEK_API_KEY"]
DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"


class TranslateHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/translate":
            self.send_error(404)
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)
        try:
            req = json.loads(body)
        except json.JSONDecodeError:
            self.send_json(400, {"error": "invalid json"})
            return

        text = req.get("text", "")
        if not text:
            self.send_json(400, {"error": "empty text"})
            return

        try:
            result = self.call_deepseek(text)
            self.send_json(200, {"translated": result})
        except Exception as e:
            self.send_json(500, {"error": str(e)})

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"status": "ok"})
        else:
            self.send_error(404)

    def call_deepseek(self, text):
        payload = json.dumps({
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": "你是专业日语翻译助手。将输入的日文翻译成简体中文，只输出翻译结果，不要任何解释。如果输入是中文则直接返回原文。"},
                {"role": "user", "content": text}
            ],
            "temperature": 0.1,
            "max_tokens": 1024
        }).encode("utf-8")

        req = Request(DEEPSEEK_URL, data=payload)
        req.add_header("Content-Type", "application/json")
        req.add_header("Authorization", f"Bearer {DEEPSEEK_KEY}")

        with urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read())
            return data["choices"][0]["message"]["content"].strip()

    def send_json(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {args[0]}")


if __name__ == "__main__":
    print(f"Translate server starting on 0.0.0.0:{PORT}")
    server = HTTPServer(("0.0.0.0", PORT), TranslateHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.server_close()
