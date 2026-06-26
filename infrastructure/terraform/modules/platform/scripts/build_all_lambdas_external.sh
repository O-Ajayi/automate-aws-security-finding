#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 - "$INPUT" "$SCRIPT_DIR" <<'PY'
import base64
import hashlib
import json
import subprocess
import sys

payload = json.loads(sys.argv[1])
script_dir = sys.argv[2]
build_dir = payload["build_dir"]
services_root = payload["services_root"]
services = payload["services"]
if isinstance(services, str):
    services = json.loads(services)

import os
os.makedirs(build_dir, exist_ok=True)

result = {}
for key, cfg in services.items():
    output = cfg["output"]
    service_dir = cfg["service_dir"]
    subprocess.run(
        ["bash", f"{script_dir}/build_lambda.sh", service_dir, output, services_root],
        check=True,
    )
    digest = base64.b64encode(hashlib.sha256(open(output, "rb").read()).digest()).decode()
    result[f"{key}_hash"] = digest
    result[f"{key}_path"] = output

print(json.dumps(result))
PY
