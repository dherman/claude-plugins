# My Claude Code Plugin Marketplace

This is my personal marketplace of Claude Code plugins.

## Available Plugins

### [Git Rewriter](plugins/git-rewriter/)

Rewrite git commit sequences to create clean, readable branches optimized for code review.

**Version:** 0.1.1

Takes messy commit history (WIP commits, fixes, typos) and rewrites it into logical, well-documented commits that tell a clear story.

[View Plugin Documentation →](plugins/git-rewriter/README.md)

## Installation

### Adding This Marketplace

To add this marketplace to Claude Code:

```bash
/plugin marketplace add https://github.com/dherman/claude-plugins
```

### Installing Plugins

Once the marketplace is added, install plugins with:

```bash
/plugin install git-rewriter@dherman
```

Or browse available plugins:

```bash
/plugin marketplace
```

## License

See individual plugin directories for licensing information.
