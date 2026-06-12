export function readValue(read: () => string): string {
  try {
    return read()
  } catch {}
  return ''
}
