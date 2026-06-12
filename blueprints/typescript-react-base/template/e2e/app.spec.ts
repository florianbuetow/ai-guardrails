import { expect, test } from '@playwright/test'

test('app loads and renders content', async ({ page }) => {
  await page.goto('/')
  await expect(page.locator('#root')).not.toBeEmpty()
})
