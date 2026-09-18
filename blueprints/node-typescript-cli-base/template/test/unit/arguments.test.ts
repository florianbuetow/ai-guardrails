import { describe, expect, it } from 'vitest'

import { parseArguments, UsageError } from '../../src/cli/arguments.js'

describe('parseArguments', () => {
  it('recognizes both help flags', () => {
    expect(parseArguments(['--help'])).toEqual({ kind: 'help' })
    expect(parseArguments(['-h'])).toEqual({ kind: 'help' })
  })

  it('parses a summarize command with a file source', () => {
    expect(parseArguments(['summarize', 'data/input/numbers.txt'])).toEqual({
      kind: 'summarize',
      source: 'data/input/numbers.txt',
    })
  })

  it('parses a summarize command that reads stdin', () => {
    expect(parseArguments(['summarize', '-'])).toEqual({ kind: 'summarize', source: '-' })
  })

  it('rejects a missing command', () => {
    expect(() => parseArguments([])).toThrow(UsageError)
    expect(() => parseArguments([])).toThrow('missing command')
  })

  it('rejects an unknown command', () => {
    expect(() => parseArguments(['frobnicate'])).toThrow('unknown command: frobnicate')
  })

  it('rejects a missing or surplus source', () => {
    expect(() => parseArguments(['summarize'])).toThrow(
      'summarize takes exactly one source: a file path or -',
    )
    expect(() => parseArguments(['summarize', 'a', 'b'])).toThrow(
      'summarize takes exactly one source: a file path or -',
    )
  })

  it('rejects an empty source', () => {
    expect(() => parseArguments(['summarize', ''])).toThrow('summarize source must not be empty')
  })
})
