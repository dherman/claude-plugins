# Log MCP Server

MCP server for structured logging with optional detailed messages.

## Overview

Provides a `log` tool that agents can use for consistent, timestamped logging without worrying about bash quoting issues.

## Features

- **Timestamped logs**: Automatic timestamp formatting
- **Agent-tagged**: Each log entry is tagged with the agent name
- **Optional details**: Large outputs can be saved to separate files
- **Consistent format**: No bash quoting issues

## Tool: `log`

### Parameters

- `session` (required): Session ID (e.g., "historian-20251026-120316")
- `agent` (required): Agent name in uppercase (e.g., "ANALYST", "NARRATOR", "SCRIBE")
- `message` (required): Log message to append to transcript
- `details` (optional): Detailed message to save in a separate file

### Output Format

**Without details:**
```
[2025-10-26 12:03:29] [ANALYST] Starting analysis
```

**With details:**
```
[2025-10-26 12:03:29] [ANALYST] [1730000609123-a3f2d9] Created commit plan
```

When details are provided, a unique ID is generated and the detailed message is saved to:
```
/tmp/{session_id}/log/{details_id}
```

## Usage Example

```typescript
// Simple log
log({
  session: "historian-20251026-120316",
  agent: "SCRIBE",
  message: "Processing request for commit 1"
})

// Log with details
log({
  session: "historian-20251026-120316",
  agent: "NARRATOR",
  message: "Received commit plan",
  details: JSON.stringify(commitPlan, null, 2)
})
```

## File Structure

```
/tmp/{session_id}/
├── transcript.log          # Main log file
└── log/                    # Details directory
    ├── 1730000609123-a3f2d9
    ├── 1730000610456-b8c1e2
    └── ...
```

## Building

```bash
npm install
npm run build
```

This creates:
- `dist/index.js` - Compiled TypeScript
- `dist/bundle.js` - Bundled standalone executable

## Testing

### Quick Test
```bash
cd servers/log-mcp
chmod +x test-simple.sh
./test-simple.sh
```

This verifies:
- Bundle exists and has correct shebang
- No duplicate shebang (common build issue)
- Server can start without errors

### Integration Test

The MCP server will be automatically loaded by Claude Code when the historian plugin is installed. To verify it's working:

1. Reinstall the historian plugin
2. Check Claude Code's MCP server logs
3. Use the `/historian:narrate` command and check `/tmp/historian-*/transcript.log` for properly formatted timestamps

### Manual Test

To test the `log` tool manually:
```bash
node dist/bundle.js
```

Then send a JSON-RPC request via stdin:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "log",
    "arguments": {
      "session": "test-session",
      "agent": "TEST",
      "message": "Hello world"
    }
  }
}
```

Check `/tmp/test-session/transcript.log` for the logged message.
