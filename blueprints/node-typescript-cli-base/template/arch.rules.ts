import { functions, project, slices, tsconfig } from '@nielspeter/ts-archunit'
import { agentGuardrails } from '@nielspeter/ts-archunit/presets'
import { functionNoProcessEnv } from '@nielspeter/ts-archunit/rules/security'

const p = project('tsconfig.json')

// Rules are collected into the default export; `ts-archunit check` runs them.
export default [
  // The project's own compiler strictness is part of the architecture.
  tsconfig(p).requires({
    strict: true,
    noUncheckedIndexedAccess: true,
    exactOptionalPropertyTypes: true,
  }),

  // Guardrails for the mistakes AI coding agents make most: generic errors,
  // stub comments, empty bodies, and dynamic code execution.
  ...agentGuardrails(p, {
    src: '**/src/**',
    noInlineLogic: ['eval'],
    noGenericErrors: true,
    noStubs: true,
    noEmptyBodies: true,
  }),

  // Layer order: the CLI adapter calls application services, which call the domain.
  slices(p)
    .assignedFrom({
      cli: '**/src/cli/**',
      application: '**/src/application/**',
      domain: '**/src/domain/**',
    })
    .should()
    .respectLayerOrder('cli', 'application', 'domain')
    .rule({
      id: 'layers/cli-application-domain',
      because: 'Inner layers must stay reusable and testable without the CLI',
      suggestion: 'Move the dependency down a layer or pass the value in as an argument',
    }),

  slices(p).matching('src/(**)/').should().beFreeOfCycles(),

  // Domain and application code never read the process environment.
  functions(p)
    .that()
    .resideInFolder('**/src/{domain,application}/**')
    .should()
    .satisfy(functionNoProcessEnv())
    .rule({
      id: 'config/no-process-env-in-core',
      because: 'Environment access hides configuration inputs and makes behavior untestable',
      suggestion: 'Read configuration in the CLI layer and pass explicit values inward',
    }),
]
