locals {
  services_root = abspath("${path.module}/../../../../services")
  lambda_build_dir = abspath("${path.module}/build")

  lambda_services = {
    ingestion = {
      service_dir   = "ingestion-service"
      function_name = var.workflow_lambda_function_names.ingestion
      timeout       = 60
      environment = {
        FINDINGS_TABLE = aws_dynamodb_table.tables["findings_catalog"].name
      }
    }
    generator = {
      service_dir   = "remediation-generator-service"
      function_name = var.workflow_lambda_function_names.generator
      timeout       = 120
      environment = {
        REMEDIATION_TABLE = aws_dynamodb_table.tables["remediation_plans"].name
        BEDROCK_MODEL_ID  = var.bedrock_model_id
      }
    }
    validator = {
      service_dir   = "remediation-validator-service"
      function_name = var.workflow_lambda_function_names.validator
      timeout       = 30
      environment   = {}
    }
    approval = {
      service_dir   = "approval-service"
      function_name = var.workflow_lambda_function_names.approval
      timeout       = 30
      environment = {
        APPROVAL_HISTORY_TABLE = aws_dynamodb_table.tables["approval_history"].name
      }
    }
    execution = {
      service_dir   = "execution-service"
      function_name = var.workflow_lambda_function_names.execution
      timeout       = 120
      environment = {
        EXECUTION_HISTORY_TABLE = aws_dynamodb_table.tables["execution_history"].name
      }
    }
    reporting = {
      service_dir   = "reporting-service"
      function_name = var.workflow_lambda_function_names.reporting
      timeout       = 60
      environment = {
        FINDINGS_TABLE  = aws_dynamodb_table.tables["findings_catalog"].name
        REPORTING_TABLE = aws_dynamodb_table.tables["reporting_aggregates"].name
      }
    }
  }
}

data "external" "lambda_artifacts" {
  count = var.deploy_lambda_functions ? 1 : 0

  program = ["bash", "${path.module}/scripts/build_all_lambdas_external.sh"]
  query = {
    build_dir     = local.lambda_build_dir
    services_root = local.services_root
    services = jsonencode({
      for key, cfg in local.lambda_services : key => {
        service_dir = cfg.service_dir
        output      = "${local.lambda_build_dir}/${key}.zip"
      }
    })
  }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_platform" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem",
    ]
    resources = [for table in aws_dynamodb_table.tables : table.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "securityhub:GetFindings",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]
    resources = [aws_kms_key.platform.arn]
  }
}

resource "aws_iam_role" "lambda" {
  count              = var.deploy_lambda_functions ? 1 : 0
  name               = "${var.name}-${var.environment}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = var.deploy_lambda_functions ? 1 : 0
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_platform" {
  count  = var.deploy_lambda_functions ? 1 : 0
  name   = "${var.name}-${var.environment}-lambda-platform"
  role   = aws_iam_role.lambda[0].id
  policy = data.aws_iam_policy_document.lambda_platform.json
}

resource "aws_lambda_function" "workflow" {
  for_each = var.deploy_lambda_functions ? local.lambda_services : {}

  function_name = each.value.function_name
  role          = aws_iam_role.lambda[0].arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = each.value.timeout
  memory_size   = 256

  filename         = data.external.lambda_artifacts[0].result["${each.key}_path"]
  source_code_hash = data.external.lambda_artifacts[0].result["${each.key}_hash"]

  environment {
    variables = each.value.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy.lambda_platform,
  ]
}

resource "aws_lambda_permission" "ingestion_schedule" {
  count = var.deploy_lambda_functions ? 1 : 0

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.workflow["ingestion"].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ingestion_schedule.arn
}

resource "aws_cloudwatch_event_target" "ingestion_schedule" {
  count = var.deploy_lambda_functions ? 1 : 0

  rule = aws_cloudwatch_event_rule.ingestion_schedule.name
  arn  = aws_lambda_function.workflow["ingestion"].arn
}
