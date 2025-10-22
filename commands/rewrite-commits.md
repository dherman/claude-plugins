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

Invoke the git-rewriter agent using the Task tool:

- **subagent_type**: `"git-rewriter"`
- **prompt**: Include the changeset description from $ARGUMENTS

The git-rewriter agent will handle all orchestration:
- Validating the repository state
- Preparing materials (clean branch, master diff)
- Developing the story
- Creating a commit plan
- Executing the plan
- Validating the results

## Example

For the command:
```
/rewrite-commits Add user profile feature with avatar support
```

You should invoke:
```
Task tool with:
- subagent_type: "git-rewriter"
- description: "Rewrite git commits"
- prompt: "Rewrite the git commit sequence for this changeset: Add user profile feature with avatar support"
```

The agent will create a clean branch with commits like:
- `feat: add user profile data model`
- `feat: implement profile CRUD operations`
- `feat: add avatar upload functionality`
- `feat: integrate profile UI components`

Rather than the messy original history of WIP commits and fixes.
