import { describe, expectTypeOf, it } from 'vitest'

import {
  EmptySampleError,
  InvalidNumberLineError,
  NonFiniteSampleError,
  parseNumbers,
  summarize,
  summarizeText,
  type Summary,
} from '../../src/lib.js'

describe('public API contract', () => {
  it('exposes an immutable summary shape', () => {
    expectTypeOf<Summary>().toEqualTypeOf<{
      readonly count: number
      readonly min: number
      readonly max: number
      readonly mean: number
    }>()
  })

  it('summarize accepts read-only number arrays and returns a Summary', () => {
    expectTypeOf(summarize).parameter(0).toEqualTypeOf<readonly number[]>()
    expectTypeOf(summarize).returns.toEqualTypeOf<Summary>()
  })

  it('text helpers keep string in and numbers out', () => {
    expectTypeOf(parseNumbers).toEqualTypeOf<(input: string) => number[]>()
    expectTypeOf(summarizeText).toEqualTypeOf<(input: string) => Summary>()
  })

  it('errors are real Error subclasses with typed context', () => {
    expectTypeOf<EmptySampleError>().toMatchTypeOf<Error>()
    expectTypeOf<NonFiniteSampleError>().toMatchTypeOf<Error & { readonly index: number }>()
    expectTypeOf<InvalidNumberLineError>().toMatchTypeOf<
      Error & { readonly line: number; readonly text: string }
    >()
  })
})
