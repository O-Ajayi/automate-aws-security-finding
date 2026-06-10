provider "aws" {
  region = "us-east-1"
}

module "platform" {
  source      = "../../modules/platform"
  name        = "ai-remediation-platform"
  environment = "local"
  enable_codepipeline = false
  tables = {
    findings_catalog = {
      hash_key    = "findingId"
      ttl_enabled = false
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
      gsis = [
        { name = "approval-index", hash_key = "approvalState", range_key = "createdAt" }
      ]
    }
    approval_history = {
      hash_key  = "pk"
      range_key = "sk"
    }
    execution_history = {
      hash_key  = "pk"
      range_key = "sk"
      gsis = [
        { name = "status-index", hash_key = "status", range_key = "createdAt" }
      ]
    }
    reporting_aggregates = {
      hash_key  = "pk"
      range_key = "sk"
    }
  }
}
