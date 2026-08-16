#!/usr/bin/env bash
# Forces an ECS service back onto a known-good task definition revision.
# Called by the deploy workflow when the post-deploy smoke test fails.
# ECS's own deployment circuit breaker (see terraform/modules/ecs) also
# rolls back automatically if a deployment can't reach steady state —
# this script is the explicit, scriptable fallback on top of that.
set -euo pipefail

CLUSTER="${1:?usage: rollback.sh <cluster> <service> <task-definition-arn>}"
SERVICE="${2:?usage: rollback.sh <cluster> <service> <task-definition-arn>}"
TASK_DEFINITION="${3:?usage: rollback.sh <cluster> <service> <task-definition-arn>}"

echo "Rolling back $SERVICE on $CLUSTER to $TASK_DEFINITION"

aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --task-definition "$TASK_DEFINITION" \
  --force-new-deployment \
  --query 'service.{service:serviceName,taskDefinition:taskDefinition,status:status}' \
  --output table

echo "Waiting for rollback to reach steady state..."
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE"

echo "Rollback complete: $SERVICE is now running $TASK_DEFINITION"
