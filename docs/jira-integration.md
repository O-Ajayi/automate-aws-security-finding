# Security Hub to Jira Automation

## Flow

1. AWS Security Hub emits finding updates.
2. EventBridge rule in the control account captures findings.
3. `ingestion-service` Lambda normalizes and deduplicates findings.
4. Lambda writes to `findings_catalog` and creates Jira issues.

## Required Environment Variables

- `JIRA_BASE_URL` (example: `https://your-domain.atlassian.net`)
- `JIRA_PROJECT_KEY`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`

## EventBridge Rule Example

```json
{
  "source": ["aws.securityhub"],
  "detail-type": ["Security Hub Findings - Imported"]
}
```

## Security Controls

- Store Jira token in AWS Secrets Manager and inject via Lambda environment.
- Restrict Lambda egress through VPC/NAT policy where required.
- Enable CloudTrail and CloudWatch logs for full auditability.
