provider "aws" {
  region = "us-east-1"
}

module "platform" {
  source      = "../../modules/platform"
  name        = "ai-remediation-platform"
  environment = "prod"
  enable_codepipeline        = true
  github_connection_arn      = "arn:aws:codestar-connections:us-east-1:111111111111:connection/replace-me"
  github_full_repository_id  = "replace-me-org/replace-me-repo"
  github_branch              = "main"
  tables = {
    findings_catalog = {
      hash_key = "findingId"
      gsis = [
        { name = "severity-index", hash_key = "severity", range_key = "updatedAt" },
        { name = "status-index", hash_key = "status", range_key = "updatedAt" }
      ]
    }
    finding_targets = {
      hash_key  = "findingId"
      range_key = "targetId"
    }
    remediation_plans = {
      hash_key  = "planId"
      range_key = "findingId"
    }
    approval_history = {
      hash_key  = "pk"
      range_key = "sk"
    }
    execution_history = {
      hash_key  = "pk"
      range_key = "sk"
    }
    reporting_aggregates = {
      hash_key  = "pk"
      range_key = "sk"
    }
  }
}
