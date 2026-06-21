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

    def test_make_hailo_safe_produces_embeddable_json_fragment(self):
        raw = 'You must respond with JSON:\n{\\n  "plan": ["x"]\\n}\nAnd a quoted token: \\"p'
        safe = proxy.make_hailo_safe(raw)
        self.assertTrue(proxy._is_hailo_embeddable(safe))

    def test_recursive_sanitization_outputs_hailo_embeddable_strings(self):
        payload = {
            "model": "qwen2:1.5b",
            "messages": [
                {
                    "role": "system",
                    "content": "You are Tab Maestro. Respond with JSON:\n{\n  \"plan\": []\n}",
                },
                {"role": "user", "content": 'Tab state with quoted key: \\"windowId\\"'},
            ],
        }
        out = json.loads(proxy.sanitize_messages(json.dumps(payload).encode("utf-8")))
        for msg in out["messages"]:
            if isinstance(msg.get("content"), str):
                self.assertTrue(proxy._is_hailo_embeddable(msg["content"]))

    def test_sanitize_messages_escapes_nested_tool_schema_strings(self):
        payload = {
            "model": "qwen2:1.5b",
            "messages": [{"role": "user", "content": "organize tabs"}],
            "tools": [
                {
                    "type": "function",
                    "function": {
                        "name": "apply_tab_actions",
                        "description": "Return JSON only:\n{\n  \"plan\": []\n}",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "plan": {
                                    "type": "array",
                                    "description": "Actions with \"windowId\" and \"tabId\"",
                                }
                            },
                        },
                    },
                }
            ],
        }

        body = json.dumps(payload).encode("utf-8")
        sanitized_payload = json.loads(proxy.sanitize_messages(body))

        desc = sanitized_payload["tools"][0]["function"]["description"]
        nested_desc = sanitized_payload["tools"][0]["function"]["parameters"]["properties"]["plan"]["description"]
        self.assertIn("\\n", desc)
        self.assertIn('\\"plan\\"', desc)
        self.assertIn('\\"windowId\\"', nested_desc)


if __name__ == "__main__":
    unittest.main()
