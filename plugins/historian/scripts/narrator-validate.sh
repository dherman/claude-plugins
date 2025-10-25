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
  "$WORK_DIR/scripts/log.sh" "$WORK_DIR" "NARRATOR" "ERROR: Branch trees do not match!"
  git diff --stat "$CLEAN_BRANCH" "$ORIGINAL_BRANCH"
  exit 1
fi

"$WORK_DIR/scripts/log.sh" "$WORK_DIR" "NARRATOR" "Validation successful - trees match"
