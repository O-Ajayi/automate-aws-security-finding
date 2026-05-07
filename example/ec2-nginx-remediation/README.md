# EC2 Nginx Remediation Example

This example deploys an EC2 instance with nginx intentionally pinned to an older baseline so that Security Hub can report patch-related findings and the platform can generate and execute a remediation.

## Deploy the Example

```bash
cd example/ec2-nginx-remediation
terraform init
terraform apply -var="admin_cidr=203.0.113.10/32"
```

Capture the output `instance_id`.

## Trigger Finding Ingestion and AI Remediation

1. Ensure the control-plane stack is deployed (`infrastructure/terraform/live/nonprod`).
2. Confirm Security Hub has imported findings for the instance.
3. Trigger ingestion service:

```bash
aws lambda invoke \
  --function-name ingestion-service \
  --payload '{}' \
  /tmp/ingestion-output.json
```

4. Trigger plan generation with finding context:

```bash
aws lambda invoke \
  --function-name remediation-generator-service \
  --payload '{"findingId":"<finding-id>","summary":"Outdated nginx package detected","osVariant":"linux"}' \
  /tmp/generation-output.json
```

5. Validate generated plan:

```bash
aws lambda invoke \
  --function-name remediation-validator-service \
  --payload file:///tmp/generation-output.json \
  /tmp/validation-output.json
```

6. Approve remediation:

```bash
aws lambda invoke \
  --function-name approval-service \
  --payload '{"findingId":"<finding-id>","planId":"<plan-id>","action":"approve","actor":"secops@example.com","role":"security_admin"}' \
  /tmp/approval-output.json
```

7. Execute remediation through SSM:

```bash
aws lambda invoke \
  --function-name execution-service \
  --payload '{"findingId":"<finding-id>","targetInstanceId":"<instance-id>","script":"sudo yum versionlock delete nginx* && sudo dnf update -y nginx && sudo systemctl restart nginx","roleArn":"arn:aws:iam::<acct-id>:role/SecurityHubIngestionRole","correlationId":"manual-demo-001"}' \
  /tmp/execution-output.json
```

8. Run reporting aggregation:

```bash
aws lambda invoke \
  --function-name reporting-service \
  --payload '{}' \
  /tmp/report-output.json
```

## Verify Remediation

Use SSM Run Command history or connect via SSM Session Manager and check:

```bash
nginx -v
sudo systemctl status nginx --no-pager
```

## Tear Down

```bash
terraform destroy -var="admin_cidr=203.0.113.10/32"
```
