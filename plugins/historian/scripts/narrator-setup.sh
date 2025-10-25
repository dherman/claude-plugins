#!/bin/bash
# Narrator setup script - validates git repo and prepares materials
# Usage: narrator-setup.sh <CHANGESET>

set -e

# Determine work directory from script location
WORK_DIR="$(cd "$(dirname "$0")/.." && pwd)"

CHANGESET="$1"

# ===== STEP 1: VALIDATE READINESS =====
"$WORK_DIR/scripts/log.sh" "NARRATOR" "Validating git repository"

# Check working tree is clean
if ! git diff-index --quiet HEAD --; then
  echo "error" > "$WORK_DIR/narrator/status"
  "$WORK_DIR/scripts/log.sh" "NARRATOR" "ERROR: Working tree not clean"
  exit 1
fi

# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "HEAD" ]; then
  echo "error" > "$WORK_DIR/narrator/status"
  "$WORK_DIR/scripts/log.sh" "NARRATOR" "ERROR: Detached HEAD"
  exit 1
fi

"$WORK_DIR/scripts/log.sh" "NARRATOR" "Git validation passed, on branch: $BRANCH"

# ===== STEP 2: PREPARE MATERIALS =====
"$WORK_DIR/scripts/log.sh" "NARRATOR" "Preparing materials"

# Get base commit
BASE_COMMIT=$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main)

# Extract timestamp
TIMESTAMP=$(basename "$WORK_DIR" | sed 's/historian-//')
CLEAN_BRANCH="${BRANCH}-${TIMESTAMP}-clean"

# Create master diff
git diff ${BASE_COMMIT}..HEAD > "$WORK_DIR/master.diff"

# Create clean branch
git checkout -b "$CLEAN_BRANCH" "$BASE_COMMIT"

# Update state.json
cat > "$WORK_DIR/state.json" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "original_branch": "$BRANCH",
  "clean_branch": "$CLEAN_BRANCH",
  "base_commit": "$BASE_COMMIT",
  "work_dir": "$WORK_DIR"
}
EOF

"$WORK_DIR/scripts/log.sh" "NARRATOR" "Created clean branch: $CLEAN_BRANCH"

# Output variables for the caller to source
echo "BRANCH=$BRANCH"
echo "CLEAN_BRANCH=$CLEAN_BRANCH"
echo "BASE_COMMIT=$BASE_COMMIT"
echo "TIMESTAMP=$TIMESTAMP"
