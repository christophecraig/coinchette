// @ts-check
const { test, expect } = require('@playwright/test');
const { loginAsTestUser, waitForLiveView, createMultiplayerGame, startMultiplayerGame } = require('./helpers');

test.describe('Multiplayer Game', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsTestUser(page);
  });

  test('can access lobby', async ({ page }) => {
    await page.goto('/lobby');
    await waitForLiveView(page);

    await expect(page.locator('[data-testid="create-game-button"]')).toBeVisible({ timeout: 10000 });
  });

  test('can create a new game', async ({ page }) => {
    await createMultiplayerGame(page);

    // Should be in game lobby with start button and room code
    await expect(page.locator('[data-testid="start-game-button"]')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('[data-testid="room-code"]')).toBeVisible();
  });

  test('shows empty slots for other positions', async ({ page }) => {
    await createMultiplayerGame(page);

    // Creator is in position 0, so positions 1, 2, 3 should show empty slots
    // At least some empty slots should be visible
    const emptySlots = page.locator('[data-testid^="empty-slot-"]');
    await expect(emptySlots.first()).toBeVisible({ timeout: 10000 });

    const count = await emptySlots.count();
    expect(count).toBeGreaterThanOrEqual(1);
  });

  test('can start game (bots fill empty slots)', async ({ page }) => {
    await createMultiplayerGame(page);

    // Start game - empty slots will be filled by bots automatically
    await startMultiplayerGame(page);

    // Should see game UI with player hand
    const playerHand = page.locator('[data-testid="player-hand"]');
    await expect(playerHand).toBeVisible({ timeout: 10000 });
  });

  test('shows chat input in game', async ({ page }) => {
    await createMultiplayerGame(page);
    await startMultiplayerGame(page);

    const chatInput = page.locator('[data-testid="chat-input"]');
    await expect(chatInput).toBeVisible({ timeout: 10000 });
  });

  test('displays room code in game lobby', async ({ page }) => {
    await createMultiplayerGame(page);

    const roomCode = page.locator('[data-testid="room-code"]');
    await expect(roomCode).toBeVisible();

    const text = await roomCode.textContent();
    // Room code should be non-empty
    expect(text?.trim().length).toBeGreaterThan(0);
  });
});
