// Render the executive Markdown deliverables to polished, brand-styled PDFs.
// Runs inside the Playwright image (Chromium page.pdf); marked does Markdown->HTML.
import { readFileSync, writeFileSync } from 'node:fs';
import { marked } from 'marked';
import { chromium } from 'playwright';

// ADAPT: output folder (container path) + the md→pdf list below. Override via env if you like.
const DIR = process.env.DELIV_DIR || '/work/deliverables/afg-alex-2026-07';
const DOCS = [
  { md: 'A-system-doc.md',          pdf: 'MCA-Tracker-System-Documentation.pdf',   title: 'MCA-Tracker — System Documentation' },
  { md: 'B-salesforce-migration.md', pdf: 'Centrex-to-Salesforce-Migration-Plan.pdf', title: 'Centrex → Salesforce Migration Game Plan' },
  { md: 'C-alex-meeting.md',        pdf: 'Alex-Meeting-Strategy.pdf',              title: 'Meeting Strategy & Clarifications' },
];

marked.setOptions({ gfm: true, breaks: false });

const css = `
  :root { --navy900:#0A1628; --navy700:#1A2742; --navy600:#243550; --ink:#1f2937; --muted:#6b7280; --accent:#2563eb; --line:#e5e7eb; }
  * { box-sizing: border-box; }
  html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  body { font-family: 'Figtree','Segoe UI',ui-sans-serif,system-ui,-apple-system,sans-serif; color: var(--ink); font-size: 10.5pt; line-height: 1.55; margin: 0; }
  .doc { padding: 4px 2px; }
  h1 { color: var(--navy900); font-size: 22pt; line-height: 1.15; margin: 0 0 4px; letter-spacing: -0.01em; }
  h1 + p, h1 + h2 { margin-top: 0; }
  h2 { color: var(--navy900); font-size: 14.5pt; margin: 22px 0 8px; padding-bottom: 5px; border-bottom: 2px solid var(--navy900); page-break-after: avoid; }
  h3 { color: var(--navy600); font-size: 12pt; margin: 16px 0 6px; page-break-after: avoid; }
  h4 { color: var(--navy700); font-size: 10.8pt; margin: 12px 0 4px; }
  p, li { orphans: 2; widows: 2; }
  ul, ol { padding-left: 18px; margin: 6px 0; }
  li { margin: 2px 0; }
  strong { color: var(--navy900); }
  a { color: var(--accent); text-decoration: none; }
  code { font-family: ui-monospace,'SF Mono',Menlo,Consolas,monospace; font-size: 9pt; background: #f3f4f6; padding: 1px 4px; border-radius: 3px; color: #0f172a; }
  pre { background: #0A1628; color: #e2e8f0; padding: 12px 14px; border-radius: 8px; overflow-x: auto; font-size: 8.6pt; line-height: 1.4; page-break-inside: avoid; }
  pre code { background: none; color: inherit; padding: 0; }
  table { width: 100%; border-collapse: collapse; margin: 10px 0; font-size: 9pt; page-break-inside: avoid; }
  th { background: var(--navy900); color: #fff; text-align: left; padding: 7px 9px; font-weight: 600; }
  td { border: 1px solid var(--line); padding: 6px 9px; vertical-align: top; }
  tbody tr:nth-child(even) { background: #f8fafc; }
  blockquote { margin: 10px 0; padding: 8px 14px; border-left: 4px solid var(--accent); background: #f0f6ff; color: #1e3a5f; }
  img { max-width: 100%; border: 1px solid var(--line); border-radius: 8px; margin: 8px 0; page-break-inside: avoid; }
  hr { border: none; border-top: 1px solid var(--line); margin: 18px 0; }
  .cover { border-left: 6px solid var(--navy900); padding: 2px 0 2px 14px; margin-bottom: 8px; }
  .cover .kicker { color: var(--accent); font-weight: 700; font-size: 9pt; letter-spacing: .08em; text-transform: uppercase; }
  .cover .meta { color: var(--muted); font-size: 9pt; margin-top: 2px; }
`;

const footer = `<div style="width:100%;font-size:8px;color:#9ca3af;padding:0 14mm;display:flex;justify-content:space-between;">
  <span>MCA-Tracker · Confidential — prepared for AFG</span><span>Page <span class="pageNumber"></span> / <span class="totalPages"></span></span></div>`;

const browser = await chromium.launch();
const page = await browser.newPage();
for (const d of DOCS) {
  let body = marked.parse(readFileSync(`${DIR}/${d.md}`, 'utf8'));
  // Map host absolute asset paths to the container mount so <img> resolves under file://.
  // ADAPT: set HOST_REPO to your repo's host root when docs embed absolute-path images.
  body = body.replaceAll(process.env.HOST_REPO || '/mnt/c/Users/VJ_Rodriguguez/Desktop/Repository/MCA-Tracker', 'file:///work');
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head>
    <body><div class="doc">
      <div class="cover"><div class="kicker">MCA-Tracker · AFG (Alternative Funding Group)</div>
      <div class="meta">Prepared by VJ Rodriguez · ${new Date().toISOString().slice(0,10)} · Confidential</div></div>
      ${body}
    </div></body></html>`;
  const htmlPath = `/work/deliverables/_build/${d.md}.html`;
  writeFileSync(htmlPath, html);
  await page.goto('file://' + htmlPath, { waitUntil: 'networkidle' });
  await page.pdf({
    path: `${DIR}/${d.pdf}`, format: 'A4', printBackground: true,
    margin: { top: '16mm', bottom: '16mm', left: '15mm', right: '15mm' },
    displayHeaderFooter: true, headerTemplate: '<span></span>', footerTemplate: footer,
  });
  console.log('rendered', d.pdf);
}
await browser.close();
