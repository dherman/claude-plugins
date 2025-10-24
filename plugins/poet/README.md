# Poet - Experimental Plugin

A simple experimental plugin to test whether Claude Code agents can directly use the AskUserQuestion tool.

## Purpose

This plugin tests if:
- An agent launched via Task can use AskUserQuestion
- User responses are properly passed back to the agent
- The agent can continue execution after receiving the response

## Usage

```
/poem
```

The agent will:
1. Ask for your name
2. Write a personalized poem
3. Show you the result

## What We're Testing

If this works directly without any trampoline/coordinator:
- Agents CAN ask users questions directly
- The fork/join model supports user interaction
- We may not need the complex trampoline pattern in historian

If this doesn't work:
- We'll see how the agent behaves
- We'll learn what limitations exist
- We can design around them
