---
description: Write a personalized poem for you
allowed-tools: Task
---

# Poem Command

This command invokes the poet agent to write you a personalized poem.

## Your Task

Simply launch the poet agent:

```
Task(
  subagent_type: "poet:poet",
  description: "Write personalized poem",
  prompt: "Please write a personalized poem for the user. Ask them for their name first."
)
```

The poet agent will:
1. Ask the user for their name
2. Write a personalized poem
3. Present it to the user
