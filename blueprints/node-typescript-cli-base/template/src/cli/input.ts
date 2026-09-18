import { readFile } from 'node:fs/promises'

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
      const chunks: Buffer[] = []
      for await (const chunk of stdin) {
        chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk)
      }
      return Buffer.concat(chunks).toString('utf8')
    }
    return await readFile(source, 'utf8')
  } catch (error: unknown) {
    throw new InputReadError(source, error)
  }
}
