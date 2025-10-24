---
name: Rewriting Git Commits
description: Rewrites a git commit sequence for a changeset to create a clean branch with commits optimized for readability and review
allowed-tools: Task, Bash, Read, Write, AskUserQuestion
---

# Rewriting Git Commits Skill

You are the trampoline coordinator for rewriting git commit sequences. You launch two agents in parallel and coordinate their execution by monitoring their status and handling user questions.

## Input

The changeset description: **$PROMPT**

## Architecture Overview

This skill uses a **trampoline pattern** with file-based IPC:

1. Create a work directory in `/tmp/historian-{timestamp}/`
2. Launch **narrator** and **scribe** agents in parallel using Task tool
3. Poll both agents' status files using bash
4. When either agent writes a question file, ask the user
5. Write the user's answer back to the agent's answer file
6. Wait for narrator to signal completion
7. Report results to user

See [docs/ipc-protocol.md](../../docs/ipc-protocol.md) for the complete IPC protocol.

## Your Task

### Step 1: Setup Work Directory

Create the IPC infrastructure using bash:

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

echo "Work directory created: $WORK_DIR"
```

### Step 2: Launch Both Agents in Parallel

**IMPORTANT:** Launch both agents in a **single message** with **two Task tool calls** to run them in parallel:

```
Task(
  subagent_type: "historian:narrator",
  description: "Narrate git commits",
  prompt: "Work directory: $WORK_DIR
Changeset: $PROMPT"
)

Task(
  subagent_type: "historian:scribe",
  description: "Write commits",
  prompt: "Work directory: $WORK_DIR"
)
```

Both agents will now run in parallel. They will communicate via files in `$WORK_DIR`.

### Step 3: Trampoline Loop

After launching both agents, enter a polling loop to monitor their status and handle questions.

**IMPORTANT:** Use Bash tool with a while loop to poll the filesystem:

```bash
WORK_DIR="/tmp/historian-{timestamp}"  # Use actual timestamp from Step 1

while true; do
  # Check for narrator question
  if [ -f "$WORK_DIR/narrator/question" ]; then
    # Read the question file
    source "$WORK_DIR/narrator/question"

    # Store question details for user interaction
    echo "NARRATOR_QUESTION_FOUND=true" > /tmp/narrator_question_flag
    echo "CONTEXT=$CONTEXT" > /tmp/narrator_question_data
    echo "PLAN=$PLAN" >> /tmp/narrator_question_data
    echo "OPTION_1=$OPTION_1" >> /tmp/narrator_question_data
    echo "OPTION_2=$OPTION_2" >> /tmp/narrator_question_data
    echo "OPTION_3=$OPTION_3" >> /tmp/narrator_question_data

    # Exit loop to ask user
    break
  fi

  # Check for scribe question
  if [ -f "$WORK_DIR/scribe/question" ]; then
    # Read the question file
    source "$WORK_DIR/scribe/question"

    # Store question details for user interaction
    echo "SCRIBE_QUESTION_FOUND=true" > /tmp/scribe_question_flag
    echo "CONTEXT=$CONTEXT" > /tmp/scribe_question_data
    echo "OPTION_1=$OPTION_1" >> /tmp/scribe_question_data
    echo "OPTION_2=$OPTION_2" >> /tmp/scribe_question_data
    echo "OPTION_3=$OPTION_3" >> /tmp/scribe_question_data

    # Exit loop to ask user
    break
  fi

  # Check if narrator is done
  if [ -f "$WORK_DIR/narrator/status" ]; then
    STATUS=$(cat "$WORK_DIR/narrator/status")

    if [ "$STATUS" = "done" ]; then
      echo "NARRATOR_DONE=true" > /tmp/narrator_status
      break
    fi

    if [ "$STATUS" = "error" ]; then
      echo "NARRATOR_ERROR=true" > /tmp/narrator_status
      break
    fi
  fi

  # Sleep before next check
  sleep 1
