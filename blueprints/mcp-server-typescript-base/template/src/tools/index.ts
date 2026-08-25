import type { McpServer } from '@modelcontextprotocol/server'

import type { ItemService } from '../services/items.js'
import { registerGetItemTool } from './get-item.js'
import { registerSearchTool } from './search.js'

export interface ToolDependencies {
  items: ItemService
}

export function registerTools(server: McpServer, dependencies: ToolDependencies): void {
  registerSearchTool(server, dependencies.items)
  registerGetItemTool(server, dependencies.items)
}
