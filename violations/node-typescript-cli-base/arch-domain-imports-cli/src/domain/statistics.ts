import { USAGE } from '../cli/arguments.js'

export interface Summary {
  readonly count: number
  readonly min: number
  readonly max: number
  readonly mean: number
}

export class EmptySampleError extends Error {
  constructor() {
    super(`cannot summarize an empty sample\n${USAGE}`)
    this.name = 'EmptySampleError'
  }
}

export class NonFiniteSampleError extends Error {
  constructor(readonly index: number) {
    super(`sample value at index ${index} is not a finite number`)
    this.name = 'NonFiniteSampleError'
  }
}

export function summarize(values: readonly number[]): Summary {
  if (values.length === 0) {
    throw new EmptySampleError()
  }

  let min = Number.POSITIVE_INFINITY
  let max = Number.NEGATIVE_INFINITY
  let total = 0
  values.forEach((value, index) => {
    if (!Number.isFinite(value)) {
      throw new NonFiniteSampleError(index)
    }
    min = Math.min(min, value)
    max = Math.max(max, value)
    total += value
  })

  return { count: values.length, min, max, mean: total / values.length }
}
