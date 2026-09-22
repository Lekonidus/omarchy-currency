#!/usr/bin/env python3
# Run: python3 tests/test_fetch_rates.py
"""Smoke checks for bin/fetch-rates byte ceiling and success path."""
from __future__ import annotations

import http.server
import subprocess
import threading
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FETCH = ROOT / "bin" / "fetch-rates"


class Handler(http.server.BaseHTTPRequestHandler):
    mode = "ok"

    def log_message(self, *_args):
        return

    def do_GET(self):
        if self.mode == "big":
            body = b"x" * 70000
        else:
            body = b'{"amount":1.0,"base":"USD","date":"2026-09-20","rates":{"ILS":3.0}}'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def run_fetch(url: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(FETCH), url],
        capture_output=True,
        timeout=15,
        check=False,
    )


def main() -> None:
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    port = server.server_address[1]
    base = f"http://127.0.0.1:{port}/"

    try:
        Handler.mode = "ok"
        ok = run_fetch(base)
        assert ok.returncode == 0, ok.stderr
        assert b'"base":"USD"' in ok.stdout

        Handler.mode = "big"
        big = run_fetch(base)
        assert big.returncode == 3, (big.returncode, big.stderr)
        assert big.stdout == b""
        print("ok")
    finally:
        server.shutdown()


if __name__ == "__main__":
    main()
