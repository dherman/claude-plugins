---
description: Rewrite git commit sequence to create a clean, readable branch
argument-hint: [changeset-description]
allowed-tools: Skill
---

# Narrate Git Commits

This command delegates to the "Rewriting Git Commits" skill to rewrite git commit sequences.

## Your Task

Simply invoke the skill with the changeset description:

```
Skill(command: "historian:rewriting-git-commits")
```

Pass the user's arguments (`$ARGUMENTS`) as the prompt to the skill.

## What the Skill Does

The skill coordinates the rewrite process:
1. Sets up a work directory in `/tmp/historian-{timestamp}/`
2. Launches narrator and scribe agents in parallel (fork/join)
3. Waits for both agents to complete
4. Reports final results

Both agents use AskUserQuestion directly when they need user input.

See [skills/rewriting-git-commits/SKILL.md](../skills/rewriting-git-commits/SKILL.md) for details.

## Example

```
User: /narrate Add user authentication with OAuth support

Command: Invokes historian:rewriting-git-commits skill with that prompt

Skill: Coordinates the entire rewrite process
```
