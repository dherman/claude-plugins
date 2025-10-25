#!/bin/bash
# Log a message to the transcript
# Usage: log.sh <AGENT_NAME> <MESSAGE>

# Determine work directory from script location
WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"

AGENT_NAME="$1"
shift
MESSAGE="$*"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$AGENT_NAME] $MESSAGE" >> "$WORK_DIR/transcript.log"
