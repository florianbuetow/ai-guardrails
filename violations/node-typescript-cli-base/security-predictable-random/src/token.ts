export function createSessionToken(): string {
  return Math.random().toString(36)
}
