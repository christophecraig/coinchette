// @ts-check
const { test, expect } = require('@playwright/test');
const { loginAsTestUser, navigateToProfile } = require('./helpers');

test.describe('Profile Page', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsTestUser(page);
  });

  test('can navigate to profile page', async ({ page }) => {
    await navigateToProfile(page);
    await expect(page).toHaveURL(/\/profile/);
  });

  test('shows username', async ({ page }) => {
    await navigateToProfile(page);

    const username = page.locator('[data-testid="profile-username"]');
    await expect(username).toBeVisible();
    await expect(username).toContainText('Profil de');
  });

  test('shows stats cards', async ({ page }) => {
    await navigateToProfile(page);

    const statsCards = page.locator('[data-testid="stats-cards"]');
    await expect(statsCards).toBeVisible();

    // Should have stat cards for games, wins, losses, best score
    await expect(page.getByText('Parties jouées')).toBeVisible();
    await expect(page.getByText('Victoires', { exact: true })).toBeVisible();
    await expect(page.getByText('Défaites', { exact: true })).toBeVisible();
  });

  test('shows recent games section', async ({ page }) => {
    await navigateToProfile(page);

    const recentGames = page.locator('[data-testid="recent-games"]');
    await expect(recentGames).toBeVisible();
    await expect(page.getByText('Historique récent')).toBeVisible();
  });
});
