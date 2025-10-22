# Git Commit Rewriter - Claude Code Plugin

A Claude Code plugin that automates the process of rewriting git commit sequences to create clean, readable branches optimized for code review.

## Overview

When working on features or bug fixes, commit history often becomes messy with "WIP", "fix typo", "oops", and other non-descriptive commits. This plugin helps you take that messy history and rewrite it into a logical, well-documented sequence that tells a clear story.

## What It Does

The plugin takes your current branch (with messy commits) and creates a new "clean" branch with the same final code changes, but organized into logical commits that:

- Tell a clear story of how the feature was built
- Are appropriately sized for code review
- Have descriptive commit messages
- Follow a logical progression

## Components

The plugin consists of three main components:

### 1. Slash Command: `/rewrite-commits`

The entry point for users. Takes a description of what the changeset accomplishes.

**Usage:**
```bash
/rewrite-commits Add user authentication with OAuth support
```

**Location:** `commands/rewrite-commits.md`

### 2. Skill: `git-rewriter`

The orchestrator that manages the overall rewriting process through six steps:

1. **Validate Readiness** - Ensures git working tree is clean and ready
2. **Prepare Materials** - Creates clean branch and master diff file
3. **Develop Story** - Analyzes changes and creates narrative structure
4. **Create Commit Plan** - Breaks story into discrete commits
5. **Execute Plan** - Delegates to commit-writer agent for each commit
6. **Validate Results** - Verifies clean branch matches original

**Location:** `skills/git-rewriter/SKILL.md`

### 3. Agent: `commit-writer`

A specialized agent that writes individual commits. It can:

- Create focused, atomic commits
- Detect when a commit is too large
- Ask for guidance on splitting large commits
- Resume from where it left off after getting guidance

**Location:** `agents/commit-writer.md`

## How It Works

### Basic Flow

1. You invoke: `/rewrite-commits "Description of your changeset"`

2. The skill validates your git state and prepares materials:
   - Creates a new branch: `{your-branch}-{timestamp}-clean`
   - Generates a master diff of all changes

3. The skill analyzes your changes and develops a story:
   - Identifies key themes and layers
   - Determines logical ordering
   - Creates narrative structure

4. The skill creates a commit plan:
   - Breaks story into discrete commits
   - Estimates size and identifies files
   - Presents plan for your approval

5. You review and approve the plan

6. The skill executes the plan:
   - Delegates each commit to the commit-writer agent
   - Handles questions if commits need splitting
   - Tracks progress with todo list

7. The skill validates results:
   - Compares clean branch to original
   - Ensures contents are identical
   - Provides summary

### Handling Large Commits

If the commit-writer agent detects a commit is too large, it will:

1. Stop and return a QUESTION result
2. Propose 2-3 options for splitting the commit
3. Wait for your guidance
4. Resume with your chosen approach

**Example Question:**
```
This commit includes 23 files across authentication, authorization, and session management.

Option 1: Three commits - (1) core auth logic, (2) authorization middleware, (3) session handling
Option 2: Two commits - (1) backend implementation, (2) frontend integration
Option 3: Four commits - (1) database schema, (2) auth service, (3) middleware, (4) UI

What approach should I take?
```

## Installation

This plugin can be installed from GitHub. See [INSTALL.md](INSTALL.md) for detailed instructions.

Quick start:

```bash
/plugin marketplace add dherman/git-rewriter
/plugin install git-rewriter@dherman
```

### Plugin Structure

The plugin contains:

```
git-rewriter/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── commands/
│   └── rewrite-commits.md       # Slash command
├── skills/
│   └── git-rewriter/
│       └── SKILL.md              # Main orchestrator skill
├── agents/
│   └── commit-writer.md          # Commit creation agent
└── settings.json                 # Recommended permissions
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
