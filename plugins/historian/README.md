# Historian - Claude Code Plugin

A Claude Code plugin that automates the process of rewriting git commit sequences to create clean, readable branches optimized for code review.

## Overview

When working on features or bug fixes, commit history often becomes messy with "WIP", "fix typo", "oops", and other non-descriptive commits. This plugin helps you take that messy history and rewrite it into a logical, well-documented sequence that tells a clear story.

## What It Does

The plugin takes your current branch (with messy commits) and creates a new "clean" branch with the same final code changes, but organized into logical commits that:

- Tell a clear story explaining the feature in layers
- Are appropriately sized for code review
- Have descriptive commit messages
- Follow a logical progression

## Architecture

The plugin uses **parallel long-running agents** with **direct user interaction** and **sidechat MCP** for agent coordination. Simple and elegant!

### Components

#### 1. Slash Command: `/narrate`

A lightweight wrapper that invokes the "Rewriting Git Commits" skill.

**Usage:**
```bash
/narrate Add user authentication with OAuth support
```

**Location:** `commands/narrate.md`

#### 2. Skill: Rewriting Git Commits

Simple coordinator that:
- Establishes a unique session ID for agent communication
- Creates a work directory in `/tmp/historian-{timestamp}/`
- Launches narrator and scribe agents **once** in parallel
- Waits for both to complete
- Reports final results

**Location:** `skills/rewriting-git-commits/SKILL.md`

#### 3. Agent: `narrator` (cyan)

Long-running orchestrator that executes from start to finish in one invocation:

1. **Validates** - Ensures git working tree is clean
2. **Prepares** - Creates clean branch and master diff
3. **Analyzes** - Reads diff and creates commit plan
4. **Asks User** - Uses **AskUserQuestion** to get approval for plan
5. **Executes** - Sends commit requests to scribe via sidechat, waits for responses
6. **Validates** - Compares final branch to original
7. **Completes** - Writes "done" status

**Location:** `agents/narrator.md`

#### 4. Agent: `scribe` (orange)

Long-running worker that processes commits in a continuous loop:

1. **Receives** - Blocks on `receive_message` waiting for commit requests from narrator
2. **Processes** - Reads master diff and creates commit
3. **Responds** - Sends result back to narrator via sidechat
4. **Repeats** - Continues until narrator writes "done" status

**Location:** `agents/scribe.md`

#### 5. MCP Server: Sidechat

Session-based message passing system for agent coordination:

- Provides `send_message` and `receive_message` tools
- Handles message queuing and delivery (FIFO)
- Agents communicate through named sessions
- Messages stored in `/tmp/sidechat-{instance-id}/`

**Location:** `servers/sidechat-mcp/`

### Work Directory Structure

The work directory in `/tmp/historian-{timestamp}/` contains:

```
/tmp/historian-{timestamp}/
  ├── transcript.log              # Shared log
  ├── master.diff                 # All changes
  ├── state.json                  # Final results
  └── narrator/
      └── status                  # "done" | "error"
```

Agent communication happens via sidechat MCP, not files. Messages are stored separately in `/tmp/sidechat-{instance-id}/`.

## How It Works

### Single Execution Cycle

The skill launches both agents once and waits for completion:

**Setup:**
1. **Skill:** Establishes session ID `historian-20251024-140530`
2. **Skill:** Creates work directory `/tmp/historian-20251024-140530/`
3. **Skill:** Launches narrator + scribe in parallel with session ID

**Both agents start running simultaneously:**

**Narrator (long-running):**
4. Validates git repository
5. Creates clean branch and master diff
6. Analyzes changes and creates commit plan
7. **Asks you directly** "Approve this commit plan?" using AskUserQuestion
8. You respond "Proceed"
9. Sends commit request #1 to scribe via sidechat (`send_message`)
10. Waits for scribe's response (`receive_message`)
11. Receives success response, sends request #2
12. Repeats for all commits
13. Validates final branch matches original
14. Writes "done" status and exits

**Scribe (long-running):**
4. Waits for request from narrator (`receive_message` blocks)
5. Receives request #1, processes it, sends success response via sidechat
6. Waits for request #2 (`receive_message` blocks)
7. Receives request #2, processes it, sends success response
8. Repeats until narrator writes "done" status
9. Exits

**Completion:**
15. **Skill:** Both agents finished, reads final state
16. **Skill:** Reports results to you

### Advantages of This Architecture

