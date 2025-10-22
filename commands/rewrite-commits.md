---
description: Rewrite git commit sequence to create a clean, readable branch
argument-hint: [changeset-description]
allowed-tools: Skill, Bash, Read, Write, Edit, Task, TodoWrite, Grep, Glob, AskUserQuestion
---

# Rewrite Git Commits

You are tasked with rewriting a git commit sequence to create a clean branch with well-organized, readable commits.

## Input

The changeset description provided: **$ARGUMENTS**

## Your Task

1. **Invoke the git-rewriter skill**: Use the Skill tool to invoke the "git-rewriter" skill

2. **Pass the context**: Provide the changeset description to guide the rewriting process

3. **Follow the skill's process**: The skill will guide you through:
   - Validating the repository state
   - Preparing materials (clean branch, master diff)
   - Developing the story
   - Creating a commit plan
   - Executing the plan (delegating to commit-writer agent)
   - Validating the results

4. **Handle interactions**:
   - Present commit plans to the user for approval
   - Handle questions from the commit-writer agent
   - Report errors and get user guidance
   - Keep the user informed of progress

5. **Complete successfully**: Ensure the clean branch has identical contents to the original but with a better commit structure

## Important Guidelines

- **Be conversational**: Explain what you're doing at each step
- **Seek approval**: Always get user approval before executing the commit plan
- **Handle questions**: When the agent asks questions, present them clearly to the user
- **Verify results**: Always verify the final branch matches the original changeset
- **Provide summary**: Give a clear summary of what was accomplished

## Expected Outcome

A new git branch with the suffix `-{timestamp}-clean` containing the same changes as the original branch, but organized into logical, well-documented commits that tell a clear story.

## Example Invocation

```
/rewrite-commits Add user profile feature with avatar support
```

This would create a clean branch with commits like:
- `feat: add user profile data model`
- `feat: implement profile CRUD operations`
- `feat: add avatar upload functionality`
- `feat: integrate profile UI components`

Rather than the messy original history of WIP commits and fixes.
