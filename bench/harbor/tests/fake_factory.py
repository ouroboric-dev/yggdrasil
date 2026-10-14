"""A stand-in for Yggdrasil's side of the bridge, until Phase 6 builds the real one.

    fake_factory.py <script.json> <transcript.jsonl>   send the scripted requests, record every line
    fake_factory.py smoke                               build a tiny app in /app, self-check, finish

A script is a list of requests ({"op": ...}) and steps: {"sleep": seconds}, {"exit": code}.
The transcript holds {"pid": ...}, the start message, and each reply, one JSON object per line.
"""

import json
import os
import sys
import time

SMOKE = [
    {"op": "exec", "command": "mkdir -p /app/www && echo yggdrasil > /app/www/index.html"},
    {
        "op": "exec",
        "command": "printf '#!/bin/sh\\nexec python3 -m http.server 3000 --bind 0.0.0.0 --directory /app/www\\n'"
        " > /app/start.sh && chmod +x /app/start.sh",
    },
    {"op": "spend", "usd": 0.0},
    {"op": "selfcheck"},
    {"op": "done"},
]


def main() -> int:
    if sys.argv[1:] == ["smoke"]:
        script, transcript = SMOKE, None
    else:
        script, transcript = json.load(open(sys.argv[1])), open(sys.argv[2], "a")

    def record(obj):
        if transcript:
            transcript.write(json.dumps(obj) + "\n")
            transcript.flush()

    record({"pid": os.getpid()})
    record(json.loads(sys.stdin.readline()))
    for n, step in enumerate(script):
        if "sleep" in step:
            time.sleep(step["sleep"])
        elif "exit" in step:
            return step["exit"]
        else:
            print(json.dumps({"id": n, **step}), flush=True)
            reply = json.loads(sys.stdin.readline())
            record(reply)
            if step["op"] == "selfcheck" and transcript is None and not reply.get("passed"):
                print(f"self-check failed: {reply}", file=sys.stderr)
            if step["op"] == "done":
                return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