1. **Simple** - Single launch, single execution
2. **Direct User Interaction** - Agents use AskUserQuestion mid-execution
3. **Easy to Understand** - Two agents working in parallel
4. **Clean Communication** - Sidechat MCP handles message passing
5. **Easy Debugging** - View transcript log and message files
6. **Reusable** - Sidechat MCP can be used in other plugins

### Example: Handling Large Commits

If the scribe detects a commit is too large, it **asks you directly**:

```
This commit "Add authentication" is quite large (23 files, 1200 lines).

How would you like to split it?

1. Split by layer (backend/frontend/tests)
2. Split by feature area
3. Keep as one commit
```

You respond, scribe creates multiple commits accordingly, then continues.

## Installation

This plugin can be installed from GitHub. See [INSTALL.md](INSTALL.md) for detailed instructions.

Quick start:

```bash
/plugin marketplace add https://github.com/dherman/claude-plugins
/plugin install historian@dherman
```

### Plugin Structure

The plugin contains:

```
historian/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest (includes MCP server config)
├── commands/
│   └── narrate.md                     # Slash command wrapper
├── skills/
│   └── rewriting-git-commits/
│       └── SKILL.md                   # Coordinator skill
├── agents/
│   ├── narrator.md                    # Main orchestrator (cyan)
│   └── scribe.md                      # Commit creator (orange)
├── servers/
│   └── sidechat-mcp/                  # Message passing MCP server
│       ├── src/
│       │   └── index.ts               # TypeScript implementation
│       ├── dist/                      # Compiled JavaScript
│       ├── package.json
│       ├── tsconfig.json
│       └── README.md
└── settings.json                       # Recommended permissions
```

## Usage Examples

### Example 1: Feature Branch

**Before:**
```
* feat: wip
* fix: oops forgot file
* feat: add more stuff
* fix: typo
* feat: initial implementation
```

**Command:**
```bash
/narrate Add user profile feature with avatar uploads
```

**After:**
```
* feat: add user profile data model
* feat: implement profile CRUD API
* feat: add avatar upload with S3 integration
* feat: create profile UI components
* test: add profile feature test coverage
```

### Example 2: Refactoring

**Before:**
```
* refactor: move stuff around
* fix: broken tests
* refactor: more changes
* fix: lint errors
```

**Command:**
```bash
/narrate Extract user validation logic into separate module
```

**After:**
```
* refactor: create user validation module
* refactor: migrate validators to new module
* refactor: update imports and dependencies
* test: add validation module tests
```


## Design Philosophy

### Atomic Commits

Each commit should:
- Do one thing well
- Leave code in a working state
- Be independently reviewable
- Have a clear purpose

### Story-Driven

Commits should tell a story:
- Foundation/infrastructure first
- Core functionality next
- Polish and refinements last
- Logical dependencies respected

### Review-Optimized

Commits are sized for human review:
- Small: < 5 files, < 150 lines
- Medium: 5-15 files, 150-500 lines
- Large: Needs splitting (triggers agent question)

## Configuration

### Commit Message Format

The scribe agent uses conventional commits format:

```
<type>: <short summary>

<detailed explanation>
```

**Types:** feat, fix, refactor, docs, test, chore, perf, style

### Agent Behavior

The scribe agent is configured to:
- Ask questions when commits exceed 15 files or 500 lines
- Use Read, Write, Edit, Bash, Grep, and Glob tools
- Run on the Sonnet model for balance of capability and speed

## Troubleshooting

### "Working tree is not clean"

Commit or stash your changes before running the rewriter:
```bash
git stash
/narrate Your changeset description
git stash pop  # After rewriting
```

### "Cannot find base commit"

Ensure your branch has a clear merge-base with main/master:
```bash
git merge-base HEAD origin/main  # Should return a commit hash
```

### "Clean branch differs from original"

This shouldn't happen, but if it does:
1. Check the git diff output provided
2. Review the commit sequence
3. Consider re-running or manual fixes

## Development

### Testing

To test the plugin, you can:

1. Create a test repository with messy commits
2. Invoke the rewriter
3. Verify the clean branch matches original
4. Review commit quality

### Extending

You can extend the plugin by:

- Customizing the scribe agent prompt
- Adjusting size thresholds for large commits
- Adding additional validation steps
- Customizing commit message format

## License

MIT

## Contributing

To improve this plugin:

1. Modify the files in `.claude/`
2. Test with real-world scenarios
3. Share improvements with the community
