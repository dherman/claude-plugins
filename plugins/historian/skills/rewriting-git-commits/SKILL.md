---
name: Rewriting Git Commits
description: Rewrites a git commit sequence for a changeset to create a clean branch with commits optimized for readability and review
allowed-tools: SlashCommand
---

# Rewriting Git Commits Skill

This skill is a lightweight frontend that invokes the `/narrate` command to rewrite commit sequences.

## Your Task

When this skill is invoked with a changeset description, simply delegate to the `/narrate` command:

```
/narrate {changeset description}
```

## Architecture

The historian plugin uses a **trampoline pattern** with file-based IPC. See [docs/ipc-protocol.md](../../docs/ipc-protocol.md) for details on how this works.

The `/narrate` command:
1. Launches narrator and scribe agents in parallel
2. Monitors their status via files
3. Handles user questions from either agent
4. Reports final results

## Example

**Input to skill:**
```
Add user authentication with OAuth support
```

**Skill action:**
```
/narrate Add user authentication with OAuth support
```

**What happens:**
1. `/narrate` command sets up work directory
2. Launches both agents in parallel
3. Narrator creates commit plan and asks user for approval
4. User approves
5. Narrator and scribe coordinate via files to create commits
6. Scribe may ask user about splitting large commits
7. Final clean branch is created
8. Results reported to user

## Notes

- This skill is now just a thin wrapper around the `/narrate` command
- All the orchestration logic is in the command
- The command handles all user interaction
- Both agents run in parallel for minimal context overhead
