from typing import Any

from services.shared.shared_utils import assert_safe_script, log, utc_now


def handler(event: dict[str, Any], _context: Any) -> dict[str, Any]:
    plan = event["plan"]
    assert_safe_script(plan["script"])

    if len(plan.get("rollbackScript", "").strip()) <= 10:
        raise ValueError("Rollback guidance is mandatory")

    confidence_score = min(0.99, max(0.5, float(plan.get("confidenceScore", 0.5))))
    result = {
        **plan,
        "confidenceScore": confidence_score,
        "policyStatus": "pass",
        "validatedAt": utc_now(),
    }
    log("INFO", "Validated remediation plan", {"planId": plan["planId"], "confidenceScore": confidence_score})
    return result
