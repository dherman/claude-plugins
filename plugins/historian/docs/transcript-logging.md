# Transcript Logging

The historian plugin maintains a detailed transcript log to help with debugging and understanding the control flow between agents.

## Overview

When the historian runs, it creates a transcript log file in `/tmp` that records all significant events as they happen. Both the `narrator` and `scribe` agents append to this shared log file.

## Log File Location

```
/tmp/historian-{timestamp}/transcript.log
```

The timestamp format is `YYYYMMDD-HHMMSS`, matching the timestamp used for the work directory, clean branch name, and master diff file.

## Log Entry Format

Each log entry follows this format:

```
[YYYY-MM-DD HH:MM:SS] [AGENT:agent-name] [EVENT_TYPE] Description
```

### Event Types

**Narrator Agent Events:**
- `START` - Agent begins execution
- `STEP` - Transition between workflow steps
- `REQUEST` - Before sending request to scribe
- `RESULT` - After receiving result from scribe
- `USER_QUESTION` - When asking user a question via AskUserQuestion
- `USER_ANSWER` - After receiving user's answer
- `ERROR` - When encountering errors
- `COMPLETE` - When marking done/error status

**Scribe Agent Events:**
- `START` - Agent begins execution
- `POLLING` - Waiting for requests (logged periodically)
- `REQUEST_RECEIVED` - New request from narrator
- `ANALYZE` - Analysis results about the commit
- `DECIDE` - Decision point (split or proceed)
- `COMMIT` - Successfully created a commit
- `USER_QUESTION` - When asking user how to split via AskUserQuestion
- `USER_ANSWER` - After receiving user's answer
- `ERROR` - When encountering errors
- `RESULT_SENT` - After writing result file
- `COMPLETE` - When exiting (narrator marked done)

## Example Transcript

Here's what a typical transcript looks like for a successful run where the scribe asks a splitting question:

```
[2025-10-24 15:08:14] [AGENT:narrator] [START] Initial execution with changeset: Add user authentication
[2025-10-24 15:08:15] [AGENT:narrator] [STEP] Step 1: Validate Readiness - working tree clean
[2025-10-24 15:08:16] [AGENT:narrator] [STEP] Step 2: Prepare Materials - created branch feature-auth-20251024-150814-clean
[2025-10-24 15:08:17] [AGENT:narrator] [STEP] Step 3: Develop the Story - identified 3 main themes
[2025-10-24 15:08:18] [AGENT:narrator] [STEP] Step 4: Present the Plan - 5 commits planned
[2025-10-24 15:08:19] [AGENT:narrator] [USER_QUESTION] Asking user to approve commit plan
[2025-10-24 15:08:45] [AGENT:narrator] [USER_ANSWER] User approved: Proceed with this plan
[2025-10-24 15:08:46] [AGENT:narrator] [STEP] Step 5: Execute Plan - starting commit creation
[2025-10-24 15:08:46] [AGENT:narrator] [REQUEST] Sending request to scribe for commit 1: Add database schema
[2025-10-24 15:08:46] [AGENT:scribe] [START] Beginning polling loop
[2025-10-24 15:08:47] [AGENT:scribe] [REQUEST_RECEIVED] Commit 1: Add database schema
[2025-10-24 15:08:47] [AGENT:scribe] [ANALYZE] Found 3 files, 45 lines changed - size: small
[2025-10-24 15:08:48] [AGENT:scribe] [DECIDE] Commit size acceptable, proceeding
[2025-10-24 15:08:54] [AGENT:scribe] [COMMIT] Created commit abc123: Add database schema
[2025-10-24 15:08:55] [AGENT:scribe] [RESULT_SENT] SUCCESS result written to outbox
[2025-10-24 15:08:55] [AGENT:narrator] [RESULT] Received SUCCESS from scribe - commit hash: abc123
[2025-10-24 15:08:56] [AGENT:narrator] [REQUEST] Sending request to scribe for commit 2: Add auth endpoints
[2025-10-24 15:08:56] [AGENT:scribe] [REQUEST_RECEIVED] Commit 2: Add auth endpoints
[2025-10-24 15:09:00] [AGENT:scribe] [ANALYZE] Found 18 files, 320 lines changed - size: large
[2025-10-24 15:09:01] [AGENT:scribe] [DECIDE] Commit too large, asking user how to split
[2025-10-24 15:09:02] [AGENT:scribe] [USER_QUESTION] Asking user to choose split strategy (3 options)
[2025-10-24 15:12:45] [AGENT:scribe] [USER_ANSWER] User chose: Option 1 - Split into models, controllers, routes
[2025-10-24 15:12:46] [AGENT:scribe] [COMMIT] Created commit def456: Add auth models
[2025-10-24 15:12:56] [AGENT:scribe] [COMMIT] Created commit ghi789: Add auth controllers
[2025-10-24 15:13:06] [AGENT:scribe] [COMMIT] Created commit jkl012: Add auth routes
[2025-10-24 15:13:07] [AGENT:scribe] [RESULT_SENT] SUCCESS result written - 3 commits created
[2025-10-24 15:13:07] [AGENT:narrator] [RESULT] Received SUCCESS from scribe - 3 commits created
[2025-10-24 15:13:08] [AGENT:narrator] [REQUEST] Sending request to scribe for commit 3: Add tests
[2025-10-24 15:13:08] [AGENT:scribe] [REQUEST_RECEIVED] Commit 3: Add tests
[2025-10-24 15:13:10] [AGENT:scribe] [ANALYZE] Found 5 files, 120 lines changed - size: medium
[2025-10-24 15:13:11] [AGENT:scribe] [DECIDE] Commit size acceptable, proceeding
[2025-10-24 15:13:16] [AGENT:scribe] [COMMIT] Created commit mno345: Add tests
[2025-10-24 15:13:17] [AGENT:scribe] [RESULT_SENT] SUCCESS result written to outbox
[2025-10-24 15:13:17] [AGENT:narrator] [RESULT] Received SUCCESS from scribe - commit hash: mno345
[2025-10-24 15:13:18] [AGENT:narrator] [STEP] Step 6: Validate Results - comparing branches
[2025-10-24 15:13:19] [AGENT:narrator] [STEP] Step 6: Validation successful - branches match
[2025-10-24 15:13:20] [AGENT:narrator] [COMPLETE] Marked status as done - 7 commits total
[2025-10-24 15:13:20] [AGENT:scribe] [COMPLETE] Narrator marked done, exiting polling loop
```

