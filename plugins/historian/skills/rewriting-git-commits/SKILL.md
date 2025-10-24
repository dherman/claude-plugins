---
name: Rewriting Git Commits
description: Rewrites a git commit sequence for a changeset to create a clean branch with commits optimized for readability and review
allowed-tools: Task, Bash, Read, AskUserQuestion
---

# Rewriting Git Commits Skill

You are the trampoline coordinator for rewriting git commit sequences. You launch two agents in parallel and coordinate their execution by monitoring their status and handling user questions.

## CRITICAL: Your Job Doesn't End After Launching Agents

**YOU MUST:**
1. Setup work directory (Step 1)
2. Launch both agents in parallel (Step 2)
3. **IMMEDIATELY START POLLING** (Step 3) - this is where you spend most of your time
4. Keep polling until you find a question or narrator completes
5. Handle questions and resume polling
6. Only finish when narrator signals "done"

**DO NOT:**
1. Terminate after launching agents - you must continue polling
2. Wait for the agents to finish on their own - you must actively monitor them
3. Describe what's happening - just execute the steps

## Input

The changeset description: **$PROMPT**

## Architecture Overview

This skill uses a **trampoline pattern** with file-based IPC:

1. Create a work directory in `/tmp/historian-{timestamp}/`
2. Launch **narrator** and **scribe** agents in parallel using Task tool
3. **Continuously poll** both agents' status files
4. When either agent writes a question file, ask the user
5. Write the user's answer back to the agent's answer file
6. **Resume polling** until agents complete
7. Report final results to user

See [docs/ipc-protocol.md](../../docs/ipc-protocol.md) for the complete IPC protocol.

## Your Task - Execute These Steps

### Step 1: Setup Work Directory

Use Bash to create the IPC infrastructure. Store the WORK_DIR value for use in all subsequent steps.

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
WORK_DIR="/tmp/historian-$TIMESTAMP"
mkdir -p "$WORK_DIR/narrator"
mkdir -p "$WORK_DIR/scribe/inbox"
mkdir -p "$WORK_DIR/scribe/outbox"

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

### Step 2: Launch Both Agents in Parallel

**CRITICAL:** Make TWO Task tool calls in a SINGLE message to run agents in parallel.

Call Task tool with:
- `subagent_type: "historian:narrator"`
- `description: "Narrate git commits"`
- `prompt: "Work directory: {WORK_DIR from step 1}\nChangeset: {$PROMPT}"`

Call Task tool with:
- `subagent_type: "historian:scribe"`
- `description: "Write commits"`
- `prompt: "Work directory: {WORK_DIR from step 1}"`

Both agents will now run in parallel.

### Step 3: Start Polling Loop

**CRITICAL:** After launching both agents, you MUST immediately start polling. You will repeat the polling check over and over until you find a question or the narrator completes.

**DO NOT WAIT. DO NOT DESCRIBE WHAT YOU'RE DOING. START POLLING NOW.**

**Use the Bash tool to run this check script:**

```bash
WORK_DIR="/tmp/historian-{actual-timestamp}"

# Check for narrator question
if [ -f "$WORK_DIR/narrator/question" ]; then
  echo "NARRATOR_QUESTION=true"
  cat "$WORK_DIR/narrator/question"
  exit 0
fi

# Check for scribe question
if [ -f "$WORK_DIR/scribe/question" ]; then
  echo "SCRIBE_QUESTION=true"
  cat "$WORK_DIR/scribe/question"
  exit 0
fi

# Check if narrator is done
if [ -f "$WORK_DIR/narrator/status" ]; then
  STATUS=$(cat "$WORK_DIR/narrator/status")
  if [ "$STATUS" = "done" ]; then
    echo "NARRATOR_DONE=true"
    exit 0
  fi
  if [ "$STATUS" = "error" ]; then
    echo "NARRATOR_ERROR=true"
    exit 0
  fi
fi

# Nothing found, continue polling
sleep 0.2
echo "CONTINUE_POLLING=true"
```

2. **After running the check, IMMEDIATELY check the output and take action:**
   - If output contains `NARRATOR_QUESTION=true`: Go to Step 4 (Handle Narrator Question)
   - If output contains `SCRIBE_QUESTION=true`: Go to Step 5 (Handle Scribe Question)
   - If output contains `NARRATOR_DONE=true`: Go to Step 6 (Report Results)
   - If output contains `NARRATOR_ERROR=true`: Report error and exit
   - If output contains `CONTINUE_POLLING=true`: **IMMEDIATELY GO BACK TO STEP 3.1** (run the check script again - do NOT describe, do NOT wait, just run it again)

