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

The plugin uses a **fork/join trampoline pattern** with **stateful resumable agents** and **file-based IPC**. This minimizes context overhead while allowing the skill to handle user interaction.

### Components

#### 1. Slash Command: `/narrate`

A lightweight wrapper that invokes the "Rewriting Git Commits" skill.

**Usage:**
```bash
/narrate Add user authentication with OAuth support
```

**Location:** `commands/narrate.md`

#### 2. Skill: Rewriting Git Commits

The fork/join trampoline coordinator that:
- Sets up a work directory in `/tmp/historian-{timestamp}/`
- **Repeatedly launches** narrator and scribe agents in parallel
- **Waits** for both agents to exit (fork/join semantics)
- Checks for user questions after each iteration
- Handles user questions and writes answers
- Restarts agents in a loop until completion
- Reports final results

The skill launches agents potentially 50-100+ times, with each agent doing incremental work and exiting.

**Location:** `skills/rewriting-git-commits/SKILL.md`

#### 3. Agent: `narrator` (cyan)

A **stateful, resumable agent** that orchestrates the rewrite process. Each invocation:

1. **Loads state** from `narrator/state.json`
2. **Does one unit of work** based on current phase
3. **Saves updated state** back to disk
4. **Exits** - skill will restart it

**State Machine Phases:**
- `init` - Validate git, create clean branch and master diff
- `planning` - Analyze changes, create commit plan, write question file
- `waiting_for_user` - Check for answer file, process response
- `executing` - Send commit requests to scribe, wait for results
- `validating` - Compare branches, mark done
- `done` - Finished successfully

Communicates via files in `narrator/` directory.

**Location:** `agents/narrator.md`

#### 4. Agent: `scribe` (orange)

A **stateful, resumable agent** that creates individual commits. Each invocation:

1. **Loads state** from `scribe/state.json`
2. **Does one unit of work** based on current phase
3. **Saves updated state** back to disk
4. **Exits** - skill will restart it

**State Machine Phases:**
- `idle` - Check for narrator done or new request in inbox
- `processing` - Read master diff, extract changes, create commit, write result
- `waiting_for_user` - (Future) Ask how to split large commits
- `done` - Narrator finished, shut down

Communicates via files in `scribe/` directory.

**Location:** `agents/scribe.md`

### File-Based IPC and State Management

Agents coordinate through files in `/tmp/historian-{timestamp}/`:

```
/tmp/historian-{timestamp}/
  ├── transcript.log              # Shared log
  ├── master.diff                 # All changes
  ├── state.json                  # Shared final results
  ├── narrator/
  │   ├── state.json              # Narrator's resumable state
  │   ├── status                  # "planning" | "executing" | "done" | "error"
  │   ├── question                # Questions for user
  │   └── answer                  # User answers
  └── scribe/
      ├── state.json              # Scribe's resumable state
      ├── status                  # "idle" | "processing" | "done"
      ├── question                # Questions for user
      ├── answer                  # User answers
      ├── inbox/request           # Requests from narrator
      └── outbox/result           # Results to narrator
```

**Key principle:** Agents save their state before exiting and resume from that state when restarted.

See [docs/ipc-protocol.md](docs/ipc-protocol.md) for complete details.

## How It Works

### Fork/Join Iteration Loop

The skill uses fork/join semantics to repeatedly launch and coordinate the agents:

**Iteration 1-2: Setup and Planning**
1. **Skill:** Setup work directory
2. **Skill:** Launch narrator + scribe (both exit quickly)
3. **Narrator:** Initialize, create clean branch, generate master diff → save state, exit
4. **Scribe:** Initialize → save state, exit
5. **Skill:** Check for questions (none), restart agents
6. **Narrator:** Load state, analyze changes, create commit plan, write question file → save state, exit
7. **Scribe:** Load state, check for requests (none) → exit
8. **Skill:** Check for questions → **found one!**

**User Interaction:**
9. **Skill:** Present commit plan to you via AskUserQuestion
10. **You:** Choose "Proceed with this plan"
11. **Skill:** Write answer file, restart agents

**Iteration 3-N: Executing Commits**
12. **Narrator:** Load state, check for answer → found it! Advance to executing phase, send commit request #1 → save state, exit
13. **Scribe:** Load state, check for request → found one! Create commit #1, write result → save state, exit
14. **Skill:** Check for questions (none), restart agents
15. **Narrator:** Load state, read result for commit #1, send request #2 → save state, exit
16. **Scribe:** Load state, check for request → found one! Create commit #2 → save state, exit
17. Repeat for all commits (potentially 50-100 iterations)

**Final Iterations: Validation**
N. **Narrator:** Load state, all commits done, validate branches match → mark "done", exit
N+1. **Scribe:** Load state, narrator is done → mark "done", exit
N+2. **Skill:** Check status → narrator done! Read final state and report results

### Advantages of This Architecture

1. **Minimal Context Overhead** - Agents run briefly, isolated from main context
2. **Skill Controls Flow** - Can handle user questions between agent invocations
3. **Stateful Resume** - Agents pick up exactly where they left off
4. **Fork/Join Parallelism** - Both agents can make progress simultaneously
5. **Direct User Communication** - Skill can present questions from either agent
6. **Easy Debugging** - All state and IPC files visible for inspection
7. **Incremental Progress** - Each iteration moves the process forward

### Example: Handling Large Commits

If the scribe agent detects a commit is too large:

1. **Scribe writes question file:**
   ```
   CONTEXT=Commit 3 "add authentication" is too large (23 files)
   OPTION_1=Three commits: (1) core auth (2) middleware (3) sessions
   OPTION_2=Two commits: (1) backend (2) frontend
   OPTION_3=Four commits: (1) schema (2) service (3) middleware (4) UI
   ```

2. **Skill detects question in polling loop and asks you**

3. **You choose Option 1**

4. **Skill writes answer file:**
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
│   └── narrate.md                     # Lightweight wrapper
├── skills/
│   └── rewriting-git-commits/
│       └── SKILL.md                   # Trampoline coordinator
├── agents/
│   ├── narrator.md                    # Main orchestrator (cyan)
│   └── scribe.md                      # Commit creator (orange)
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
