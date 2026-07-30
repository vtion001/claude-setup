/**
 * Enumerate real, visible, interactive elements per route.
 *
 * This exists because of a specific defect: the cursor path in v1-v3 was a
 * hand-typed map of viewport percentages, so it pointed at whatever happened to
 * occupy that fraction of the frame. Nothing tied a coordinate to a rendered
 * element.
 *
 * Discovery makes the per-screen intake question answerable — you pick from
 * things that demonstrably exist on the page, so a target can never be a
 * coordinate that corresponds to nothing. It runs against the SAME url and
 * viewport the capture uses, so a candidate that resolves here resolves there.
 */
import { chromium } from 'playwright';
import fs from 'node:fs';

const BASE = process.env.BASE_URL;
const EMAIL = process.env.DEMO_EMAIL;
const PASS = process.env.DEMO_PASS;
const ROUTES = (process.env.ROUTES || '/dashboard,/calls,/chat-qa,/supervisor').split(',');
const VIEWPORT = { width: 1600, height: 900 };

/** A selector that is unique by construction: id when present, else a CSS path. */
const UNIQUE_SELECTOR = `(el) => {
  if (el.id && document.querySelectorAll('#' + CSS.escape(el.id)).length === 1) {
    return '#' + CSS.escape(el.id);
  }
  const parts = [];
  let node = el;
  while (node && node.nodeType === 1 && node !== document.body) {
    let part = node.tagName.toLowerCase();
    const parent = node.parentElement;
    if (parent) {
      const sibs = [...parent.children].filter((c) => c.tagName === node.tagName);
      if (sibs.length > 1) part += ':nth-of-type(' + (sibs.indexOf(node) + 1) + ')';
    }
    parts.unshift(part);
    node = node.parentElement;
  }
  return 'body > ' + parts.join(' > ');
}`;

const run = async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: VIEWPORT });

  const login = await ctx.newPage();
  await login.goto(`${BASE}/login`, { waitUntil: 'networkidle' });
  await login.fill('input[name="email"]', EMAIL);
  await login.fill('input[name="password"]', PASS);
  await login.click('button[type="submit"]');
  await login.waitForTimeout(2500);
  if (/\/login\b/.test(login.url())) throw new Error(`login failed — still at ${login.url()}`);
  await login.close();

  const out = {};
  for (const route of ROUTES) {
    const page = await ctx.newPage();
    // Streaming pages never reach networkidle; discovery must not hang on them.
    await page.goto(`${BASE}${route}`, { waitUntil: 'domcontentloaded', timeout: 20000 });
    await page.waitForTimeout(2500);

    const found = await page.evaluate(({ uniqueSelectorSrc, vw, vh }) => {
      const uniqueSelector = eval(uniqueSelectorSrc);
      const INTERACTIVE = 'a[href], button, [role="button"], [role="tab"], summary, select, input[type="submit"]';

      const describe = (el, kind) => {
        const r = el.getBoundingClientRect();
        const text = (el.innerText || el.getAttribute('aria-label') || '').trim().replace(/\s+/g, ' ');
        return {
          kind,
          // Page chrome (sidebar, top nav) exists on every route and is never the
          // point of a scene. Flagged rather than dropped — a nav item is a valid
          // target when the scene is ABOUT navigation.
          chrome: !!el.closest('aside, nav, header'),
          sel: uniqueSelector(el),
          text: text.slice(0, 70),
          x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height),
        };
      };

      const interactive = [...document.querySelectorAll(INTERACTIVE)].map((el) => describe(el, 'interactive'));

      /**
       * Headline metrics are the most demo-worthy thing on a dashboard and are
       * usually NOT interactive. Matching class names (`.stat`, `.card`) finds
       * nothing in a utility-CSS app — this app returned zero on that heuristic.
       * Detect them by RENDERED FORM instead: big type, short string. That is a
       * property of the design, not of anyone's naming convention.
       */
      const metrics = [...document.querySelectorAll('main *')].filter((el) => {
        if (el.children.length) return false;                 // leaf nodes only
        const t = (el.innerText || '').trim();
        if (!t || t.length > 24) return false;
        return parseFloat(getComputedStyle(el).fontSize) >= 26;
      }).map((el) => {
        // Point at the enclosing tile, not the bare number — a focus ring around
        // a 3-character text node reads as a mistake.
        const tile = el.closest('div');
        return describe(tile && tile.getBoundingClientRect().height >= 60 ? tile : el, 'metric');
      });

      const rows = [...document.querySelectorAll('tbody tr')].slice(0, 4).map((el) => describe(el, 'row'));
      const headings = [...document.querySelectorAll('main h1, main h2, main h3')].map((el) => describe(el, 'heading'));

      const seen = new Set();
      return [...metrics, ...rows, ...interactive, ...headings]
        // Visible, on-screen, big enough to point at, and actually labelled.
        .filter((c) => c.w >= 60 && c.h >= 24 && c.x >= 0 && c.y >= 0
                    && c.x + c.w <= vw && c.y + c.h <= vh && c.text.length > 0)
        .filter((c) => !seen.has(c.sel) && seen.add(c.sel))
        // Content before chrome, then largest first — the ordering the intake
        // question wants, since chrome repeats on every route.
        .sort((a, b) => (a.chrome - b.chrome) || (b.w * b.h - a.w * a.h))
        .slice(0, 20);
    }, { uniqueSelectorSrc: UNIQUE_SELECTOR, vw: VIEWPORT.width, vh: VIEWPORT.height });

    out[route] = found;
    console.log(`\n=== ${route}  (${found.length} candidates) ===`);
    for (const c of found) {
      console.log(`  [${c.kind.padEnd(11)}] ${String(c.w).padStart(4)}x${String(c.h).padStart(3)} @ ${String(c.x).padStart(4)},${String(c.y).padStart(3)}  "${c.text}"\n      ${c.sel}`);
    }
    await page.close();
  }

  fs.writeFileSync('targets.discovered.json', JSON.stringify(out, null, 2));
  await ctx.close();
  await browser.close();
};

run().catch((e) => { console.error(e); process.exit(1); });
