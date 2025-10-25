#!/bin/bash
# Check if narrator is done or if there's a request to process
# Usage: scribe-check-work.sh <WORK_DIR>
# Exits with 0 and outputs request if work found
# Exits with 0 and no output if no work (loop again)
# Exits with 99 if narrator is done (terminate)

WORK_DIR="$1"

# Check if narrator is done
if [ -f "$WORK_DIR/narrator/status" ] && grep -q "done" "$WORK_DIR/narrator/status"; then
  "$WORK_DIR/scripts/log.sh" "$WORK_DIR" "SCRIBE" "Narrator finished, exiting"
  exit 99  # Special exit code to signal termination
fi

# Check for new request
if [ -f "$WORK_DIR/scribe/inbox/request" ]; then
  # Output the request for the agent to see
  cat "$WORK_DIR/scribe/inbox/request"

  # Log that we got a request
  "$WORK_DIR/scripts/log.sh" "$WORK_DIR" "SCRIBE" "Processing request"

  # Remove it so we don't process twice
  rm "$WORK_DIR/scribe/inbox/request"

  exit 0
fi

# No work found
exit 0
