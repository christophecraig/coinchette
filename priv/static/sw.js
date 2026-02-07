// Coinchette Service Worker
// Version: 1.0.0

const CACHE_VERSION = 'coinchette-v2';
const STATIC_CACHE = `${CACHE_VERSION}-static`;
const DYNAMIC_CACHE = `${CACHE_VERSION}-dynamic`;
const IMAGE_CACHE = `${CACHE_VERSION}-images`;

// Static assets to cache on install
// Note: JS/CSS are fingerprinted by Phoenix and cached by the browser automatically
const STATIC_ASSETS = [
  '/favicon.ico',
  '/manifest.json'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');

  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => {
        console.log('[SW] Precaching static assets');
        return cache.addAll(STATIC_ASSETS);
      })
      .then(() => {
        console.log('[SW] Installation complete');
        return self.skipWaiting(); // Activate immediately
      })
      .catch((error) => {
        console.error('[SW] Installation failed:', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');

  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((cacheName) => {
              // Delete caches that don't match current version
              return cacheName.startsWith('coinchette-') &&
                     !cacheName.startsWith(CACHE_VERSION);
            })
            .map((cacheName) => {
              console.log('[SW] Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            })
        );
      })
      .then(() => {
        console.log('[SW] Activation complete');
        return self.clients.claim(); // Take control immediately
      })
  );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }

  // Skip WebSocket and Phoenix LiveView requests
  if (url.pathname.startsWith('/live/websocket') ||
      url.pathname.startsWith('/socket/')) {
    return;
  }

  // Skip API calls and dynamic routes that need fresh data
  if (url.pathname.startsWith('/api/') ||
      url.pathname.includes('/game/') ||
      url.pathname.includes('/lobby/')) {
    // Network first for dynamic content
    event.respondWith(networkFirst(request));
    return;
  }

  // Images - Cache first strategy
  if (request.destination === 'image') {
    event.respondWith(cacheFirstImages(request));
    return;
  }

  // Static assets - Cache first strategy
  if (url.pathname.startsWith('/assets/') ||
      url.pathname === '/favicon.ico' ||
      url.pathname === '/manifest.json') {
    event.respondWith(cacheFirst(request));
    return;
  }

  // Default - Network first with cache fallback
  event.respondWith(networkFirst(request));
});

// Cache first strategy (for static assets)
async function cacheFirst(request) {
  try {
    const cached = await caches.match(request);
    if (cached) {
      console.log('[SW] Cache hit:', request.url);
      return cached;
    }

    console.log('[SW] Cache miss, fetching:', request.url);
    const response = await fetch(request);

    if (response && response.status === 200) {
      const cache = await caches.open(STATIC_CACHE);
      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    console.error('[SW] Cache first failed:', error);
    throw error;
  }
}

// Cache first strategy for images
async function cacheFirstImages(request) {
  try {
    const cached = await caches.match(request);
    if (cached) {
      return cached;
    }

    const response = await fetch(request);

    if (response && response.status === 200) {
      const cache = await caches.open(IMAGE_CACHE);
      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    console.error('[SW] Image cache failed:', error);
    // Return a placeholder image if available
    return new Response('', { status: 404 });
  }
}

// Network first strategy (for dynamic content)
async function networkFirst(request) {
  try {
    console.log('[SW] Network first:', request.url);
    const response = await fetch(request);

    if (response && response.status === 200) {
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, response.clone());
    }

    return response;
  } catch (error) {
    console.log('[SW] Network failed, trying cache:', request.url);
    const cached = await caches.match(request);

    if (cached) {
      console.log('[SW] Serving from cache:', request.url);
      return cached;
    }

    // If it's a navigation request, return offline page
    if (request.mode === 'navigate') {
      const offlinePage = await caches.match('/');
      if (offlinePage) {
        return offlinePage;
      }
    }

    console.error('[SW] Both network and cache failed:', error);
    return new Response('Offline - Network unavailable', {
      status: 503,
      statusText: 'Service Unavailable',
      headers: new Headers({
        'Content-Type': 'text/plain'
      })
    });
  }
}

// Listen for messages from the app
self.addEventListener('message', (event) => {
  console.log('[SW] Message received:', event.data);

  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'CACHE_URLS') {
    const urls = event.data.urls || [];
    event.waitUntil(
      caches.open(DYNAMIC_CACHE)
        .then((cache) => cache.addAll(urls))
        .then(() => console.log('[SW] Cached additional URLs:', urls))
    );
  }
});

