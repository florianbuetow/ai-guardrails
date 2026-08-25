import { Client } from '@modelcontextprotocol/client'
import { StdioClientTransport } from '@modelcontextprotocol/client/stdio'
import { expect, it } from 'vitest'

it('serves tools through the built stdio entrypoint', async () => {
  const client = new Client(
    { name: 'stdio-test-harness', version: '1.0.0' },
    { versionNegotiation: { mode: 'auto' } },
  )
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: ['dist/index.js'],
  })
  await client.connect(transport)

  try {
    const result = await client.callTool({
      name: 'get-item',
      arguments: { id: 'guardrail-design' },
    })
    expect(result.structuredContent).toEqual({
      item: {
        id: 'guardrail-design',
        name: 'Guardrail design',
        description: 'Design validation rules that fail fast with actionable feedback.',
      },
    })
  } finally {
    await client.close()
  }
})
