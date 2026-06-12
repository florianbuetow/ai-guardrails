export function runUserCode(code: string): unknown {
  return eval(code)
}
