---
name: Git Commit Rewriter
description: Rewrites a git commit sequence for a changeset to create a clean branch with commits optimized for readability and review
allowed-tools: Bash, Read, Write, Edit, Task, TodoWrite, Grep, Glob
---

# Git Commit Rewriter Skill

This skill orchestrates the process of rewriting a git commit sequence from a draft changeset into a clean, well-organized series of commits that tell a clear story.

## Overview

The rewriting process takes a changeset (such as a draft pull request) and creates an alternative clean branch with the same net contents, but where the commits are optimized for readability and logical progression.

## Process Steps

### Step 1: Validate Readiness

Before starting, verify:

1. **Clean working tree**: Run `git status` to ensure there are no uncommitted changes
2. **Valid branch**: Confirm we're on a branch (not detached HEAD)
3. **Commits exist**: Verify there are commits to rewrite
4. **No conflicts**: Check that the branch is in a good state

If any validation fails, report the issue to the user and stop.

### Step 2: Prepare Materials

Create the necessary infrastructure for the rewriting process:

1. **Get current branch name**: `git rev-parse --abbrev-ref HEAD`
2. **Generate timestamp**: Use format `YYYYMMDD-HHMMSS`
3. **Create clean branch name**: `{original-branch}-{timestamp}-clean`
4. **Find base commit**: Determine where the changeset diverges from main/master
   - Try: `git merge-base HEAD origin/main`
   - Fallback: `git merge-base HEAD origin/master`
5. **Create master diff file**:
   - Generate diff: `git diff {base-commit}..HEAD > /tmp/git-rewriter-master-{timestamp}.diff`
   - Store the path for use throughout the process
6. **Create clean branch**: `git checkout -b {clean-branch-name} {base-commit}`

### Step 3: Develop the Story

Analyze the changeset to create a narrative structure:

1. **Read the master diff**: Understand all changes being made
2. **Identify key themes**: What are the major conceptual changes?
3. **Determine layers**: What's the logical order of changes?
   - Foundation/infrastructure changes first
   - Core functionality next
   - Polish/refinements last
4. **Consider dependencies**: What must come before what?
5. **Create the story**: Write a narrative description of how the changes should be introduced

The story should be a concise summary (3-10 sentences) that describes the changeset as a series of logical steps.

### Step 4: Create Commit Plan

Based on the story, create a detailed commit plan:

1. **Break into commits**: Divide the story into discrete commits
2. **For each commit**:
   - Write a clear description of what it should contain
   - Identify which files/changes belong to it
   - Estimate the size (small/medium/large)
3. **Number the commits**: Create a sequential plan (Commit 1, Commit 2, etc.)
4. **Review for coherence**: Does each commit stand alone? Is the order logical?

Output the commit plan in this format:

```
COMMIT PLAN
===========

Commit 1: {description}
Files: {estimated file list}
Size: {small/medium/large}

Commit 2: {description}
Files: {estimated file list}
Size: {small/medium/large}

...
```

Ask the user to review and approve the commit plan before proceeding.

### Step 5: Execute the Commit Plan

This is the main execution loop that creates each commit:

1. **Use TodoWrite**: Create a todo list with one item per commit from the plan
2. **For each commit in the plan**:

   a. **Mark todo as in_progress**

   b. **Invoke commit-writer agent**:
      - Use the Task tool with subagent_type pointing to the commit-writer agent
      - Pass the commit description, master diff path, and branch name
      - If resuming from a question, include resume context

   c. **Parse the result**:

      - **If SUCCESS**:
        - Mark todo as completed
        - Record the commit hash
        - Continue to next commit

      - **If ERROR**:
        - Report the error to the user
        - Ask how to proceed (retry, skip, abort)
        - Handle user's choice

      - **If QUESTION**:
        - **STOP** - Do not proceed automatically
        - Parse the agent's proposed options (Option 1, Option 2, etc.)
        - **Use AskUserQuestion tool** to present options to the user
        - Wait for the user's answer
        - Prepare resume context with the user's choice
        - Re-invoke the agent with resume context and answer
        - Continue from where it left off

   d. **Verify commit was created**: Run `git log -1` to confirm

3. **Continue until all commits are created**

### Step 6: Validate Results

After all commits are created, verify the result:

1. **Compare final states**:
   ```bash
   git checkout {original-branch}
   git diff {clean-branch-name}
   ```

2. **The diff should be empty**: If there are differences, report them to the user

3. **Provide summary**:
   ```
   REWRITE COMPLETE
   ================
   Original branch: {original-branch}
   Clean branch: {clean-branch-name}
   Base commit: {base-commit}
   Commits created: {count}

   To review: git log {base-commit}..{clean-branch-name}
   To compare: git diff {original-branch} {clean-branch-name}
   ```

4. **Return to original branch**: `git checkout {original-branch}`

## Handling Agent Questions

When the commit-writer agent returns a QUESTION result:

1. **STOP and parse the question**: Extract the agent's proposed split options from the QUESTION result

2. **Use AskUserQuestion tool**: ALWAYS use the AskUserQuestion tool to present the options to the user
   - Parse the agent's Option 1, Option 2, Option 3, etc.
   - Create question options for each proposed split
   - Let the user choose which approach to take
   - NEVER automatically choose an option yourself

3. **Wait for user response**: Get their decision before proceeding

4. **Prepare resume context**: Once you have the user's answer, create the resume context:
   ```json
   {
     "where_left_off": "{from agent's context}",
     "answer": "{user's choice}",
     "partial_work": "{any work completed}"
   }
   ```

5. **Re-invoke agent**: Pass the resume context along with original parameters

6. **Continue execution**: The agent should pick up where it left off

**IMPORTANT**: You must ALWAYS ask the user using the AskUserQuestion tool when the agent returns a QUESTION result. Do NOT make decisions about how to split commits without explicit user guidance.

### Example of Handling QUESTION Result

When the agent returns:
```
RESULT: QUESTION
Context: This commit is meant to "add user authentication" but includes 23 files.

Proposed Split:

Option 1: Three commits - (1) core auth logic, (2) authorization middleware, (3) session handling
Option 2: Two commits - (1) backend implementation, (2) frontend integration
Option 3: Four commits - (1) database schema, (2) auth service, (3) middleware, (4) UI

What approach should I take?
```

You should use AskUserQuestion like this:

```javascript
AskUserQuestion({
  questions: [{
    question: "The commit-writer agent found that 'add user authentication' is too large (23 files). How should we split it?",
    header: "Split commit",
    multiSelect: false,
    options: [
      {
        label: "Three commits by layer",
        description: "(1) core auth logic, (2) authorization middleware, (3) session handling"
      },
      {
        label: "Two commits by tier",
        description: "(1) backend implementation, (2) frontend integration"
      },
      {
        label: "Four commits by component",
        description: "(1) database schema, (2) auth service, (3) middleware, (4) UI"
      }
    ]
  }]
})
```

Then use the user's answer in the resume context when re-invoking the agent.

## Error Handling

- **Validation failures**: Stop and report what's wrong
- **Git command failures**: Capture error output and report to user
- **Agent failures**: Report error and ask user how to proceed
- **Unexpected state**: Always check assumptions and verify state before proceeding

## Important Notes

- **Never force**: Don't use `-f` or `--force` flags without explicit user permission
- **Preserve original**: Never modify the original branch
- **Clean state**: Always ensure git is in a clean state before operations
- **User approval**: Get approval for the commit plan before executing
- **Progress tracking**: Use TodoWrite to keep user informed of progress
- **Verification**: Always verify the final result matches the original changeset

## Example Usage Flow

1. User invokes: `/rewrite-commits "Add user profile feature"`
2. Skill validates: ✓ Working tree clean, ✓ On branch `feature/user-profile`
3. Skill prepares: Creates branch `feature/user-profile-20251021-143022-clean`
4. Skill develops story: "This changeset adds user profiles in 3 layers..."
5. Skill creates plan: 5 commits identified
6. User approves plan
7. Skill executes: Delegates each commit to commit-writer agent
8. Agent asks question: "Commit 3 is too large, split how?"
9. User answers: "Option 1"
10. Skill resumes: Agent completes with user's guidance
11. Skill validates: ✓ Contents match original branch
12. Complete: User now has clean branch ready for PR

## Success Criteria

- All commits created successfully
- Final branch content identical to original changeset
- Each commit tells a clear part of the story
- Commits are appropriately sized for review
- User understands what was done and can review the result
