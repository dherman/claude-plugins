#!/usr/bin/env node

/**
 * Sidechat MCP Server
 *
 * A session-based communication system for coordinating agents.
 * Agents communicate by sending JSON messages through named sessions,
 * creating a "sidechat" alongside their main work.
 *
 * Tools:
 * - send_message: Send a message to an agent's inbox
 * - receive_message: Block until a message arrives (with optional timeout)
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import * as fs from "fs/promises";
import * as path from "path";
import * as os from "os";

// Types
interface SendMessageArgs {
  session: string;
  to: string;
  message: unknown;
}

interface ReceiveMessageArgs {
  session: string;
  as: string;
  timeout?: number;
}

interface Message {
  id: string;
  timestamp: number;
  from?: string;
  message: unknown;
}

// Global state
let serverInstanceId: string;
let baseDir: string;

/**
 * Initialize server instance with unique ID and base directory
 */
function initializeServer(): void {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const random = Math.random().toString(36).substring(2, 8);
  serverInstanceId = `${timestamp}-${random}`;
  baseDir = path.join(os.tmpdir(), `sidechat-${serverInstanceId}`);
}

/**
 * Get the inbox directory path for an agent in a session
 */
function getInboxPath(session: string, agentId: string): string {
  return path.join(baseDir, session, agentId, 'inbox');
}

/**
 * Ensure directory exists
 */
async function ensureDir(dirPath: string): Promise<void> {
  await fs.mkdir(dirPath, { recursive: true });
}

/**
 * Generate unique message ID
 */
function generateMessageId(): string {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 9);
  return `msg-${timestamp}-${random}`;
}

/**
 * Send a message to an agent's inbox
 */
async function sendMessage(args: SendMessageArgs): Promise<{ message_id: string }> {
  const { session, to, message } = args;

  // Validate inputs
  if (!session || typeof session !== 'string') {
    throw new Error('session is required and must be a string');
  }
  if (!to || typeof to !== 'string') {
    throw new Error('to is required and must be a string');
  }

  // Create inbox if it doesn't exist
  const inboxPath = getInboxPath(session, to);
  await ensureDir(inboxPath);

  // Create message
  const messageId = generateMessageId();
  const messageData: Message = {
    id: messageId,
    timestamp: Date.now(),
    message,
  };

  // Write message to file
  const messagePath = path.join(inboxPath, `${messageId}.json`);
  await fs.writeFile(messagePath, JSON.stringify(messageData, null, 2));

  return { message_id: messageId };
}

/**
 * Receive a message from an agent's inbox (blocks until message arrives)
 */
async function receiveMessage(
  args: ReceiveMessageArgs
): Promise<{ message_id: string; message: unknown } | null> {
  const { session, as: agentId, timeout } = args;

  // Validate inputs
  if (!session || typeof session !== 'string') {
    throw new Error('session is required and must be a string');
  }
  if (!agentId || typeof agentId !== 'string') {
    throw new Error('as is required and must be a string');
  }

  const inboxPath = getInboxPath(session, agentId);
  await ensureDir(inboxPath);

  const startTime = Date.now();
  const pollInterval = 200; // Poll every 200ms

  while (true) {
    // Check for timeout
    if (timeout !== undefined) {
      const elapsed = Date.now() - startTime;
      if (elapsed >= timeout) {
        return null; // Timeout reached
      }
    }

    // Read inbox directory
    const files = await fs.readdir(inboxPath);
    const jsonFiles = files.filter(f => f.endsWith('.json')).sort();

    if (jsonFiles.length > 0) {
      // Read and parse the first (oldest) message
      const messageFile = jsonFiles[0];
      const messagePath = path.join(inboxPath, messageFile);
      const content = await fs.readFile(messagePath, 'utf-8');
      const messageData: Message = JSON.parse(content);

      // Delete the message file
      await fs.unlink(messagePath);

      return {
        message_id: messageData.id,
        message: messageData.message,
      };
    }

    // Wait before polling again
    await new Promise(resolve => setTimeout(resolve, pollInterval));
  }
}

/**
 * Main server setup
 */
async function main(): Promise<void> {
  initializeServer();

  const server = new Server(
    {
      name: "sidechat",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // List available tools
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
      tools: [
        {
          name: "send_message",
          description:
            "Send a message to an agent's inbox within a session. " +
            "The session ID must be agreed upon by all coordinating agents. " +
            "Messages are delivered in FIFO order.",
          inputSchema: {
            type: "object",
            properties: {
              session: {
                type: "string",
                description: "Session ID shared by coordinating agents",
              },
              to: {
                type: "string",
                description: "Target agent ID to receive the message",
              },
              message: {
                type: "object",
                description: "Message payload (free-form JSON)",
              },
            },
            required: ["session", "to", "message"],
          },
        },
        {
          name: "receive_message",
          description:
            "Receive the next message from an agent's inbox. " +
            "Blocks until a message arrives or timeout is reached. " +
            "Returns null if timeout is reached with no message.",
          inputSchema: {
            type: "object",
            properties: {
              session: {
                type: "string",
                description: "Session ID shared by coordinating agents",
              },
              as: {
                type: "string",
                description: "Agent ID receiving the message",
              },
              timeout: {
                type: "number",
                description: "Optional timeout in milliseconds. If omitted, blocks indefinitely.",
              },
            },
            required: ["session", "as"],
          },
        },
      ],
    };
  });

  // Handle tool calls
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    try {
      if (name === "send_message") {
        const result = await sendMessage(args as unknown as SendMessageArgs);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      if (name === "receive_message") {
        const result = await receiveMessage(args as unknown as ReceiveMessageArgs);
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      throw new Error(`Unknown tool: ${name}`);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({ error: errorMessage }, null, 2),
          },
        ],
        isError: true,
      };
    }
  });

  // Start server
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error(`Sidechat MCP Server started (instance: ${serverInstanceId})`);
  console.error(`Base directory: ${baseDir}`);
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
