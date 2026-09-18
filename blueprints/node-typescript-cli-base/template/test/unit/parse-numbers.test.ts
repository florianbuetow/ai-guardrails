import { describe, expect, it } from 'vitest'

import { InvalidNumberLineError, parseNumbers } from '../../src/application/parse-numbers.js'
import { summarizeText } from '../../src/application/summarize-text.js'

describe('parseNumbers', () => {
  it('parses one number per line and skips blank lines', () => {
    expect(parseNumbers('1\n\n 2.5 \r\n-3\n')).toEqual([1, 2.5, -3])
  })

  it('returns an empty list for blank input', () => {
    expect(parseNumbers('\n  \n')).toEqual([])
  })

  it('reports the line number and text of an invalid entry', () => {
    expect(() => parseNumbers('1\nabc\n3')).toThrow(InvalidNumberLineError)
    expect(() => parseNumbers('1\nabc\n3')).toThrow('line 2 is not a number: "abc"')
  })

  it('rejects non-finite entries', () => {
    expect(() => parseNumbers('Infinity')).toThrow(InvalidNumberLineError)
  })
})

describe('summarizeText', () => {
  it('summarizes parsed text', () => {
    expect(summarizeText('4\n8\n')).toEqual({ count: 2, min: 4, max: 8, mean: 6 })
  })

  it('propagates the empty sample error for blank text', () => {
    expect(() => summarizeText('')).toThrow('cannot summarize an empty sample')
  })
})
