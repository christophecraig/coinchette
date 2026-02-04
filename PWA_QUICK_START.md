# 📱 PWA Quick Start Guide

## ✅ What's Been Implemented

Your Coinchette app is now a **Progressive Web App (PWA)**! This means users can install it on their phones and desktops like a native app.

## 🎯 Key Features

- ✅ **Installable** - Users can add to home screen (iOS, Android, Desktop)
- ✅ **Offline Support** - App works without internet (cached assets)
- ✅ **Fast Loading** - Service worker caches assets for instant loads
- ✅ **Native Feel** - Looks and feels like a native app
- ✅ **App Icon** - Custom icon on home screen
- ✅ **Standalone Mode** - Opens without browser UI
- ✅ **Auto Updates** - Service worker handles updates automatically

## 🚀 What You Need to Do

### 1. Generate App Icons (Required)

Your app needs PNG icons in various sizes. Choose one method:

#### Option A: Automatic Generation (Recommended if you have Node.js)

```bash
cd priv/static/images
npm install sharp
node generate-icons.js
```

This will generate all 8 required icon sizes from the SVG template.

#### Option B: Online Tool (Easiest)

1. Go to: https://www.pwabuilder.com/imageGenerator
2. Upload `priv/static/images/icon-template.svg`
3. Download all generated icons
4. Place them in `priv/static/images/`

Required icon files:
- icon-72.png
- icon-96.png
- icon-128.png
- icon-144.png
- icon-152.png
- icon-192.png (maskable)
- icon-384.png
- icon-512.png (maskable)

### 2. Test PWA Installation (Recommended)

After generating icons, test the installation:

**On Desktop:**
1. Visit https://coinchette.onrender.com
2. Look for install icon (⊕) in Chrome address bar
3. Click "Install"

**On Mobile:**
- **iOS**: Safari → Share → Add to Home Screen
- **Android**: Chrome → Menu → Install app

### 3. Run Lighthouse Audit (Optional)

Check your PWA score:

```bash
lighthouse https://coinchette.onrender.com --view
```

Target: 100/100 PWA score ✅

## 📱 How Users Will Install

### iOS (Safari)

1. Visit your site in Safari
2. Tap Share button (□↑)
3. Scroll down → "Add to Home Screen"
4. Tap "Add"
5. App appears on home screen with your icon

### Android (Chrome)

1. Visit your site in Chrome
2. See "Install" banner at top (or bottom)
3. Tap "Install"
4. App appears on home screen

### Desktop (Chrome/Edge)

1. Visit your site
2. Look for install icon in address bar
3. Click "Install Coinchette"
4. App opens in its own window

## 🎨 UI Components Available

You can now use these PWA components in your LiveViews:

### Install Banner
```elixir
<.pwa_install_banner position="top" dismissible={true} />
```
Shows a prompt to install the app when available.

### Update Banner
```elixir
<.pwa_update_banner />
```
Notifies users when a new version is available.

### Offline Indicator
```elixir
<.pwa_offline_indicator />
```
Shows when user is offline but app still works.

### Debug Info (Dev Only)
```elixir
<.pwa_debug_info />
```
Shows PWA status during development.

## 🔧 Service Worker Details

The service worker (`/sw.js`) automatically:

- ✅ Caches CSS, JavaScript, and images
- ✅ Serves cached content when offline
- ✅ Updates cache when new version deployed
- ✅ Cleans up old cache versions
- ✅ Falls back gracefully when offline

**Cache Strategy:**
- **Static assets** (CSS/JS): Cache first, update in background
- **Images**: Cache forever, serve instantly
- **Dynamic content**: Network first, cache fallback
- **WebSocket/LiveView**: Always live, no cache

## 📊 Testing Checklist

After generating icons:

- [ ] Icons visible in `priv/static/images/` (8 files)
- [ ] Visit site and check for install prompt
- [ ] Test installation on desktop
- [ ] Test installation on mobile (iOS + Android)
- [ ] Test offline mode (DevTools → Network → Offline)
- [ ] Run Lighthouse audit
- [ ] Verify service worker registered (DevTools → Application)
- [ ] Check manifest loaded (DevTools → Application → Manifest)

## 🐛 Troubleshooting

### "Install prompt doesn't show"

**Possible causes:**
- Icons not generated yet
- Already installed
- User dismissed it recently
- Not on HTTPS (Render.com is HTTPS ✅)

**Solution:**
- Generate icons first
- Try in incognito window
- Check console for errors

### "Service Worker not registered"

**Check:**
- Is `/sw.js` accessible?
- Check browser console for errors
- Try hard refresh (Ctrl+Shift+R)

**Fix:**
```javascript
// In browser console:
navigator.serviceWorker.getRegistrations().then(regs => {
  regs.forEach(reg => reg.unregister());
  location.reload();
});
```

### "Offline mode doesn't work"

- Service worker needs at least one visit to cache assets
- Check DevTools → Application → Cache Storage
- Verify files are cached

## 📝 Files Created

```
priv/static/
├── manifest.json              # PWA configuration
├── sw.js                      # Service worker
└── images/
    ├── icon-template.svg      # Icon source
    ├── generate-icons.js      # Generation script
    └── ICON_GENERATION_GUIDE.md

assets/js/
└── pwa.js                     # PWA hooks

lib/coinchette_web/
└── components/
    └── pwa_components.ex      # UI components

.claudefiles/
└── PWA.md                     # Full documentation
```

## 🎯 Next Steps

1. **Generate icons** (5 minutes)
2. **Test installation** (10 minutes)
3. **Optional:** Create screenshots for better app store presentation
   - Mobile: 390x844px
   - Desktop: 1280x720px
4. **Optional:** Run Lighthouse audit
5. **Optional:** Implement push notifications (future feature)

## 📚 Documentation

For complete details, see:
- `.claudefiles/PWA.md` - Full PWA implementation guide
- `priv/static/images/ICON_GENERATION_GUIDE.md` - Icon generation details

## ✅ Current Status

- [x] PWA manifest configured
- [x] Service worker implemented
- [x] Meta tags added
- [x] UI components created
- [x] Hooks implemented
- [x] Documentation written
- [ ] Icons generated (user action required)
- [ ] Tested on real devices (recommended)

---

**Your PWA is ready to go!** Just generate the icons and you're live with a fully installable app. 🚀

Questions? Check `.claudefiles/PWA.md` for detailed documentation.
