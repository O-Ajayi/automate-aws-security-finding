from __future__ import annotations

import json
import random
import re
import string
from datetime import datetime, timezone
from typing import Any

BLOCKED_PATTERNS = [
    re.compile(r"rm\s+-rf", re.IGNORECASE),
    re.compile(r"mkfs", re.IGNORECASE),
    re.compile(r"shutdown", re.IGNORECASE),
    re.compile(r"reboot", re.IGNORECASE),
    re.compile(r"curl.+\|.+bash", re.IGNORECASE),
    re.compile(r"kernel", re.IGNORECASE),
]


def assert_safe_script(script: str) -> None:
    for pattern in BLOCKED_PATTERNS:
        if pattern.search(script):
            raise ValueError(f"Blocked remediation command matched: {pattern.pattern}")


def create_correlation_id() -> str:
    random_suffix = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(8))
    return f"{int(datetime.now(tz=timezone.utc).timestamp())}-{random_suffix}"


def utc_now() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


def log(level: str, message: str, metadata: dict[str, Any] | None = None) -> None:
    payload = {
        "timestamp": utc_now(),
        "level": level,
        "message": message,
    }
    if metadata:
        payload.update(metadata)
    print(json.dumps(payload))
