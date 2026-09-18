export class InvalidNumberLineError extends Error {
  constructor(
    readonly line: number,
    readonly text: string,
  ) {
    super(`line ${line} is not a number: "${text}"`)
    this.name = 'InvalidNumberLineError'
  }
}

export function parseNumbers(input: string): number[] {
  const values: number[] = []
  input.split(/\r?\n/).forEach((rawLine, index) => {
    const text = rawLine.trim()
    if (text.length === 0) {
      return
    }
    const value = Number(text)
    if (!Number.isFinite(value)) {
      throw new InvalidNumberLineError(index + 1, text)
    }
    values.push(value)
  })
  return values
}
