import base64
import os
from typing import Any

import boto3
import requests
from botocore.exceptions import ClientError

from services.shared.shared_utils import create_correlation_id, log, utc_now

dynamodb = boto3.resource("dynamodb")
securityhub = boto3.client("securityhub")
table = dynamodb.Table(os.getenv("FINDINGS_TABLE", "findings_catalog"))


def normalize(raw: dict[str, Any]) -> dict[str, Any]:
    resource_id = "unknown"
    resources = raw.get("Resources") or []
    if resources:
        resource_id = resources[0].get("Id", "unknown")

    return {
        "findingId": raw["Id"],
        "accountId": raw["AwsAccountId"],
        "region": raw["Region"],
        "resourceId": resource_id,
        "title": raw.get("Title", "Untitled Finding"),
        "description": raw.get("Description", ""),
        "severity": (raw.get("Severity") or {}).get("Label", "LOW"),
        "status": "new",
        "complianceStatus": (raw.get("Compliance") or {}).get("Status"),
        "dedupKey": f"{raw['AwsAccountId']}:{raw['Region']}:{raw.get('GeneratorId', 'na')}:{resource_id}",
        "updatedAt": utc_now(),
    }


def create_jira_ticket(finding: dict[str, Any]) -> None:
    jira_base_url = os.getenv("JIRA_BASE_URL")
    jira_project_key = os.getenv("JIRA_PROJECT_KEY")
    jira_email = os.getenv("JIRA_EMAIL")
    jira_api_token = os.getenv("JIRA_API_TOKEN")
    if not (jira_base_url and jira_project_key and jira_email and jira_api_token):
        return

    auth = base64.b64encode(f"{jira_email}:{jira_api_token}".encode("utf-8")).decode("utf-8")
    payload = {
        "fields": {
            "project": {"key": jira_project_key},
            "summary": f"[{finding['severity']}] {finding['title']}",
            "description": {
                "type": "doc",
                "version": 1,
                "content": [
                    {
                        "type": "paragraph",
                        "content": [
                            {"type": "text", "text": f"{finding['description']}\nResource: {finding['resourceId']}"}
                        ],
                    }
                ],
            },
            "issuetype": {"name": "Task"},
        }
    }
    response = requests.post(
        f"{jira_base_url}/rest/api/3/issue",
        headers={"Authorization": f"Basic {auth}", "Content-Type": "application/json"},
        json=payload,
        timeout=10,
    )
    response.raise_for_status()


def handler(_event: dict[str, Any], _context: Any) -> dict[str, int]:
    correlation_id = create_correlation_id()
    log("INFO", "Starting ingestion workflow", {"correlationId": correlation_id})
    findings = securityhub.get_findings(MaxResults=50).get("Findings", [])
    normalized = [normalize(item) for item in findings]

    ingested = 0
    for finding in normalized:
        try:
            table.put_item(
                Item=finding,
                ConditionExpression="attribute_not_exists(findingId) OR updatedAt < :updatedAt",
                ExpressionAttributeValues={":updatedAt": finding["updatedAt"]},
            )
            create_jira_ticket(finding)
            ingested += 1
        except ClientError as exc:
            if exc.response["Error"]["Code"] != "ConditionalCheckFailedException":
                raise

    log("INFO", "Completed ingestion workflow", {"correlationId": correlation_id, "count": ingested})
    return {"ingested": ingested}
