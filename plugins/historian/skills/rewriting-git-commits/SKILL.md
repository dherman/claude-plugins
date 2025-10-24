---
name: Rewriting Git Commits
description: Rewrites a git commit sequence for a changeset to create a clean branch with commits optimized for readability and review
allowed-tools: Task, Bash, Read, AskUserQuestion
---

# Rewriting Git Commits Skill

You are the trampoline coordinator for rewriting git commit sequences. You repeatedly launch two agents in parallel (fork/join), check for questions after they finish, and restart them in a loop until completion.

## CRITICAL: Fork/Join Execution Model

The Task tool uses **fork/join semantics**:
- When you call Task twice in one message, both agents run in parallel
- **You block until BOTH agents exit**
- Then you regain control and can check for questions

This means:
1. You launch narrator + scribe
2. **WAIT** for both to exit (they do one unit of work and exit)
3. Check if narrator wrote a question file
4. If question: present to user, write answer
5. **RESTART** both agents (goto step 1)
6. Repeat until narrator signals "done"

## Input

The changeset description: **$PROMPT**

## Your Task - Execute This Loop

### Step 1: One-Time Setup

**DO THIS ONCE at the beginning:**

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

**Save $WORK_DIR** - you'll need it in every iteration.

### Step 2: The Main Loop

**YOU MUST REPEAT THIS LOOP until narrator signals "done":**

#### 2.1: Launch Both Agents (Fork/Join)

**Make TWO Task calls in a SINGLE message** to run agents in parallel:

```
Task(
  subagent_type: "historian:narrator",
  description: "Narrator iteration",
  prompt: "Work directory: $WORK_DIR
Changeset: $PROMPT"
)

Task(
  subagent_type: "historian:scribe",
  description: "Scribe iteration",
  prompt: "Work directory: $WORK_DIR"
)
```

**Both agents will:**
- Load their saved state
- Do one unit of work
- Save updated state
- Exit

**You will block here until BOTH agents exit.**

#### 2.2: Check for Questions

After agents finish, check if narrator wrote a question:

```bash
WORK_DIR="/tmp/historian-{actual-timestamp}"

if [ -f "$WORK_DIR/narrator/question" ]; then
  echo "QUESTION_FOUND=true"
  cat "$WORK_DIR/narrator/question"
else
  echo "NO_QUESTION=true"
fi
```

#### 2.3: Handle Question (if found)

If output contains `QUESTION_FOUND=true`:

**CRITICAL: You MUST actually use the AskUserQuestion tool. DO NOT skip this step. DO NOT assume an answer.**

1. Parse the question file contents from the bash output:
   - Extract `CONTEXT`, `PLAN`, `OPTION_1`, `OPTION_2`
   - The PLAN will be in heredoc format between `PLAN<<PLANEOF` and `PLANEOF`

2. **USE THE AskUserQuestion TOOL** to present the question:
   - Format the message clearly
   - Show the CONTEXT
   - Show the PLAN (formatted as a numbered list)
   - Show the two options
   - Ask the user to choose

3. **WAIT for the user's response** from AskUserQuestion

4. Map the user's choice to the answer format and write it:
   ```bash
   WORK_DIR="/tmp/historian-{actual-timestamp}"
   # If user chose option 1: ANSWER="Option 1"
   # If user chose option 2: ANSWER="Option 2"
   echo "ANSWER=Option 1" > "$WORK_DIR/narrator/answer"
   ```

**DO NOT PROCEED** until you have actually asked the user and received their answer.

#### 2.4: Check for Completion

Check if narrator is done:

```bash
WORK_DIR="/tmp/historian-{actual-timestamp}"

if [ -f "$WORK_DIR/narrator/status" ]; then
  cat "$WORK_DIR/narrator/status"
fi
```

If status is "done", go to Step 3 (Report Results).

If status is "error", report error and exit.

Otherwise, **GO BACK TO STEP 2.1** - restart both agents.

### Step 3: Report Results (When Done)

When narrator status is "done":

1. **Read final state:**
   ```bash
   WORK_DIR="/tmp/historian-{actual-timestamp}"
   cat "$WORK_DIR/state.json"
   ```

2. **Use Read tool** to read `$WORK_DIR/state.json` and extract:
   - `original_branch`
   - `clean_branch`
   - `commits_created`

3. **Report success to user:**
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

### The Fork/Join Loop

Your execution looks like:

```
Iteration 1:
  - Launch narrator (init phase) + scribe (idle) → both exit
  - No question
  - Restart

Iteration 2:
  - Launch narrator (planning phase) + scribe (idle) → both exit
  - Question found!
  - Ask user
  - Write answer
  - Restart

Iteration 3:
  - Launch narrator (waiting_for_user) + scribe (idle) → both exit
  - No question (narrator processed answer)
  - Restart

Iteration 4:
  - Launch narrator (executing, sends request 1) + scribe (idle) → both exit
  - No question
  - Restart

Iteration 5:
  - Launch narrator (executing, waiting for result) + scribe (processing request 1) → both exit
  - No question
  - Restart

Iteration 6:
  - Launch narrator (executing, reads result, sends request 2) + scribe (idle) → both exit
  - No question
  - Restart

... many iterations ...

Final iteration:
  - Launch narrator (validating, marks done) + scribe (idle) → both exit
  - Status is "done"
  - Report results
```

**You will do MANY iterations** (potentially 50-100+). This is expected and correct.

### Why This Works

- **Agents are stateful** - they resume from where they left off
- **Agents do incremental work** - one small task per invocation
- **You control the loop** - you can check for questions between iterations
- **Fork/join semantics** - both agents run in parallel, you wait for both

### No Polling Needed

You don't poll in a tight loop. Instead:
1. Launch agents → they do work → they exit
2. You regain control
3. Check for question
4. Launch again

The "loop" is you repeatedly launching the agents, not bash polling.

### State Files

Agents maintain their own state:
- `narrator/state.json` - narrator's progress
- `scribe/state.json` - scribe's progress
- `state.json` - shared final results

You don't need to manage their state - just keep restarting them.

## Example Execution

```
1. Setup work dir: /tmp/historian-20251024-140530/
2. Iteration 1: Launch both → narrator inits, scribe inits → both exit
3. Check: no question, not done
4. Iteration 2: Launch both → narrator plans, scribe waits → both exit
5. Check: question found!
6. Ask user → user chooses "1"
7. Write answer file
8. Iteration 3: Launch both → narrator processes answer, scribe waits → both exit
9. Check: no question, not done
10. Iteration 4: Launch both → narrator sends req 1, scribe waits → both exit
11. Check: no question, not done
12. Iteration 5: Launch both → narrator waits, scribe processes req 1 → both exit
13. Check: no question, not done
14. Iteration 6: Launch both → narrator sends req 2, scribe waits → both exit
... repeat for all 15 commits ...
50. Iteration 47: Launch both → narrator validates, scribe waits → both exit
51. Check: status is "done"
52. Report results to user
```

## Expected Behavior

- **Many short-lived agent invocations** instead of two long-running agents
- **Quick feedback loop** - each iteration takes seconds
- **User questions handled** between iterations
- **Clean state management** via files

This fork/join pattern allows the skill to maintain control and handle user interaction while coordinating the parallel agents.
