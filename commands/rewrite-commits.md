---
description: Rewrite git commit sequence to create a clean, readable branch
argument-hint: [changeset-description]
allowed-tools: Task
---

# Rewrite Git Commits

You are tasked with rewriting a git commit sequence to create a clean branch with well-organized, readable commits.

## Input

The changeset description provided: **$ARGUMENTS**

## Your Task

This is a multi-step process that may require interaction with the user:

### Step 1: Initial Invocation

Invoke the git-rewriter agent using the Task tool:

- **subagent_type**: `"git-rewriter"`
- **description**: "Rewrite git commits"
- **prompt**: "Rewrite the git commit sequence for this changeset: {changeset description from $ARGUMENTS}"

### Step 2: Handle the Result

The git-rewriter agent will return one of three results:

#### SUCCESS Result

If the agent returns SUCCESS:
```
RESULT: SUCCESS
Original branch: {branch}
Clean branch: {clean-branch}
Base commit: {hash}
Commits created: {count}
```

**Action**: Report success to the user with the summary information.

#### ERROR Result

If the agent returns ERROR:
```
RESULT: ERROR
Step: {step}
Description: {description}
Details: {details}
```

**Action**: Report the error to the user and explain what went wrong.

#### QUESTION Result

If the agent returns QUESTION:
```
RESULT: QUESTION
Context: {context}
Resume State: {state information}

{Question text with options}

Option 1: {description}
Option 2: {description}
Option 3: {description}

What should I do?
```

**Action**:
1. Present the question and options clearly to the user
2. Wait for the user's answer
3. Re-invoke the git-rewriter agent with:
   - **subagent_type**: `"git-rewriter"`
   - **description**: "Resume git rewriter"
   - **prompt**: Include the resume state from the QUESTION result and the user's answer
4. Go back to Step 2 to handle the new result

### Step 3: Completion

Once you receive a SUCCESS or ERROR result, you're done.

## Example Flow

### Simple Success Case

```
/rewrite-commits Add user profile feature with avatar support
```

1. Invoke git-rewriter agent
2. Agent returns SUCCESS
3. Report to user: "Successfully created clean branch with 4 commits"

### Case with Question

```
/rewrite-commits Add authentication system
```

1. Invoke git-rewriter agent
2. Agent returns QUESTION about splitting a large commit
3. Present options to user
4. User chooses "Option 1"
5. Re-invoke git-rewriter agent with resume context and answer
6. Agent returns SUCCESS
7. Report to user: "Successfully created clean branch with 6 commits"

## Expected Outcome

A new git branch with the suffix `-{timestamp}-clean` containing the same changes as the original branch, but organized into logical, well-documented commits that tell a clear story.
