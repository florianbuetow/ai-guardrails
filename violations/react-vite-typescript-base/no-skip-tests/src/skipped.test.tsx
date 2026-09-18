import { describe, expect, it } from 'vitest'

describe('skipped suite', () => {
  it.skip('never runs', () => {
    expect(1).toBe(1)
  })
})
