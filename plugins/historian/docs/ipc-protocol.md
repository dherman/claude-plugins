# File-Based IPC Protocol

The historian plugin uses file-based inter-process communication (IPC) to coordinate between the narrator and scribe agents running in parallel.

## Directory Structure

```
/tmp/historian-{timestamp}/
  ├── transcript.log              # Shared transcript for both agents
  ├── master.diff                 # The full diff of changes
  ├── state.json                  # Shared state (branches, base commit, plan)
  ├── narrator/
  │   ├── status                  # Narrator status: "planning" | "executing" | "done" | "error"
  │   ├── question                # Question for user (created when needed)
  │   └── answer                  # User's answer (created by command/skill)
  └── scribe/
      ├── status                  # Scribe status: "idle" | "working" | "done"
      ├── question                # Question for user (created when needed)
      ├── answer                  # User's answer (created by command/skill)
      ├── inbox/
      │   └── request             # Current request from narrator (only one at a time)
      └── outbox/
          └── result              # Current result to narrator (only one at a time)
```

## File Formats

All files use simple key=value format for easy bash parsing.

### Request File (`scribe/inbox/request`)

```
COMMIT_NUMBER=1
DESCRIPTION=Add class attribute syntax support to parser
```

### Result File (`scribe/outbox/result`)

**For SUCCESS:**
```
STATUS=SUCCESS
COMMIT_HASH=abc123
MESSAGE=Add class attribute syntax support to parser
FILES_CHANGED=5
```

**For ERROR:**
```
STATUS=ERROR
STEP=analyze
DESCRIPTION=Could not parse diff
DETAILS=Error message here
```

### Question File (`narrator/question` or `scribe/question`)

When an agent needs user input, it writes a question file:

```
CONTEXT=This commit is too large (18 files)
OPTION_1=Split into 3 commits: models, controllers, routes
OPTION_2=Split into 2 commits: backend, frontend
OPTION_3=Split into 4 commits: schema, logic, middleware, tests
```

### Answer File (`narrator/answer` or `scribe/answer`)

The command/skill writes the user's answer:

```
ANSWER=Option 1
```

### State File (`state.json`)

```json
{
  "timestamp": "20251022-195104",
  "original_branch": "class-attribute",
  "clean_branch": "class-attribute-20251022-195104-clean",
  "base_commit": "5793b622",
  "total_commits": 15,
  "commits_completed": 0
}
```

## Communication Protocol

### Initialization (Command/Skill)

1. Create work directory: `/tmp/historian-{timestamp}/`
2. Create subdirectories: `narrator/`, `scribe/inbox/`, `scribe/outbox/`
3. Write `state.json` with initial values
4. Launch narrator agent in background
5. Launch scribe agent in background
6. Wait for both agents to complete

### Narrator Agent Workflow

**Step 1: Planning**
```bash
echo "planning" > narrator/status
# Do planning work...
# Update state.json with commit plan
```

**Step 2: Ask User for Plan Approval**
```bash
# Write question for user
cat > question <<EOF
CONTEXT=Created commit plan with 15 commits
PLAN=$(cat state.json | jq -r '.commit_plan')
OPTION_1=Proceed with this plan
OPTION_2=Cancel and return to original branch
EOF

# Wait for answer
while [ ! -f answer ]; do
  sleep 1
done

source answer
rm answer

if [ "$ANSWER" != "Option 1" ]; then
  echo "error" > status
  exit 1
fi
```

**Step 3: Executing**
```bash
echo "executing" > status

for i in 1 2 3 ... N; do
  # Write request
  cat > ../scribe/inbox/request <<EOF
COMMIT_NUMBER=$i
DESCRIPTION=Commit $i description here
EOF

  # Wait for result
  while [ ! -f ../scribe/outbox/result ]; do
    sleep 1
  done

  # Read result
  source ../scribe/outbox/result
  rm ../scribe/outbox/result

  # Handle result
  case "$STATUS" in
    SUCCESS)
      # Log success, continue to next commit
      rm ../scribe/inbox/request
      ;;
    ERROR)
      # Log error, write to status
      echo "error" > status
      exit 1
      ;;
  esac
done
```

**Step 3: Completion**
```bash
echo "done" > narrator/status
```

### Scribe Agent Workflow

**Initialization:**
```bash
echo "idle" > status
```

**Main Loop:**
```bash
while true; do
  # Check if narrator is done
  if [ -f ../narrator/status ] && grep -q "done" ../narrator/status; then
    echo "done" > status
    exit 0
  fi

  # Check for new request
  if [ -f inbox/request ]; then
    echo "working" > status

    # Read request
    source inbox/request

    # Analyze the commit size
    # If too large, ask user how to split

    if [ $FILES_TOO_MANY -eq 1 ]; then
      # Write question for user
      cat > question <<EOF
CONTEXT=Commit $COMMIT_NUMBER is too large (18 files)
OPTION_1=Split into 3 commits: models, controllers, routes
OPTION_2=Split into 2 commits: backend, frontend
OPTION_3=Split into 4 commits: schema, logic, middleware, tests
EOF

      # Wait for answer
      while [ ! -f answer ]; do
        sleep 1
      done

      source answer
      rm answer

      # Create multiple commits based on answer
      # ...
    else
      # Create single commit
      # ...
    fi

    # Write result
    cat > outbox/result <<EOF
STATUS=SUCCESS
COMMIT_HASH=$hash
MESSAGE=$message
FILES_CHANGED=$count
EOF

    echo "idle" > status
  fi

  sleep 1
done
```

