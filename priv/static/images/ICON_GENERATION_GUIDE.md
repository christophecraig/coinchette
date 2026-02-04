# PWA Icon Generation Guide

This guide explains how to generate the PWA icons from the SVG template.

## Required Icons

The PWA manifest requires the following icon sizes:
- 72x72px
- 96x96px
- 128x128px
- 144x144px
- 152x152px
- 192x192px (maskable)
- 384x384px
- 512x512px (maskable)

## Method 1: Online Tools (Easiest)

### Using PWA Asset Generator (Recommended)
1. Visit: https://www.pwabuilder.com/imageGenerator
2. Upload `icon-template.svg`
3. Download all generated icons
4. Place them in this directory (`priv/static/images/`)

### Using RealFaviconGenerator
1. Visit: https://realfavicongenerator.net/
2. Upload `icon-template.svg`
3. Configure for PWA
4. Download and extract to this directory

## Method 2: Using ImageMagick (Command Line)

If you have ImageMagick installed:

```bash
# Navigate to this directory
cd priv/static/images/

# Generate all required sizes
convert icon-template.svg -resize 72x72 icon-72.png
convert icon-template.svg -resize 96x96 icon-96.png
convert icon-template.svg -resize 128x128 icon-128.png
convert icon-template.svg -resize 144x144 icon-144.png
convert icon-template.svg -resize 152x152 icon-152.png
convert icon-template.svg -resize 192x192 icon-192.png
convert icon-template.svg -resize 384x384 icon-384.png
convert icon-template.svg -resize 512x512 icon-512.png
```

## Method 3: Using Node.js Script

If you have Node.js with `sharp` installed:

```bash
npm install sharp
node generate-icons.js
```

See `generate-icons.js` in this directory.

## Method 4: Manual Design

If you prefer to design custom icons:

1. Use any design tool (Figma, Sketch, Photoshop, GIMP, etc.)
2. Start with 512x512px canvas
3. Design should have:
   - Safe zone: 80% center (avoid edges for maskable icons)
   - Recognizable at small sizes
   - Good contrast
   - Brand colors: #155724 (green), #1e7e34 (dark green)
4. Export at all required sizes
5. Name files: `icon-{size}.png`

## Maskable Icons

For Android adaptive icons (icon-192.png and icon-512.png):
- Use the entire canvas (no transparency at edges)
- Important content should be in the center 80% "safe zone"
- Background should extend to all edges

## Screenshots (Optional but Recommended)

For better app store presentation, create screenshots:
- Mobile: 390x844px (iPhone 12 size)
- Desktop: 1280x720px (landscape)

Name them:
- `screenshot-mobile.png`
- `screenshot-desktop.png`

## Testing Icons

After generating icons, test them:

1. **Lighthouse PWA Audit:**
   ```bash
   lighthouse https://coinchette.onrender.com --view
   ```

2. **Chrome DevTools:**
   - Open DevTools
   - Go to Application > Manifest
   - Check if all icons load correctly

3. **Real Device:**
   - Install PWA on mobile device
   - Check home screen icon
   - Check splash screen

## Placeholder Icons

Until custom icons are created, you can use the SVG template directly in some contexts, or generate quick placeholders using online favicon generators.

## Current Status

- [ ] 72x72 icon
- [ ] 96x96 icon
- [ ] 128x128 icon
- [ ] 144x144 icon
- [ ] 152x152 icon
- [ ] 192x192 icon (maskable)
- [ ] 384x384 icon
- [ ] 512x512 icon (maskable)
- [ ] Mobile screenshot
- [ ] Desktop screenshot

---

**Note:** The `icon-template.svg` provided is a starting point. You can customize it or replace it with your own design before generating the PNG icons.
