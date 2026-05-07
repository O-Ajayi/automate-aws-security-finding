import os
from typing import Any

import boto3

from services.shared.shared_utils import log, utc_now

dynamodb = boto3.resource("dynamodb")
history_table = dynamodb.Table(os.getenv("APPROVAL_HISTORY_TABLE", "approval_history"))


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    if event["role"] not in {"security_admin", "ops_engineer"}:
        raise PermissionError("RBAC denied: role cannot approve plans")

    record = {
        "pk": event["findingId"],
        "sk": f"{int(__import__('time').time())}#{event['actor']}",
        "planId": event["planId"],
        "action": event["action"],
        "actor": event["actor"],
        "role": event["role"],
        "reason": event.get("reason", ""),
        "createdAt": utc_now(),
    }
    history_table.put_item(Item=record)
    log("INFO", "Approval decision persisted", record)
    return {"status": "ok", "record": record}
