import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach } from 'vitest'

// Without Vitest globals enabled, Testing Library's automatic afterEach cleanup
// is not registered, so rendered components accumulate across tests in a file.
// Register it explicitly to unmount the DOM after every test.
afterEach(() => {
  cleanup()
})
