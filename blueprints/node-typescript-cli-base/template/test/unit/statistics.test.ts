import { describe, expect, it } from 'vitest'

import { EmptySampleError, NonFiniteSampleError, summarize } from '../../src/domain/statistics.js'

describe('summarize', () => {
  it('computes count, min, max, and mean', () => {
    expect(summarize([3, 1, 2])).toEqual({ count: 3, min: 1, max: 3, mean: 2 })
  })

  it('handles a single value', () => {
    expect(summarize([7])).toEqual({ count: 1, min: 7, max: 7, mean: 7 })
  })

  it('handles negative values', () => {
    expect(summarize([-5, 5])).toEqual({ count: 2, min: -5, max: 5, mean: 0 })
  })

  it('rejects an empty sample explicitly', () => {
    expect(() => summarize([])).toThrow(EmptySampleError)
    expect(() => summarize([])).toThrow('cannot summarize an empty sample')
  })

  it('rejects non-finite values with their index', () => {
    expect(() => summarize([1, Number.NaN])).toThrow(NonFiniteSampleError)
    expect(() => summarize([1, Number.POSITIVE_INFINITY])).toThrow(
      'sample value at index 1 is not a finite number',
    )
  })
})
