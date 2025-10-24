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

The skill acts as a trampoline coordinator:
1. Sets up a work directory in `/tmp/historian-{timestamp}/`
2. Launches narrator and scribe agents in parallel
3. Polls their status files to detect questions or completion
4. Asks the user questions when either agent needs input
5. Reports final results

See [skills/rewriting-git-commits/SKILL.md](../skills/rewriting-git-commits/SKILL.md) for details.

## Example

```
User: /narrate Add user authentication with OAuth support

Command: Invokes historian:rewriting-git-commits skill with that prompt

Skill: Coordinates the entire rewrite process
```