// Background sync for offline actions (future enhancement)
self.addEventListener('sync', (event) => {
  console.log('[SW] Background sync:', event.tag);

  if (event.tag === 'sync-game-state') {
    event.waitUntil(syncGameState());
  }
});

async function syncGameState() {
  // Future: Sync offline game actions when coming back online
  console.log('[SW] Syncing game state...');
}

// Push notification event - received when server sends a push
self.addEventListener('push', (event) => {
  console.log('[SW] Push notification received:', event);

  let notificationData = {
    title: 'Coinchette',
    body: 'Nouvelle notification',
    icon: '/images/icon-192.png',
    badge: '/images/icon-96.png',
    tag: 'default',
    requireInteraction: false,
    data: {}
  };

  // Parse the push payload if available
  if (event.data) {
    try {
      const payload = event.data.json();
      notificationData = {
        title: payload.title || notificationData.title,
        body: payload.body || notificationData.body,
        icon: payload.icon || notificationData.icon,
        badge: payload.badge || notificationData.badge,
        tag: payload.tag || notificationData.tag,
        requireInteraction: payload.requireInteraction || false,
        data: payload.data || {},
        actions: payload.actions || []
      };
    } catch (error) {
      console.error('[SW] Failed to parse push payload:', error);
    }
  }

  // Show the notification
  event.waitUntil(
    self.registration.showNotification(notificationData.title, {
      body: notificationData.body,
      icon: notificationData.icon,
      badge: notificationData.badge,
      tag: notificationData.tag,
      requireInteraction: notificationData.requireInteraction,
      data: notificationData.data,
      actions: notificationData.actions,
      vibrate: [200, 100, 200], // Vibration pattern
      timestamp: Date.now()
    })
  );
});

// Notification click event - handle when user clicks notification
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked:', event.notification.tag);
  event.notification.close();

  const data = event.notification.data || {};
  const action = event.action; // Action button clicked (if any)

  // Determine the URL to open based on notification type
  let urlToOpen = '/';

  if (data.type === 'friend_request' || data.type === 'friend_accepted') {
    urlToOpen = '/friends';
  } else if (data.game_id) {
    urlToOpen = `/game/${data.game_id}/lobby`;
  } else if (data.lobby_code) {
    urlToOpen = `/lobby/${data.lobby_code}`;
  } else if (data.url) {
    urlToOpen = data.url;
  }

  // Handle action button clicks
  if (action === 'join_game' && data.game_id) {
    urlToOpen = `/game/${data.game_id}/lobby`;
  } else if (action === 'view_lobby' && data.lobby_code) {
    urlToOpen = `/lobby/${data.lobby_code}`;
  }

  // Open the URL in the app or focus existing window
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Check if app is already open
        for (const client of clientList) {
          if (client.url.includes(urlToOpen) && 'focus' in client) {
            return client.focus();
          }
        }

        // Open new window with the URL
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
      .catch((error) => {
        console.error('[SW] Failed to handle notification click:', error);
      })
  );
});

// Notification close event - track when user dismisses notifications
self.addEventListener('notificationclose', (event) => {
  console.log('[SW] Notification closed:', event.notification.tag);

  // Future: Track notification dismissal analytics
  const data = event.notification.data || {};
  if (data.track_dismissal) {
    // Could send analytics here
  }
});

console.log('[SW] Service worker loaded');
