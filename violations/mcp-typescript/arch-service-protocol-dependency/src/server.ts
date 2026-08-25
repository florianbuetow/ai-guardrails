import { McpServer } from '@modelcontextprotocol/server'

import { SERVER_CONFIG } from './config.js'
import { ItemService } from './services/items.js'
import { leakedProtocolRegistration } from './services/protocol-leak.js'
import { registerTools } from './tools/index.js'

export function createServer(): McpServer {
  void leakedProtocolRegistration
  const server = new McpServer(SERVER_CONFIG)
  registerTools(server, { items: new ItemService() })
  return server
}
