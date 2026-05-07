# Delivery Phases

## Phase 1: Repository Foundation
- Monorepo workspace with `services/*` and `frontend`
- Terraform base module with KMS + DynamoDB + EventBridge + logging
- Shared Python module for models, logging, and command guardrails
- Commands:
  - `npm install`
  - `python3 -m compileall services`

## Phase 2: Ingestion + Data Model + Workflow
- `ingestion-service` Lambda for Security Hub intake and normalization
- DynamoDB tables: `findings_catalog`, `finding_targets`
- Step Functions orchestration ASL added at `services/workflows`
- Commands:
  - `python3 -m compileall services/ingestion-service`
  - `terraform -chdir=infrastructure/terraform/live/nonprod validate`

## Phase 3: AI Generation + Validation
- `remediation-generator-service` invoking Amazon Bedrock
- `remediation-validator-service` deterministic policy and safety checks
- Commands:
  - `python3 -m compileall services/remediation-generator-service`
  - `python3 -m compileall services/remediation-validator-service`

## Phase 4: Execution + SSM Integration
- `execution-service` runs `AWS-RunShellScript` with blocked-command guardrails
- Execution telemetry persisted to `execution_history`
- Commands:
  - `python3 -m compileall services/execution-service`

## Phase 5: Frontend Dashboard
- Next.js operational dashboard with findings/remediation status cards
- Tailwind scaffold for enterprise UI extension
- Commands:
  - `npm run dev --workspace frontend`

## Phase 6: CI/CD + Observability
- AWS CodePipeline/CodeBuild (Terraform-managed) and GitHub Actions CI templates
- Structured JSON logs for all backend handlers
- Commands:
  - `npm run lint`
  - `npm run test`

## Phase 7: Testing + Hardening
- Add deeper unit/integration/contract tests per service
- Add SCP-aligned IAM guardrails and policy tests
- Enable CloudWatch alarms + dashboard resources in Terraform
- Commands:
  - `npm run test`
  - `terraform -chdir=infrastructure/terraform/live/prod plan`
