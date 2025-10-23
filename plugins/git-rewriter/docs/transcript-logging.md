# Transcript Logging

The git-rewriter plugin maintains a detailed transcript log to help with debugging and understanding the control flow between agents.

## Overview

When the git-rewriter runs, it creates a transcript log file in `/tmp` that records all significant events as they happen. Both the `main` and `commit-writer` agents append to this shared log file.

## Log File Location

```
/tmp/git-rewriter-transcript-{timestamp}.log
```

The timestamp format is `YYYYMMDD-HHMMSS`, matching the timestamp used for the clean branch name and master diff file.

## Log Entry Format

Each log entry follows this format:

```
[YYYY-MM-DD HH:MM:SS] [AGENT:agent-name] [EVENT_TYPE] Description
```

### Event Types

**Main Agent Events:**
- `START` - Agent begins execution (initial or resumed)
- `STEP` - Transition between workflow steps
- `INVOKE` - Before calling commit-writer subagent
- `RESULT` - After receiving response from commit-writer
- `QUESTION` - When returning QUESTION to caller
- `ERROR` - When encountering errors
- `COMPLETE` - When returning final SUCCESS/ERROR

**Commit-Writer Agent Events:**
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
[2025-10-22 15:08:14] [AGENT:main] [START] Initial invocation with changeset: Add user authentication
[2025-10-22 15:08:15] [AGENT:main] [STEP] Step 1: Validate Readiness - working tree clean
[2025-10-22 15:08:16] [AGENT:main] [STEP] Step 2: Prepare Materials - created branch feature-auth-20251022-150814-clean
[2025-10-22 15:08:17] [AGENT:main] [STEP] Step 3: Develop the Story - identified 3 main themes
[2025-10-22 15:08:20] [AGENT:main] [STEP] Step 4: Commit plan approved by user - 5 commits planned
[2025-10-22 15:08:21] [AGENT:main] [STEP] Step 5: Execute Plan - starting commit creation
[2025-10-22 15:08:21] [AGENT:main] [INVOKE] Calling git-rewriter:commit-writer for commit 1: Add database schema
[2025-10-22 15:08:21] [AGENT:commit-writer] [START] Creating commit: Add database schema
[2025-10-22 15:08:25] [AGENT:commit-writer] [ANALYZE] Found 3 files, 45 lines changed - size: small
[2025-10-22 15:08:26] [AGENT:commit-writer] [DECIDE] Commit size acceptable, proceeding
[2025-10-22 15:08:34] [AGENT:commit-writer] [COMMIT] Created commit abc123: Add database schema
[2025-10-22 15:08:35] [AGENT:commit-writer] [COMPLETE] Returning SUCCESS
[2025-10-22 15:08:35] [AGENT:main] [RESULT] commit-writer returned SUCCESS - commit hash: abc123
[2025-10-22 15:08:36] [AGENT:main] [INVOKE] Calling git-rewriter:commit-writer for commit 2: Add auth endpoints
[2025-10-22 15:08:56] [AGENT:commit-writer] [START] Creating commit: Add auth endpoints
[2025-10-22 15:09:00] [AGENT:commit-writer] [ANALYZE] Found 18 files, 320 lines changed - size: large
[2025-10-22 15:09:01] [AGENT:commit-writer] [DECIDE] Commit too large, requesting split guidance
[2025-10-22 15:09:02] [AGENT:commit-writer] [QUESTION] Returning QUESTION with 3 split options
[2025-10-22 15:09:02] [AGENT:main] [RESULT] commit-writer returned QUESTION - commit too large
[2025-10-22 15:09:03] [AGENT:main] [QUESTION] Returning QUESTION to caller - waiting for user decision
[2025-10-22 15:12:45] [AGENT:main] [START] Resumed with user answer: Option 1
[2025-10-22 15:12:46] [AGENT:main] [INVOKE] Re-calling git-rewriter:commit-writer for commit 2 with user answer
[2025-10-22 15:12:46] [AGENT:commit-writer] [START] Resumed - splitting commit into 3 parts
[2025-10-22 15:13:00] [AGENT:commit-writer] [COMMIT] Created commit def456: Add auth models
[2025-10-22 15:13:10] [AGENT:commit-writer] [COMMIT] Created commit ghi789: Add auth controllers
[2025-10-22 15:13:20] [AGENT:commit-writer] [COMMIT] Created commit jkl012: Add auth routes
[2025-10-22 15:13:20] [AGENT:commit-writer] [COMPLETE] Returning SUCCESS - 3 commits created
[2025-10-22 15:13:21] [AGENT:main] [RESULT] commit-writer returned SUCCESS - 3 commits created
[2025-10-22 15:13:22] [AGENT:main] [INVOKE] Calling git-rewriter:commit-writer for commit 3: Add tests
[2025-10-22 15:13:22] [AGENT:commit-writer] [START] Creating commit: Add tests
[2025-10-22 15:13:24] [AGENT:commit-writer] [ANALYZE] Found 5 files, 120 lines changed - size: medium
[2025-10-22 15:13:25] [AGENT:commit-writer] [DECIDE] Commit size acceptable, proceeding
[2025-10-22 15:13:30] [AGENT:commit-writer] [COMMIT] Created commit mno345: Add tests
[2025-10-22 15:13:31] [AGENT:commit-writer] [COMPLETE] Returning SUCCESS
[2025-10-22 15:13:31] [AGENT:main] [RESULT] commit-writer returned SUCCESS - commit hash: mno345
[2025-10-22 15:13:32] [AGENT:main] [STEP] Step 6: Validate Results - comparing branches
[2025-10-22 15:13:33] [AGENT:main] [STEP] Step 6: Validation successful - branches match
[2025-10-22 15:13:35] [AGENT:main] [COMPLETE] Returning SUCCESS - 7 commits total
```

## How It Works

### 1. Main Agent Creates Log

In Step 1 (Validate Readiness), the main agent:
1. Generates a timestamp
2. Creates the log file path: `/tmp/git-rewriter-transcript-{timestamp}.log`
3. Writes the first entry: `[timestamp] [AGENT:main] [START] ...`

### 2. Main Agent Passes Log Path

When invoking the commit-writer agent, the main agent includes the transcript log path in the prompt:

```
Create a commit for: "add user authentication logic"
Master diff: /tmp/git-rewriter-master-20251022-150814.diff
Branch: feature/auth-20251022-150814-clean
Transcript: /tmp/git-rewriter-transcript-20251022-150814.log
```

### 3. Commit-Writer Appends to Log

The commit-writer agent:
1. Receives the transcript path from the main agent
2. Appends its own log entries using bash echo or Write tool
3. Logs all significant events during commit creation

### 4. Resume Operations Continue Logging

When resumed after a QUESTION:
- The main agent includes the transcript path in Resume State
- Both agents continue appending to the same log file
- The control flow is fully traceable across resumptions

## Accessing the Transcript

After a git-rewriter run completes, the transcript path is included in the final result:

```
RESULT: SUCCESS
Original branch: feature/auth
Clean branch: feature/auth-20251022-150814-clean
Base commit: abc123
Commits created: 7
Transcript: /tmp/git-rewriter-transcript-20251022-150814.log
```

You can then read the transcript to see exactly what happened:

```bash
cat /tmp/git-rewriter-transcript-20251022-150814.log
```

## Benefits

1. **Debugging**: See exactly where failures occur in the agent workflow
2. **Understanding**: Trace the control flow between main and commit-writer agents
3. **Performance**: Identify slow steps by comparing timestamps
4. **Validation**: Verify that agents are following the expected workflow
5. **Improvement**: Analyze patterns to improve the plugin's instructions

## Implementation Details

Both agents use bash commands to append to the log:

```bash
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [AGENT:main] [STEP] Step 1: Validate Readiness" >> /tmp/git-rewriter-transcript-{timestamp}.log
```

The logging is designed to have minimal performance impact while providing comprehensive visibility into the agent workflow.
