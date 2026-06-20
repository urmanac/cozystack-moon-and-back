#!/usr/bin/env python3
"""
hailo-ollama-proxy: A thin HTTP proxy that sanitizes chat completion requests
before forwarding to hailo-ollama.

Bug: hailo-ollama v5.3.0 passes message content strings directly to HailoRT's
render_prompt_from_json_strings without JSON-escaping them first. Any message
content containing literal control characters (newlines, tabs, etc.) causes
HailoRT's strict nlohmann::json parser to reject the prompt with:
  "invalid string: control character U+000A (LF) must be escaped to \u000A or \n"

This proxy intercepts requests, parses the JSON, and re-serializes the message
content strings so they are guaranteed to be clean before forwarding.

Listens on :11434 (standard Ollama port), forwards to hailo-ollama on :8000.
"""

import json
import http.server
import http.client
import sys
import os

UPSTREAM_HOST = os.environ.get("UPSTREAM_HOST", "127.0.0.1")
UPSTREAM_PORT = int(os.environ.get("UPSTREAM_PORT", "8000"))
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "11434"))


def sanitize_messages(body_bytes: bytes) -> bytes:
    """
    Parse the request body JSON and re-serialize it, which guarantees that
    all string values (including message content with newlines) are properly
    JSON-escaped. Returns the sanitized bytes.
    """
    try:
        data = json.loads(body_bytes)
        # Re-dump with ensure_ascii=False to preserve unicode but escape control chars
        return json.dumps(data, ensure_ascii=False).encode("utf-8")
    except (json.JSONDecodeError, ValueError):
        # Can't parse — pass through unchanged
        return body_bytes


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[proxy] {self.address_string()} {fmt % args}", file=sys.stderr)

    def do_request(self, method: str):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else b""

        # Only sanitize JSON content-type requests (chat/completions, etc.)
        content_type = self.headers.get("Content-Type", "")
        if "application/json" in content_type and body:
            body = sanitize_messages(body)

        # Forward to upstream hailo-ollama
        conn = http.client.HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=120)
        headers = {
            k: v for k, v in self.headers.items()
            if k.lower() not in ("host", "content-length", "transfer-encoding")
        }
        headers["Host"] = f"{UPSTREAM_HOST}:{UPSTREAM_PORT}"
        if body:
            headers["Content-Length"] = str(len(body))

        try:
            conn.request(method, self.path, body=body, headers=headers)
            resp = conn.getresponse()

            self.send_response(resp.status)
            for header, value in resp.getheaders():
                if header.lower() not in ("transfer-encoding",):
                    self.send_header(header, value)
            self.end_headers()

            # Stream the response back
            while True:
                chunk = resp.read(4096)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
        except Exception as e:
            print(f"[proxy] upstream error: {e}", file=sys.stderr)
            self.send_error(502, f"Bad Gateway: {e}")
        finally:
            conn.close()

    def do_GET(self):    self.do_request("GET")
    def do_POST(self):   self.do_request("POST")
    def do_DELETE(self): self.do_request("DELETE")
    def do_HEAD(self):   self.do_request("HEAD")
    def do_PUT(self):    self.do_request("PUT")


if __name__ == "__main__":
    server = http.server.ThreadingHTTPServer(("0.0.0.0", LISTEN_PORT), ProxyHandler)
    print(f"[proxy] Listening on :{LISTEN_PORT}, forwarding to {UPSTREAM_HOST}:{UPSTREAM_PORT}", file=sys.stderr)
    server.serve_forever()
