import { describe, expect, it } from 'vitest'

import { bucket, grade } from '../../src/domain/grade.js'

describe('grade', () => {
  // Executes every branch but asserts nothing about the boundaries, so mutants survive.
  it('runs without throwing', () => {
    expect(() => [95, 85, 75, 65, 55, 45, 35, 25, 15, 5].map(grade)).not.toThrow()
    expect(() => [-1, 5, 50, 500, 5000, 50000, 500000].map(bucket)).not.toThrow()
  })
})
