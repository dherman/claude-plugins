#!/bin/bash
# Write result file for narrator
# Usage: scribe-write-result.sh <STATUS> <COMMIT_HASH> <MESSAGE> <FILES_CHANGED>

# Determine work directory from script location
WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"

STATUS="$1"
COMMIT_HASH="$2"
MESSAGE="$3"
FILES_CHANGED="$4"

cat > "$WORK_DIR/scribe/outbox/result" <<EOF
STATUS=$STATUS
COMMIT_HASH=$COMMIT_HASH
MESSAGE=$MESSAGE
FILES_CHANGED=$FILES_CHANGED
EOF

"$WORK_DIR/scripts/log.sh" "SCRIBE" "Sent result to narrator: $STATUS"
