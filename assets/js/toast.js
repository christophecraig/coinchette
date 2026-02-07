/**
 * Toast Notification Manager for Coinchette
 *
 * Provides enhanced toast notifications with:
 * - Multiple types (success, error, warning, info)
 * - Configurable positions
 * - Auto-dismiss
 * - Stack management
 * - Animations
 */

class ToastManager {
  constructor() {
    this.toasts = new Map();
    this.container = null;
    this.nextId = 1;
    this.defaultDuration = 3000;
    this.init();
  }

  /**
   * Initialize toast container
   */
  init() {
    // Create container if it doesn't exist
    if (!this.container) {
      this.container = document.createElement('div');
      this.container.id = 'toast-container';
      this.container.className = 'toast toast-top toast-end z-[9999]';
      document.body.appendChild(this.container);
    }
  }

  /**
   * Show a toast notification
   * @param {object} options - Toast options
   * @returns {number} Toast ID
   */
  show(options = {}) {
    const id = this.nextId++;
    const {
      type = 'info',
      message = '',
      duration = this.defaultDuration,
      dismissible = true,
      position = 'top-end',
      icon = this.getDefaultIcon(type),
      action = null
    } = options;

    // Update container position if needed
    this.updatePosition(position);

    // Create toast element
    const toast = this.createToast(id, type, message, icon, dismissible, action);
    this.container.appendChild(toast);
    this.toasts.set(id, toast);

    // Animate in
    setTimeout(() => toast.classList.add('opacity-100'), 10);

    // Auto-dismiss
    if (duration > 0) {
      setTimeout(() => this.dismiss(id), duration);
    }

    return id;
  }

  /**
   * Create toast element
   */
  createToast(id, type, message, icon, dismissible, action) {
    const toast = document.createElement('div');
    toast.id = `toast-${id}`;
    toast.className = `alert ${this.getAlertClass(type)} shadow-lg w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap opacity-0 transition-opacity duration-300`;

    // Icon
    const iconEl = document.createElement('span');
    iconEl.innerHTML = icon;
    iconEl.className = 'text-2xl';
    toast.appendChild(iconEl);

    // Message
    const messageEl = document.createElement('span');
    messageEl.textContent = message;
    messageEl.className = 'flex-1';
    toast.appendChild(messageEl);

    // Action button (optional)
    if (action) {
      const actionBtn = document.createElement('button');
      actionBtn.textContent = action.label;
      actionBtn.className = 'btn btn-sm btn-ghost';
      actionBtn.onclick = () => {
        action.onClick();
        this.dismiss(id);
      };
      toast.appendChild(actionBtn);
    }

    // Close button
    if (dismissible) {
      const closeBtn = document.createElement('button');
      closeBtn.innerHTML = '×';
      closeBtn.className = 'btn btn-sm btn-ghost btn-circle';
      closeBtn.onclick = () => this.dismiss(id);
      toast.appendChild(closeBtn);
    }

    return toast;
  }

  /**
   * Dismiss a toast
   * @param {number} id - Toast ID
   */
  dismiss(id) {
    const toast = this.toasts.get(id);
    if (!toast) return;

    // Animate out
    toast.classList.remove('opacity-100');
    toast.classList.add('opacity-0');

    // Remove after animation
    setTimeout(() => {
      toast.remove();
      this.toasts.delete(id);
    }, 300);
  }

  /**
   * Dismiss all toasts
   */
  dismissAll() {
    this.toasts.forEach((_, id) => this.dismiss(id));
  }

  /**
   * Update container position
   */
  updatePosition(position) {
    const positions = {
      'top-start': 'toast toast-top toast-start',
      'top-center': 'toast toast-top toast-center',
      'top-end': 'toast toast-top toast-end',
      'middle-start': 'toast toast-middle toast-start',
      'middle-center': 'toast toast-middle toast-center',
      'middle-end': 'toast toast-middle toast-end',
      'bottom-start': 'toast toast-bottom toast-start',
      'bottom-center': 'toast toast-bottom toast-center',
      'bottom-end': 'toast toast-bottom toast-end',
    };

    this.container.className = `${positions[position] || positions['top-end']} z-[9999]`;
  }

  /**
   * Get alert class for type
   */
  getAlertClass(type) {
    const classes = {
      success: 'alert-success',
      error: 'alert-error',
      warning: 'alert-warning',
      info: 'alert-info',
    };
    return classes[type] || classes.info;
  }

  /**
   * Get default icon for type
   */
  getDefaultIcon(type) {
    const icons = {
      success: '✅',
      error: '❌',
      warning: '⚠️',
      info: 'ℹ️',
    };
    return icons[type] || icons.info;
  }

  /**
   * Convenience methods
   */
  success(message, options = {}) {
    return this.show({ ...options, type: 'success', message });
  }

  error(message, options = {}) {
    return this.show({ ...options, type: 'error', message, duration: 5000 });
  }

  warning(message, options = {}) {
    return this.show({ ...options, type: 'warning', message, duration: 4000 });
  }

  info(message, options = {}) {
    return this.show({ ...options, type: 'info', message });
  }
}

// Create singleton instance
const toastManager = new ToastManager();

/**
 * Phoenix LiveView Hook for Toast
 *
 * Usage:
 *
 * Server-side trigger:
 * push_event("toast", %{
 *   type: "success",
 *   message: "Game started!",
 *   duration: 3000
 * })
 */
export const ToastHook = {
  mounted() {
    // Listen for server-side toast triggers
    this.handleEvent('toast', (data) => {
      // Convert server-side action_label/action_url to a client-side action object
      if (data.action_label && data.action_url) {
        const url = data.action_url;
        data.action = {
          label: data.action_label,
          onClick: () => { window.location.href = url; }
        };
      }
      toastManager.show(data);
    });

    // Also handle specific type events
    this.handleEvent('toast-success', ({ message, ...options }) => {
      toastManager.success(message, options);
    });

    this.handleEvent('toast-error', ({ message, ...options }) => {
      toastManager.error(message, options);
    });

    this.handleEvent('toast-warning', ({ message, ...options }) => {
      toastManager.warning(message, options);
    });

    this.handleEvent('toast-info', ({ message, ...options }) => {
      toastManager.info(message, options);
    });
  }
};

/**
 * Helper functions to show toasts from JavaScript
 */
export function toast(message, options = {}) {
  return toastManager.show({ ...options, message });
}

export function toastSuccess(message, options = {}) {
  return toastManager.success(message, options);
}

export function toastError(message, options = {}) {
  return toastManager.error(message, options);
}

export function toastWarning(message, options = {}) {
  return toastManager.warning(message, options);
}

export function toastInfo(message, options = {}) {
  return toastManager.info(message, options);
}

export default toastManager;
