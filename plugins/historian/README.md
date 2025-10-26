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

The plugin uses **three parallel long-running agents** with **direct user interaction** and **sidechat MCP** for agent coordination. Simple and elegant!

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
- Launches analyst, narrator, and scribe agents **once** in parallel
- Waits for all to complete
- Reports final results

**Location:** `skills/rewriting-git-commits/SKILL.md`

#### 3. Agent: `analyst` (magenta)

Analyzes the changeset and prepares the commit plan:

1. **Validates** - Ensures git working tree is clean
2. **Prepares** - Creates clean branch and master diff
3. **Determines Build** - Detects project type and build command (cargo check, tsc --noEmit, etc.)
4. **Analyzes** - Reads diff and creates commit plan
5. **Asks User** - Uses **AskUserQuestion** to get approval for plan
6. **Coordinates** - Sends commit_plan to narrator and build_config to scribe via sidechat
7. **Exits** - Writes "done" status and terminates

**Location:** `agents/analyst.md`

#### 4. Agent: `narrator` (cyan)

Orchestrator that executes the commit plan:

1. **Waits** - Blocks until analyst sends commit_plan
2. **Executes** - Sends commit requests to scribe via sidechat, waits for responses
3. **Validates** - Compares final branch tree to original branch
4. **Fixes** - Amends last commit if trees don't match
5. **Completes** - Writes "done" status

**Location:** `agents/narrator.md`

#### 5. Agent: `scribe` (orange)

Worker that creates commits and validates builds:

1. **Waits for Config** - Blocks until analyst sends build_config
2. **Receives** - Blocks on `receive_message` waiting for commit requests from narrator
3. **Processes** - Reads master diff and creates commit
4. **Validates Build** - Runs build command, auto-fixes failures up to 3 times
5. **Responds** - Sends result back to narrator via sidechat
6. **Repeats** - Continues until narrator writes "done" status

**Location:** `agents/scribe.md`

#### 6. MCP Server: Sidechat

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

The skill launches all three agents once and waits for completion:

**Setup:**
1. **Skill:** Establishes session ID `historian-20251024-140530`
2. **Skill:** Creates work directory `/tmp/historian-20251024-140530/`
3. **Skill:** Launches analyst + narrator + scribe in parallel with session ID

**All three agents start running simultaneously:**

**Analyst (runs once, exits):**
4. Validates git repository
5. Creates clean branch and master diff
6. Determines build command (cargo check, tsc --noEmit, etc.)
7. Analyzes changes and creates commit plan
8. **Asks you directly** "Approve this commit plan?" using AskUserQuestion
9. You respond "Proceed"
10. Sends commit_plan to narrator via sidechat
11. Sends build_config to scribe via sidechat
12. Writes "done" status and exits

**Narrator (long-running):**
4. Waits for commit_plan from analyst (`receive_message` blocks)
5. Receives commit plan with list of commits
6. Sends commit request #1 to scribe via sidechat (`send_message`)
7. Waits for scribe's response (`receive_message`)
8. Receives success response, sends request #2
9. Repeats for all commits in the plan
10. Validates final branch tree matches original branch tree
11. Amends last commit if trees don't match (fixes missing changes)
12. Writes "done" status and exits

**Scribe (long-running):**
4. Waits for build_config from analyst (`receive_message` blocks)
5. Receives build command (or null)
6. Waits for commit request from narrator (`receive_message` blocks)
7. Receives request #1, creates commit
8. Validates build: runs build command, auto-fixes failures, retries up to 3 times
9. Sends success response to narrator via sidechat
10. Waits for request #2 (`receive_message` blocks)
11. Repeats until narrator writes "done" status
12. Exits

**Completion:**
13. **Skill:** All agents finished, reads final state
14. **Skill:** Reports results to you

### Advantages of This Architecture

1. **Simple** - Single launch, single execution
2. **Direct User Interaction** - Agents use AskUserQuestion mid-execution
3. **Easy to Understand** - Three agents with clear responsibilities
4. **Clean Communication** - Sidechat MCP handles message passing
5. **Easy Debugging** - View transcript log and message files
6. **Reusable** - Sidechat MCP can be used in other plugins
7. **Build Validation** - Catches missing changes automatically
8. **Self-Healing** - Both scribe (build fixes) and narrator (tree fixes) can repair issues

### Example: Build Validation

The scribe validates builds after each commit and auto-fixes failures:

**Scenario:** Commit #2 "Implement OAuth token validation" fails to build because it's missing some imports that are part of a later commit.

**What happens:**
1. Scribe creates the commit
2. Runs `cargo check` (the build command)
3. Build fails with "cannot find module `oauth_helpers`"
4. Scribe analyzes error, finds the missing module in master.diff
5. Applies the missing changes
6. Amends the commit
7. Retries build → passes
8. Sends success response to narrator

If after 3 attempts the build still fails, scribe **asks you directly** for help.

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
│   ├── analyst.md                     # Analyzer and planner (magenta)
│   ├── narrator.md                    # Orchestrator (cyan)
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
