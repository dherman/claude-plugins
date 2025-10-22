---
name: Rewriting Git Commits
description: Rewrites a git commit sequence for a changeset to create a clean branch with commits optimized for readability and review
allowed-tools: Task
---

# Rewriting Git Commits Skill

This skill is a lightweight frontend that invokes the git-rewriter agent to rewrite commit sequences.

## Your Task

This skill handles the result protocol from the git-rewriter agent and may require multiple invocations to handle user questions.

### Step 1: Initial Invocation

When this skill is invoked with a changeset description:

1. Invoke the git-rewriter agent using Task tool:
   - **subagent_type**: `"git-rewriter:main"`
   - **description**: "Rewrite git commits"
   - **prompt**: Include the changeset description

### Step 2: Handle the Result

The git-rewriter agent returns one of three results:

#### SUCCESS Result
```
RESULT: SUCCESS
Original branch: {branch}
Clean branch: {clean-branch}
Base commit: {hash}
Commits created: {count}
```

**Action**: Report success to the caller with the summary.

#### ERROR Result
```
RESULT: ERROR
Step: {step}
Description: {description}
Details: {details}
```

**Action**: Report the error to the caller.

#### QUESTION Result
```
RESULT: QUESTION
Context: {context}
Resume State: {state}

{Question with options}

Option 1: {description}
Option 2: {description}
Option 3: {description}

What should I do?
```

**Action**:
1. Present the question and options to the user (via your caller)
2. Wait for the user's answer
3. Re-invoke git-rewriter agent following the resumption template in [docs/result-protocol.md](../../docs/result-protocol.md):
   - Use standard format with Resume State and User's Answer
4. Go back to Step 2 to handle the new result

### Step 3: Return Result

Once you receive SUCCESS or ERROR, pass it back to your caller.

## Example

**Simple case:**
```
Input: "Add user authentication with OAuth support"
→ Invoke git-rewriter agent
→ Agent returns SUCCESS
→ Return success to caller
```

**Case with question:**
```
Input: "Add authentication system"
→ Invoke git-rewriter agent
→ Agent returns QUESTION
→ Present question to user (via caller)
→ User answers "Option 1"
→ Re-invoke git-rewriter with resume context
→ Agent returns SUCCESS
→ Return success to caller
```
