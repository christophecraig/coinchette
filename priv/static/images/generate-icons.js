#!/usr/bin/env node

/**
 * PWA Icon Generator for Coinchette
 *
 * This script generates all required PWA icon sizes from the SVG template.
 *
 * Requirements:
 *   npm install sharp
 *
 * Usage:
 *   node generate-icons.js
 */

const fs = require('fs');
const path = require('path');

// Check if sharp is installed
let sharp;
try {
  sharp = require('sharp');
} catch (error) {
  console.error('Error: sharp module not found.');
  console.error('Please install it with: npm install sharp');
  process.exit(1);
}

const ICON_SIZES = [72, 96, 128, 144, 152, 192, 384, 512];
const SVG_SOURCE = path.join(__dirname, 'icon-template.svg');

async function generateIcons() {
  console.log('🎨 Generating PWA icons from SVG template...\n');

  // Check if SVG source exists
  if (!fs.existsSync(SVG_SOURCE)) {
    console.error(`Error: SVG template not found at ${SVG_SOURCE}`);
    process.exit(1);
  }

  let successCount = 0;
  let errorCount = 0;

  for (const size of ICON_SIZES) {
    const outputPath = path.join(__dirname, `icon-${size}.png`);

    try {
      await sharp(SVG_SOURCE)
        .resize(size, size, {
          fit: 'contain',
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        })
        .png({
          quality: 100,
          compressionLevel: 9
        })
        .toFile(outputPath);

      console.log(`✅ Generated: icon-${size}.png`);
      successCount++;
    } catch (error) {
      console.error(`❌ Failed to generate icon-${size}.png:`, error.message);
      errorCount++;
    }
  }

  console.log(`\n📊 Summary:`);
  console.log(`   ✅ Success: ${successCount}/${ICON_SIZES.length}`);
  if (errorCount > 0) {
    console.log(`   ❌ Failed: ${errorCount}/${ICON_SIZES.length}`);
  }

  if (successCount === ICON_SIZES.length) {
    console.log('\n🎉 All icons generated successfully!');
    console.log('\n📝 Next steps:');
    console.log('   1. Review the generated icons');
    console.log('   2. Test PWA installation');
    console.log('   3. Create screenshots (optional): screenshot-mobile.png, screenshot-desktop.png');
  } else {
    console.log('\n⚠️  Some icons failed to generate. Please check the errors above.');
  }
}

// Run the generator
generateIcons().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
