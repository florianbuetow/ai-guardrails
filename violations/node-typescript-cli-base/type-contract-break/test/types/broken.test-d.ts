import { expectTypeOf, it } from 'vitest'

import { summarize } from '../../src/lib.js'

it('claims a contract the implementation does not provide', () => {
  expectTypeOf(summarize).returns.toEqualTypeOf<string>()
})
