# Sidechat MCP Server

A session-based communication system for coordinating agents via MCP (Model Context Protocol).

## Overview

Sidechat provides simple, reliable communication between agents using a session-based model. Agents can "sidechat" with each other by sending and receiving JSON messages through named inboxes, creating a communication channel alongside their main work.

## Concepts

### Sessions

A **session** is a unique identifier that groups related agents together. All agents participating in the same coordination must agree on a session ID. How you establish this session ID is up to you:

- Use a timestamp-based identifier
- Use a work directory name
- Use any unique string your agents can share

Sessions are completely isolated - agents in different sessions cannot see each other's messages.

### Agent IDs

Within a session, each agent has a unique **agent ID** (a simple string like `"narrator"` or `"scribe"`). Messages are addressed to agent IDs.

### Messages

Messages are free-form JSON objects. The structure and content are entirely up to the agents using the server. Common patterns include:

```json
{ "type": "request", "data": {...} }
{ "type": "response", "status": "success", "result": {...} }
```

## Tools

### `send_message`

Send a message to an agent's inbox.

**Parameters:**
- `session` (string, required): Session ID
- `to` (string, required): Target agent ID
- `message` (object, required): Message payload (any JSON object)

**Returns:**
```json
{ "message_id": "msg-1234567890-abc123" }
```

**Example:**
```typescript
send_message({
  session: "historian-20251024-140530",
  to: "scribe",
  message: {
    type: "commit_request",
    commit_num: 1,
    description: "Add user authentication"
  }
})
```

### `receive_message`

Receive the next message from an agent's inbox. **Blocks** until a message arrives or timeout is reached.

**Parameters:**
- `session` (string, required): Session ID
- `as` (string, required): Agent ID receiving the message
- `timeout` (number, optional): Timeout in milliseconds. If omitted, blocks indefinitely.

**Returns:**
```json
{
  "message_id": "msg-1234567890-abc123",
  "message": { ... }
}
```

Returns `null` if timeout is reached with no message.

**Example:**
```typescript
// Wait indefinitely
receive_message({
  session: "historian-20251024-140530",
  as: "narrator"
})

// With timeout (30 seconds)
receive_message({
  session: "historian-20251024-140530",
  as: "narrator",
  timeout: 30000
})
```

## Message Delivery

- Messages are delivered in **FIFO order** (first in, first out)
- Messages persist until received
- Once received, messages are automatically deleted
- Messages are stored in `/tmp/sidechat-{instance-id}/{session}/{agent}/inbox/`

## Usage in Claude Code Plugins

### 1. Add to plugin.json

```json
{
  "mcpServers": {
    "sidechat": {
      "command": "node",
      "args": ["${CLAUDE_PLUGIN_ROOT}/servers/sidechat-mcp/dist/index.js"]
    }
  }
}
```

### 2. Use in Agent Prompts

Agents automatically get access to `send_message` and `receive_message` tools:

```bash
# In narrator agent:
SESSION_ID="my-unique-session"

# Send a message
send_message \
  --session "$SESSION_ID" \
  --to "scribe" \
  --message '{"type":"request","data":"..."}'

# Receive a message
receive_message \
  --session "$SESSION_ID" \
  --as "narrator"
```

## Development

### Build

```bash
npm install
npm run build
```

### Watch Mode

```bash
npm run watch
```

## Design Philosophy

This MCP server is intentionally **generic and plugin-agnostic**:

- No assumptions about message structure
- No knowledge of specific use cases
- Simple session-based isolation
- Minimal API surface

This makes it easy to extract into a standalone package or reuse across different plugins.

## Future Enhancements

Potential additions (not yet implemented):

- `has_messages(session, agent)` - Check inbox without blocking
- `clear_messages(session, agent)` - Delete all pending messages
- Message priorities or filtering
- Broadcast messages to multiple agents
- Session lifecycle management

## License

MIT
