#!/usr/bin/env node
import { run } from './cli/run.js'

const exitCode = await run(process.argv.slice(2), {
  stdin: process.stdin,
  stdout: process.stdout,
  stderr: process.stderr,
})
process.exitCode = exitCode
