terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

resource "aws_kms_key" "platform" {
  description             = "KMS key for remediation platform"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.platform.arn
}

resource "aws_dynamodb_table" "tables" {
  for_each         = var.tables
  name             = each.key
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = each.value.hash_key
  range_key        = try(each.value.range_key, null)
  stream_enabled   = false
  ttl {
    attribute_name = try(each.value.ttl_attribute, "ttl")
    enabled        = try(each.value.ttl_enabled, false)
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.platform.arn
  }

  attribute {
    name = each.value.hash_key
    type = "S"
  }
  dynamic "attribute" {
    for_each = try(each.value.range_key, null) == null ? [] : [1]
    content {
      name = each.value.range_key
      type = "S"
    }
  }

  dynamic "global_secondary_index" {
    for_each = try(each.value.gsis, [])
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = try(global_secondary_index.value.range_key, null)
      projection_type = "ALL"
    }
  }
}

resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.name}-${var.environment}-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.platform.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_cloudwatch_event_rule" "ingestion_schedule" {
  name                = "${var.name}-${var.environment}-ingestion"
  schedule_expression = "rate(15 minutes)"
}

resource "aws_apigatewayv2_api" "control_plane" {
  name          = "${var.name}-${var.environment}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.control_plane.id
  name        = "$default"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format          = jsonencode({ requestId = "$context.requestId", status = "$context.status" })
  }
}

resource "aws_iam_role" "step_functions" {
  name = "${var.name}-${var.environment}-sfn-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "step_functions" {
  role = aws_iam_role.step_functions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_sfn_state_machine" "remediation" {
  name       = "${var.name}-${var.environment}-remediation"
  role_arn   = aws_iam_role.step_functions.arn
  type       = "STANDARD"
  definition = file(var.state_machine_definition_path)
  logging_configuration {
    include_execution_data = true
    level                  = "ALL"
    log_destination        = "${aws_cloudwatch_log_group.api.arn}:*"
  }
}

resource "aws_cloudwatch_metric_alarm" "sfn_failures" {
  alarm_name          = "${var.name}-${var.environment}-sfn-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  dimensions = {
    StateMachineArn = aws_sfn_state_machine.remediation.arn
  }
}

resource "aws_iam_role" "codebuild" {
  count = var.enable_codepipeline ? 1 : 0
  name  = "${var.name}-${var.environment}-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  count = var.enable_codepipeline ? 1 : 0
  role  = aws_iam_role.codebuild[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_codebuild_project" "platform" {
  count        = var.enable_codepipeline ? 1 : 0
  name         = "${var.name}-${var.environment}-build"
  service_role = aws_iam_role.codebuild[0].arn
  artifacts { type = "CODEPIPELINE" }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOT
version: 0.2
phases:
  install:
    runtime-versions:
      python: 3.12
      nodejs: 22
    commands:
      - pip install -r services/ingestion-service/requirements.txt -r services/remediation-generator-service/requirements.txt -r services/remediation-validator-service/requirements.txt -r services/approval-service/requirements.txt -r services/execution-service/requirements.txt -r services/reporting-service/requirements.txt
      - npm install --workspace frontend
  build:
    commands:
      - PYTHONPYCACHEPREFIX=.pycache python3 -m compileall services
      - python3 -m unittest services/shared/test_shared_utils.py
      - npm run build --workspace frontend
      - terraform -chdir=infrastructure/terraform/live/nonprod init -backend=false
      - terraform -chdir=infrastructure/terraform/live/nonprod validate
artifacts:
  files:
    - '**/*'
EOT
  }
}

resource "aws_iam_role" "codepipeline" {
  count = var.enable_codepipeline ? 1 : 0
  name  = "${var.name}-${var.environment}-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  count = var.enable_codepipeline ? 1 : 0
  role  = aws_iam_role.codepipeline[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.platform[0].arn
      },
      {
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = var.github_connection_arn
      }
    ]
  })
}

resource "aws_codepipeline" "platform" {
  count    = var.enable_codepipeline ? 1 : 0
  name     = "${var.name}-${var.environment}-pipeline"
  role_arn = aws_iam_role.codepipeline[0].arn
  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
    encryption_key {
      id   = aws_kms_key.platform.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_full_repository_id
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "BuildAndValidate"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.platform[0].name
      }
    }
  }
}

data "aws_caller_identity" "current" {}
