#!/bin/bash
# Narrator setup script - validates git repo and prepares materials
# Usage: narrator-setup.sh <WORK_DIR> <CHANGESET>

set -e

WORK_DIR="$1"
CHANGESET="$2"

# ===== STEP 1: VALIDATE READINESS =====
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [NARRATOR] Validating git repository" >> "$WORK_DIR/transcript.log"

# Check working tree is clean
if ! git diff-index --quiet HEAD --; then
  echo "error" > "$WORK_DIR/narrator/status"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [NARRATOR] ERROR: Working tree not clean" >> "$WORK_DIR/transcript.log"
  exit 1
fi

# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" = "HEAD" ]; then
  echo "error" > "$WORK_DIR/narrator/status"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [NARRATOR] ERROR: Detached HEAD" >> "$WORK_DIR/transcript.log"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [NARRATOR] Git validation passed, on branch: $BRANCH" >> "$WORK_DIR/transcript.log"

# ===== STEP 2: PREPARE MATERIALS =====
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [NARRATOR] Preparing materials" >> "$WORK_DIR/transcript.log"

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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] [NARRATOR] Created clean branch: $CLEAN_BRANCH" >> "$WORK_DIR/transcript.log"

# Output variables for the caller to source
echo "BRANCH=$BRANCH"
echo "CLEAN_BRANCH=$CLEAN_BRANCH"
echo "BASE_COMMIT=$BASE_COMMIT"
echo "TIMESTAMP=$TIMESTAMP"
