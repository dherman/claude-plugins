# File-Based IPC Protocol

The historian plugin uses file-based inter-process communication (IPC) for coordination between the narrator and scribe agents running in parallel.

## Directory Structure

```
/tmp/historian-{timestamp}/
  ├── transcript.log              # Shared transcript for both agents
  ├── master.diff                 # The full diff of changes
  ├── state.json                  # Final results written by narrator
  ├── narrator/
  │   └── status                  # Narrator status: "done" | "error"
  └── scribe/
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

### State File (`state.json`)

Written by the narrator at the end with final results:

```json
{
  "timestamp": "20251022-195104",
  "original_branch": "class-attribute",
  "clean_branch": "class-attribute-20251022-195104-clean",
  "base_commit": "5793b622",
  "total_commits": 15,
  "commits_completed": 15
}
```

## Communication Protocol

### Initialization (Skill)

1. Create work directory: `/tmp/historian-{timestamp}/`
2. Create subdirectories: `narrator/`, `scribe/inbox/`, `scribe/outbox/`
3. Initialize `state.json` with basic info
4. Launch narrator and scribe agents **in parallel** using Task tool
5. Wait for both to complete (fork/join semantics)

### Narrator Agent Workflow

The narrator runs a single long-lived execution:

```bash
# Step 1: Validate git repository
# Step 2: Create clean branch and master.diff
# Step 3-4: Analyze changes and create commit plan

# Step 5: Ask user for plan approval using AskUserQuestion

# Step 6-13: Execute commits by coordinating with scribe
for i in 1 2 3 ... N; do
  # Write request
  cat > ../scribe/inbox/request <<EOF
COMMIT_NUMBER=$i
DESCRIPTION=Commit $i description here
EOF

  # Wait for result
  while [ ! -f ../scribe/outbox/result ]; do
    sleep 0.2
  done

  # Read result
  source ../scribe/outbox/result
  rm ../scribe/outbox/result

  # Handle result
  case "$STATUS" in
    SUCCESS)
      rm ../scribe/inbox/request
      ;;
    ERROR)
      echo "error" > status
      exit 1
      ;;
  esac
done

# Step 14: Validate and mark done
echo "done" > narrator/status
```

### Scribe Agent Workflow

The scribe runs a continuous polling loop:

```bash
while true; do
  # Check if narrator is done
  if [ -f ../narrator/status ] && grep -q "done" ../narrator/status; then
    exit 0
  fi

  # Check for new request
  if [ -f inbox/request ]; then
    source inbox/request
    rm inbox/request

    # Analyze commit size
    # If too large, use AskUserQuestion to ask how to split

    # Create commit(s)
    git commit --allow-empty -m "$DESCRIPTION..."

    # Write result
    cat > outbox/result <<EOF
STATUS=SUCCESS
COMMIT_HASH=$hash
MESSAGE=$message
FILES_CHANGED=$count
EOF
  fi

  sleep 0.2
done
```

## User Interaction

Both agents use the `AskUserQuestion` tool when they need user input:

- **Narrator:** Asks for commit plan approval in Step 5
- **Scribe:** Asks how to split large commits when detected

The Task tool's fork/join semantics handle this automatically - it waits for the agents to complete their AskUserQuestion calls and continues execution.

## Transcript Logging

Both agents append to the shared transcript file:

```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AGENT:narrator] [STEP] Description" >> ../transcript.log
```

This provides a unified view of the entire workflow for debugging.

## Advantages

1. **Natural parallelism** - Both agents run simultaneously
2. **Direct user interaction** - Agents use AskUserQuestion
3. **Simple protocol** - Request/result files for coordination
4. **Easy debugging** - Can inspect all IPC files during execution
5. **Stateless coordination** - Each request/response is independent

## Considerations

1. **Polling overhead** - 0.2s sleep intervals balance responsiveness and CPU usage
2. **File system reliability** - Assumes atomic file writes (generally safe)
3. **Cleanup** - Files accumulate in /tmp (manual cleanup or could add to workflow)
4. **Sequential commits** - Single request/result at a time keeps coordination simple
