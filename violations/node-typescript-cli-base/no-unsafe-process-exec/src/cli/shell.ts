import { execSync } from 'node:child_process'

export function countLines(path: string): number {
  return Number(execSync(`wc -l < ${path}`, { encoding: 'utf8' }).trim())
}
