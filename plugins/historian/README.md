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

The plugin uses a **trampoline pattern** with **file-based IPC** to coordinate two parallel long-running agents. This minimizes context overhead by keeping agent work isolated.

### Components

#### 1. Slash Command: `/narrate`

The trampoline coordinator that:
- Sets up a work directory in `/tmp/historian-{timestamp}/`
- Launches narrator and scribe agents in parallel
- Monitors their status via files
- Handles user questions from either agent
- Reports final results

**Usage:**
```bash
/narrate Add user authentication with OAuth support
```

**Location:** `commands/narrate.md`

#### 2. Skill: Rewriting Git Commits

A lightweight wrapper that delegates to `/narrate`.

**Location:** `skills/rewriting-git-commits/SKILL.md`

#### 3. Agent: `narrator` (cyan)

The main orchestrator that runs in parallel with scribe. Workflow:

1. **Validate Readiness** - Ensures git working tree is clean
2. **Prepare Materials** - Creates clean branch and master diff
3. **Develop Story** - Analyzes changes and creates narrative
4. **Create Commit Plan** - Breaks story into discrete commits
5. **Ask User for Approval** - Presents plan via question file
6. **Execute Plan** - Sends requests to scribe via IPC
7. **Validate Results** - Verifies clean branch matches original

Communicates via files in `narrator/` directory.

**Location:** `agents/narrator.md`

#### 4. Agent: `scribe` (orange)

A specialized worker that runs in parallel with narrator. Workflow:

- Waits for requests from narrator in `scribe/inbox/`
- Analyzes commit size and complexity
- Creates single commits for reasonable size
- Asks user (via question file) how to split large commits
- Writes results to `scribe/outbox/`
- Shuts down when narrator signals done

**Location:** `agents/scribe.md`

### File-Based IPC

Agents coordinate through files in `/tmp/historian-{timestamp}/`:

```
/tmp/historian-{timestamp}/
  ├── transcript.log              # Shared log
  ├── master.diff                 # All changes
  ├── state.json                  # Shared state
  ├── narrator/
  │   ├── status                  # "planning" | "executing" | "done" | "error"
  │   ├── question                # Questions for user
  │   └── answer                  # User answers
  └── scribe/
      ├── status                  # "idle" | "working" | "done"
      ├── question                # Questions for user
      ├── answer                  # User answers
      ├── inbox/request           # Requests from narrator
      └── outbox/result           # Results to narrator
```

See [docs/ipc-protocol.md](docs/ipc-protocol.md) for complete details.

## How It Works

### Basic Flow

1. **You invoke:** `/narrate "Description of your changeset"`

2. **Command sets up IPC:**
   - Creates work directory `/tmp/historian-{timestamp}/`
   - Initializes file structure for communication

3. **Launches agents in parallel:**
   - Narrator agent starts planning
   - Scribe agent starts waiting for requests

4. **Narrator validates and prepares:**
   - Checks git working tree is clean
   - Creates clean branch: `{your-branch}-{timestamp}-clean`
   - Generates master diff of all changes

5. **Narrator creates commit plan:**
   - Analyzes changes and develops a story
   - Identifies key themes and logical layers
   - Creates detailed commit plan
   - Breaks into discrete, logical commits

6. **User reviews and approves:**
   - Narrator writes question file
   - Command presents plan to you
   - You approve or cancel

7. **Execution loop:**
   - Narrator sends commit requests to scribe via `inbox/request` files
   - Scribe creates each commit
   - Scribe writes results to `outbox/result` files
   - If commit is too large, scribe asks user how to split
   - Command handles all user questions via file IPC

8. **Validation:**
   - Narrator compares clean branch to original
   - Ensures contents are identical
   - Writes "done" status

9. **Command reports results:**
   - Both agents shut down cleanly
   - You get clean branch name and commit count
   - Transcript available for debugging

### Advantages of This Architecture

1. **Minimal Context Overhead** - Agents run in parallel, isolated from your main context
2. **No Agent-to-Agent Calls** - Works around Claude Code limitation
3. **Direct User Communication** - Both agents can ask questions without propagation
4. **Easy Debugging** - All IPC files visible for inspection
5. **Resumable** - User questions don't block either agent

### Example: Handling Large Commits

If the scribe agent detects a commit is too large:

1. **Scribe writes question file:**
   ```
   CONTEXT=Commit 3 "add authentication" is too large (23 files)
   OPTION_1=Three commits: (1) core auth (2) middleware (3) sessions
   OPTION_2=Two commits: (1) backend (2) frontend
   OPTION_3=Four commits: (1) schema (2) service (3) middleware (4) UI
   ```

2. **Command detects question and asks you**

3. **You choose Option 1**

4. **Command writes answer file:**
   ```
   ANSWER=Option 1
   ```

5. **Scribe reads answer and creates 3 commits**

6. **Execution continues**

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
│   └── plugin.json                    # Plugin manifest
├── commands/
│   └── narrate.md                     # Trampoline coordinator
├── skills/
│   └── rewriting-git-commits/
│       └── SKILL.md                   # Wrapper around /narrate
├── agents/
│   ├── narrator.md                    # Main orchestrator (cyan)
│   └── scribe.md               # Commit creator (orange)
├── docs/
│   ├── ipc-protocol.md                # File-based IPC specification
│   └── transcript-logging.md          # Transcript format
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
