// @ts-check
const { test, expect } = require('@playwright/test');
const { loginAsTestUser, waitForLiveView, navigateToFriends } = require('./helpers');

test.describe('Friends Page', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsTestUser(page);
  });

  test('can navigate to friends page', async ({ page }) => {
    await navigateToFriends(page);
    await expect(page).toHaveURL(/\/friends/);
  });

  test('shows 3 tabs', async ({ page }) => {
    await navigateToFriends(page);

    await expect(page.locator('[data-testid="tab-friends"]')).toBeVisible();
    await expect(page.locator('[data-testid="tab-requests"]')).toBeVisible();
    await expect(page.locator('[data-testid="tab-search"]')).toBeVisible();
  });

  test('can switch to search tab and see search input', async ({ page }) => {
    await navigateToFriends(page);

    await page.locator('[data-testid="tab-search"]').click();
    await expect(page.locator('[data-testid="search-input"]')).toBeVisible();
    await expect(page.locator('[data-testid="search-button"]')).toBeVisible();
  });

  test('can switch between tabs', async ({ page }) => {
    await navigateToFriends(page);

    // Switch to requests tab
    await page.locator('[data-testid="tab-requests"]').click();
    // Should show requests content (received/sent headings)
    await expect(page.getByText('Demandes reçues')).toBeVisible();

    // Switch to search tab
    await page.locator('[data-testid="tab-search"]').click();
    await expect(page.locator('[data-testid="search-input"]')).toBeVisible();

    // Switch back to friends tab
    await page.locator('[data-testid="tab-friends"]').click();
  });

  test('can type in search input', async ({ page }) => {
    await navigateToFriends(page);

    await page.locator('[data-testid="tab-search"]').click();
    const input = page.locator('[data-testid="search-input"]');
    await input.fill('test');
    await expect(input).toHaveValue('test');
  });
});
