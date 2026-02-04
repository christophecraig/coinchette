# 📱 Progressive Web App (PWA) Guide

This document describes the PWA implementation for Coinchette.

## 🎯 Overview

Coinchette is now a Progressive Web App, which means:
- ✅ Installable on mobile devices (iOS, Android)
- ✅ Works offline (cached assets)
- ✅ Fast loading (service worker caching)
- ✅ Native-like experience (standalone mode)
- ✅ App icon on home screen
- ✅ Splash screen on launch
- ✅ Push notifications ready (future)

## 📁 PWA Files Structure

```
coinchette/
├── priv/static/
│   ├── manifest.json           # PWA manifest configuration
│   ├── sw.js                   # Service worker for offline support
│   └── images/
│       ├── icon-72.png        # App icons (various sizes)
│       ├── icon-96.png
│       ├── icon-128.png
│       ├── icon-144.png
│       ├── icon-152.png
│       ├── icon-192.png       # Maskable icon
│       ├── icon-384.png
│       ├── icon-512.png       # Maskable icon
│       ├── icon-template.svg  # Source SVG for icons
│       ├── generate-icons.js  # Script to generate PNGs
│       └── ICON_GENERATION_GUIDE.md
├── assets/js/
│   └── pwa.js                 # PWA JavaScript hooks
├── lib/coinchette_web/
│   ├── components/
│   │   ├── layouts/
│   │   │   └── root.html.heex # PWA meta tags + SW registration
│   │   └── pwa_components.ex  # PWA UI components
│   └── ...
└── .claudefiles/
    └── PWA.md                 # This file
```

## 🚀 Installation Status

### ✅ Completed

1. **Manifest.json** - Complete PWA configuration
2. **Service Worker** - Offline caching strategy implemented
3. **Icons** - SVG template and generation script created
4. **Meta Tags** - All PWA meta tags added to root.html.heex
5. **SW Registration** - Automatic service worker registration
6. **LiveView Hooks** - PWA install banner, update banner, offline indicator
7. **UI Components** - Reusable PWA components created
8. **Documentation** - Complete implementation guide

### ⏳ Pending (User Action Required)

1. **Generate PNG Icons** - Run icon generation script
   ```bash
   cd priv/static/images
   npm install sharp
   node generate-icons.js
   ```
   Or use online tool: https://www.pwabuilder.com/imageGenerator

2. **Create Screenshots** (Optional but recommended)
   - Mobile: 390x844px
   - Desktop: 1280x720px
   - Place in `priv/static/images/`

3. **Test on Real Devices**
   - Test install on iOS Safari
   - Test install on Android Chrome
   - Verify offline functionality

## 📱 User Installation Process

### Android (Chrome)

1. Visit https://coinchette.onrender.com
2. Tap "Install" in banner OR
3. Tap menu (⋮) → "Install app"
4. App appears on home screen

### iOS (Safari)

1. Visit https://coinchette.onrender.com
2. Tap Share button (□↑)
3. Scroll and tap "Add to Home Screen"
4. Tap "Add"
5. App appears on home screen

### Desktop (Chrome/Edge)

1. Visit https://coinchette.onrender.com
2. Click install icon (⊕) in address bar OR
3. Click menu → "Install Coinchette"
4. App opens in standalone window

## 🔧 Service Worker Caching Strategy

### Static Assets (Cache First)
- `/assets/css/app.css`
- `/assets/js/app.js`
- `/favicon.ico`
- `/manifest.json`
- All files in `/assets/` directory

**Strategy**: Check cache first, fallback to network

### Images (Cache First)
- All images (`/images/*`)
- Card graphics
- Icons

**Strategy**: Cache indefinitely, serve from cache

### Dynamic Content (Network First)
- LiveView pages
- Game state
- API calls
- WebSocket connections

**Strategy**: Network first, fallback to cache if offline

### WebSocket/LiveView
- **Not cached** - Always use live connection
- Falls back gracefully when offline

## 🎨 PWA UI Components

### Install Banner

Shows a prompt to install the app:

```elixir
<.pwa_install_banner position="top" dismissible={true} />
```

**Features:**
- Auto-shows when app is installable
- Remembers if user dismissed
- Triggers native install prompt

### Update Banner

Notifies when new version is available:

```elixir
<.pwa_update_banner />
```

**Features:**
- Auto-shows when SW update detected
- Reload button to apply update

### Offline Indicator

Shows when user goes offline:

```elixir
<.pwa_offline_indicator />
```

**Features:**
- Real-time online/offline detection
- Minimal, non-intrusive design

### Debug Info (Dev Only)

Shows PWA status in development:

```elixir
<.pwa_debug_info />
```

**Shows:**
- Service Worker status
- Install status
- Online/offline status

## 🧪 Testing PWA

### Lighthouse Audit

```bash
lighthouse https://coinchette.onrender.com --view
```

**Target Scores:**
- PWA: 100/100 ✅
- Performance: 90+
- Accessibility: 95+
- Best Practices: 95+
- SEO: 95+

### Chrome DevTools

1. Open DevTools (F12)
2. Go to **Application** tab
3. Check sections:
   - **Manifest** - Verify all fields
   - **Service Workers** - Check registration
   - **Cache Storage** - Verify cached assets
   - **Storage** - Check available space

