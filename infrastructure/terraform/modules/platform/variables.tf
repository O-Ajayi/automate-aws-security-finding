variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "tables" {
  type = map(object({
    hash_key      = string
    range_key     = optional(string)
    ttl_enabled   = optional(bool, false)
    ttl_attribute = optional(string, "ttl")
    gsis = optional(list(object({
      name      = string
      hash_key  = string
      range_key = optional(string)
    })), [])
  }))
}

variable "state_machine_definition_path" {
  type        = string
  default     = ""
  description = "Optional override for the remediation ASL template. When empty, the default file in services/workflows/ is used."
}

variable "workflow_lambda_function_names" {
  description = "Lambda function names referenced by the remediation state machine ASL template."
  type = object({
    ingestion = string
    generator = string
    validator = string
    approval  = string
    execution = string
    reporting = string
  })
  default = {
    ingestion = "ingestion-service"
    generator = "remediation-generator-service"
    validator = "remediation-validator-service"
    approval  = "approval-service"
    execution = "execution-service"
    reporting = "reporting-service"
  }
}

variable "enable_codepipeline" {
  type    = bool
  default = false
}

variable "github_connection_arn" {
  type    = string
  default = ""
}

variable "github_full_repository_id" {
  type    = string
  default = ""
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "deploy_lambda_functions" {
  type        = bool
  default     = true
  description = "Build and deploy workflow Lambda functions from services/."
}

variable "bedrock_model_id" {
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  description = "Bedrock model ID for remediation plan generation."
}
