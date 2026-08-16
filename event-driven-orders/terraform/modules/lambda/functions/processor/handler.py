import json
import os
import boto3
from datetime import datetime, timezone
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")

TABLE_NAME = os.environ["ORDERS_TABLE_NAME"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    results = {"successful": 0, "failed": 0, "errors": []}

    for record in event["Records"]:
        order_id = None
        try:
            order = json.loads(record["body"])
            order_id = order["order_id"]

            # Write to DynamoDB — convert floats to Decimal (DynamoDB requirement)
            table.put_item(
                Item={
                    "order_id": order_id,
                    "customer_id": order["customer_id"],
                    "items": order["items"],
                    "total_amount": Decimal(str(order["total_amount"])),
                    "status": "PROCESSED",
                    "created_at": order["created_at"],
                    "processed_at": datetime.now(timezone.utc).isoformat(),
                },
                ConditionExpression="attribute_not_exists(order_id)",  # idempotency guard
            )

            # Publish confirmation to SNS
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"Order Confirmed: {order_id}",
                Message=json.dumps({
                    "order_id": order_id,
                    "customer_id": order["customer_id"],
                    "total_amount": order["total_amount"],
                    "status": "PROCESSED",
                    "processed_at": datetime.now(timezone.utc).isoformat(),
                }),
                MessageAttributes={
                    "event_type": {
                        "DataType": "String",
                        "StringValue": "ORDER_CONFIRMED",
                    }
                },
            )

            results["successful"] += 1

        except dynamodb.meta.client.exceptions.ConditionalCheckFailedException:
            # Duplicate message — already processed, safe to skip
            results["successful"] += 1

        except Exception as exc:
            results["failed"] += 1
            results["errors"].append({"order_id": order_id, "error": str(exc)})
            # Re-raise so SQS returns the message to the queue → eventually DLQ
            raise

    return results