**IMPORTANT:** The bash script includes a brief sleep (0.2 seconds) to avoid excessive polling. This provides good responsiveness (checks 5 times per second) while being CPU-friendly.

**YOU WILL RUN THIS CHECK MANY TIMES** - potentially dozens or hundreds of times until something happens. This is expected. Just keep running it.

### Step 4: Handle Narrator Question

When you detect a narrator question:

1. The question file contents were printed by the check script. Parse them to extract:
   - `CONTEXT` - description of the question
   - `PLAN` - the commit plan (may be multi-line)
   - `OPTION_1`, `OPTION_2`, `OPTION_3` - the choices

2. Use AskUserQuestion to present the question:
   - Show the CONTEXT
   - Show the PLAN if present (formatted nicely)
   - Show the numbered options
   - Ask user to choose 1, 2, or 3

3. Map the user's numeric choice to the option text:
   - 1 → "Option 1"
   - 2 → "Option 2"
   - 3 → "Option 3"

4. Write the answer file and remove the question file:

```bash
WORK_DIR="/tmp/historian-{actual-timestamp}"
echo "ANSWER=Option 1" > "$WORK_DIR/narrator/answer"
rm "$WORK_DIR/narrator/question"
```

5. **IMMEDIATELY return to Step 3** to resume polling

### Step 5: Handle Scribe Question

When you detect a scribe question:

1. Parse the question file contents to extract CONTEXT and options

2. Use AskUserQuestion to present the question

3. Map user's choice to "Option N" format

4. Write answer and remove question:

```bash
WORK_DIR="/tmp/historian-{actual-timestamp}"
echo "ANSWER=Option 1" > "$WORK_DIR/scribe/answer"
rm "$WORK_DIR/scribe/question"
```

5. **IMMEDIATELY return to Step 3** to resume polling

### Step 6: Report Results

When narrator is done:

1. Wait for scribe to finish:

```bash
WORK_DIR="/tmp/historian-{actual-timestamp}"
while [ -f "$WORK_DIR/scribe/status" ] && [ "$(cat "$WORK_DIR/scribe/status")" != "done" ]; do
  sleep 1
done
```

2. Read the final state:

```bash
WORK_DIR="/tmp/historian-{actual-timestamp}"
cat "$WORK_DIR/state.json"
```

3. Use Read tool to read the state.json file and extract:
   - `original_branch`
   - `clean_branch`
   - `commits_created`

4. Report success to the user:

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

## Critical Implementation Notes

### Continuous Polling

You MUST continuously poll without waiting. The loop looks like:

1. Run check script
2. If CONTINUE_POLLING → immediately run check script again
3. If question found → handle it, then immediately run check script again
4. If done → report results

Do NOT add delays between checks. Do NOT stop polling until narrator is done.

### Parallel Agent Launch

Launch both agents in ONE message with TWO Task calls. This makes them run in parallel.

### Question File Format

Question files use simple key=value format:
```
CONTEXT=Description here
OPTION_1=First choice
OPTION_2=Second choice
OPTION_3=Third choice
```

For multiline values (like PLAN), they use heredoc format:
```
PLAN<<EOF
Line 1
Line 2
EOF
```

Parse these carefully when presenting to the user.

### Error Handling

If narrator status is "error":
1. Read transcript.log with tail:
   ```bash
   tail -20 "$WORK_DIR/transcript.log"
   ```
2. Show the error to the user
3. Exit

## Example Execution

1. Setup work dir → `/tmp/historian-20251023-140530/`
2. Launch narrator + scribe in parallel (single message, 2 Task calls)
3. Poll: CONTINUE_POLLING → poll again
4. Poll: CONTINUE_POLLING → poll again
5. Poll: NARRATOR_QUESTION found
6. Ask user about commit plan → user chooses "1"
7. Write answer file
8. Poll: CONTINUE_POLLING → poll again
9. Poll: CONTINUE_POLLING → poll again
10. Poll: SCRIBE_QUESTION found (commit too large)
11. Ask user how to split → user chooses "1"
12. Write answer file
13. Poll: CONTINUE_POLLING → poll again (repeat many times)
14. Poll: NARRATOR_DONE found
15. Wait for scribe to finish
16. Report results

The key is **continuous polling** - you keep checking until done.
