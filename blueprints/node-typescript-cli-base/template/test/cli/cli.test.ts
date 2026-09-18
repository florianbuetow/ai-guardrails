import { spawnSync } from 'node:child_process'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import { describe, expect, it } from 'vitest'

const CLI = join(process.cwd(), 'dist', 'index.js')

interface Result {
  readonly status: number | null
  readonly stdout: string
  readonly stderr: string
}

function runCli(args: readonly string[], stdin: string): Result {
  const result = spawnSync(process.execPath, [CLI, ...args], {
    input: stdin,
    encoding: 'utf8',
  })
  if (result.error !== undefined) {
    throw result.error
  }
  return { status: result.status, stdout: result.stdout, stderr: result.stderr }
}

describe('built CLI', () => {
  it('prints usage and exits 0 for --help', () => {
    const result = runCli(['--help'], '')
    expect(result.status).toBe(0)
    expect(result.stdout).toContain('Usage:')
    expect(result.stderr).toBe('')
  })

  it('summarizes a file argument', () => {
    const dir = mkdtempSync(join(tmpdir(), 'cli-test-'))
    const file = join(dir, 'numbers.txt')
    writeFileSync(file, '10\n20\n30\n')
    const result = runCli(['summarize', file], '')
    expect(result.status).toBe(0)
    expect(JSON.parse(result.stdout)).toEqual({ count: 3, min: 10, max: 30, mean: 20 })
    expect(result.stderr).toBe('')
  })

  it('summarizes stdin when the source is -', () => {
    const result = runCli(['summarize', '-'], '2\n4\n')
    expect(result.status).toBe(0)
    expect(JSON.parse(result.stdout)).toEqual({ count: 2, min: 2, max: 4, mean: 3 })
  })

  it('exits 2 with usage on stderr when arguments are missing', () => {
    const result = runCli([], '')
    expect(result.status).toBe(2)
    expect(result.stdout).toBe('')
    expect(result.stderr).toContain('error: missing command')
    expect(result.stderr).toContain('Usage:')
  })

  it('exits 1 and names the offending line for invalid input', () => {
    const result = runCli(['summarize', '-'], '1\nx\n')
    expect(result.status).toBe(1)
    expect(result.stdout).toBe('')
    expect(result.stderr).toBe('error: line 2 is not a number: "x"\n')
  })

  it('exits 1 for a missing file', () => {
    const result = runCli(['summarize', join(tmpdir(), 'missing-input-file.txt')], '')
    expect(result.status).toBe(1)
    expect(result.stderr).toMatch(/^error: cannot read input from /)
  })
})
