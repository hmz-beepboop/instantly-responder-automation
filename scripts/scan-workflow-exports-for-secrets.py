#!/usr/bin/env python3
"""Credential-leak scan for local workflow exports (Gate S5 requirement).

Scans workflows/*.json for secret-shaped values. n8n exports must contain
credential REFERENCES (id + name) only — never key material. Exits 1 on any
finding so this can gate commits/deploys.
"""
import glob
import json
import re
import sys

PATTERNS = [
    (re.compile(r"sk-[A-Za-z0-9_-]{20,}"), "OpenAI-style secret key"),
    (re.compile(r"eyJhbGciOi[A-Za-z0-9._-]{40,}"), "JWT token literal"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "AWS access key"),
    (re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"), "Slack token"),
    (re.compile(r"(?i)\"(api_key|apikey|password|secret|token)\"\s*:\s*\"(?!\{\{)[A-Za-z0-9+/=_-]{24,}\""),
     "inline credential-shaped value"),
]
# Known-safe strings that match the broad patterns (webhook path tokens, template ids, etc.)
ALLOWLIST_RX = re.compile(r"(?i)(\$env\.|\{\{|X-N8N-API-KEY|httpHeaderAuth|genericCredentialType)")

findings = 0
for path in sorted(glob.glob("workflows/*.json")):
    try:
        text = open(path, encoding="utf-8-sig").read()
    except Exception as e:
        print(f"[WARN] cannot read {path}: {e}")
        continue
    for rx, label in PATTERNS:
        for m in rx.finditer(text):
            window = text[max(0, m.start() - 60):m.end() + 20]
            if ALLOWLIST_RX.search(window):
                continue
            findings += 1
            print(f"[LEAK?] {path}: {label}: ...{m.group(0)[:12]}*** (redacted)")

if findings:
    print(f"RESULT: {findings} potential credential leak(s) found — do not commit/deploy until resolved.")
    sys.exit(1)
print("RESULT: no credential-shaped values found in workflow exports.")
