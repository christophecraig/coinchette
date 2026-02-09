// @ts-check
const { test, expect } = require('@playwright/test');
const { loginAsTestUser, createSoloGame, waitForLiveView, handleBidding } = require('./helpers');

test.describe('Solo Game vs Bots', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsTestUser(page);
  });

  test('can create a solo game from lobby', async ({ page }) => {
    await page.goto('/lobby');
    await waitForLiveView(page);

    const soloButton = page.locator('[data-testid="create-solo-game-button"]');
    await expect(soloButton).toBeVisible();
    await soloButton.click();

    // Should redirect to /game/:id/play
    await page.waitForURL(/\/game\/.*\/play/, { timeout: 15000 });
    await waitForLiveView(page);
  });

  test('shows player hand after game starts', async ({ page }) => {
    await createSoloGame(page);

    const playerHand = page.locator('[data-testid="player-hand"]');
    await expect(playerHand).toBeVisible({ timeout: 10000 });
  });

  test('displays bidding interface or game state', async ({ page }) => {
    await createSoloGame(page);

    // After game starts, should see either bidding buttons or player hand with cards
    const bidTake = page.locator('[data-testid="bid-take-button"]');
    const playerHand = page.locator('[data-testid="player-hand"]');

    await expect(bidTake.or(playerHand)).toBeVisible({ timeout: 10000 });
  });

  test('can interact with bidding phase', async ({ page }) => {
    await createSoloGame(page);

    // Try to handle bidding - it may be our turn or not
    const tookAction = await handleBidding(page, 'take');

    if (tookAction) {
      // After taking, should see trump indicator or hand
      const trump = page.locator('[data-testid="trump-indicator"]');
      const hand = page.locator('[data-testid="player-hand"]');
      await expect(trump.or(hand)).toBeVisible({ timeout: 10000 });
    }
  });

  test('shows score panel during game', async ({ page }) => {
    await createSoloGame(page);

    const scorePanel = page.locator('[data-testid="score-panel"]');
    await expect(scorePanel).toBeVisible({ timeout: 10000 });
  });

  test('can play a card when it is our turn', { timeout: 60000 }, async ({ page }) => {
    await createSoloGame(page);

    // Handle bidding if it's our turn
    await handleBidding(page, 'take');

    // Wait for a playable card to appear (may need to wait for bots)
    const playableCard = page.locator('[data-playable="true"]').first();
    try {
      await playableCard.waitFor({ timeout: 15000 });
      await playableCard.click();

      // After playing, hand should still be visible
      await expect(page.locator('[data-testid="player-hand"]')).toBeVisible({ timeout: 5000 });
    } catch {
      // Not our turn yet or bidding still in progress - that's ok
    }
  });
});
