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
      comment: 'Every production module must be reachable from the stdio entrypoint.',
      from: {
        orphan: true,
        pathNot: ['\\.d\\.ts$', '^test/', '\\.test\\.ts$'],
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
      name: 'services-not-to-mcp-protocol',
      severity: 'error',
      comment: 'Business services must remain independent from MCP adapters and transports.',
      from: { path: '^src/services' },
      to: { path: '^src/(index|server|tools)' },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsPreCompilationDeps: true,
    tsConfig: { fileName: 'tsconfig.json' },
  },
}
