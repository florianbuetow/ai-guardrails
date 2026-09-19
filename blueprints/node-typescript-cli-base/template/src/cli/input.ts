import { readFile } from 'node:fs/promises'
import { text } from 'node:stream/consumers'

class InputReadError extends Error {
  constructor(
    readonly source: string,
    cause: unknown,
  ) {
    super(`cannot read input from ${source === '-' ? 'stdin' : source}`, { cause })
    this.name = 'InputReadError'
  }
}

export async function readInput(source: string, stdin: NodeJS.ReadableStream): Promise<string> {
  try {
    if (source === '-') {
      return await text(stdin)
    }
    return await readFile(source, 'utf8')
  } catch (error: unknown) {
    throw new InputReadError(source, error)
  }
}
