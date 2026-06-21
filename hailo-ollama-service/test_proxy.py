#!/usr/bin/env python3
import json
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import proxy  # noqa: E402


class ProxySanitizerTests(unittest.TestCase):
    def test_escape_content_produces_valid_json_fragment(self):
        raw = 'line1\nline2\t"quote" \\ path\r\b\f and ctrl:\x01'
        escaped = proxy.escape_content(raw)

        # If this cannot be loaded, the escape function produced invalid JSON syntax.
        decoded = json.loads(f'"{escaped}"')
        self.assertEqual(decoded, raw)

    def test_sanitize_messages_escapes_messages_and_system(self):
        payload = {
            "model": "qwen2:1.5b",
            "system": "sys\nline",
            "messages": [
                {"role": "user", "content": "hello\nworld"},
                {"role": "assistant", "content": "tab\tand\\backslash"},
            ],
        }

        body = json.dumps(payload).encode("utf-8")
        sanitized_body = proxy.sanitize_messages(body)
        sanitized_payload = json.loads(sanitized_body)

        self.assertEqual(sanitized_payload["messages"][0]["content"], "hello\\nworld")
        self.assertEqual(sanitized_payload["messages"][1]["content"], "tab\\tand\\\\backslash")
        self.assertEqual(sanitized_payload["system"], "sys\\nline")

    def test_sanitize_messages_non_json_passthrough(self):
        raw = b"not-json"
        self.assertEqual(proxy.sanitize_messages(raw), raw)


if __name__ == "__main__":
    unittest.main()
