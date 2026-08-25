import type { McpServer } from '@modelcontextprotocol/server'
import * as z from 'zod/v4'

import type { ItemService } from '../services/items.js'

const itemSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string(),
})

export function registerSearchTool(server: McpServer, items: ItemService): void {
  server.registerTool(
    'search',
    {
      description: 'Search the example item catalog by text',
      inputSchema: z.object({
        query: z.string().trim().min(1).describe('Text to find in item names and descriptions'),
        limit: z.number().int().min(1).max(100).describe('Maximum number of items to return'),
      }),
      outputSchema: z.object({
        items: z.array(itemSchema),
      }),
    },
    ({ query, limit }) => {
      const result = { items: items.search(query, limit) }
      return {
        content: [{ type: 'text', text: JSON.stringify(result) }],
        structuredContent: result,
      }
    },
  )
}
