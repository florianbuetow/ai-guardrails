import { spawnSync } from 'node:child_process'
import { mkdtempSync, readdirSync, readFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import { beforeAll, describe, expect, it } from 'vitest'

interface PackageManifest {
  readonly name: string
  readonly bin: Readonly<Record<string, string>>
  readonly exports: Readonly<Record<string, Readonly<Record<string, string>>>>
}

function runOrThrow(command: string, args: readonly string[], cwd: string): string {
  const result = spawnSync(command, args, { cwd, encoding: 'utf8' })
  if (result.error !== undefined) {
    throw result.error
  }
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(' ')} failed (${result.status}): ${result.stderr}`)
  }
  return result.stdout
}

describe('packed artifact', () => {
  const manifest = JSON.parse(readFileSync('package.json', 'utf8')) as PackageManifest
  let packageDir = ''

  beforeAll(() => {
    const dir = mkdtempSync(join(tmpdir(), 'pack-test-'))
    runOrThrow('npm', ['pack', '--pack-destination', dir], process.cwd())
    const tarballs = readdirSync(dir).filter((name) => name.endsWith('.tgz'))
    if (tarballs.length !== 1) {
      throw new Error(`expected exactly one tarball, found ${tarballs.length}`)
    }
    const [tarball] = tarballs
    if (tarball === undefined) {
      throw new Error('tarball name missing')
    }
    runOrThrow('tar', ['-xzf', join(dir, tarball), '-C', dir], dir)
    packageDir = join(dir, 'package')
  })

  it('ships the compiled bin, public API, and declarations, but no sources or tests', () => {
    const shipped = readdirSync(packageDir, { recursive: true }).map(String).sort()
    const [binPath] = Object.values(manifest.bin)
    expect(binPath).toBeDefined()
    expect(shipped).toContain(binPath?.replace(/^\.\//, ''))
    expect(shipped).toContain('dist/lib.js')
    expect(shipped).toContain('dist/lib.d.ts')
    expect(shipped).toContain('package.json')
    expect(shipped.some((entry) => entry.startsWith('src'))).toBe(false)
    expect(shipped.some((entry) => entry.startsWith('test'))).toBe(false)
  })

  it('runs the shipped CLI', () => {
    const [binPath] = Object.values(manifest.bin)
    if (binPath === undefined) {
      throw new Error('package.json declares no bin')
    }
    const output = runOrThrow(process.execPath, [join(packageDir, binPath), '--help'], packageDir)
    expect(output).toContain('Usage:')
  })

  it('exposes the public API from the shipped package', async () => {
    const entry = manifest.exports['.']?.['import']
    if (entry === undefined) {
      throw new Error('package.json declares no "." import export')
    }
    const api = (await import(join(packageDir, entry))) as { summarizeText: (s: string) => unknown }
    expect(api.summarizeText('1\n3\n')).toEqual({ count: 2, min: 1, max: 3, mean: 2 })
  })
})
