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

**CRITICAL: Make TWO Task calls in a SINGLE message** to launch both agents in parallel:

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

Both agents will run in parallel:
- **Narrator**: Asks you to approve the commit plan, sends requests to scribe, validates results
- **Scribe**: Polls for requests, creates commits, may ask you about splitting large commits

You will **block here** until both agents complete.

### Step 3: Check if Scribe Needs Restart

After both agents return, check if the work is complete:

```bash
WORK_DIR="/tmp/historian-{actual-timestamp}"

if [ -f "$WORK_DIR/narrator/status" ] && grep -q "done" "$WORK_DIR/narrator/status"; then
  echo "Work complete"
else
  echo "Narrator still working - need to restart scribe"
fi
```

If narrator is **not done**, the scribe must have run out of tokens. Restart it:

```
Task(
  subagent_type: "historian:scribe",
  description: "Create commits (restarted)",
  prompt: "Work directory: $WORK_DIR"
)
```

After the scribe completes, **go back to the beginning of Step 3** and check again.

**Keep repeating Step 3** until the narrator writes "done" to its status file.

The scribe will:
- Poll for commit requests from narrator
- Create each commit
- Possibly ask you how to split large commits (using AskUserQuestion)
- Automatically restart if it runs out of tokens (via your loop)

### Step 4: Report Results

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

### Sequential Agent Launches

Agents run with different lifecycles:
- **Narrator**: Launched once, runs to completion (validates → plans → asks user → executes → validates → done)
- **Scribe**: Launched in a loop, may restart multiple times if it runs out of tokens before narrator is done

### Direct User Interaction

Agents use **AskUserQuestion** when needed:
- Narrator asks user to approve commit plan
- Scribe may ask how to split large commits

### IPC Coordination

Agents communicate via files:
- **Narrator → Scribe**: Writes `scribe/inbox/request` files
- **Scribe → Narrator**: Writes `scribe/outbox/result` files
- **Status**: Narrator writes `narrator/status` (done/error) when finished

### Restart Pattern for Scribe

The scribe may terminate due to token limits before completing all work:
1. Launch narrator first (runs once to completion)
2. Launch scribe in a loop
3. Scribe runs until done or out of tokens
4. If scribe terminates but narrator not done, restart scribe
5. Repeat until narrator writes "done" status
6. Scribe picks up where it left off each time (stateless polling)

## Expected Behavior

**Execution flow:**
1. Setup work directory
2. Launch narrator (blocks until complete)
3. Launch scribe in loop:
   - Scribe polls for requests
   - Narrator asks you "Approve this commit plan?" → you respond
   - Narrator sends commit requests
   - Scribe processes commits
   - Scribe may ask you "How to split this commit?" → you respond
   - If scribe runs out of tokens, it terminates
   - Loop restarts scribe if narrator not done yet
4. Narrator finishes and writes "done"
5. Scribe exits on next check
6. You report results
