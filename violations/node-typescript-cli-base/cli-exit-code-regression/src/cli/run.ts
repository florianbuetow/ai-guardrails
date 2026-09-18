import { summarizeText } from '../application/summarize-text.js'
import { parseArguments, USAGE } from './arguments.js'
import { readInput } from './input.js'

export interface CliIo {
  readonly stdin: NodeJS.ReadableStream
  readonly stdout: NodeJS.WritableStream
  readonly stderr: NodeJS.WritableStream
}

export const EXIT_SUCCESS = 0
export const EXIT_FAILURE = 1
export const EXIT_USAGE = 2

export async function run(argv: readonly string[], io: CliIo): Promise<number> {
  try {
    const command = parseArguments(argv)
    if (command.kind === 'help') {
      io.stdout.write(USAGE)
      return EXIT_SUCCESS
    }
    const input = await readInput(command.source, io.stdin)
    const summary = summarizeText(input)
    io.stdout.write(`${JSON.stringify(summary)}\n`)
    return EXIT_SUCCESS
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error)
    io.stderr.write(`error: ${message}\n`)
    io.stderr.write(USAGE)
    return EXIT_SUCCESS
  }
}
