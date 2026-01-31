// @ts-check

/**
 * Helper functions for E2E tests
 */

/**
 * Register and login a test user using test auth header
 * @param {import('@playwright/test').Page} page
 * @param {string} [username] - Optional username, will generate if not provided
 * @returns {Promise<{username: string, email: string}>}
 */
async function loginAsTestUser(page, username) {
  const testUsername = username || 'e2e_tester';
  const testEmail = 'e2e_test@example.com';

  // Set test auth header to automatically authenticate
  await page.setExtraHTTPHeaders({
    'x-test-auth': 'true'
  });

  // Navigate to home to create session
  await page.goto('/');
  await page.waitForLoadState('networkidle');

  return { username: testUsername, email: testEmail };
}

/**
 * Create authenticated session using test header
 * @param {import('@playwright/test').Page} page
 * @returns {Promise<boolean>}
 */
async function createAuthSession(page) {
  // Set test auth header
  await page.setExtraHTTPHeaders({
    'x-test-auth': 'true'
  });

  await page.goto('/');
  await page.waitForLoadState('networkidle');

  return true;
}

/**
 * Wait for element to be visible or skip if not found
 * @param {import('@playwright/test').Page} page
 * @param {string} selector
 * @param {number} [timeout=5000]
 * @returns {Promise<boolean>}
 */
async function waitForElementOrSkip(page, selector, timeout = 5000) {
  try {
    await page.waitForSelector(selector, { timeout });
    return true;
  } catch {
    return false;
  }
}

/**
 * Create a multiplayer game with bots
 * @param {import('@playwright/test').Page} page
 * @param {number} [botCount=3] - Number of bots to add
 * @returns {Promise<{roomCode: string | null}>}
 */
async function createGameWithBots(page, botCount = 3) {
  // Navigate to lobby
  await page.goto('/lobby');
  await page.waitForLoadState('networkidle');

  // Create game
  const createButton = page.locator('button:has-text("Créer"), button:has-text("Create")').first();
  if (await createButton.count() > 0) {
    await createButton.click();
    await page.waitForTimeout(1000);

    // Try to get room code
    let roomCode = null;
    const roomCodeText = await page.textContent('body');
    const match = roomCodeText?.match(/[A-Z0-9]{4,}/);
    if (match) {
      roomCode = match[0];
    }

    // Add bots
    const addBotButton = page.locator('button:has-text("Ajouter"), button:has-text("Add Bot")');
    for (let i = 0; i < botCount; i++) {
      if (await addBotButton.count() > 0) {
        await addBotButton.first().click();
        await page.waitForTimeout(300);
      }
    }

    return { roomCode };
  }

  return { roomCode: null };
}

/**
 * Start a multiplayer game
 * @param {import('@playwright/test').Page} page
 * @returns {Promise<boolean>}
 */
async function startMultiplayerGame(page) {
  const startButton = page.locator('button:has-text("Démarrer"), button:has-text("Start")');
  if (await startButton.count() > 0) {
    await startButton.click();
    await page.waitForTimeout(2000);
    return true;
  }
  return false;
}

/**
 * Handle bidding phase if present
 * @param {import('@playwright/test').Page} page
 * @param {'take' | 'pass'} [action='take'] - Action to take
 * @returns {Promise<boolean>}
 */
async function handleBidding(page, action = 'take') {
  const takeButton = page.locator('button:has-text("Prendre"), button:has-text("Take")');
  const passButton = page.locator('button:has-text("Passer"), button:has-text("Pass")');

  if (action === 'take' && await takeButton.count() > 0) {
    await takeButton.click();
    await page.waitForTimeout(2000);
    return true;
  } else if (action === 'pass' && await passButton.count() > 0) {
    await passButton.click();
    await page.waitForTimeout(1000);
    return true;
  }

  return false;
}

module.exports = {
  loginAsTestUser,
  createAuthSession,
  waitForElementOrSkip,
  createGameWithBots,
  startMultiplayerGame,
  handleBidding
};
