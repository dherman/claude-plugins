#!/bin/bash
# Send a commit request to scribe and wait for result
# Usage: narrator-send-request.sh <WORK_DIR> <COMMIT_NUM> <DESCRIPTION>

set -e

WORK_DIR="$1"
COMMIT_NUM="$2"
DESCRIPTION="$3"

"$WORK_DIR/scripts/log.sh" "$WORK_DIR" "NARRATOR" "Requesting commit $COMMIT_NUM: $DESCRIPTION"

# Send request to scribe
cat > "$WORK_DIR/scribe/inbox/request" <<EOF
COMMIT_NUMBER=$COMMIT_NUM
DESCRIPTION=$DESCRIPTION
EOF

# Wait for scribe to complete (poll for result)
while [ ! -f "$WORK_DIR/scribe/outbox/result" ]; do
  sleep 0.5
done

# Read and output result
cat "$WORK_DIR/scribe/outbox/result"
