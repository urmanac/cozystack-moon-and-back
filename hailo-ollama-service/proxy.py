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


def escape_content(s: str) -> str:
    """
    Replace real control characters in a string with their backslash-escape
    equivalents (two printable chars, e.g. LF → backslash + n).

    WHY THIS IS NEEDED:
    hailo-ollama v5.3.0 builds prompt_json_strings by naive C++ string
    concatenation: '"' + role + '":"' + content + '"'. When content contains
    a real LF (U+000A), the resulting "JSON" is invalid and HailoRT's strict
    nlohmann::json parser rejects it with HAILO_INTERNAL_FAILURE(8).

    By replacing '\n' with the two-char literal '\\n' before sending,
    hailo-ollama's C++ string contains backslash+n. When it concatenates that
    into its JSON, it produces the valid JSON escape sequence \\n, which
    HailoRT parses correctly and the model receives as a real newline.

    Note: json.loads/json.dumps alone is a no-op here — valid JSON in means
    valid JSON out, and the bug is inside hailo-ollama after it parses us.
    """
    # json.dumps gives us the exact escaping rules JSON strings require
    # (quotes, backslashes, and all C0 control characters).
    return json.dumps(s, ensure_ascii=False)[1:-1]


def _is_hailo_embeddable(s: str) -> bool:
    """
    Validate that a string can survive hailo-ollama's buggy JSON concatenation
    pattern: '..."content":"' + s + '"...'.
    """
    try:
        json.loads('{"role":"user","content":"' + s + '"}')
        return True
    except (json.JSONDecodeError, ValueError):
        return False


def make_hailo_safe(value: str) -> str:
    """
    Convert an arbitrary string into a form that remains valid when embedded
    into hailo-ollama's internal concatenated JSON.
    """
    sanitized = escape_content(value)
    if _is_hailo_embeddable(sanitized):
        return sanitized

    # Fallback for edge cases: canonicalize once more from the sanitized form.
    # This favors correctness/parsability over perfect textual fidelity.
    fallback = escape_content(sanitized)
    return fallback if _is_hailo_embeddable(fallback) else sanitized


def sanitize_messages(body_bytes: bytes) -> bytes:
    """
    Parse the request body, escape control characters in all message content
    strings, then re-serialize. Returns sanitized bytes.
    """
    try:
        data = json.loads(body_bytes)
        sanitized_fields = 0

        def sanitize_string(value: str) -> str:
            nonlocal sanitized_fields
            sanitized = make_hailo_safe(value)
            if sanitized != value:
                sanitized_fields += 1
            return sanitized

        def sanitize_value(value):
            if isinstance(value, str):
                return sanitize_string(value)
            if isinstance(value, list):
                return [sanitize_value(item) for item in value]
            if isinstance(value, dict):
                return {k: sanitize_value(v) for k, v in value.items()}
            return value

        # HailoRT prompt rendering can break on unescaped characters in any
        # string field (messages, system, tool schema descriptions, etc.).
        # Recursively sanitize all string values in the JSON payload.
        data = sanitize_value(data)

        if sanitized_fields > 0:
            print(
                f"[proxy] sanitized {sanitized_fields} field(s) in request body ({len(body_bytes)} bytes)",
                file=sys.stderr,
            )

        return json.dumps(data, ensure_ascii=False).encode("utf-8")
    except (json.JSONDecodeError, ValueError) as exc:
        # Can't parse — pass through unchanged, but surface reason for troubleshooting.
        print(
            f"[proxy] sanitize skipped: {type(exc).__name__}: {exc} (body_bytes={len(body_bytes)})",
            file=sys.stderr,
        )
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
        # Long timeout for pull/push (model downloads can be several GB)
        timeout = 3600 if "/pull" in self.path or "/push" in self.path else 120
        conn = http.client.HTTPConnection(UPSTREAM_HOST, UPSTREAM_PORT, timeout=timeout)
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
