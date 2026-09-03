#!/usr/bin/env python3
"""
Server test cho OutboxUploadDemo.

    python3 mock_server.py            # latency 0
    python3 mock_server.py --delay 2  # giả lập mạng chậm 2s mỗi batch

Endpoint: POST /upload
Header  : Idempotency-Key  -> batch đã xử lý thì trả 200 mà không ghi lại.

Cái Idempotency-Key này chính là thứ làm cho việc gửi lại batch bị cancel
giữa đường trở nên an toàn. Xem log server: bạn sẽ thấy dòng "DUPLICATE"
mỗi lần app resend một batch đã tới nơi trước khi bị cắt.
"""

import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

seen_batches = set()
total_records = 0


class Handler(BaseHTTPRequestHandler):
    delay = 0.0

    def do_POST(self):
        if self.path != "/upload":
            self.send_error(404)
            return

        global total_records

        length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(length) or b"{}")
        key = self.headers.get("Idempotency-Key", "")
        records = body.get("records", [])

        if self.delay:
            time.sleep(self.delay)

        if key in seen_batches:
            print(f"  DUPLICATE  {key[:8]}  ({len(records)} record, bỏ qua)")
        else:
            seen_batches.add(key)
            total_records += len(records)
            print(f"  OK         {key[:8]}  +{len(records)}  tổng={total_records}")

        payload = json.dumps({"ok": True, "total": total_records}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--delay", type=float, default=0.0)
    args = parser.parse_args()

    Handler.delay = args.delay
    print(f"Nghe trên 0.0.0.0:{args.port}, delay {args.delay}s mỗi batch")
    HTTPServer(("0.0.0.0", args.port), Handler).serve_forever()
