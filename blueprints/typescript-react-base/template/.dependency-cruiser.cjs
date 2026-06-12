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
      comment: 'Every module must be reachable from an entry point.',
      from: {
        orphan: true,
        // Test files and e2e specs are entry points — discovered by their
        // runners, imported by nothing.
        pathNot: ['\\.d\\.ts$', '^src/test-setup\\.ts$', '\\.test\\.tsx?$', '^e2e/'],
      },
      to: {},
    },
    {
      name: 'src-not-to-e2e',
      severity: 'error',
      comment: 'Production code must never depend on e2e test code.',
      from: { path: '^src' },
      to: { path: '^e2e' },
    },
    {
      name: 'src-not-to-tests',
      severity: 'error',
      comment: 'Production code must never depend on unit test code.',
      from: { path: '^src', pathNot: '\\.test\\.tsx?$' },
      to: { path: '\\.test\\.tsx?$' },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: 'tsconfig.app.json' },
  },
}
