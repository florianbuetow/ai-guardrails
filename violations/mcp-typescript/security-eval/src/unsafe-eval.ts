export function evaluateUntrustedInput(source: string): unknown {
  return eval(source)
}
