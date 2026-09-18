import { summarize, type Summary } from '../domain/statistics.js'
import { parseNumbers } from './parse-numbers.js'

export function summarizeText(input: string): Summary {
  return summarize(parseNumbers(input))
}
