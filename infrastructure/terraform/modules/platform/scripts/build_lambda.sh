#!/usr/bin/env bash
set -euo pipefail

SERVICE_DIR="${1:?service directory required}"
OUTPUT_ZIP="${2:?output zip path required}"
SERVICES_ROOT="${3:?services root required}"

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

REQ_FILE="$SERVICES_ROOT/$SERVICE_DIR/requirements.txt"
if [[ -f "$REQ_FILE" ]] && grep -Eq '^[[:space:]]*[A-Za-z0-9]' "$REQ_FILE"; then
  PIP_DISABLE_PIP_VERSION_CHECK=1 python3 -m pip install -r "$REQ_FILE" -t "$BUILD_DIR" --upgrade --quiet
fi

mkdir -p "$BUILD_DIR/services/shared"
cp "$SERVICES_ROOT/shared/shared_utils.py" "$BUILD_DIR/services/shared/"
cp "$SERVICES_ROOT/$SERVICE_DIR/src/handler.py" "$BUILD_DIR/handler.py"

mkdir -p "$(dirname "$OUTPUT_ZIP")"
rm -f "$OUTPUT_ZIP"
(cd "$BUILD_DIR" && zip -rq "$OUTPUT_ZIP" .)
