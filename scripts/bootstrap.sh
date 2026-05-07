#!/usr/bin/env bash
set -euo pipefail

echo "Installing dependencies..."
npm install --workspace frontend
python3 -m pip install -r services/ingestion-service/requirements.txt
python3 -m pip install -r services/remediation-generator-service/requirements.txt
python3 -m pip install -r services/remediation-validator-service/requirements.txt
python3 -m pip install -r services/approval-service/requirements.txt
python3 -m pip install -r services/execution-service/requirements.txt
python3 -m pip install -r services/reporting-service/requirements.txt

echo "Building workspace..."
npm run build
python3 -m compileall services

echo "Validating Terraform nonprod..."
terraform -chdir=infrastructure/terraform/live/nonprod init -backend=false
terraform -chdir=infrastructure/terraform/live/nonprod validate

echo "Bootstrap complete."
