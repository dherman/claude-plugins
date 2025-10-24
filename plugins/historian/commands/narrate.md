---
description: Rewrite git commit sequence to create a clean, readable branch
argument-hint: [changeset-description]
allowed-tools: Task, Bash, Read
---

# Narrate Git Commits

You are the trampoline coordinator for rewriting git commit sequences. You launch two agents in parallel and coordinate their execution by monitoring their status and handling user questions.

## Input

The changeset description provided: **$ARGUMENTS**

## Architecture Overview

This command uses a **trampoline pattern** with file-based IPC:

1. Create a work directory in `/tmp/historian-{timestamp}/`
2. Launch **narrator** and **scribe** agents in parallel
3. Monitor both agents' status files
4. When either agent writes a question, present it to the user
5. Write the user's answer back to the agent
6. Wait for narrator to signal completion
7. Report results to user

See [docs/ipc-protocol.md](../docs/ipc-protocol.md) for details.

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

echo "Work directory created: $WORK_DIR"
```

### Step 2: Launch Both Agents in Parallel

Start narrator and scribe simultaneously:

```bash
# Launch narrator agent
Task(
  subagent_type: "historian:narrator",
  description: "Narrate git commits",
  prompt: "Work directory: $WORK_DIR
Changeset: $ARGUMENTS"
) &
NARRATOR_PID=$!

# Launch scribe agent
Task(
  subagent_type: "historian:scribe",
  description: "Write commits",
  prompt: "Work directory: $WORK_DIR"
) &
WRITER_PID=$!

echo "Both agents launched in parallel"
```

### Step 3: Trampoline Loop

Monitor agents and handle questions:

```bash
while true; do
  # Check for narrator question
  if [ -f "$WORK_DIR/narrator/question" ]; then
    # Read the question
    source "$WORK_DIR/narrator/question"

    # Present to user
    echo ""
    echo "Question from narrator:"
    echo "$CONTEXT"
    echo ""

    # Show plan if included
    if [ -n "$PLAN" ]; then
      echo "Commit Plan:"
      echo "$PLAN"
      echo ""
    fi

    # Show options
    echo "1) $OPTION_1"
    [ -n "$OPTION_2" ] && echo "2) $OPTION_2"
    [ -n "$OPTION_3" ] && echo "3) $OPTION_3"
    echo ""

    # Get user's choice
    read -p "Your choice (1-3): " CHOICE

    # Map choice to option name
    case "$CHOICE" in
      1) ANSWER="Option 1" ;;
      2) ANSWER="Option 2" ;;
      3) ANSWER="Option 3" ;;
      *) ANSWER="Option 1" ;;  # Default
    esac

    # Write answer
    echo "ANSWER=$ANSWER" > "$WORK_DIR/narrator/answer"
    rm "$WORK_DIR/narrator/question"

    echo "Answer sent to narrator"
  fi

  # Check for scribe question
  if [ -f "$WORK_DIR/scribe/question" ]; then
    # Read the question
    source "$WORK_DIR/scribe/question"

    # Present to user
    echo ""
    echo "Question from scribe:"
    echo "$CONTEXT"
    echo ""
    echo "1) $OPTION_1"
    [ -n "$OPTION_2" ] && echo "2) $OPTION_2"
    [ -n "$OPTION_3" ] && echo "3) $OPTION_3"
    echo ""

    # Get user's choice
    read -p "Your choice (1-3): " CHOICE

    # Map choice to option name
    case "$CHOICE" in
      1) ANSWER="Option 1" ;;
      2) ANSWER="Option 2" ;;
      3) ANSWER="Option 3" ;;
      *) ANSWER="Option 1" ;;  # Default
    esac

    # Write answer
    echo "ANSWER=$ANSWER" > "$WORK_DIR/scribe/answer"
    rm "$WORK_DIR/scribe/question"

    echo "Answer sent to scribe"
  fi

  # Check if narrator is done
  if [ -f "$WORK_DIR/narrator/status" ]; then
    STATUS=$(cat "$WORK_DIR/narrator/status")

    if [ "$STATUS" = "done" ]; then
      # Wait for scribe to shut down
      while [ -f "$WORK_DIR/scribe/status" ] && [ "$(cat "$WORK_DIR/scribe/status")" != "done" ]; do
        sleep 1
      done

      echo "Both agents completed successfully"
      break
    fi

    if [ "$STATUS" = "error" ]; then
      echo "ERROR: Narrator encountered an error"

      # Kill scribe
      kill $WRITER_PID 2>/dev/null

      # Read transcript for details
      if [ -f "$WORK_DIR/transcript.log" ]; then
        echo ""
        echo "Transcript:"
        tail -20 "$WORK_DIR/transcript.log"
      fi

      exit 1
    fi
  fi

  # Check if agents crashed
  if ! kill -0 $NARRATOR_PID 2>/dev/null; then
    echo "ERROR: Narrator agent crashed"
    kill $WRITER_PID 2>/dev/null
    exit 1
  fi

  if ! kill -0 $WRITER_PID 2>/dev/null; then
    echo "ERROR: Scribe agent crashed"
    kill $NARRATOR_PID 2>/dev/null
    exit 1
  fi

  # Sleep before next check
  sleep 1
