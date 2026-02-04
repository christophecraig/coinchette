/**
 * Push Notifications Manager
 *
 * Handles Web Push API subscription, permission management, and notification preferences.
 */

const PushNotifications = {
  /**
   * Initialize push notifications - check support and current state
   */
  async init() {
    if (!this.isSupported()) {
      console.log('[Push] Push notifications not supported');
      return { supported: false };
    }

    const permission = Notification.permission;
    const subscription = await this.getSubscription();

    console.log('[Push] Initialized - Permission:', permission, 'Subscribed:', !!subscription);

    return {
      supported: true,
      permission,
      subscribed: !!subscription,
      subscription
    };
  },

  /**
   * Check if push notifications are supported
   */
  isSupported() {
    return ('serviceWorker' in navigator) &&
           ('PushManager' in window) &&
           ('Notification' in window);
  },

  /**
   * Request notification permission from user
   */
  async requestPermission() {
    if (!this.isSupported()) {
      throw new Error('Push notifications not supported');
    }

    const permission = await Notification.requestPermission();
    console.log('[Push] Permission result:', permission);

    return permission === 'granted';
  },

  /**
   * Subscribe to push notifications
   * @param {string} vapidPublicKey - VAPID public key from server
   * @returns {Promise<Object>} Subscription object
   */
  async subscribe(vapidPublicKey) {
    if (!this.isSupported()) {
      throw new Error('Push notifications not supported');
    }

    // Request permission if not already granted
    if (Notification.permission === 'default') {
      const granted = await this.requestPermission();
      if (!granted) {
        throw new Error('Notification permission denied');
      }
    }

    if (Notification.permission !== 'granted') {
      throw new Error('Notification permission denied');
    }

    // Get service worker registration
    const registration = await navigator.serviceWorker.ready;

    // Check if already subscribed
    let subscription = await registration.pushManager.getSubscription();

    if (subscription) {
      console.log('[Push] Already subscribed');
      return this.serializeSubscription(subscription);
    }

    // Subscribe to push notifications
    console.log('[Push] Subscribing...');
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.urlBase64ToUint8Array(vapidPublicKey)
    });

    console.log('[Push] Subscription created:', subscription);

    return this.serializeSubscription(subscription);
  },

  /**
   * Unsubscribe from push notifications
   */
  async unsubscribe() {
    if (!this.isSupported()) {
      return false;
    }

    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();

    if (!subscription) {
      console.log('[Push] No subscription to unsubscribe');
      return false;
    }

    console.log('[Push] Unsubscribing...');
    const result = await subscription.unsubscribe();
    console.log('[Push] Unsubscribed:', result);

    return result;
  },

  /**
   * Get current subscription
   */
  async getSubscription() {
    if (!this.isSupported()) {
      return null;
    }

    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();

      if (!subscription) {
        return null;
      }

      return this.serializeSubscription(subscription);
    } catch (error) {
      console.error('[Push] Failed to get subscription:', error);
      return null;
    }
  },

  /**
   * Serialize subscription for sending to server
   */
  serializeSubscription(subscription) {
    const key = subscription.getKey('p256dh');
    const auth = subscription.getKey('auth');

    return {
      endpoint: subscription.endpoint,
      keys: {
        p256dh: this.arrayBufferToBase64(key),
        auth: this.arrayBufferToBase64(auth)
      }
    };
  },

  /**
   * Convert VAPID public key from base64 to Uint8Array
   */
  urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding)
      .replace(/\-/g, '+')
      .replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }

    return outputArray;
  },

  /**
   * Convert ArrayBuffer to base64
   */
  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer);
    let binary = '';
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return window.btoa(binary);
  },

  /**
   * Show a test notification
   */
  async showTestNotification() {
    if (Notification.permission !== 'granted') {
      throw new Error('Notification permission not granted');
    }

    const registration = await navigator.serviceWorker.ready;

    return registration.showNotification('Test Notification', {
      body: 'Push notifications are working!',
      icon: '/images/icon-192.png',
      badge: '/images/icon-96.png',
      tag: 'test',
      requireInteraction: false,
      vibrate: [200, 100, 200]
    });
  }
};

/**
 * LiveView Hook for Push Notification Management
 */
export const PushNotificationHook = {
  mounted() {
    this.pushManager = PushNotifications;

    // Get VAPID public key from data attribute
    this.vapidPublicKey = this.el.dataset.vapidPublicKey;

    // Initialize and check current state
    this.initializePushState();

    // Handle subscribe button
    this.handleEvent('subscribe_push', async () => {
      try {
        const subscription = await this.pushManager.subscribe(this.vapidPublicKey);

        // Send subscription to server
        this.pushEvent('push_subscription_created', {
          subscription: subscription,
          user_agent: navigator.userAgent
        });

      } catch (error) {
        console.error('[Push] Subscribe failed:', error);
        this.pushEvent('push_subscription_error', {
          error: error.message
        });
      }
    });

    // Handle unsubscribe button
    this.handleEvent('unsubscribe_push', async ({ endpoint }) => {
      try {
        await this.pushManager.unsubscribe();

        // Notify server
        this.pushEvent('push_subscription_deleted', { endpoint });

      } catch (error) {
        console.error('[Push] Unsubscribe failed:', error);
        this.pushEvent('push_subscription_error', {
          error: error.message
        });
      }
    });

    // Handle test notification
    this.handleEvent('test_notification', async () => {
      try {
        await this.pushManager.showTestNotification();
      } catch (error) {
        console.error('[Push] Test notification failed:', error);
      }
    });
  },

  async initializePushState() {
    const state = await this.pushManager.init();

    // Send initial state to server
    this.pushEvent('push_state_initialized', state);
  }
};

export default PushNotifications;
