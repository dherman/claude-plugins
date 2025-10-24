---
name: Rewriting Git Commits
description: Rewrites a git commit sequence for a changeset to create a clean branch with commits optimized for readability and review
allowed-tools: Task, Bash, Read
---

# Rewriting Git Commits Skill

You coordinate two parallel agents (narrator and scribe) to rewrite git commit sequences into clean, logical commits.

## Input

The changeset description: **$PROMPT**

## Your Task

### Step 1: Setup Work Directory

Create the IPC infrastructure:

```bash
# Generate timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
WORK_DIR="/tmp/historian-$TIMESTAMP"

# Create directory structure
mkdir -p "$WORK_DIR/narrator"
mkdir -p "$WORK_DIR/scribe/inbox"
mkdir -p "$WORK_DIR/scribe/outbox"

# Initialize state file
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
cat > "$WORK_DIR/state.json" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "original_branch": "$CURRENT_BRANCH",
  "work_dir": "$WORK_DIR"
}
EOF

echo "Created work directory: $WORK_DIR"
```

Save the `$WORK_DIR` value for later use.

### Step 2: Launch Both Agents in Parallel

**Make TWO Task calls in a SINGLE message** to run agents in parallel:

```
Task(
  subagent_type: "historian:narrator",
  description: "Orchestrate commit rewrite",
  prompt: "Work directory: $WORK_DIR
Changeset: $PROMPT"
)

Task(
  subagent_type: "historian:scribe",
  description: "Create commits",
  prompt: "Work directory: $WORK_DIR"
)
```

**Both agents will run to completion.** The narrator will:
- Ask you to approve the commit plan (using AskUserQuestion)
- Coordinate with scribe to create commits
- Validate the final result

The scribe will:
- Wait for commit requests from narrator
- Create each commit
- Possibly ask you how to split large commits (using AskUserQuestion)

You will **block here** until both agents finish.

### Step 3: Report Results

After both agents complete, read the final state:

```bash
WORK_DIR="/tmp/historian-{actual-timestamp}"
cat "$WORK_DIR/state.json"
```

Use the Read tool to read `$WORK_DIR/state.json` and extract:
- `original_branch`
- `clean_branch`
- `commits_created`

Report success to the user:

```
✅ Successfully created clean branch!

Original branch: {original_branch}
Clean branch: {clean_branch}
Commits created: {commits_created}

To review the commits:
  git log {clean_branch}

To switch to the clean branch:
  git checkout {clean_branch}

Transcript saved to: {WORK_DIR}/transcript.log
```

## Architecture Notes

### Parallel Long-Running Agents

Both agents run in **while loops** until completion:
- **Narrator**: Validates → creates plan → asks user → executes commits → validates → done
- **Scribe**: Polls for requests → processes each → polls again → exits when narrator done

### Direct User Interaction

Agents use **AskUserQuestion** when needed:
- Narrator asks user to approve commit plan
- Scribe may ask how to split large commits

### IPC Coordination

Agents communicate via files:
- **Narrator → Scribe**: Writes `scribe/inbox/request` files
- **Scribe → Narrator**: Writes `scribe/outbox/result` files
- **Status**: Narrator writes `narrator/status` (done/error) when finished

### Fork/Join Semantics

When you launch both agents:
1. Both start running simultaneously
2. You block until BOTH complete
3. They may ask you questions mid-execution
4. You wait for those questions and provide answers
5. They continue running
6. Eventually both finish and return control to you

## Expected Behavior

**Execution flow:**
1. Setup work directory
2. Launch narrator + scribe → both running
3. Narrator asks you "Approve this commit plan?" → you respond
4. Narrator + scribe coordinate to create commits
5. Scribe may ask you "How to split this commit?" → you respond
6. Both agents eventually finish
7. You report results
