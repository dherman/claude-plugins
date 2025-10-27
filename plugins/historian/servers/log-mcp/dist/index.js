import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import * as fs from "node:fs";
import * as path from "node:path";
// Generate a unique ID for detail files (timestamp-based with random suffix)
function generateDetailsId() {
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 8);
    return `${timestamp}-${random}`;
}
// Format timestamp for log entries
function formatTimestamp() {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}
// Ensure directory exists
function ensureDir(dirPath) {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
}
// Main logging function
function log(args) {
    const { session, agent, message, details } = args;
    // Validate inputs
    if (!session || !agent || !message) {
        throw new Error("session, agent, and message are required");
    }
    const sessionDir = `/tmp/${session}`;
    const transcriptPath = path.join(sessionDir, 'transcript.log');
    const timestamp = formatTimestamp();
    // Ensure session directory exists
    ensureDir(sessionDir);
    let logLine;
    if (details) {
        // Generate unique ID for details file
        const detailsId = generateDetailsId();
        const logDir = path.join(sessionDir, 'log');
        const detailsPath = path.join(logDir, detailsId);
        // Ensure log directory exists
        ensureDir(logDir);
        // Write details to separate file
        fs.writeFileSync(detailsPath, details, 'utf8');
        // Format log line with details ID
        logLine = `[${timestamp}] [${agent}] [${detailsId}] ${message}\n`;
    }
    else {
        // Format log line without details
        logLine = `[${timestamp}] [${agent}] ${message}\n`;
    }
    // Append to transcript log
    fs.appendFileSync(transcriptPath, logLine, 'utf8');
    return logLine.trim();
}
// Create and configure the MCP server
const server = new Server({
    name: "log-mcp",
    version: "1.0.0",
}, {
    capabilities: {
        tools: {},
    },
});
// Define the log tool
const logTool = {
    name: "log",
    description: "Log a message to the session transcript with optional detailed output",
    inputSchema: {
        type: "object",
        properties: {
            session: {
                type: "string",
                description: "Session ID (e.g., 'historian-20251026-120316')",
            },
            agent: {
                type: "string",
                description: "Agent name (e.g., 'ANALYST', 'NARRATOR', 'SCRIBE')",
            },
            message: {
                type: "string",
                description: "Log message to append to transcript",
            },
            details: {
                type: "string",
                description: "Optional detailed message to save in a separate file",
            },
        },
        required: ["session", "agent", "message"],
    },
};
// Handle list_tools requests
server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: [logTool],
}));
// Handle call_tool requests
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    if (request.params.name === "log") {
        const args = request.params.arguments;
        try {
            const result = log(args);
            return {
                content: [
                    {
                        type: "text",
                        text: `Logged: ${result}`,
                    },
                ],
            };
        }
        catch (error) {
            const errorMessage = error instanceof Error ? error.message : String(error);
            return {
                content: [
                    {
                        type: "text",
                        text: `Error logging message: ${errorMessage}`,
                    },
                ],
                isError: true,
            };
        }
    }
    throw new Error(`Unknown tool: ${request.params.name}`);
});
// Start the server
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
}
main().catch((error) => {
    console.error("Server error:", error);
    process.exit(1);
});