### Command/Skill Orchestration

The command/skill acts as a "trampoline" - a top-level loop that coordinates both agents and handles all user interaction.

```bash
# Setup work directory
WORK_DIR="/tmp/historian-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$WORK_DIR/narrator"
mkdir -p "$WORK_DIR/scribe/inbox"
mkdir -p "$WORK_DIR/scribe/outbox"

# Initialize state
cat > "$WORK_DIR/state.json" <<EOF
{
  "timestamp": "$(date +%Y%m%d-%H%M%S)",
  "original_branch": "$(git rev-parse --abbrev-ref HEAD)",
  "work_dir": "$WORK_DIR"
}
EOF

# Launch both agents in parallel using Task tool
# Pass work directory to each agent via prompt
Task(
  subagent_type: "historian:narrator",
  description: "Narrate git commits",
  prompt: "Work directory: $WORK_DIR\nChangeset: $CHANGESET"
) &
NARRATOR_PID=$!

Task(
  subagent_type: "historian:scribe",
  description: "Write commits",
  prompt: "Work directory: $WORK_DIR"
) &
WRITER_PID=$!

# Trampoline loop - coordinate agents and handle user questions
while true; do
  # Check for narrator question
  if [ -f "$WORK_DIR/narrator/question" ]; then
    source "$WORK_DIR/narrator/question"

    # Present question to user with options
    echo "Question from narrator: $CONTEXT"
    echo "1) $OPTION_1"
    echo "2) $OPTION_2"
    [ -n "$OPTION_3" ] && echo "3) $OPTION_3"

    # Get user's choice
    read -p "Your choice: " CHOICE

    # Write answer
    echo "ANSWER=Option $CHOICE" > "$WORK_DIR/narrator/answer"
    rm "$WORK_DIR/narrator/question"
  fi

  # Check for scribe question
  if [ -f "$WORK_DIR/scribe/question" ]; then
    source "$WORK_DIR/scribe/question"

    # Present question to user with options
    echo "Question from scribe: $CONTEXT"
    echo "1) $OPTION_1"
    echo "2) $OPTION_2"
    [ -n "$OPTION_3" ] && echo "3) $OPTION_3"

    # Get user's choice
    read -p "Your choice: " CHOICE

    # Write answer
    echo "ANSWER=Option $CHOICE" > "$WORK_DIR/scribe/answer"
    rm "$WORK_DIR/scribe/question"
  fi

  # Check if narrator is done
  if [ -f "$WORK_DIR/narrator/status" ] && grep -q "done" "$WORK_DIR/narrator/status"; then
    # Wait for scribe to finish
    while [ -f "$WORK_DIR/scribe/status" ] && ! grep -q "done" "$WORK_DIR/scribe/status"; do
      sleep 1
    done
    break
  fi

  # Check for errors
  if [ -f "$WORK_DIR/narrator/status" ] && grep -q "error" "$WORK_DIR/narrator/status"; then
    echo "ERROR: Narrator encountered an error"
    kill $NARRATOR_PID $WRITER_PID 2>/dev/null
    exit 1
  fi

  sleep 1
done

# Both agents done successfully
wait $NARRATOR_PID
wait $WRITER_PID

# Report results to user
source "$WORK_DIR/state.json"
echo "Success! Created clean branch: $clean_branch"
echo "Transcript: $WORK_DIR/transcript.log"
```

## Error Handling

### Timeout Detection
If an agent gets stuck, the command/skill can implement a timeout:
```bash
TIMEOUT=600  # 10 minutes
START_TIME=$(date +%s)

while true; do
  NOW=$(date +%s)
  if [ $((NOW - START_TIME)) -gt $TIMEOUT ]; then
    echo "ERROR: Timeout after $TIMEOUT seconds"
    kill $NARRATOR_PID $WRITER_PID
    exit 1
  fi
  # ... rest of monitoring loop
done
```

### Agent Crash Detection
The command/skill monitors both agent processes:
```bash
if ! kill -0 $NARRATOR_PID 2>/dev/null; then
  echo "ERROR: Narrator agent crashed"
  kill $WRITER_PID
  exit 1
fi
```

## Transcript Logging

Both agents append to the same transcript file:
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AGENT:narrator] [EVENT] Message" >> transcript.log
```

This provides a unified view of the entire workflow.

## Advantages

1. **No agent-to-agent Task calls** - Works around Claude Code limitation where agents cannot invoke other agents
2. **Natural parallelism** - Both agents run simultaneously, coordinated by command/skill trampoline
3. **Direct user communication** - Each agent can ask questions directly without propagating through layers
4. **Simple protocol** - Just files and bash commands, easy to understand and debug
5. **Easy debugging** - Can inspect all IPC files at any point during execution
6. **Stateless communication** - Each request/response is independent
7. **Minimal context overhead** - Agents run in parallel, user's main context is unaffected

## Considerations

1. **Polling overhead** - 1-second sleep intervals are CPU-friendly but add latency
2. **File system reliability** - Assumes atomic file writes (generally safe)
3. **Cleanup** - Files accumulate in /tmp (could add cleanup step)
4. **Concurrency** - Single request/result at a time keeps it simple
