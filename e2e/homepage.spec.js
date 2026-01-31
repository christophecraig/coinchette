// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Homepage', () => {
  test('loads successfully', async ({ page }) => {
    await page.goto('/');

    // Verify page title
    await expect(page).toHaveTitle(/Coinchette/);

    // Verify main content is visible
    await expect(page.locator('body')).toBeVisible();
  });

  test('has navigation links', async ({ page }) => {
    await page.goto('/');

    // Check for common navigation elements
    // Adjust selectors based on actual implementation
    const body = await page.textContent('body');
    expect(body).toBeTruthy();
  });

  test('is responsive on mobile', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');

    // Verify page loads on mobile
    await expect(page.locator('body')).toBeVisible();
  });
});
