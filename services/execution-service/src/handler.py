import os
from typing import Any

import boto3

from services.shared.shared_utils import assert_safe_script, log, utc_now

ssm = boto3.client("ssm")
dynamodb = boto3.resource("dynamodb")
execution_table = dynamodb.Table(os.getenv("EXECUTION_HISTORY_TABLE", "execution_history"))


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    assert_safe_script(event["script"])

    response = ssm.send_command(
        InstanceIds=[event["targetInstanceId"]],
        DocumentName="AWS-RunShellScript",
        Parameters={"commands": [event["script"]]},
        TimeoutSeconds=600,
        CloudWatchOutputConfig={"CloudWatchOutputEnabled": True},
    )

    item = {
        "pk": event["findingId"],
        "sk": f"{int(__import__('time').time())}#{event['targetInstanceId']}",
        "commandId": response.get("Command", {}).get("CommandId"),
        "status": "in_progress",
        "correlationId": event["correlationId"],
        "createdAt": utc_now(),
    }
    execution_table.put_item(Item=item)
    log("INFO", "Execution started", item)
    return item
