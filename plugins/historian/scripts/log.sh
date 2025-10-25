#!/bin/bash
# Log a message to the transcript
# Usage: log.sh <WORK_DIR> <AGENT_NAME> <MESSAGE>

WORK_DIR="$1"
AGENT_NAME="$2"
shift 2
MESSAGE="$*"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$AGENT_NAME] $MESSAGE" >> "$WORK_DIR/transcript.log"
