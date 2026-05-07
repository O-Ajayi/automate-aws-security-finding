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
  type    = string
  default = "../../../services/workflows/remediation-orchestration.asl.json"
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
