import { execFile } from 'node:child_process'

export function listDirectory(callback: (output: string) => void): void {
  const directory = process.argv[2]
  if (directory === undefined) {
    throw new TypeError('directory argument is required')
  }
  execFile('/bin/sh', ['-c', `ls ${directory}`], (error, stdout) => {
    if (error !== null) {
      throw error
    }
    callback(stdout)
  })
}
