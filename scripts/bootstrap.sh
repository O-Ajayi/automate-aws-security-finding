#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Installing Node dependencies..."
npm install --workspace frontend

echo "==> Installing Python service dependencies..."
python3 -m pip install --quiet \
  -r services/ingestion-service/requirements.txt \
  -r services/remediation-generator-service/requirements.txt \
  -r services/remediation-validator-service/requirements.txt \
  -r services/approval-service/requirements.txt \
  -r services/execution-service/requirements.txt \
  -r services/reporting-service/requirements.txt

echo "==> Building frontend..."
npm run build

echo "==> Validating Python services..."
python3 -m compileall services
python3 -m unittest services/shared/test_shared_utils.py

if command -v terraform >/dev/null 2>&1; then
  echo "==> Validating Terraform nonprod..."
  terraform -chdir=infrastructure/terraform/live/nonprod init -backend=false
  terraform -chdir=infrastructure/terraform/live/nonprod validate
else
  echo "==> Skipping Terraform validation (terraform not installed)"
fi

echo ""
echo "Bootstrap complete. Start the frontend with:"
echo "  npm run dev --workspace frontend"
