# Transcript Logging

The historian plugin maintains a detailed transcript log to help with debugging and understanding the control flow between agents.

## Overview

When the historian runs, it creates a transcript log file in `/tmp` that records all significant events as they happen. Both the `narrator` and `scribe` agents append to this shared log file.

## Log File Location

```
/tmp/historian-transcript-{timestamp}.log
```

The timestamp format is `YYYYMMDD-HHMMSS`, matching the timestamp used for the clean branch name and master diff file.

## Log Entry Format

Each log entry follows this format:

```
[YYYY-MM-DD HH:MM:SS] [AGENT:agent-name] [EVENT_TYPE] Description
```

### Event Types

**Narrator Agent Events:**
- `START` - Agent begins execution (initial or resumed)
- `STEP` - Transition between workflow steps
- `INVOKE` - Before calling scribe subagent
- `RESULT` - After receiving response from scribe
- `QUESTION` - When returning QUESTION to caller
- `ERROR` - When encountering errors
- `COMPLETE` - When returning final SUCCESS/ERROR

**Scribe Agent Events:**
- `START` - Agent begins execution
- `ANALYZE` - Analysis results about the commit
- `DECIDE` - Decision point (split or proceed)
- `COMMIT` - Successfully created a commit
- `QUESTION` - When returning QUESTION for guidance
- `ERROR` - When encountering errors
- `COMPLETE` - When returning final SUCCESS/ERROR

## Example Transcript

Here's what a typical transcript looks like for a successful run with a question:

```
[2025-10-22 15:08:14] [AGENT:narrator] [START] Initial invocation with changeset: Add user authentication
[2025-10-22 15:08:15] [AGENT:narrator] [STEP] Step 1: Validate Readiness - working tree clean
[2025-10-22 15:08:16] [AGENT:narrator] [STEP] Step 2: Prepare Materials - created branch feature-auth-20251022-150814-clean
[2025-10-22 15:08:17] [AGENT:narrator] [STEP] Step 3: Develop the Story - identified 3 main themes
[2025-10-22 15:08:20] [AGENT:narrator] [STEP] Step 4: Commit plan approved by user - 5 commits planned
[2025-10-22 15:08:21] [AGENT:narrator] [STEP] Step 5: Execute Plan - starting commit creation
[2025-10-22 15:08:21] [AGENT:narrator] [INVOKE] Calling historian:scribe for commit 1: Add database schema
[2025-10-22 15:08:21] [AGENT:scribe] [START] Creating commit: Add database schema
[2025-10-22 15:08:25] [AGENT:scribe] [ANALYZE] Found 3 files, 45 lines changed - size: small
[2025-10-22 15:08:26] [AGENT:scribe] [DECIDE] Commit size acceptable, proceeding
[2025-10-22 15:08:34] [AGENT:scribe] [COMMIT] Created commit abc123: Add database schema
[2025-10-22 15:08:35] [AGENT:scribe] [COMPLETE] Returning SUCCESS
[2025-10-22 15:08:35] [AGENT:narrator] [RESULT] scribe returned SUCCESS - commit hash: abc123
[2025-10-22 15:08:36] [AGENT:narrator] [INVOKE] Calling historian:scribe for commit 2: Add auth endpoints
[2025-10-22 15:08:56] [AGENT:scribe] [START] Creating commit: Add auth endpoints
[2025-10-22 15:09:00] [AGENT:scribe] [ANALYZE] Found 18 files, 320 lines changed - size: large
[2025-10-22 15:09:01] [AGENT:scribe] [DECIDE] Commit too large, requesting split guidance
[2025-10-22 15:09:02] [AGENT:scribe] [QUESTION] Returning QUESTION with 3 split options
[2025-10-22 15:09:02] [AGENT:narrator] [RESULT] scribe returned QUESTION - commit too large
[2025-10-22 15:09:03] [AGENT:narrator] [QUESTION] Returning QUESTION to caller - waiting for user decision
[2025-10-22 15:12:45] [AGENT:narrator] [START] Resumed with user answer: Option 1
[2025-10-22 15:12:46] [AGENT:narrator] [INVOKE] Re-calling historian:scribe for commit 2 with user answer
[2025-10-22 15:12:46] [AGENT:scribe] [START] Resumed - splitting commit into 3 parts
[2025-10-22 15:13:00] [AGENT:scribe] [COMMIT] Created commit def456: Add auth models
[2025-10-22 15:13:10] [AGENT:scribe] [COMMIT] Created commit ghi789: Add auth controllers
[2025-10-22 15:13:20] [AGENT:scribe] [COMMIT] Created commit jkl012: Add auth routes
[2025-10-22 15:13:20] [AGENT:scribe] [COMPLETE] Returning SUCCESS - 3 commits created
[2025-10-22 15:13:21] [AGENT:narrator] [RESULT] scribe returned SUCCESS - 3 commits created
[2025-10-22 15:13:22] [AGENT:narrator] [INVOKE] Calling historian:scribe for commit 3: Add tests
[2025-10-22 15:13:22] [AGENT:scribe] [START] Creating commit: Add tests
[2025-10-22 15:13:24] [AGENT:scribe] [ANALYZE] Found 5 files, 120 lines changed - size: medium
[2025-10-22 15:13:25] [AGENT:scribe] [DECIDE] Commit size acceptable, proceeding
[2025-10-22 15:13:30] [AGENT:scribe] [COMMIT] Created commit mno345: Add tests
[2025-10-22 15:13:31] [AGENT:scribe] [COMPLETE] Returning SUCCESS
[2025-10-22 15:13:31] [AGENT:narrator] [RESULT] scribe returned SUCCESS - commit hash: mno345
[2025-10-22 15:13:32] [AGENT:narrator] [STEP] Step 6: Validate Results - comparing branches
[2025-10-22 15:13:33] [AGENT:narrator] [STEP] Step 6: Validation successful - branches match
[2025-10-22 15:13:35] [AGENT:narrator] [COMPLETE] Returning SUCCESS - 7 commits total
```

