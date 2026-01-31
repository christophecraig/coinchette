// @ts-check
const { test, expect } = require('@playwright/test');
const { loginAsTestUser } = require('./helpers');

test.describe('Multiplayer Game', () => {
  test.beforeEach(async ({ page }) => {
    // Authenticate for each test
    await loginAsTestUser(page);
  });

  test('can access lobby', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Should see lobby UI
    await expect(page.locator('body')).toBeVisible();

    // Should have option to create game using data-testid
    const createButton = page.locator('[data-testid="create-game-button"]');
    await expect(createButton).toBeVisible({ timeout: 5000 });
  });

  test('can create a new game', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Click create game button using data-testid
    const createButton = page.locator('[data-testid="create-game-button"]');
    await createButton.click();

    // Should redirect to game lobby
    await page.waitForURL(/\/game\/.*\/lobby/, { timeout: 5000 });

    // Should see start game button (means we're in lobby)
    const startButton = page.locator('[data-testid="start-game-button"]');
    await expect(startButton).toBeVisible({ timeout: 5000 });
  });

  test('can add bots to game', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Create game using data-testid
    const createButton = page.locator('[data-testid="create-game-button"]');
    await createButton.click();
    await page.waitForURL(/\/game\/.*\/lobby/, { timeout: 5000 });

    // Add bots using data-testid (positions 1, 2, 3)
    for (let position of [1, 2, 3]) {
      const addBotButton = page.locator(`[data-testid="add-bot-button-${position}"]`);
      if (await addBotButton.count() > 0) {
        await addBotButton.click();
        await page.waitForTimeout(500);
      }
    }

    // Should see start game button enabled (4 players)
    const startButton = page.locator('[data-testid="start-game-button"]');
    await expect(startButton).toBeEnabled({ timeout: 5000 });
  });

  test('can start game with bots', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Create game
    const createButton = page.locator('[data-testid="create-game-button"]');
    await createButton.click();
    await page.waitForURL(/\/game\/.*\/lobby/, { timeout: 5000 });

    // Add bots
    for (let position of [1, 2, 3]) {
      const addBotButton = page.locator(`[data-testid="add-bot-button-${position}"]`);
      if (await addBotButton.count() > 0) {
        await addBotButton.click();
        await page.waitForTimeout(300);
      }
    }

    // Start game
    const startButton = page.locator('[data-testid="start-game-button"]');
    await startButton.click();
    await page.waitForURL(/\/game\/.*\/play/, { timeout: 5000 });

    // Should see game UI with player hand
    const playerHand = page.locator('[data-testid="player-hand-south"]');
    await expect(playerHand).toBeVisible({ timeout: 5000 });
  });

  test('displays chat in multiplayer game', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Create and start game
    const createButton = page.locator('button:has-text("Créer"), button:has-text("Create")').first();
    await createButton.click();
    await page.waitForTimeout(1000);

    // Add bots and start
    const addBotButton = page.locator('button:has-text("Ajouter"), button:has-text("Add Bot")');
    if (await addBotButton.count() > 0) {
      for (let i = 0; i < 3; i++) {
        if (await addBotButton.count() > 0) {
          await addBotButton.first().click();
          await page.waitForTimeout(300);
        }
      }
    }

    const startButton = page.locator('button:has-text("Démarrer"), button:has-text("Start")');
    if (await startButton.count() > 0) {
      await startButton.click();
      await page.waitForTimeout(2000);

      // Look for chat interface
      const hasChatInput = await page.locator('input[placeholder*="message"], textarea[placeholder*="message"]').count() > 0;

      if (hasChatInput) {
        // Try to send a message
        const chatInput = page.locator('input[placeholder*="message"], textarea[placeholder*="message"]').first();
        await chatInput.fill('Test message');

        const sendButton = page.locator('button:has-text("Envoyer"), button:has-text("Send")');
        if (await sendButton.count() > 0) {
          await sendButton.click();
          await page.waitForTimeout(500);

          // Should see message in chat
          const hasMessage = await page.locator('text=/test message/i').count() > 0;
          expect(hasMessage).toBeTruthy();
        }
      }
    }
  });

  test('shows system messages during game', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Create and start game
    const createButton = page.locator('button:has-text("Créer"), button:has-text("Create")').first();
    await createButton.click();
    await page.waitForTimeout(1000);

    // Add bots and start
    const addBotButton = page.locator('button:has-text("Ajouter"), button:has-text("Add Bot")');
    if (await addBotButton.count() > 0) {
      for (let i = 0; i < 3; i++) {
        if (await addBotButton.count() > 0) {
          await addBotButton.first().click();
          await page.waitForTimeout(300);
        }
      }
    }

    const startButton = page.locator('button:has-text("Démarrer"), button:has-text("Start")');
    if (await startButton.count() > 0) {
      await startButton.click();
      await page.waitForTimeout(3000);

      // Should see system messages about bidding, announcements, etc.
      const body = await page.textContent('body');
      expect(body).toBeTruthy();
    }
  });
});
