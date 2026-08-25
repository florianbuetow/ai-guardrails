import { Client, StreamableHTTPClientTransport } from '@modelcontextprotocol/client'
import { createMcpHandler } from '@modelcontextprotocol/server'
import { describe, expect, it } from 'vitest'

import { createServer } from '../../src/server.js'

async function withClient(run: (client: Client) => Promise<void>): Promise<void> {
  const handler = createMcpHandler(createServer)
  const transport = new StreamableHTTPClientTransport(new URL('http://test.local/mcp'), {
    fetch: (url, init) => handler.fetch(new Request(url, init)),
  })
  const client = new Client(
    { name: 'test-harness', version: '1.0.0' },
    { versionNegotiation: { mode: 'auto' } },
  )
  await client.connect(transport)

  try {
    await run(client)
  } finally {
    await client.close()
    await handler.close()
  }
}

describe('MCP tools', () => {
  it('returns structured search results through a real client', async () => {
    await withClient(async (client) => {
      const result = await client.callTool({
        name: 'search',
        arguments: { query: 'protocol', limit: 10 },
      })

      expect(result.structuredContent).toEqual({
        items: [
          {
            id: 'protocol-testing',
            name: 'Protocol testing',
            description: 'Exercise MCP tools through a real client instead of calling handlers directly.',
          },
        ],
      })
    })
  })

  it('returns a model-readable error when an item is absent', async () => {
    await withClient(async (client) => {
      const result = await client.callTool({
        name: 'get-item',
        arguments: { id: 'missing' },
      })

      expect(result.isError).toBe(true)
      expect(result.content).toEqual([{ type: 'text', text: 'No item exists with id: missing' }])
    })
  })

  it('rejects invalid arguments before invoking a tool', async () => {
    await withClient(async (client) => {
      const result = await client.callTool({
        name: 'search',
        arguments: { query: 'protocol' },
      })

      expect(result.isError).toBe(true)
    })
  })
})
