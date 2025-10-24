#!/bin/bash
# Validate that clean branch matches original branch
# Usage: narrator-validate.sh <WORK_DIR> <CLEAN_BRANCH> <ORIGINAL_BRANCH>

set -e

WORK_DIR="$1"
CLEAN_BRANCH="$2"
ORIGINAL_BRANCH="$3"

# Compare tree hashes
git checkout "$CLEAN_BRANCH"
CLEAN_TREE=$(git rev-parse HEAD^{tree})

git checkout "$ORIGINAL_BRANCH"
ORIGINAL_TREE=$(git rev-parse HEAD^{tree})

if [ "$CLEAN_TREE" != "$ORIGINAL_TREE" ]; then
  echo "error" > "$WORK_DIR/narrator/status"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [NARRATOR] ERROR: Branch trees do not match!" >> "$WORK_DIR/transcript.log"
  git diff --stat "$CLEAN_BRANCH" "$ORIGINAL_BRANCH"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [NARRATOR] Validation successful - trees match" >> "$WORK_DIR/transcript.log"
