module.exports = {
  forbidden: [
    {
      name: 'no-circular',
      severity: 'error',
      comment: 'Circular imports make modules impossible to reason about in isolation.',
      from: {},
      to: { circular: true },
    },
    {
      name: 'no-orphans',
      severity: 'error',
      comment: 'Every production module must be reachable from the CLI entrypoint or the public API.',
      from: {
        orphan: true,
        pathNot: ['\\.d\\.ts$', '^test/', '\\.test\\.ts$', '\\.test-d\\.ts$'],
      },
      to: {},
    },
    {
      name: 'production-not-to-tests',
      severity: 'error',
      comment: 'Production code must never depend on test code.',
      from: { path: '^src' },
      to: { path: '^test' },
    },
    {
      name: 'domain-not-to-outer-layers',
      severity: 'error',
      comment: 'Domain code must stay independent from application services and the CLI.',
      from: { path: '^src/domain' },
      to: { path: '^src/(application|cli|index\\.ts|lib\\.ts)' },
    },
    {
      name: 'application-not-to-cli',
      severity: 'error',
      comment: 'Application services must not depend on the CLI adapter.',
      from: { path: '^src/application' },
      to: { path: '^src/(cli|index\\.ts)' },
    },
    {
      name: 'domain-not-to-node-runtime',
      severity: 'error',
      comment: 'Domain code is pure: it must not touch the file system, processes, or the network.',
      from: { path: '^src/domain' },
      to: {
        dependencyTypes: ['core'],
        path: '^(node:)?(fs|fs/promises|child_process|process|net|http|https|os)$',
      },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: 'tsconfig.json' },
  },
}
