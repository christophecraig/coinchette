/**
 * Haptic Feedback Manager for Coinchette
 *
 * Provides tactile feedback on mobile devices using the Vibration API.
 * Enhances UX with subtle vibrations for game actions.
 */

class HapticManager {
  constructor() {
    this.enabled = this.isSupported() && this.loadPreference();
    this.patterns = {
      // Short tap - playing a card
      cardPlay: 50,

      // Double tap - trick won
      trickWin: [100, 50, 100],

      // Victory pattern (ascending)
      victory: [200, 100, 200, 100, 300],

      // Defeat pattern (descending)
      defeat: [300, 150, 200, 100, 100],

      // Bid actions
      bidTake: 75,
      bidPass: 50,

      // Button click
      buttonClick: 30,

      // Error/invalid action
      error: [50, 50, 50],
    };
  }

  /**
   * Check if Vibration API is supported
   * @returns {boolean}
   */
  isSupported() {
    return 'vibrate' in navigator;
  }

  /**
   * Load user preference from localStorage
   * @returns {boolean}
   */
  loadPreference() {
    const pref = localStorage.getItem('haptics-enabled');
    // Default to true on mobile, false on desktop
    if (pref === null) {
      return this.isMobile();
    }
    return pref === 'true';
  }

  /**
   * Save user preference to localStorage
   * @param {boolean} enabled
   */
  savePreference(enabled) {
    localStorage.setItem('haptics-enabled', enabled.toString());
    this.enabled = enabled;
  }

  /**
   * Detect if device is mobile
   * @returns {boolean}
   */
  isMobile() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) ||
           (navigator.maxTouchPoints && navigator.maxTouchPoints > 1);
  }

  /**
   * Trigger a haptic feedback pattern
   * @param {string} patternName - Name of pattern to play
   */
  vibrate(patternName) {
    if (!this.enabled || !this.isSupported()) {
      return;
    }

    const pattern = this.patterns[patternName];
    if (!pattern) {
      console.warn(`Haptic pattern not found: ${patternName}`);
      return;
    }

    try {
      navigator.vibrate(pattern);
    } catch (err) {
      console.warn('Haptic feedback failed:', err);
    }
  }

  /**
   * Enable haptics
   */
  enable() {
    this.savePreference(true);
  }

  /**
   * Disable haptics
   */
  disable() {
    this.savePreference(false);
    // Stop any ongoing vibration
    if (this.isSupported()) {
      navigator.vibrate(0);
    }
  }

  /**
   * Toggle haptics on/off
   * @returns {boolean} New state
   */
  toggle() {
    const newState = !this.enabled;
    this.savePreference(newState);
    return newState;
  }

  /**
   * Check if haptics are enabled
   * @returns {boolean}
   */
  isEnabled() {
    return this.enabled;
  }

  /**
   * Test vibration (useful for settings UI)
   * @param {number} duration - Duration in ms
   */
  test(duration = 200) {
    if (this.isSupported()) {
      navigator.vibrate(duration);
    }
  }
}

// Create singleton instance
const hapticManager = new HapticManager();

/**
 * Phoenix LiveView Hook for Haptic Feedback
 *
 * Usage in LiveView:
 *
 * <div phx-hook="Haptic" data-haptic="cardPlay" id="haptic-trigger"></div>
 *
 * Or trigger from server:
 *
 * push_event("haptic-feedback", %{pattern: "cardPlay"})
 */
export const HapticHook = {
  mounted() {
    // Listen for server-side haptic triggers
    this.handleEvent('haptic-feedback', ({ pattern }) => {
      hapticManager.vibrate(pattern);
    });

    // Trigger haptic on mount if data-haptic is present
    const pattern = this.el.dataset.haptic;
    if (pattern) {
      hapticManager.vibrate(pattern);
    }
  },

  updated() {
    // Trigger haptic on update if data-haptic changed and trigger flag is set
    const pattern = this.el.dataset.haptic;
    if (pattern && this.el.dataset.hapticTrigger === 'update') {
      hapticManager.vibrate(pattern);
    }
  }
};

/**
 * Phoenix LiveView Hook for Haptic Control Toggle
 *
 * Usage:
 *
 * <div phx-hook="HapticControl" id="haptic-control">
 *   <button data-action="toggle-haptic">Toggle Haptics</button>
 *   <button data-action="test-haptic">Test</button>
 * </div>
 */
export const HapticControlHook = {
  mounted() {
    // Find toggle button
    const toggleBtn = this.el.querySelector('[data-action="toggle-haptic"]');
    if (toggleBtn) {
      this.updateToggleButton(toggleBtn, hapticManager.isEnabled());

      toggleBtn.addEventListener('click', () => {
        const enabled = hapticManager.toggle();
        this.updateToggleButton(toggleBtn, enabled);
        this.pushEvent('haptic-toggled', { enabled });

        // Give feedback on toggle
        if (enabled) {
          hapticManager.test(100);
        }
      });
    }

    // Find test button
    const testBtn = this.el.querySelector('[data-action="test-haptic"]');
    if (testBtn) {
      testBtn.addEventListener('click', () => {
        hapticManager.test(200);
      });
    }
  },

  updateToggleButton(btn, enabled) {
    btn.textContent = enabled ? '📳 Haptics On' : '📴 Haptics Off';
    btn.setAttribute('aria-label', enabled ? 'Disable haptics' : 'Enable haptics');
  }
};

/**
 * Helper function to trigger haptics from JavaScript
 * Can be called from browser console or other JS modules
 */
export function vibrate(patternName) {
  hapticManager.vibrate(patternName);
}

export default hapticManager;