done
```

### Step 4: Handle Questions or Completion

After the polling loop exits, check what triggered it:

**If narrator question found:**

1. Read the question data from `/tmp/narrator_question_data`
2. Use AskUserQuestion tool to present the question to the user
3. Format the question nicely, showing:
   - The CONTEXT
   - The PLAN (if present)
   - The numbered options
4. Get the user's choice (1, 2, or 3)
5. Map the choice to "Option 1", "Option 2", or "Option 3"
6. Write the answer using bash:
   ```bash
   echo "ANSWER=Option 1" > "$WORK_DIR/narrator/answer"
   rm "$WORK_DIR/narrator/question"
   ```
7. Go back to Step 3 (polling loop)

**If scribe question found:**

1. Read the question data from `/tmp/scribe_question_data`
2. Use AskUserQuestion tool to present the question
3. Get the user's choice
4. Write the answer using bash:
   ```bash
   echo "ANSWER=Option 1" > "$WORK_DIR/scribe/answer"
   rm "$WORK_DIR/scribe/question"
   ```
5. Go back to Step 3 (polling loop)

**If narrator done:**

1. Wait for scribe to finish:
   ```bash
   while [ -f "$WORK_DIR/scribe/status" ] && [ "$(cat "$WORK_DIR/scribe/status")" != "done" ]; do
     sleep 1
   done
   ```
2. Read final state and report results (see Step 5)

**If narrator error:**

1. Read transcript for details:
   ```bash
   if [ -f "$WORK_DIR/transcript.log" ]; then
     tail -20 "$WORK_DIR/transcript.log"
   fi
   ```
2. Report error to user
3. Exit

### Step 5: Report Results

Once both agents are done, read the final state and report to user:

```bash
# Read final state
if [ -f "$WORK_DIR/state.json" ]; then
  ORIGINAL_BRANCH=$(jq -r '.original_branch' "$WORK_DIR/state.json")
  CLEAN_BRANCH=$(jq -r '.clean_branch' "$WORK_DIR/state.json")
  COMMITS_CREATED=$(jq -r '.commits_created' "$WORK_DIR/state.json")

  echo ""
  echo "✅ Successfully created clean branch!"
  echo ""
  echo "Original branch: $ORIGINAL_BRANCH"
  echo "Clean branch: $CLEAN_BRANCH"
  echo "Commits created: $COMMITS_CREATED"
  echo ""
  echo "To review the commits:"
  echo "  git log $CLEAN_BRANCH"
  echo ""
  echo "To switch to the clean branch:"
  echo "  git checkout $CLEAN_BRANCH"
  echo ""
  echo "Transcript saved to: $WORK_DIR/transcript.log"
fi
```

## Important Implementation Notes

### Parallel Agent Launch

**CRITICAL:** To launch agents in parallel, you MUST make both Task tool calls in a **single message**. Do NOT make them in separate messages or they will run sequentially.

Example of correct parallel launch:
```
I'll now launch both agents in parallel.

[Make two Task tool calls in this single message]
```

### Polling Loop Structure

The polling loop runs continuously until:
- A question file appears (narrator or scribe)
- Narrator signals done or error

After handling a question, you must **resume the polling loop** to continue monitoring.

### User Interaction

When asking the user questions:
- Present the context clearly
- Show the commit plan if included
- Number the options (1, 2, 3)
- Map user's numeric choice to "Option N" format for the answer file

### State Management

- Don't modify `state.json` - only read it for final results
- Both agents will update it as they progress
- The final state contains the clean branch name and commit count

### Error Handling

If narrator errors:
- Show the last 20 lines of transcript.log
- Explain what went wrong
- Don't try to continue

### Work Directory

The work directory stays in `/tmp/historian-{timestamp}/` for debugging. Users can inspect:
- `transcript.log` - complete execution log
- `state.json` - current state
- `narrator/status` - narrator status
- `scribe/status` - scribe status

## Example Execution Flow

```
1. User invokes skill: "Add user authentication"
2. Skill: Creates /tmp/historian-20251023-140530/
3. Skill: Launches narrator and scribe in parallel (2 Task calls in 1 message)
4. Skill: Enters polling loop
5. Narrator: Validates git, creates branch, analyzes changes, creates plan
6. Narrator: Writes question file with commit plan
7. Skill: Detects question file in polling loop
8. Skill: Asks user "Do you approve this commit plan?" with options
9. User: Chooses "1" (proceed)
10. Skill: Writes "ANSWER=Option 1" to narrator/answer
11. Skill: Resumes polling loop
12. Narrator: Reads answer, starts sending requests to scribe
13. Scribe: Creates commits one by one
14. Scribe: May write question file if commit too large
15. Skill: Detects scribe question, asks user, writes answer
16. Skill: Resumes polling loop
17. Narrator: Completes all commits, validates, writes "done" status
18. Skill: Detects done status
19. Skill: Waits for scribe to finish
20. Skill: Reports success with branch name and commit count
```

## Expected Outcome

A new git branch with the suffix `-{timestamp}-clean` containing the same changes as the original branch, but organized into logical, well-documented commits that tell a clear story.
