export interface Item {
  id: string
  name: string
  description: string
}

const ITEMS: readonly Item[] = [
  {
    id: 'guardrail-design',
    name: 'Guardrail design',
    description: 'Design validation rules that fail fast with actionable feedback.',
  },
  {
    id: 'protocol-testing',
    name: 'Protocol testing',
    description: 'Exercise MCP tools through a real client instead of calling handlers directly.',
  },
  {
    id: 'service-boundaries',
    name: 'Service boundaries',
    description: 'Keep business logic independent from MCP schemas and transports.',
  },
]

export class ItemService {
  search(query: string, limit: number): Item[] {
    const normalizedQuery = query.trim().toLocaleLowerCase()
    if (normalizedQuery.length === 0) {
      throw new Error('query must not be blank')
    }
    if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
      throw new Error('limit must be an integer from 1 through 100')
    }

    return ITEMS.filter((item) => {
      const searchableText = `${item.name} ${item.description}`.toLocaleLowerCase()
      return searchableText.includes(normalizedQuery)
    }).slice(0, limit)
  }

  get(id: string): Item | undefined {
    const normalizedId = id.trim()
    if (normalizedId.length === 0) {
      throw new Error('id must not be blank')
    }

    return ITEMS.find((item) => item.id === normalizedId)
  }
}
