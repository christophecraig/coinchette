/**
 * PWA Hooks for LiveView
 *
 * Handles PWA installation prompts, offline detection, and service worker updates.
 */

export const PWAInstallBanner = {
  mounted() {
    console.log('[PWA] Install banner mounted');

    // Check if already installed
    if (this.isPWAInstalled()) {
      console.log('[PWA] Already installed, hiding banner');
      return;
    }

    // Check if user previously dismissed
    if (localStorage.getItem('pwa-banner-dismissed') === 'true') {
      console.log('[PWA] Banner previously dismissed');
      return;
    }

    // Listen for install prompt availability
    window.addEventListener('pwa-installable', (event) => {
      console.log('[PWA] Install prompt available, showing banner');
      this.el.classList.remove('hidden');
      this.installPrompt = event.detail.prompt;
    });

    // Handle install button click
    this.handleEvent('install-pwa', () => {
      this.installPWA();
    });

    // Handle dismiss button click
    this.handleEvent('dismiss-pwa-banner', () => {
      this.dismissBanner();
    });
  },

  installPWA() {
    console.log('[PWA] Install button clicked');

    if (window.showPWAInstallPrompt) {
      window.showPWAInstallPrompt().then((accepted) => {
        if (accepted) {
          console.log('[PWA] User accepted install');
          this.el.classList.add('hidden');
        } else {
          console.log('[PWA] User declined install');
        }
      });
    } else {
      console.warn('[PWA] Install prompt not available');
      alert('Installation non disponible. Utilisez le menu "Ajouter à l\'écran d\'accueil" de votre navigateur.');
    }
  },

  dismissBanner() {
    console.log('[PWA] Banner dismissed');
    this.el.classList.add('hidden');
    localStorage.setItem('pwa-banner-dismissed', 'true');
  },

  isPWAInstalled() {
    // Check if running in standalone mode (iOS)
    if (window.navigator.standalone === true) {
      return true;
    }

    // Check if running in standalone mode (Android/Desktop)
    if (window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }

    return false;
  }
};

export const PWAUpdateBanner = {
  mounted() {
    console.log('[PWA] Update banner mounted');

    // Listen for service worker updates
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.addEventListener('controllerchange', () => {
        // New service worker is now controlling the page
        this.el.classList.remove('hidden');
      });
    }
  }
};

export const PWAOfflineIndicator = {
  mounted() {
    console.log('[PWA] Offline indicator mounted');

    this.updateStatus();

    window.addEventListener('online', () => {
      console.log('[PWA] Back online');
      this.el.classList.add('hidden');
    });

    window.addEventListener('offline', () => {
      console.log('[PWA] Gone offline');
      this.el.classList.remove('hidden');
    });
  },

  updateStatus() {
    if (!navigator.onLine) {
      this.el.classList.remove('hidden');
    }
  }
};

/**
 * Utility: Check if app is installed
 */
export function isPWAInstalled() {
  return (
    window.navigator.standalone === true ||
    window.matchMedia('(display-mode: standalone)').matches
  );
}

/**
 * Utility: Show install prompt
 */
export async function promptPWAInstall() {
  if (window.showPWAInstallPrompt) {
    return await window.showPWAInstallPrompt();
  }
  return false;
}

/**
 * Utility: Cache specific URLs (useful for prefetching game assets)
 */
export function cacheUrls(urls) {
  if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
    navigator.serviceWorker.controller.postMessage({
      type: 'CACHE_URLS',
      urls: urls
    });
    console.log('[PWA] Requested caching of URLs:', urls);
  }
}

/**
 * Utility: Clear all caches
 */
export async function clearPWACaches() {
  if ('caches' in window) {
    const cacheNames = await caches.keys();
    await Promise.all(
      cacheNames
        .filter(name => name.startsWith('coinchette-'))
        .map(name => caches.delete(name))
    );
    console.log('[PWA] All caches cleared');
    return true;
  }
  return false;
}

/**
 * Initialize PWA features on page load
 */
export function initPWA() {
  console.log('[PWA] Initializing...');

  // Log install status
  if (isPWAInstalled()) {
    console.log('[PWA] ✅ App is installed');
  } else {
    console.log('[PWA] ℹ️  App not installed yet');
  }

  // Log online status
  console.log(`[PWA] ${navigator.onLine ? '🌐 Online' : '📡 Offline'}`);

  // Track display mode changes
  const displayModes = ['standalone', 'minimal-ui', 'fullscreen', 'browser'];
  displayModes.forEach(mode => {
    const mql = window.matchMedia(`(display-mode: ${mode})`);
    if (mql.matches) {
      console.log(`[PWA] Display mode: ${mode}`);
    }
  });
}

// Auto-initialize on import
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initPWA);
} else {
  initPWA();
}
