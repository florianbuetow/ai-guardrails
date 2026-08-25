import { expect, it } from 'vitest'

it.skip('must never be silently omitted', () => {
  expect(true).toBe(false)
})
