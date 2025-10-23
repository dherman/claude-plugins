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

## Components

The plugin consists of four main components:

### 1. Slash Command: `/rewrite-commits`

A lightweight entry point for users. Takes a description of what the changeset accomplishes and delegates to the historian agent.

**Usage:**
```bash
/rewrite-commits Add user authentication with OAuth support
```

**Location:** `commands/rewrite-commits.md`

### 2. Skill: Rewriting Git Commits

A lightweight skill that can be invoked programmatically. Simply delegates to the historian agent.

**Location:** `skills/rewriting-git-commits/SKILL.md`

### 3. Agent: `narrator` (cyan)

The main orchestrator that manages the overall rewriting process through six steps:

1. **Validate Readiness** - Ensures git working tree is clean and ready
2. **Prepare Materials** - Creates clean branch and master diff file
3. **Develop Story** - Analyzes changes and creates narrative structure
4. **Create Commit Plan** - Breaks story into discrete commits
5. **Execute Plan** - Delegates to commit-writer agent for each commit
6. **Validate Results** - Verifies clean branch matches original

**Location:** `agents/narrator.md`

### 4. Agent: `commit-writer` (orange)

A specialized agent that writes individual commits. It can:

- Create focused, atomic commits
- Detect when a commit is too large
- Ask for guidance on splitting large commits
- Resume from where it left off after getting guidance

**Location:** `agents/commit-writer.md`

## How It Works

### Basic Flow

1. You invoke: `/rewrite-commits "Description of your changeset"`

2. The command delegates to the historian agent

3. The historian agent validates your git state and prepares materials:
   - Creates a new branch: `{your-branch}-{timestamp}-clean`
   - Generates a master diff of all changes

4. The historian agent analyzes your changes and develops a story:
   - Identifies key themes and layers
   - Determines logical ordering
   - Creates narrative structure

5. The historian agent creates a commit plan:
   - Breaks story into discrete commits
   - Estimates size and identifies files
   - Presents plan for your approval

6. You review and approve the plan

7. The historian agent executes the plan:
   - Delegates each commit to the commit-writer agent (orange)
   - Handles questions if commits need splitting
   - Tracks progress with todo list

8. The historian agent validates results:
   - Compares clean branch to original
   - Ensures contents are identical
   - Provides summary

### Result Protocol and Resumability

The plugin uses a consistent result protocol throughout the agent hierarchy:

#### Three Result Types

Every agent (historian and commit-writer) returns one of:

1. **SUCCESS** - Operation completed successfully
2. **ERROR** - Unrecoverable error occurred
3. **QUESTION** - Needs user guidance to proceed

#### Question and Resume Flow

When an agent needs user input:

1. **Agent pauses** and returns a QUESTION result with:
   - Context explaining the situation
   - Resume state (all information needed to continue)
   - 2-3 options for the user to choose from

2. **User answers** by selecting an option

3. **Agent resumes** with the resume state and user's answer, picking up exactly where it left off

#### Example: Handling Large Commits

If the commit-writer agent detects a commit is too large:

**Question from commit-writer:**
```
RESULT: QUESTION
Context: Commit 3 "add authentication" is too large (23 files)

Option 1: Three commits - (1) core auth logic, (2) authorization middleware, (3) session handling
Option 2: Two commits - (1) backend implementation, (2) frontend integration
Option 3: Four commits - (1) database schema, (2) auth service, (3) middleware, (4) UI

What approach should I take?
```

**Propagated through historian:**

The historian agent receives this QUESTION, wraps it with its own resume state, and passes it up to the command/skill, which presents it to you.

**After your answer:**

Your answer flows back down: command → historian agent → commit-writer agent, and execution resumes seamlessly.

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
│   └── rewrite-commits.md             # Slash command (lightweight frontend)
├── skills/
│   └── rewriting-git-commits/
│       └── SKILL.md                    # Skill (lightweight frontend)
├── agents/
│   ├── narrator.md                    # Main orchestrator agent (cyan)
│   └── commit-writer.md               # Commit creation agent (orange)
├── docs/
│   └── result-protocol.md             # Shared protocol specification
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
/rewrite-commits Add user profile feature with avatar uploads
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
/rewrite-commits Extract user validation logic into separate module
```

**After:**
```
* refactor: create user validation module
* refactor: migrate validators to new module
* refactor: update imports and dependencies
* test: add validation module tests
```

## Architecture and Protocol

### Agent Hierarchy

The plugin uses a three-level architecture:

```
Command/Skill (frontends)
    ↓
historian agent (cyan) - orchestrator
    ↓
commit-writer agent (orange) - individual commits
```

### Result Protocol

All agents follow a consistent protocol defined in [docs/result-protocol.md](docs/result-protocol.md):

- **Return one of three results**: SUCCESS, ERROR, or QUESTION
- **Resumable execution**: When returning QUESTION, agents include complete resume state
- **Bubble up questions**: Questions propagate up the hierarchy to reach the user
- **Flow answers down**: User answers flow back down to resume execution

See the [Result Protocol documentation](docs/result-protocol.md) for detailed format specifications and examples.

This design optimizes context usage by:
1. Keeping frontends (command/skill) lightweight
2. Loading heavy orchestration logic only when needed (historian agent)
3. Isolating commit creation logic (commit-writer agent)
4. Supporting seamless pause/resume for user interaction

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

The commit-writer agent uses conventional commits format:

```
<type>: <short summary>

<detailed explanation>
```

**Types:** feat, fix, refactor, docs, test, chore, perf, style

### Agent Behavior

The commit-writer agent is configured to:
- Ask questions when commits exceed 15 files or 500 lines
- Use Read, Write, Edit, Bash, Grep, and Glob tools
- Run on the Sonnet model for balance of capability and speed

## Troubleshooting

### "Working tree is not clean"

Commit or stash your changes before running the rewriter:
```bash
git stash
/rewrite-commits Your changeset description
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

- Customizing the commit-writer agent prompt
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