## How It Works

### 1. Narrator Agent Creates Log

In Step 1 (Validate Readiness), the narrator agent:
1. Generates a timestamp
2. Creates the log file path: `/tmp/historian-transcript-{timestamp}.log`
3. Writes the first entry: `[timestamp] [AGENT:narrator] [START] ...`

### 2. Narrator Agent Passes Log Path

When invoking the scribe agent, the narrator agent includes the transcript log path in the prompt:

```
Create a commit for: "add user authentication logic"
Master diff: /tmp/historian-master-20251022-150814.diff
Branch: feature/auth-20251022-150814-clean
Transcript: /tmp/historian-transcript-20251022-150814.log
```

### 3. Scribe Appends to Log

The scribe agent:
1. Receives the transcript path from the narrator agent
2. Appends its own log entries using bash echo or Write tool
3. Logs all significant events during commit creation

### 4. Resume Operations Continue Logging

When resumed after a QUESTION:
- The narrator agent includes the transcript path in Resume State
- Both agents continue appending to the same log file
- The control flow is fully traceable across resumptions

## Accessing the Transcript

After a historian run completes, the transcript path is included in the final result:

```
RESULT: SUCCESS
Original branch: feature/auth
Clean branch: feature/auth-20251022-150814-clean
Base commit: abc123
Commits created: 7
Transcript: /tmp/historian-transcript-20251022-150814.log
```

You can then read the transcript to see exactly what happened:

```bash
cat /tmp/historian-transcript-20251022-150814.log
```

## Benefits

1. **Debugging**: See exactly where failures occur in the agent workflow
2. **Understanding**: Trace the control flow between narrator and scribe agents
3. **Performance**: Identify slow steps by comparing timestamps
4. **Validation**: Verify that agents are following the expected workflow
5. **Improvement**: Analyze patterns to improve the plugin's instructions

## Implementation Details

Both agents use bash commands to append to the log:

```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AGENT:narrator] [STEP] Step 1: Validate Readiness" >> /tmp/historian-transcript-{timestamp}.log
```

The logging is designed to have minimal performance impact while providing comprehensive visibility into the agent workflow.
