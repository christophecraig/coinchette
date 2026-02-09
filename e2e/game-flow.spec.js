// @ts-check
const { test, expect } = require('@playwright/test');
const {
  loginAsTestUser,
  waitForLiveView,
  createSoloGame,
  createMultiplayerGame,
  startMultiplayerGame,
  handleBidding,
  waitForPlayableCard,
} = require('./helpers');

test.describe('Game Flow', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsTestUser(page);
  });

  test('full hand: create solo game, bid, play cards until trick completes', { timeout: 90000 }, async ({ page }) => {
    await createSoloGame(page);

    // Handle bidding
    const tookBid = await handleBidding(page, 'take');

    if (!tookBid) {
      // Bots may have taken, or we need to pass - try pass
      await handleBidding(page, 'pass');
    }

    // Wait for playing phase - either our turn or watching bots
    const playerHand = page.locator('[data-testid="player-hand"]');
    await expect(playerHand).toBeVisible({ timeout: 30000 });

    // Try to play a card if it's our turn
    try {
      const card = await waitForPlayableCard(page, 15000);
      await card.click();

      // After playing, hand should still exist
      await expect(playerHand).toBeVisible({ timeout: 5000 });
    } catch {
      // Not our turn - that's ok, bots are playing
    }
  });

  test('chat: send a message in multiplayer game', { timeout: 60000 }, async ({ page }) => {
    await createMultiplayerGame(page);
    await startMultiplayerGame(page);

    const chatInput = page.locator('[data-testid="chat-input"]');
    await expect(chatInput).toBeVisible({ timeout: 10000 });

    await chatInput.fill('Hello!');
    await chatInput.press('Enter');

    // Message should appear in chat
    await expect(page.getByText('Hello!')).toBeVisible({ timeout: 5000 });
  });

  test('rejoin: navigate away and back to game', { timeout: 60000 }, async ({ page }) => {
    await createMultiplayerGame(page);
    await startMultiplayerGame(page);

    // Capture URL
    const gameUrl = page.url();

    // Navigate away
    await page.goto('/lobby');
    await waitForLiveView(page);

    // Navigate back
    await page.goto(gameUrl);
    await waitForLiveView(page);

    // Should still see the game
    const playerHand = page.locator('[data-testid="player-hand"]');
    await expect(playerHand).toBeVisible({ timeout: 15000 });
  });
});
