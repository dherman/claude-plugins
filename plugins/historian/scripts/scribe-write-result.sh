#!/bin/bash
# Write result file for narrator
# Usage: scribe-write-result.sh <WORK_DIR> <STATUS> <COMMIT_HASH> <MESSAGE> <FILES_CHANGED>

WORK_DIR="$1"
STATUS="$2"
COMMIT_HASH="$3"
MESSAGE="$4"
FILES_CHANGED="$5"

cat > "$WORK_DIR/scribe/outbox/result" <<EOF
STATUS=$STATUS
COMMIT_HASH=$COMMIT_HASH
MESSAGE=$MESSAGE
FILES_CHANGED=$FILES_CHANGED
EOF

"$WORK_DIR/scripts/log.sh" "$WORK_DIR" "SCRIBE" "Sent result to narrator: $STATUS"