### Test Offline Mode

1. Open DevTools → Network tab
2. Select "Offline" from throttling dropdown
3. Reload page
4. Verify app still works with cached assets

### Test Install Flow

**Desktop:**
```
1. Open incognito window
2. Visit app
3. Look for install icon in address bar
4. Click and verify install works
```

**Mobile:**
```
1. Visit app on real device
2. Follow installation steps
3. Verify app opens standalone
4. Check app icon on home screen
```

## 🎯 PWA Manifest Configuration

### Key Settings

```json
{
  "name": "Coinchette - Belote en Ligne",
  "short_name": "Coinchette",
  "start_url": "/",
  "display": "standalone",
  "theme_color": "#155724",
  "background_color": "#1e7e34"
}
```

**Display Modes:**
- `standalone` - Looks like native app (current)
- `fullscreen` - Completely immersive
- `minimal-ui` - Minimal browser UI
- `browser` - Regular browser tab

**Orientation:**
- `portrait-primary` - Default for mobile
- Can be changed to `landscape` or `any`

### Shortcuts

Quick actions from app icon:
- **Nouvelle Partie Solo** → `/game`
- **Rejoindre Partie** → `/lobby`

### Share Target

Allows sharing game links to app:
```javascript
navigator.share({
  title: 'Coinchette',
  text: 'Rejoins ma partie de belote !',
  url: 'https://coinchette.onrender.com/lobby?code=ABC123'
})
```

## 🔐 Security & Best Practices

### HTTPS Required
- ✅ PWA **requires** HTTPS
- ✅ Render.com provides automatic HTTPS
- ✅ Service Worker only works on HTTPS

### Scope
- Current scope: `/` (entire app)
- Service Worker controls all routes

### Cache Versioning
```javascript
const CACHE_VERSION = 'coinchette-v1';
```

**Update Strategy:**
1. Increment version in `sw.js`
2. Old caches automatically cleared
3. New assets cached on next load

### Cache Size Limits
- Browser typically allows 50MB - 250MB
- Currently caching ~1-5MB
- Monitor with DevTools → Application → Storage

## 📊 PWA Analytics

Track PWA-specific events:

```javascript
// Installation
window.gtag('event', 'pwa_install', {
  event_category: 'engagement',
  event_label: 'PWA Installation'
});

// Display mode
if (window.matchMedia('(display-mode: standalone)').matches) {
  // User is using installed PWA
}
```

## 🚧 Future Enhancements

### Phase 1 (Current)
- [x] Basic PWA setup
- [x] Offline caching
- [x] Install prompts
- [x] Service worker

### Phase 2 (Next)
- [ ] Push notifications
- [ ] Background sync for offline game moves
- [ ] Periodic background sync
- [ ] Advanced caching strategies
- [ ] App shortcuts for recent games

### Phase 3 (Future)
- [ ] Web Share API integration
- [ ] File handling (share game replays)
- [ ] Contact picker (invite friends)
- [ ] Badging API (unread messages)
- [ ] Screen Wake Lock (prevent sleep during game)

## 🔧 Troubleshooting

### Service Worker Not Registering

**Check:**
1. Is site served over HTTPS?
2. Is `sw.js` accessible at `/sw.js`?
3. Check console for errors
4. Try hard refresh (Ctrl+Shift+R)

**Fix:**
```javascript
// Unregister old SW
navigator.serviceWorker.getRegistrations().then(registrations => {
  registrations.forEach(reg => reg.unregister());
});
```

### Install Prompt Not Showing

**Criteria for install prompt:**
1. ✅ Manifest with required fields
2. ✅ Service worker registered
3. ✅ Served over HTTPS
4. ✅ User visited site at least once
5. ⚠️ User hasn't dismissed prompt recently

**Check:**
```javascript
// Listen for beforeinstallprompt
window.addEventListener('beforeinstallprompt', (e) => {
  console.log('Install prompt available!');
});
```

### Cached Content Not Updating

**Solutions:**
1. Increment `CACHE_VERSION` in `sw.js`
2. Clear cache manually:
   - DevTools → Application → Cache Storage → Delete
3. Hard refresh (Ctrl+Shift+R)
4. Update service worker:
   ```javascript
   registration.update();
   ```

### iOS Safari Issues

**Common iOS quirks:**
- Install only via Share → Add to Home Screen
- No install prompt banner
- Limited storage quota (50MB)
- WebSocket may disconnect in background

**Workarounds:**
- Provide manual instructions for iOS
- Keep cache size minimal
- Implement reconnection logic

## 📚 Resources

### Documentation
- [MDN: Progressive Web Apps](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps)
- [web.dev: PWA Guide](https://web.dev/progressive-web-apps/)
- [PWA Builder](https://www.pwabuilder.com/)

### Tools
- [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci)
- [PWA Asset Generator](https://www.pwabuilder.com/imageGenerator)
- [Maskable.app](https://maskable.app/) - Test maskable icons

### Testing
- [BrowserStack](https://www.browserstack.com/) - Test on real devices
- [PWA Checklist](https://web.dev/pwa-checklist/)

---

**Created:** 2026-02-04
**Version:** 1.0
**Status:** ✅ Implemented (pending icon generation)
**Maintained by:** Christophe Craig & Claude