done
```

### Step 4: Report Results

Read the final state and report to user:

```bash
# Wait for agents to fully exit
wait $NARRATOR_PID
wait $WRITER_PID

# Read final state
if [ -f "$WORK_DIR/state.json" ]; then
  # Extract values from state.json
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

## Error Handling

### Agent Crashes

If either agent crashes:
1. Kill the other agent
2. Show transcript tail for debugging
3. Exit with error

### User Cancellation

If user chooses to cancel (e.g., rejects commit plan):
- Narrator will clean up (delete clean branch, return to original branch)
- Both agents will exit
- Report cancellation to user

### Timeouts

If agents get stuck (optional enhancement):
```bash
TIMEOUT=600  # 10 minutes
START_TIME=$(date +%s)

# In trampoline loop, add:
NOW=$(date +%s)
if [ $((NOW - START_TIME)) -gt $TIMEOUT ]; then
  echo "ERROR: Operation timed out after $TIMEOUT seconds"
  kill $NARRATOR_PID $WRITER_PID
  exit 1
fi
```

## Important Notes

### Background Processes

The agents run as background processes (`&`). Use `wait` to ensure they complete before exiting.

### File Polling

Check for question files every second to minimize latency while being CPU-friendly.

### State Management

The `state.json` file is shared between both agents. Don't modify it yourself - just read it for final results.

### Transcript

The transcript log provides a complete record of what happened. Always offer to show it on errors.

### Work Directory Cleanup

The work directory stays in `/tmp` for debugging. Users can manually clean it up if needed, or you could add cleanup logic.

## Example Execution

```
User: /narrate Add user authentication

1. Setup: Create /tmp/historian-20251022-195104/
2. Launch: Start narrator & scribe in parallel
3. Narrator: Validates git, creates clean branch, analyzes changes
4. Narrator: Creates 5-commit plan
5. Narrator: Writes question file
6. Trampoline: Detects question, asks user
7. User: Chooses "Option 1" (proceed)
8. Trampoline: Writes answer file
9. Narrator: Reads answer, starts execution loop
10. Narrator: Sends request-1 to scribe
11. Scribe: Creates commit 1
12. Scribe: Writes result
13. Narrator: Sends request-2 to scribe
14. Scribe: Detects commit 2 is too large
15. Scribe: Writes question file
16. Trampoline: Detects question, asks user
17. User: Chooses "Option 1" (split by layer)
18. Trampoline: Writes answer file
19. Scribe: Creates 3 split commits
20. Scribe: Writes result
21. ... continues for remaining commits ...
22. Narrator: Validates result, writes "done" status
23. Scribe: Detects narrator done, exits
24. Trampoline: Reports success to user
```

## Expected Outcome

A new git branch with the suffix `-{timestamp}-clean` containing the same changes as the original branch, but organized into logical, well-documented commits that tell a clear story.
