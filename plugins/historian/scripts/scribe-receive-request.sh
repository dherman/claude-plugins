#!/bin/bash
# Poll for next update from narrator (either done status or new request)
# Usage: scribe-receive-request.sh
# Exits with 99 if narrator is done (terminate)
# Exits with 0 and outputs request if work received

# Determine work directory from script location
WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"

"$WORK_DIR/scripts/log.sh" "SCRIBE" "Polling for next request from narrator"

# Poll until we get work or narrator finishes
while true; do
  # Check if narrator is done
  if [ -f "$WORK_DIR/narrator/status" ] && grep -q "done" "$WORK_DIR/narrator/status"; then
    "$WORK_DIR/scripts/log.sh" "SCRIBE" "Narrator finished, exiting"
    exit 99  # Special exit code to signal termination
  fi

  # Check for new request
  if [ -f "$WORK_DIR/scribe/inbox/request" ]; then
    # Output the request for the agent to see
    cat "$WORK_DIR/scribe/inbox/request"

    # Log that we got a request
    "$WORK_DIR/scripts/log.sh" "SCRIBE" "Received request"

    # Remove it so we don't process twice
    rm "$WORK_DIR/scribe/inbox/request"

    exit 0
  fi

  # Sleep briefly before checking again
  sleep 0.5
done
