import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  ListToolsRequestSchema,
  CallToolRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { handleToolCall, tools } from './tools.js';
import { handleResourceRead, listResources } from './resources.js';
import { createServer } from 'http';

const PORT = parseInt(process.env.MCP_SERVER_PORT || '3003', 10);

const server = new Server(
  { name: 'zk-identity-mcp-server', version: '0.1.0' },
  { capabilities: { tools: {}, resources: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: tools.map(({ name, description, inputSchema }) => ({
    name,
    description,
    inputSchema,
  })),
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  try {
    const result = await handleToolCall(request.params.name, request.params.arguments);
    return result;
  } catch (error) {
    return {
      content: [{ type: 'text', text: `Error: ${error.message}` }],
      isError: true,
    };
  }
});

server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: listResources(),
}));

server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  try {
    const result = await handleResourceRead(request.params.uri);
    return result;
  } catch (error) {
    return {
      contents: [{
        uri: request.params.uri,
        mimeType: 'text/plain',
        text: `Error: ${error.message}`,
      }],
    };
  }
});

async function run() {
  const transport = new StdioServerTransport();
  await server.connect(transport);

  const httpServer = createServer((req, res) => {
    if (req.url === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok', server: 'zk-identity-mcp-server', version: '0.1.0' }));
    } else {
      res.writeHead(404);
      res.end();
    }
  });

  httpServer.listen(PORT, () => {
    console.error(`zk-identity-mcp-server listening on port ${PORT}`);
  });
}

run().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
