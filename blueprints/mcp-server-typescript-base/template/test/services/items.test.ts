import { describe, expect, it } from 'vitest'

import { ItemService } from '../../src/services/items.js'

describe('ItemService', () => {
  const service = new ItemService()

  it('searches item names and respects the requested limit', () => {
    expect(service.search('service', 1)).toEqual([
      {
        id: 'service-boundaries',
        name: 'Service boundaries',
        description: 'Keep business logic independent from MCP schemas and transports.',
      },
    ])
  })

  it('gets an item by exact identifier', () => {
    expect(service.get('protocol-testing')).toEqual({
      id: 'protocol-testing',
      name: 'Protocol testing',
      description: 'Exercise MCP tools through a real client instead of calling handlers directly.',
    })
  })

  it('returns undefined when an item does not exist', () => {
    expect(service.get('missing')).toBeUndefined()
  })

  it('rejects invalid service inputs explicitly', () => {
    expect(() => service.search(' ', 1)).toThrow('query must not be blank')
    expect(() => service.search('service', 0)).toThrow('limit must be an integer from 1 through 100')
    expect(() => service.get(' ')).toThrow('id must not be blank')
  })
})
