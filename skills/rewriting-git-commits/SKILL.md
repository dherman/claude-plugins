---
name: Rewriting Git Commits
description: Rewrites a git commit sequence for a changeset to create a clean branch with commits optimized for readability and review
allowed-tools: Task
---

# Rewriting Git Commits Skill

This skill is a lightweight frontend that invokes the git-rewriter agent to rewrite commit sequences.

## Your Task

When this skill is invoked with a changeset description:

1. **Invoke the git-rewriter agent**: Use the Task tool with `subagent_type: "git-rewriter"`

2. **Pass the changeset description**: Include the changeset description in the prompt to guide the rewriting process

3. **Let the agent handle everything**: The git-rewriter agent will:
   - Validate the repository state
   - Prepare materials (clean branch, master diff)
   - Develop the story
   - Create a commit plan
   - Execute the plan
   - Validate the results

## Example

If invoked with "Add user authentication with OAuth support", you should:

```
Use Task tool with:
- subagent_type: "git-rewriter"
- prompt: "Rewrite the git commit sequence for this changeset: Add user authentication with OAuth support"
```

The agent will handle all the orchestration and interact with the user as needed.
