# Result Protocol

This document defines the standard result protocol used by all agents in the historian plugin.

## Overview

All agents follow a consistent protocol where they return one of three result types: SUCCESS, ERROR, or QUESTION. This enables resumable execution and allows questions to bubble up through the agent hierarchy.

## Three Result Types

### SUCCESS Result

Indicates the operation completed successfully.

**Format:**
```
RESULT: SUCCESS
{key information about what was accomplished}
```

**Example from commit-writer:**
```
RESULT: SUCCESS
Commit: a1b2c3d
Message: refactor: extract user validation into separate module
Files changed: 3
```

**Example from historian:**
```
RESULT: SUCCESS
Original branch: feature/user-profile
Clean branch: feature/user-profile-20251021-143022-clean
Base commit: abc123
Commits created: 7
```

### ERROR Result

Indicates an unrecoverable error occurred.

**Format:**
```
RESULT: ERROR
{Contextual information about where the error occurred}
Description: {clear description of what went wrong}
Details: {any relevant error messages or context}
```

**Example from commit-writer:**
```
RESULT: ERROR
Description: Failed to apply changes from master diff
Details: git apply exited with code 1: patch does not apply
```

**Example from historian:**
```
RESULT: ERROR
Step: 2 (Prepare Materials)
Description: Cannot find base commit for branch
Details: git merge-base returned error - branch may not be connected to main/master
```

### QUESTION Result

Indicates the agent needs user guidance to proceed.

**Format:**
```
RESULT: QUESTION
Context: {description of where you are in the process}
Resume State: {all information needed to resume execution}

{Present the question clearly with context}

Option 1: {description}
Option 2: {description}
Option 3: {description}
[... more options as needed]

What should I do?
```

**Example from commit-writer:**
```
RESULT: QUESTION
Context: Creating commit "add user authentication system"
Resume State:
  - Master diff: /tmp/historian-master-20251021-143022.diff
  - Branch: feature/auth-20251021-143022-clean
  - Commit description: add user authentication system
  - Analysis: Found 23 files across multiple layers

This commit is too large (23 files across authentication, authorization, and session management).

Option 1: Three commits by layer - (1) core auth logic, (2) authorization middleware, (3) session handling
Option 2: Two commits by tier - (1) backend implementation, (2) frontend integration
Option 3: Four commits by component - (1) database schema, (2) auth service, (3) middleware, (4) UI

What approach should I take?
```

**Example from historian:**
```
RESULT: QUESTION
Context: Executing commit plan - commit 3 of 5
Resume State:
  - Step: 5 (Execute Plan)
  - Original branch: feature/user-profile
  - Clean branch: feature/user-profile-20251021-143022-clean
  - Base commit: abc123
  - Master diff: /tmp/historian-master-20251021-143022.diff
  - Commit plan: [detailed plan with 5 commits]
  - Current commit: 3
  - Commits completed: 2
  - Commit-writer question: {nested question from commit-writer}

The commit-writer agent found that commit 3 "add user profile API endpoints" is too large (18 files).

Option 1: Three commits - (1) data models, (2) controller logic, (3) route definitions
Option 2: Two commits - (1) backend API, (2) API documentation
Option 3: Four commits - (1) models, (2) controllers, (3) routes, (4) tests

What approach should I take?
```

## Resume State Requirements

When returning a QUESTION result, agents must include enough state information to resume exactly where they left off. The resume state should include:

### For commit-writer:
- Master diff file path
- Branch name
- Commit description
- Any analysis or partial work completed

### For historian:
- Current step (1-6)
- Original branch name
- Clean branch name
- Base commit hash
- Master diff file path
- Commit plan (if at step 5)
- Current commit index (if at step 5)
- Commits completed so far
- Any nested agent question context

## Re-invoking Agents with Resume Context

This section is for **frontends** (commands and skills) that need to re-invoke agents after receiving a QUESTION result.

### Prompt Template for Resumption

When you receive a QUESTION result from an agent and have obtained the user's answer, re-invoke the agent with this prompt structure:

