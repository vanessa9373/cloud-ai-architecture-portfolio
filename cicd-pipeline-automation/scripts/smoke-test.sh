#!/usr/bin/env bash
# Hits the deployed service's health endpoint a handful of times and
# fails (non-zero exit) if it never returns 200. Used by the deploy
# workflow to decide whether to trigger scripts/rollback.sh.
set -euo pipefail

URL="${1:?usage: smoke-test.sh <health-check-url>}"
ATTEMPTS="${SMOKE_TEST_ATTEMPTS:-10}"
SLEEP_SECONDS="${SMOKE_TEST_SLEEP_SECONDS:-6}"

echo "Smoke testing $URL ($ATTEMPTS attempts, ${SLEEP_SECONDS}s apart)..."

for attempt in $(seq 1 "$ATTEMPTS"); do
  status=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL" || echo "000")
  if [ "$status" = "200" ]; then
    echo "Attempt $attempt/$ATTEMPTS: HTTP $status — smoke test passed"
    exit 0
  fi
  echo "Attempt $attempt/$ATTEMPTS: HTTP $status — not healthy yet"
  sleep "$SLEEP_SECONDS"
done

echo "Smoke test FAILED after $ATTEMPTS attempts" >&2
exit 1
