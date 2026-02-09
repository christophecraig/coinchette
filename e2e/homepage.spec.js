// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Homepage', () => {
  test('loads successfully with title', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/Coinchette/);
  });

  test('shows login and sign up links when not authenticated', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('a[href="/login"]')).toBeVisible();
    await expect(page.locator('a[href="/register"]')).toBeVisible();
  });

  test('shows lobby link when authenticated', async ({ page }) => {
    await page.setExtraHTTPHeaders({ 'x-test-auth': 'true' });
    await page.goto('/');
    await expect(page.locator('a[href="/lobby"]')).toBeVisible();
  });

  test('is responsive on mobile', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');
    await expect(page).toHaveTitle(/Coinchette/);
    await expect(page.locator('body')).toBeVisible();
  });
});
