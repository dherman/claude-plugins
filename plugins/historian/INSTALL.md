# Installing the Historian Plugin

This plugin can be installed from GitHub so it's available across all your projects.

## Installation Steps

### 1. Add the GitHub Marketplace

From any directory in Claude Code, run:

```bash
/plugin marketplace add https://github.com/dherman/claude-plugins
```

This adds the GitHub repository as a plugin marketplace.

### 2. Install the Plugin

```bash
/plugin install historian@dherman
```

This installs the plugin from the GitHub marketplace.

### 3. Verify Installation

Check that the plugin is available:

```bash
/help
```

You should see `/narrate` in the list of available commands.

Also check:

```bash
/agents
```

You should see `commit-writer` in the list.

```bash
/skills
```

You should see "Rewriting Git Commits" skill.

### 4. Configure Permissions (Optional but Recommended)

To avoid constant approval prompts, add permissions to your settings:

**Option A: Global (All Projects)**

Edit `~/.claude/settings.json` to include the permissions from this plugin's [settings.json](settings.json) file.

**Option B: Per-Project**

Copy the plugin's [settings.json](settings.json) file to `.claude/settings.json` in your project repository.

## Usage

Navigate to any git repository and run:

```bash
/narrate Your changeset description here
```

For example:

```bash
/narrate Add user authentication with OAuth support
```

## Uninstalling

To remove the plugin:

```bash
/plugin uninstall historian
```

To remove the GitHub marketplace:

```bash
/plugin marketplace remove dherman
```

## Updating

The plugin will automatically update when changes are pushed to the GitHub repository. To force an update:

```bash
/plugin uninstall historian
/plugin install historian@dherman
```

## Troubleshooting

### Plugin not showing up

- Verify marketplace was added: `/plugin marketplace list`
- Try reinstalling: `/plugin uninstall historian && /plugin install historian@dherman`
- Restart Claude Code

### Commands not available

- Run `/help` to verify the command is loaded
- Check that you're in a git repository
- Restart Claude Code after installation

### Too many approval prompts

- Configure permissions as described in step 4 above
- Restart Claude Code after updating settings
