export function resolveSource(): string {
  return process.argv[2] ?? 'data/input/numbers.txt'
}
