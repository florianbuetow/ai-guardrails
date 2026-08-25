import type { McpServer } from '@modelcontextprotocol/server'
import * as z from 'zod/v4'

import type { ItemService } from '../services/items.js'

const itemSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string(),
})

export function registerGetItemTool(server: McpServer, items: ItemService): void {
  server.registerTool(
    'get-item',
    {
      description: 'Get one example catalog item by its exact identifier',
      inputSchema: z.object({
        id: z.string().trim().min(1).describe('Exact item identifier'),
      }),
      outputSchema: z.object({ item: itemSchema }),
    },
    ({ id }) => {
      const item = items.get(id)
      if (item === undefined) {
        return {
          content: [{ type: 'text', text: `No item exists with id: ${id}` }],
          isError: true,
        }
      }

      const result = { item }
      return {
        content: [{ type: 'text', text: JSON.stringify(result) }],
        structuredContent: result,
      }
    },
  )
}
