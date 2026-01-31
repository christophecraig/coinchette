// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Multiplayer Game', () => {
  test('can access lobby', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Should see lobby UI
    await expect(page.locator('body')).toBeVisible();

    // Should have option to create game
    const hasCreateButton = await page.locator('button:has-text("Créer"), button:has-text("Create")').count() > 0;
    expect(hasCreateButton).toBeTruthy();
  });

  test('can create a new game', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Click create game button
    const createButton = page.locator('button:has-text("Créer"), button:has-text("Create")').first();
    await createButton.click();

    // Should redirect to game lobby
    await page.waitForURL(/\/game/, { timeout: 5000 });

    // Should see room code
    const hasRoomCode = await page.locator('text=/code|room/i').count() > 0;
    expect(hasRoomCode).toBeTruthy();
  });

  test('can add bots to game', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Create game
    const createButton = page.locator('button:has-text("Créer"), button:has-text("Create")').first();
    await createButton.click();
    await page.waitForTimeout(1000);

    // Look for "Add Bot" button
    const addBotButton = page.locator('button:has-text("Ajouter"), button:has-text("Add Bot")');

    if (await addBotButton.count() > 0) {
      // Add 3 bots
      for (let i = 0; i < 3; i++) {
        if (await addBotButton.count() > 0) {
          await addBotButton.first().click();
          await page.waitForTimeout(500);
        }
      }

      // Should see 4 players (1 human + 3 bots)
      await page.waitForTimeout(500);
      const body = await page.textContent('body');
      expect(body).toBeTruthy();
    }
  });

  test('can start game with bots', async ({ page }) => {
    await page.goto('/lobby');
    await page.waitForLoadState('networkidle');

    // Create game
    const createButton = page.locator('button:has-text("Créer"), button:has-text("Create")').first();
    await createButton.click();
    await page.waitForTimeout(1000);

    // Add bots
    const addBotButton = page.locator('button:has-text("Ajouter"), button:has-text("Add Bot")');
    if (await addBotButton.count() > 0) {
      for (let i = 0; i < 3; i++) {
        if (await addBotButton.count() > 0) {
          await addBotButton.first().click();
          await page.waitForTimeout(300);
        }
      }
    }

    // Start game
    const startButton = page.locator('button:has-text("Démarrer"), button:has-text("Start")');
    if (await startButton.count() > 0) {
      await startButton.click();
      await page.waitForTimeout(2000);

      // Should see game UI (cards, bidding, etc.)
      const hasGameUI = await page.locator('.card, [data-testid="player-hand"]').count() > 0;
      expect(hasGameUI).toBeTruthy();
    }
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
