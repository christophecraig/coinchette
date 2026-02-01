/**
 * Sound Effects Manager for Coinchette
 *
 * Handles all game sound effects with volume control and mute functionality.
 * Integrates with Phoenix LiveView via hooks.
 */

class SoundManager {
  constructor() {
    this.sounds = {};
    this.volume = parseFloat(localStorage.getItem('game-volume') || '0.5');
    this.muted = localStorage.getItem('game-muted') === 'true';
    this.initialized = false;
  }

  /**
   * Initialize sound manager and preload all sounds
   */
  init() {
    if (this.initialized) return;

    // Define all game sounds
    this.sounds = {
      cardPlay: this.loadSound('/sounds/card-play.mp3'),
      cardShuffle: this.loadSound('/sounds/card-shuffle.mp3'),
      trickWin: this.loadSound('/sounds/trick-win.mp3'),
      victory: this.loadSound('/sounds/victory.mp3'),
      defeat: this.loadSound('/sounds/defeat.mp3'),
      belote: this.loadSound('/sounds/belote.mp3'),
      announcement: this.loadSound('/sounds/announcement.mp3'),
      buttonClick: this.loadSound('/sounds/button-click.mp3'),
      bidTake: this.loadSound('/sounds/bid-take.mp3'),
      bidPass: this.loadSound('/sounds/bid-pass.mp3'),
    };

    this.initialized = true;
    console.log('SoundManager initialized');
  }

  /**
   * Load a sound file
   * @param {string} path - Path to sound file
   * @returns {HTMLAudioElement}
   */
  loadSound(path) {
    const audio = new Audio(path);
    audio.volume = this.volume;
    audio.preload = 'auto';

    // Handle loading errors gracefully
    audio.addEventListener('error', (e) => {
      console.warn(`Failed to load sound: ${path}`);
    });

    return audio;
  }

  /**
   * Play a sound effect
   * @param {string} soundName - Name of sound to play
   * @param {object} options - Playback options
   */
  play(soundName, options = {}) {
    if (this.muted) return;
    if (!this.sounds[soundName]) {
      console.warn(`Sound not found: ${soundName}`);
      return;
    }

    const audio = this.sounds[soundName];
    const volume = options.volume !== undefined ? options.volume : this.volume;

    // Clone the audio to allow overlapping plays
    const sound = audio.cloneNode();
    sound.volume = Math.min(Math.max(volume, 0), 1);

    // Play and cleanup
    sound.play()
      .catch(err => console.warn('Sound play failed:', err));

    sound.addEventListener('ended', () => {
      sound.remove();
    });
  }

  /**
   * Set master volume
   * @param {number} level - Volume level (0.0 to 1.0)
   */
  setVolume(level) {
    this.volume = Math.min(Math.max(level, 0), 1);
    localStorage.setItem('game-volume', this.volume.toString());

    // Update all sound volumes
    Object.values(this.sounds).forEach(sound => {
      sound.volume = this.volume;
    });
  }

  /**
   * Toggle mute
   */
  toggleMute() {
    this.muted = !this.muted;
    localStorage.setItem('game-muted', this.muted.toString());
    return this.muted;
  }

  /**
   * Set mute state
   * @param {boolean} muted
   */
  setMuted(muted) {
    this.muted = muted;
    localStorage.setItem('game-muted', muted.toString());
  }

  /**
   * Get current volume
   * @returns {number}
   */
  getVolume() {
    return this.volume;
  }

  /**
   * Get mute state
   * @returns {boolean}
   */
  isMuted() {
    return this.muted;
  }
}

// Create singleton instance
const soundManager = new SoundManager();

/**
 * Phoenix LiveView Hook for Sound Effects
 *
 * Usage in LiveView:
 *
 * <div phx-hook="Sound" data-sound="cardPlay" id="sound-trigger"></div>
 *
 * Or trigger from server:
 *
 * push_event("play-sound", %{sound: "cardPlay", volume: 0.5})
 */
export const SoundHook = {
  mounted() {
    soundManager.init();

    // Listen for server-side sound triggers
    this.handleEvent('play-sound', ({ sound, volume }) => {
      soundManager.play(sound, { volume });
    });

    // Play sound when element is mounted (if data-sound is present)
    const soundName = this.el.dataset.sound;
    if (soundName) {
      soundManager.play(soundName);
    }
  },

  updated() {
    // Play sound on update if data-sound changed
    const soundName = this.el.dataset.sound;
    if (soundName && this.el.dataset.soundTrigger === 'update') {
      soundManager.play(soundName);
    }
  }
};

/**
 * Phoenix LiveView Hook for Volume Control
 *
 * Usage:
 *
 * <div phx-hook="VolumeControl" id="volume-control">
 *   <input type="range" min="0" max="100" value="50" />
 *   <button data-action="toggle-mute">Mute</button>
 * </div>
 */
export const VolumeControlHook = {
  mounted() {
    soundManager.init();

    // Find volume slider
    const slider = this.el.querySelector('input[type="range"]');
    if (slider) {
      slider.value = soundManager.getVolume() * 100;
      slider.addEventListener('input', (e) => {
        soundManager.setVolume(e.target.value / 100);
        this.pushEvent('volume-changed', { volume: soundManager.getVolume() });
      });
    }

    // Find mute button
    const muteBtn = this.el.querySelector('[data-action="toggle-mute"]');
    if (muteBtn) {
      this.updateMuteButton(muteBtn, soundManager.isMuted());

      muteBtn.addEventListener('click', () => {
        const muted = soundManager.toggleMute();
        this.updateMuteButton(muteBtn, muted);
        this.pushEvent('mute-toggled', { muted });
      });
    }
  },

  updateMuteButton(btn, muted) {
    btn.textContent = muted ? '🔇 Unmute' : '🔊 Mute';
    btn.setAttribute('aria-label', muted ? 'Unmute sounds' : 'Mute sounds');
  }
};

/**
 * Helper function to play sounds from JavaScript
 * Can be called from browser console or other JS modules
 */
export function playSound(soundName, volume) {
  soundManager.init();
  soundManager.play(soundName, { volume });
}

export default soundManager;
