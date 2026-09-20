import { mkdtemp, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { Readable } from 'node:stream'

import { describe, expect, it } from 'vitest'

import { readInput } from '../../src/cli/input.js'

async function rejection(operation: () => Promise<unknown>): Promise<Error> {
  try {
    await operation()
  } catch (error: unknown) {
    if (error instanceof Error) {
      return error
    }
    throw error
  }
  throw new Error('expected readInput to reject')
}

describe('readInput', () => {
  it('reads a file as UTF-8 text', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'read-input-'))
    const file = join(directory, 'numbers.txt')
    await writeFile(file, 'Grüße\n1\n2\n', 'utf8')
    expect(await readInput(file, Readable.from([]))).toBe('Grüße\n1\n2\n')
  })

  it('concatenates stdin chunks when the source is -', async () => {
    expect(await readInput('-', Readable.from(['1\n', '2\n']))).toBe('1\n2\n')
  })

  it('decodes a multi-byte character split across stdin chunks', async () => {
    const encoded = Buffer.from('äöü', 'utf8')
    const stdin = Readable.from([encoded.subarray(0, 3), encoded.subarray(3)])
    expect(await readInput('-', stdin)).toBe('äöü')
  })

  it('names the file and keeps the cause when the file cannot be read', async () => {
    const missing = join(tmpdir(), 'read-input-missing.txt')
    const error = await rejection(() => readInput(missing, Readable.from([])))
    expect(error.name).toBe('InputReadError')
    expect(error.message).toBe(`cannot read input from ${missing}`)
    expect(error.cause).toBeInstanceOf(Error)
  })

  it('names stdin and keeps the cause when the stream fails', async () => {
    const failure = new Error('stdin exploded')
    const stdin = Readable.from(
      (async function* (): AsyncGenerator<string> {
        yield '1\n'
        throw failure
      })(),
    )
    const error = await rejection(() => readInput('-', stdin))
    expect(error.name).toBe('InputReadError')
    expect(error.message).toBe('cannot read input from stdin')
    expect(error.cause).toBe(failure)
  })
})
