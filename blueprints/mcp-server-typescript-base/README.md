# TypeScript MCP Server Base Template

A Copier template for local Model Context Protocol servers built with the stable TypeScript SDK v2.

The generated project uses Node.js 22.19+, ES modules, npm, stdio transport, Zod v4 schemas, and a thin protocol layer over ordinary TypeScript services. It includes strict formatting, linting, type checking, dependency analysis, architecture checks, security checks, unit and protocol integration tests, coverage enforcement, and a fail-fast CI workflow.

## Generate a project

```bash
copier copy --trust blueprints/mcp-server-typescript-base ./my-mcp-server
cd ./my-mcp-server
just init
just test
```

Run `just inspect` to launch the official MCP Inspector against the built server.
