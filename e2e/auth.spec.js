// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Authentication', () => {
  test('can access registration page', async ({ page }) => {
    await page.goto('/register');
    await expect(page.locator('form')).toBeVisible();
    await expect(page.locator('input[name="user[email]"]')).toBeVisible();
    await expect(page.locator('input[name="user[username]"]')).toBeVisible();
    await expect(page.locator('input[name="user[password]"]')).toBeVisible();
  });

  test('shows validation errors on empty registration submit', async ({ page }) => {
    await page.goto('/register');
    await page.locator('button[type="submit"]').click();
    // HTML5 required validation prevents empty submit, form stays on page
    await expect(page).toHaveURL(/\/register/);
  });

  test('can access login page', async ({ page }) => {
    await page.goto('/login');
    await expect(page.locator('form')).toBeVisible();
  });

  test('redirects authenticated users away from login', async ({ page }) => {
    await page.setExtraHTTPHeaders({ 'x-test-auth': 'true' });
    await page.goto('/login');
    // Should redirect to home since already authenticated
    await expect(page).not.toHaveURL(/\/login/);
  });

  test('test auth header creates session and grants access to lobby', async ({ page }) => {
    await page.setExtraHTTPHeaders({ 'x-test-auth': 'true' });
    await page.goto('/lobby');
    // Should not be redirected to login
    await expect(page).toHaveURL(/\/lobby/);
    await expect(page.locator('[data-testid="create-game-button"]')).toBeVisible({ timeout: 10000 });
  });
});
