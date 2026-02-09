// @ts-check

/**
 * Helper functions for E2E tests
 */

/**
 * Login as the test user via x-test-auth header.
 * The TestAuth plug creates/finds the e2e_test@example.com user automatically.
 * @param {import('@playwright/test').Page} page
 * @returns {Promise<void>}
 */
async function loginAsTestUser(page) {
  await page.setExtraHTTPHeaders({ 'x-test-auth': 'true' });
  await page.goto('/');
  await waitForLiveView(page);
}

/**
 * Wait for LiveView to be connected (phx-connected attribute appears on body).
 * Falls back to networkidle if no LiveView on page.
 * @param {import('@playwright/test').Page} page
 * @param {number} [timeout=10000]
 */
async function waitForLiveView(page, timeout = 10000) {
  try {
    await page.waitForSelector('[data-phx-main]', { timeout: 3000 });
    // Wait for LiveView to finish connecting (phx-loading class is removed)
    await page.waitForFunction(
      () => {
        const el = document.querySelector('[data-phx-main]');
        return el && !el.classList.contains('phx-loading');
      },
      { timeout }
    );
  } catch {
    // Not a LiveView page or already loaded
    await page.waitForLoadState('networkidle');
  }
}

/**
 * Create a solo game: go to lobby, click solo button, wait for redirect to /game/:id/play
 * @param {import('@playwright/test').Page} page
 * @returns {Promise<void>}
 */
async function createSoloGame(page) {
  await page.goto('/lobby');
  await waitForLiveView(page);
  await page.locator('[data-testid="create-solo-game-button"]').click();
  await page.waitForURL(/\/game\/.*\/play/, { timeout: 15000 });
  await waitForLiveView(page);
}

/**
 * Create a multiplayer game: go to lobby, click create, wait for game lobby
 * @param {import('@playwright/test').Page} page
 * @returns {Promise<void>}
 */
async function createMultiplayerGame(page) {
  await page.goto('/lobby');
  await waitForLiveView(page);
  await page.locator('[data-testid="create-game-button"]').click();
  await page.waitForURL(/\/game\/.*\/lobby/, { timeout: 10000 });
  await waitForLiveView(page);
}

/**
 * Start a multiplayer game from the game lobby (bots fill empty slots automatically)
 * @param {import('@playwright/test').Page} page
 * @returns {Promise<void>}
 */
async function startMultiplayerGame(page) {
  await page.locator('[data-testid="start-game-button"]').click();
  await page.waitForURL(/\/game\/.*\/play/, { timeout: 10000 });
  await waitForLiveView(page);
}

/**
 * Handle bidding phase - click take or pass if available
 * @param {import('@playwright/test').Page} page
 * @param {'take' | 'pass'} [action='take']
 * @returns {Promise<boolean>} true if action was taken
 */
async function handleBidding(page, action = 'take') {
  const testid = action === 'take' ? 'bid-take-button' : 'bid-pass-button';
  const button = page.locator(`[data-testid="${testid}"]`);
  try {
    await button.waitFor({ timeout: 3000 });
    await button.click();
    return true;
  } catch {
    return false;
  }
}

module.exports = {
  loginAsTestUser,
  waitForLiveView,
  createSoloGame,
  createMultiplayerGame,
  startMultiplayerGame,
  handleBidding,
};
