variable "control_account_id" { type = string }
variable "role_name" { type = string default = "SecurityHubIngestionRole" }

resource "aws_iam_role" "spoke" {
  name = var.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.control_account_id}:root" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "spoke" {
  role = aws_iam_role.spoke.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "securityhub:GetFindings",
          "securityhub:BatchUpdateFindings",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      }
    ]
  })
}