## How It Works

### 1. Skill Creates Work Directory and Log

In Step 1 (Setup Work Directory), the skill:
1. Generates a timestamp
2. Creates the work directory: `/tmp/historian-{timestamp}/`
3. Creates the log file: `/tmp/historian-{timestamp}/transcript.log`

### 2. Skill Passes Work Directory Path

When launching both agents, the skill includes the work directory path in the prompt:

```
Work directory: /tmp/historian-20251024-150814
Changeset: Add user authentication with OAuth support
```

### 3. Both Agents Append to Log

Both agents:
1. Calculate the transcript path from the work directory
2. Append log entries using bash echo commands
3. Log all significant events during execution

Example bash command used by both agents:
```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AGENT:narrator] [STEP] Description" >> "$WORK_DIR/transcript.log"
```

### 4. Single Execution

Agents run in a single long-lived execution:
- Continuous flow from start to completion
- User interactions happen mid-execution via AskUserQuestion

## Accessing the Transcript

After a historian run completes, the skill reports the transcript location:

```
Success!

Original branch: feature/auth
Clean branch: feature/auth-20251024-150814-clean
Commits created: 7
Transcript: /tmp/historian-20251024-150814/transcript.log
```

You can then read the transcript to see exactly what happened:

```bash
cat /tmp/historian-20251024-150814/transcript.log
```

## Benefits

1. **Debugging**: See exactly where failures occur in the agent workflow
2. **Understanding**: Trace the control flow between narrator and scribe agents
3. **Performance**: Identify slow steps by comparing timestamps
4. **Validation**: Verify that agents are following the expected workflow
5. **User interaction tracking**: See when and why questions were asked
6. **Improvement**: Analyze patterns to improve the plugin's instructions

## Implementation Details

Both agents use simple bash commands to append to the log:

```bash
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] [AGENT:narrator] [STEP] Step 1: Validate Readiness" >> "$WORK_DIR/transcript.log"
```

The logging is designed to have minimal performance impact while providing comprehensive visibility into the agent workflow.
