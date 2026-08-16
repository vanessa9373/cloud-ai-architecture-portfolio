import json
import os
import uuid
import boto3
from datetime import datetime, timezone

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["INTAKE_QUEUE_URL"]

REQUIRED_FIELDS = {"customer_id", "items", "total_amount"}


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Request body must be valid JSON"})

    missing = REQUIRED_FIELDS - body.keys()
    if missing:
        return _response(400, {"error": f"Missing required fields: {sorted(missing)}"})

    items = body.get("items")
    if not isinstance(items, list) or len(items) == 0:
        return _response(400, {"error": "items must be a non-empty list"})

    total = body.get("total_amount")
    if not isinstance(total, (int, float)) or total <= 0:
        return _response(400, {"error": "total_amount must be a positive number"})

    order_id = f"ORD-{uuid.uuid4().hex[:8].upper()}"
    timestamp = datetime.now(timezone.utc).isoformat()

    message = {
        "order_id": order_id,
        "customer_id": str(body["customer_id"]),
        "items": items,
        "total_amount": float(total),
        "status": "PENDING",
        "created_at": timestamp,
    }

    sqs.send_message(
        QueueUrl=QUEUE_URL,
        MessageBody=json.dumps(message),
        MessageGroupId=str(body["customer_id"]),  # FIFO grouping by customer
        MessageDeduplicationId=order_id,
    )

    return _response(202, {
        "message": "Order accepted",
        "order_id": order_id,
        "status": "PENDING",
        "timestamp": timestamp,
    })


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "X-Request-ID": str(uuid.uuid4()),
        },
        "body": json.dumps(body),
    }
