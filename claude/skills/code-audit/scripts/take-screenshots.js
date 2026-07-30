/**
 * Playwright screenshot utility for code audit findings.
 * Captures both desktop and mobile viewports for every route.
 * Supports BEFORE and AFTER modes for pre/post-fix comparison.
 *
 * Usage:
 *   node take-screenshots.js <base-url> <output-dir> <mode> [routes...]
 *
 * Arguments:
 *   base-url   - localhost URL (e.g., http://localhost:3000)
 *   output-dir - root directory to save screenshots
 *   mode       - "before" or "after" (creates subdirectory accordingly)
 *   routes     - space-separated list of routes (e.g., /dashboard /calls /agents)
 *
 * Examples:
 *   node take-screenshots.js http://localhost:3000 ./audit-screenshots before /dashboard /calls
 *   node take-screenshots.js http://localhost:3000 ./audit-screenshots after /dashboard /calls
 *
 * Output structure:
 *   ./audit-screenshots/before/before-dashboard-desktop.png
 *   ./audit-screenshots/before/before-dashboard-mobile.png
 *   ./audit-screenshots/after/after-dashboard-desktop.png
 *   ./audit-screenshots/after/after-dashboard-mobile.png
 */

const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const VIEWPORTS = {
  desktop: { width: 1920, height: 1080 },
  mobile: { width: 375, height: 812 },
};

async function captureRoute(context, baseUrl, route, outputDir, mode) {
  const slug = route.replace(/^\//, '').replace(/\//g, '-') || 'root';
  const url = `${baseUrl.replace(/\/$/, '')}${route}`;
  const result = { route, slug, mode, screenshots: [], status: 'ok' };

  for (const [device, viewport] of Object.entries(VIEWPORTS)) {
    const page = await context.newPage();
    await page.setViewportSize(viewport);

    try {
      console.log(`  [${device}] ${url}`);
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
      await page.waitForTimeout(2000);

      const filename = `${mode}-${slug}-${device}.png`;
      const filepath = path.join(outputDir, filename);
      await page.screenshot({ path: filepath, fullPage: true });

      result.screenshots.push({ device, viewport, filepath, filename });
    } catch (err) {
      console.error(`  [${device}] Error: ${err.message}`);
      result.screenshots.push({ device, viewport, status: 'error', error: err.message });
    } finally {
      await page.close();
    }
  }

  return result;
}

async function takeScreenshots() {
  const [,, baseUrl, rootDir, mode, ...routes] = process.argv;

  if (!baseUrl || !rootDir || !mode || routes.length === 0) {
    console.error('Usage: node take-screenshots.js <base-url> <output-dir> <before|after> <route1> [route2] ...');
    console.error('Example: node take-screenshots.js http://localhost:3000 ./audit-screenshots before /dashboard /calls');
    process.exit(1);
  }

  if (mode !== 'before' && mode !== 'after') {
    console.error(`Invalid mode "${mode}". Must be "before" or "after".`);
    process.exit(1);
  }

  const outputDir = path.join(rootDir, mode);
  fs.mkdirSync(outputDir, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ deviceScaleFactor: 1 });
  const results = [];

  console.log(`[${mode.toUpperCase()}] Capturing ${routes.length} routes in desktop + mobile viewports...\n`);

  for (const route of routes) {
    console.log(`Route: ${route}`);
    const result = await captureRoute(context, baseUrl, route, outputDir, mode);
    results.push(result);
    console.log('');
  }

  await browser.close();

  const manifest = path.join(outputDir, `manifest-${mode}.json`);
  fs.writeFileSync(manifest, JSON.stringify(results, null, 2));

  const totalScreenshots = results.reduce((sum, r) =>
    sum + r.screenshots.filter(s => !s.error).length, 0);
  console.log(`Manifest: ${manifest}`);
  console.log(`Total: ${totalScreenshots} ${mode} screenshots from ${results.length} routes`);
}

takeScreenshots().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
