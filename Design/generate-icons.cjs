// Renders Design/AppIcon.svg into every size the macOS AppIcon asset catalog needs.
// Requires Node and Playwright with Chromium:  node Design/generate-icons.cjs
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const svg = fs.readFileSync(path.join(__dirname, 'AppIcon.svg'), 'utf8');
const out = path.join(root, 'Pico/Resources/Assets.xcassets/AppIcon.appiconset');

// [point size, scale] pairs required by the macOS app icon set.
const slots = [[16, 1], [16, 2], [32, 1], [32, 2], [128, 1], [128, 2], [256, 1], [256, 2], [512, 1], [512, 2]];

(async () => {
  const browser = await chromium.launch();
  for (const [points, scale] of slots) {
    const px = points * scale;
    const page = await browser.newPage({ viewport: { width: px, height: px } });
    const sized = svg.replace('width="1024" height="1024"', `width="${px}" height="${px}"`);
    await page.setContent(`<html><body style="margin:0;background:transparent">${sized}</body></html>`);
    const name = `icon_${points}x${points}${scale === 2 ? '@2x' : ''}.png`;
    await page.screenshot({ path: path.join(out, name), omitBackground: true });
    console.log(name, px);
    await page.close();
  }
  await browser.close();
})();
