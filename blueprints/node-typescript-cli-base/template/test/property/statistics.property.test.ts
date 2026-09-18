import fc from 'fast-check'
import { describe, expect, it } from 'vitest'

import { parseNumbers } from '../../src/application/parse-numbers.js'
import { summarize } from '../../src/domain/statistics.js'

// Integers keep the arithmetic exact so the invariants below hold without tolerances.
const samples = fc.array(fc.integer({ min: -1_000_000, max: 1_000_000 }), { minLength: 1 })

describe('summarize properties', () => {
  it('keeps the mean inside [min, max] and counts every value', () => {
    fc.assert(
      fc.property(samples, (values) => {
        const summary = summarize(values)
        expect(summary.count).toBe(values.length)
        expect(summary.min).toBeLessThanOrEqual(summary.max)
        expect(summary.mean).toBeGreaterThanOrEqual(summary.min)
        expect(summary.mean).toBeLessThanOrEqual(summary.max)
      }),
    )
  })

  it('is invariant under permutation', () => {
    fc.assert(
      fc.property(samples, (values) => {
        const reversed = [...values].reverse()
        expect(summarize(reversed)).toEqual(summarize(values))
      }),
    )
  })
})

describe('parseNumbers properties', () => {
  it('round-trips integers written one per line', () => {
    fc.assert(
      fc.property(fc.array(fc.integer()), (values) => {
        expect(parseNumbers(values.map(String).join('\n'))).toEqual(values)
      }),
    )
  })
})
