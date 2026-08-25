import { McpServer } from '@modelcontextprotocol/server'

import { SERVER_CONFIG } from './config.js'
import { ItemService } from './services/items.js'
import { registerTools } from './tools/index.js'

export function createServer(): McpServer {
  const server = new McpServer(SERVER_CONFIG)
  registerTools(server, { items: new ItemService() })
  return server
}