```
Resume the {agent-name} process.

Resume State:
{paste the entire "Resume State" section from the QUESTION result}

User's Answer: {user's selected option or answer text}

Continue from where you left off.
```

### Example: Resuming historian

**Original QUESTION result:**
```
RESULT: QUESTION
Context: Executing commit plan - commit 3 of 5
Resume State:
  - Step: 5 (Execute Plan)
  - Original branch: feature/user-profile
  - Clean branch: feature/user-profile-20251021-143022-clean
  - Base commit: abc123
  - Master diff: /tmp/historian-master-20251021-143022.diff
  - Commit plan: [detailed plan]
  - Current commit: 3
  - Commits completed: 2

The commit-writer agent found that commit 3 is too large.
Option 1: Three commits by layer
Option 2: Two commits by tier
```

**User selects:** "Option 1"

**Your resume prompt:**
```
Resume the historian process.

Resume State:
  - Step: 5 (Execute Plan)
  - Original branch: feature/user-profile
  - Clean branch: feature/user-profile-20251021-143022-clean
  - Base commit: abc123
  - Master diff: /tmp/historian-master-20251021-143022.diff
  - Commit plan: [detailed plan]
  - Current commit: 3
  - Commits completed: 2

User's Answer: Option 1

Continue from where you left off.
```

### Example: Resuming commit-writer

**Original QUESTION result:**
```
RESULT: QUESTION
Context: Creating commit "add user authentication system"
Resume State:
  - Master diff: /tmp/historian-master-20251021-143022.diff
  - Branch: feature/auth-20251021-143022-clean
  - Commit description: add user authentication system

This commit is too large (23 files).
Option 1: Three commits by layer
Option 2: Two commits by tier
```

**User selects:** "Option 2"

**Your resume prompt:**
```
Resume the commit-writer process.

Resume State:
  - Master diff: /tmp/historian-master-20251021-143022.diff
  - Branch: feature/auth-20251021-143022-clean
  - Commit description: add user authentication system

User's Answer: Option 2

Continue from where you left off.
```

### Key Points for Frontends

1. **Copy the entire Resume State block** from the agent's QUESTION result - don't modify or interpret it
2. **Clearly state the user's answer** - use the exact option label or text the user provided
3. **Use consistent phrasing** - "Resume the {agent} process" and "Continue from where you left off"
4. **Same agent type** - Re-invoke the same agent that returned the QUESTION (don't switch agents)

## How Agents Handle Resumption

This section is for **agents** - see individual agent documentation for specific resumption instructions.

When an agent is re-invoked with resume context:

1. **Detect resumption**: Look for "Resume State" in the input
2. **Parse the resume state**: Extract all saved information
3. **Parse the user's answer**: Understand which option they chose
4. **Jump to the right place**: Skip completed work and resume at the exact point where you paused
5. **Continue execution**: Proceed with the user's guidance
6. **Return normally**: Eventually return SUCCESS or ERROR when complete

Each agent defines its own specific resumption logic - see the "Resuming from QUESTION" section in each agent's documentation.

## Question Flow Through Hierarchy

Questions bubble up through the agent hierarchy:

```
commit-writer (orange)
    ↓ returns QUESTION
historian (cyan)
    ↓ wraps with own resume state, returns QUESTION
command/skill (frontend)
    ↓ presents to user
user
    ↓ provides answer
command/skill
    ↓ invokes historian with resume context + answer
historian
    ↓ invokes commit-writer with resume context + answer
commit-writer
    ↓ continues execution
```

Answers flow back down the same path, with each layer providing the resume context for the layer below.

## Best Practices

1. **Be specific in context**: Clearly describe where you are in the process
2. **Include complete state**: Don't make the caller guess what information you need to resume
3. **Present clear options**: Give the user 2-4 well-described choices
4. **Format consistently**: Always use the exact format shown above so callers can parse results reliably
5. **Don't skip levels**: Each agent should return its own QUESTION result rather than trying to handle nested questions internally
