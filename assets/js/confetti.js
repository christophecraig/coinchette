/**
 * Confetti Effects Manager for Coinchette
 *
 * Provides celebratory particle effects using canvas-confetti.
 * Triggered on game victory with different patterns based on score.
 */

import confetti from 'canvas-confetti';

class ConfettiManager {
  constructor() {
    this.enabled = this.loadPreference();
  }

  /**
   * Load user preference from localStorage
   * @returns {boolean}
   */
  loadPreference() {
    const pref = localStorage.getItem('confetti-enabled');
    // Default to true (enabled)
    return pref !== 'false';
  }

  /**
   * Save user preference
   * @param {boolean} enabled
   */
  savePreference(enabled) {
    localStorage.setItem('confetti-enabled', enabled.toString());
    this.enabled = enabled;
  }

  /**
   * Launch confetti celebration
   * @param {string} type - Type of celebration: 'victory', 'big_win', 'perfect'
   */
  celebrate(type = 'victory') {
    if (!this.enabled) return;

    switch (type) {
      case 'perfect':
        this.perfectWin();
        break;
      case 'big_win':
        this.bigWin();
        break;
      case 'victory':
      default:
        this.standardVictory();
        break;
    }
  }

  /**
   * Standard victory confetti
   */
  standardVictory() {
    const duration = 2000;
    const animationEnd = Date.now() + duration;

    const interval = setInterval(() => {
      const timeLeft = animationEnd - Date.now();

      if (timeLeft <= 0) {
        clearInterval(interval);
        return;
      }

      // Launch confetti from left and right
      confetti({
        particleCount: 3,
        angle: 60,
        spread: 55,
        origin: { x: 0, y: 0.7 },
        colors: ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A', '#98D8C8']
      });

      confetti({
        particleCount: 3,
        angle: 120,
        spread: 55,
        origin: { x: 1, y: 0.7 },
        colors: ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A', '#98D8C8']
      });
    }, 50);
  }

  /**
   * Big win confetti (high score)
   */
  bigWin() {
    const duration = 3000;
    const animationEnd = Date.now() + duration;
    const defaults = {
      startVelocity: 30,
      spread: 360,
      ticks: 60,
      zIndex: 0,
      colors: ['#FFD700', '#FFA500', '#FF6347', '#32CD32', '#1E90FF']
    };

    function randomInRange(min, max) {
      return Math.random() * (max - min) + min;
    }

    const interval = setInterval(() => {
      const timeLeft = animationEnd - Date.now();

      if (timeLeft <= 0) {
        clearInterval(interval);
        return;
      }

      const particleCount = 50 * (timeLeft / duration);

      // Launch from random positions at the top
      confetti(Object.assign({}, defaults, {
        particleCount,
        origin: { x: randomInRange(0.1, 0.9), y: Math.random() - 0.2 }
      }));
    }, 100);
  }

  /**
   * Perfect win confetti (maximum score)
   */
  perfectWin() {
    // Fireworks effect
    const duration = 4000;
    const animationEnd = Date.now() + duration;

    function randomInRange(min, max) {
      return Math.random() * (max - min) + min;
    }

    const interval = setInterval(() => {
      const timeLeft = animationEnd - Date.now();

      if (timeLeft <= 0) {
        clearInterval(interval);
        return;
      }

      // Create firework bursts
      confetti({
        particleCount: 100,
        startVelocity: 30,
        spread: 360,
        origin: {
          x: randomInRange(0.2, 0.8),
          y: randomInRange(0.2, 0.6)
        },
        colors: ['#FF1744', '#F50057', '#D500F9', '#651FFF', '#3D5AFE', '#2979FF', '#00B0FF'],
        shapes: ['circle', 'square'],
        scalar: randomInRange(0.4, 1),
        drift: randomInRange(-0.4, 0.4)
      });
    }, 400);
  }

  /**
   * Quick confetti burst (for milestones)
   */
  burst() {
    if (!this.enabled) return;

    confetti({
      particleCount: 100,
      spread: 70,
      origin: { y: 0.6 },
      colors: ['#FF6B6B', '#4ECDC4', '#45B7D1', '#FFA07A', '#98D8C8']
    });
  }

  /**
   * School pride style (continuous fall from top)
   */
  schoolPride() {
    if (!this.enabled) return;

    const end = Date.now() + (3 * 1000);
    const colors = ['#bb0000', '#ffffff'];

    (function frame() {
      confetti({
        particleCount: 2,
        angle: 60,
        spread: 55,
        origin: { x: 0 },
        colors: colors
      });
      confetti({
        particleCount: 2,
        angle: 120,
        spread: 55,
        origin: { x: 1 },
        colors: colors
      });

      if (Date.now() < end) {
        requestAnimationFrame(frame);
      }
    }());
  }

  /**
   * Enable confetti
   */
  enable() {
    this.savePreference(true);
  }

  /**
   * Disable confetti
   */
  disable() {
    this.savePreference(false);
  }

  /**
   * Toggle confetti on/off
   * @returns {boolean} New state
   */
  toggle() {
    const newState = !this.enabled;
    this.savePreference(newState);
    return newState;
  }

  /**
   * Check if confetti is enabled
   * @returns {boolean}
   */
  isEnabled() {
    return this.enabled;
  }
}

// Create singleton instance
const confettiManager = new ConfettiManager();

/**
 * Phoenix LiveView Hook for Confetti
 *
 * Usage:
 *
 * <div phx-hook="Confetti" data-confetti="victory" id="confetti-trigger"></div>
 *
 * Or trigger from server:
 *
 * push_event("confetti", %{type: "victory"})
 */
export const ConfettiHook = {
  mounted() {
    // Listen for server-side confetti triggers
    this.handleEvent('confetti', ({ type }) => {
      confettiManager.celebrate(type || 'victory');
    });

    // Trigger confetti on mount if data-confetti is present
    const type = this.el.dataset.confetti;
    if (type) {
      confettiManager.celebrate(type);
    }
  }
};

/**
 * Phoenix LiveView Hook for Confetti Control
 *
 * Usage:
 *
 * <div phx-hook="ConfettiControl" id="confetti-control">
 *   <button data-action="toggle-confetti">Toggle</button>
 *   <button data-action="test-confetti">Test</button>
 * </div>
 */
export const ConfettiControlHook = {
  mounted() {
    // Find toggle button
    const toggleBtn = this.el.querySelector('[data-action="toggle-confetti"]');
    if (toggleBtn) {
      this.updateToggleButton(toggleBtn, confettiManager.isEnabled());

      toggleBtn.addEventListener('click', () => {
        const enabled = confettiManager.toggle();
        this.updateToggleButton(toggleBtn, enabled);
        this.pushEvent('confetti-toggled', { enabled });

        // Give feedback on toggle
        if (enabled) {
          confettiManager.burst();
        }
      });
    }

    // Find test button
    const testBtn = this.el.querySelector('[data-action="test-confetti"]');
    if (testBtn) {
      testBtn.addEventListener('click', () => {
        confettiManager.burst();
      });
    }
  },

  updateToggleButton(btn, enabled) {
    btn.textContent = enabled ? '🎉 Confetti On' : '❌ Confetti Off';
    btn.setAttribute('aria-label', enabled ? 'Disable confetti' : 'Enable confetti');
  }
};

/**
 * Helper function to trigger confetti from JavaScript
 */
export function launchConfetti(type = 'victory') {
  confettiManager.celebrate(type);
}

export default confettiManager;
