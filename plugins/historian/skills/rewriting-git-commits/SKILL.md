---
name: Rewriting Git Commits
description: Rewrites a git commit sequence for a changeset to create a clean branch with commits optimized for readability and review
allowed-tools: Task, Bash, Read
---

# Rewriting Git Commits Skill

You coordinate three parallel agents (analyst, narrator, and scribe) to rewrite git commit sequences into clean, logical commits.

## Input

The changeset description: **$PROMPT**

## Your Task

### Step 1: Establish Session ID

Create a unique session ID for the agents to communicate via sidechat:

```bash
# Generate timestamp-based session ID
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SESSION_ID="historian-$TIMESTAMP"

# Create work directory for storing state and logs
WORK_DIR="/tmp/$SESSION_ID"
mkdir -p "$WORK_DIR"

# Initialize state file
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
cat > "$WORK_DIR/state.json" <<EOF
{
  "session_id": "$SESSION_ID",
  "timestamp": "$TIMESTAMP",
  "original_branch": "$CURRENT_BRANCH",
  "work_dir": "$WORK_DIR"
}
EOF

echo "Created session: $SESSION_ID"
echo "Work directory: $WORK_DIR"
```

Save both `$SESSION_ID` and `$WORK_DIR` for later use.

### Step 2: Launch All Three Agents in Parallel

**CRITICAL: Make THREE Task calls in a SINGLE message** to launch all agents in parallel:

```
Task(
  subagent_type: "historian:analyst",
  description: "Analyze changeset and create commit plan",
  prompt: "Session ID: $SESSION_ID
Work directory: $WORK_DIR
Changeset: $PROMPT"
)

Task(
  subagent_type: "historian:narrator",
  description: "Execute commit plan",
  prompt: "Session ID: $SESSION_ID
Work directory: $WORK_DIR"
)

Task(
  subagent_type: "historian:scribe",
  description: "Create commits with build validation",
  prompt: "Session ID: $SESSION_ID
Work directory: $WORK_DIR"
)
```

All three agents will run in parallel, communicating via sidechat:
- **Analyst**: Validates repo, determines build command, creates commit plan, asks you to approve the plan, sends plan to narrator and build config to scribe, then exits
- **Narrator**: Waits for commit plan from analyst, sends commit requests to scribe via sidechat, validates final tree hash (can amend last commit if needed)
- **Scribe**: Waits for build config from analyst, receives commit requests from narrator via sidechat, creates commits, validates builds after each commit, may ask you about splitting large commits

You will **block here** until all agents complete.

### Step 3: Report Results

After all agents complete, read the final state:

```bash
SESSION_ID="historian-{actual-timestamp}"  # Use the actual session ID from Step 1
WORK_DIR="/tmp/$SESSION_ID"
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

### Parallel Agent Coordination

All three agents launch in parallel and coordinate via sidechat (MCP-based message passing):

- **Analyst**:
  - Runs once, exits after sending messages
  - Validates repo and creates clean branch
  - Determines build command (cargo check, tsc --noEmit, etc.)
  - Creates commit plan
  - Asks user to approve plan
  - Sends commit_plan to narrator
  - Sends build_config to scribe
  - Writes "done" status and exits

- **Narrator**:
  - Waits for commit_plan from analyst
  - Executes commit loop by sending requests to scribe
  - Waits for scribe response after each request
  - Validates final tree hash
  - Can amend last commit if trees don't match
  - Writes "done" status and exits

- **Scribe**:
  - Waits for build_config from analyst
  - Continuously receives commit requests from narrator
  - Creates each commit
  - Validates build after each commit (if build_command is not null)
  - Auto-fixes build failures up to 3 times
  - May ask user how to split large commits
  - Exits when narrator signals "done"

### Direct User Interaction

Agents use **AskUserQuestion** when needed:
- **Analyst** asks user to approve commit plan
- **Scribe** may ask how to split large commits
- **Scribe** asks for help after 3 failed build attempts

### Sidechat Communication

Agents communicate via MCP tools (send_message and receive_message):
- **Analyst → Narrator**: commit_plan (branch, base_commit, commits array)
- **Analyst → Scribe**: build_config (build_command or null)
- **Narrator → Scribe**: commit requests (commit_num, description)
- **Scribe → Narrator**: commit results (status, commit_hash, files_changed)

### Build Validation

The scribe validates builds after each commit:
1. Run build command (if not null)
2. If build fails: analyze errors, identify missing hunks from master.diff, apply fixes
3. Amend commit with fixes
4. Retry build (up to 3 attempts total)
5. If still failing: ask user for help via AskUserQuestion
6. Once build passes, send success response to narrator

### Tree Validation

The narrator validates the final tree hash matches:
1. After all commits, compare tree hash of clean branch vs original branch
2. If trees don't match: create remaining.diff, apply it, amend last commit
3. This catches any changes the scribe missed

## Expected Behavior

**Execution flow:**
1. Setup work directory with session ID
2. Launch all three agents in parallel (single message with 3 Task calls)
3. Analyst runs:
   - Creates clean branch and master.diff
   - Determines build command
   - Creates commit plan
   - Asks you "Approve this plan?" → you respond
   - Sends messages to narrator and scribe
   - Exits
4. Narrator and scribe coordinate:
   - Narrator sends commit #1 request
   - Scribe creates commit #1, validates build, responds
   - Narrator sends commit #2 request
   - Scribe creates commit #2, validates build (may fail, auto-fix, retry), responds
   - Scribe may ask you "How to split this commit?" → you respond
   - Repeat for all commits
5. Narrator validates final tree, fixes if needed, writes "done"
6. Scribe detects "done" status and exits
7. You report results
