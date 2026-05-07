import os
from collections import Counter
from typing import Any

import boto3

from services.shared.shared_utils import log, utc_now

dynamodb = boto3.resource("dynamodb")
findings_table = dynamodb.Table(os.getenv("FINDINGS_TABLE", "findings_catalog"))
aggregate_table = dynamodb.Table(os.getenv("REPORTING_TABLE", "reporting_aggregates"))


def handler(_event: dict[str, Any], _context: Any) -> dict[str, Any]:
    findings = findings_table.scan().get("Items", [])
    severity_counts = Counter(item.get("severity", "UNKNOWN") for item in findings)

    aggregate = {
        "pk": "daily",
        "sk": utc_now()[:10],
        "findingCountsBySeverity": dict(severity_counts),
        "generatedAt": utc_now(),
    }
    aggregate_table.put_item(Item=aggregate)
    log("INFO", "Reporting aggregate generated", aggregate)
    return aggregate
