// Renders an ALTO Property delivery report (writing-delivery-reports skill,
// letterhead variant) from template.html + a data.json to a branded PDF.
//
// Usage:
//   node render.mjs --data data.json --logo logo.png --photo photo.jpg --out out.pdf [--caption "..."]
//
// Colors are fixed to ALTO's brand: white background only, red (#a52c10,
// sampled from the real logo file — NOT the site's brand-red-600 Tailwind
// token, which is a brighter shade) for every heading/accent/table-header,
// near-black/grey for body text only (pure-red body copy is unreadable at
// length). Do not introduce other colors.
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const DIR = path.dirname(fileURLToPath(import.meta.url))

// playwright-core isn't installed alongside this skill — it's resolved from
// altoproperty-main's own node_modules (an absolute-path ESM import works
// regardless of where this script itself is invoked from). Override with
// PLAYWRIGHT_CORE_PROJECT if the repo ever moves.
const PROJECT_DIR = process.env.PLAYWRIGHT_CORE_PROJECT
  || '/Users/archerterminez/Desktop/REPOSITORY/altoproperty-main'
const pwModule = await import(pathToFileURL(path.join(PROJECT_DIR, 'node_modules/playwright-core/index.js')))
const { chromium } = pwModule.default ?? pwModule

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`)
  return i !== -1 ? process.argv[i + 1] : fallback
}

const dataPath = arg('data', path.join(DIR, 'example-data.json'))
const logoPath = arg('logo', path.join(DIR, 'assets/alto-logo-red.png'))
const photoPath = arg('photo')
const outPath = arg('out', path.join(DIR, 'report.pdf'))

if (!photoPath) {
  console.error('Missing --photo. Pull a fresh property photo from the properties table first — see README.md "Pulling a cover photo".')
  process.exit(1)
}

const RED = '#a52c10'
const RED_WASH = '#fbeeea'
const INK = '#1a1614'
const GREY = '#6b625d'

const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'))
const template = fs.readFileSync(path.join(DIR, 'template.html'), 'utf8')

function toDataUri(p) {
  const ext = path.extname(p).toLowerCase()
  const mime = ext === '.png' ? 'image/png' : ext === '.svg' ? 'image/svg+xml' : 'image/jpeg'
  return `data:${mime};base64,${fs.readFileSync(p).toString('base64')}`
}

const snapshotRows = data.snapshotRows.map(r =>
  `<tr><td>${r[0]}</td><td class="b">${r[1]}</td><td class="rag">${r[2]}</td><td class="muted">${r[3]}</td></tr>`
).join('\n')

const deliveredRows = data.deliveredRows.map(r =>
  `<tr><td>${r[0]}</td><td class="b">${r[1]}</td><td class="status">${r[2]}</td><td class="muted">${r[3]}</td></tr>`
).join('\n')

const riskRows = data.riskRows.map(r =>
  `<tr><td>${r[0]}</td><td>${r[1]}</td><td class="muted">${r[2]}</td><td class="muted">${r[3]}</td><td class="status">${r[4]}</td></tr>`
).join('\n')

const listItems = arr => arr.map(x => `<li>${x}</li>`).join('\n')

// Section headings are overridable per document "kind" (progress report vs
// gameplan/approval request, etc.) via data.sections — falls back to the
// original progress-report wording so existing data files keep working.
const sec = {
  exec: 'Executive summary',
  snapshot: 'System snapshot',
  delivered: 'Delivered this period',
  progress: 'In progress',
  upcoming: "Upcoming — where we'd like your steer",
  risks: 'Risks & mitigations',
  decisions: 'Decisions needed from you',
  milestone: 'Milestone / acceptance ledger',
  ...(data.sections || {}),
}

// Approval box: only rendered when data.approval is present (e.g. a
// gameplan/roadmap document asking for explicit sign-off) — omitted
// entirely for a plain progress report.
const approvalBox = data.approval ? `
  <div class="approval-box">
    <div class="ask">${data.approval.ask}</div>
    <div class="approval-line">
      <div>Approved by: <span class="field">&nbsp;</span></div>
      <div>Date: <span class="field">&nbsp;</span></div>
    </div>
  </div>` : ''

let html = template
  .replaceAll('{{RED}}', RED)
  .replaceAll('{{RED_WASH}}', RED_WASH)
  .replaceAll('{{INK}}', INK)
  .replaceAll('{{GREY}}', GREY)
  .replace('{{LOGO_SRC}}', toDataUri(logoPath))
  .replace('{{DOCTYPE_LABEL}}', data.doctypeLabel)
  .replace('{{TITLE}}', data.title)
  .replace('{{META_LINE}}', data.metaLine)
  .replace('{{STATUS_EMOJI}}', data.statusEmoji)
  .replace('{{STATUS_LABEL}}', data.statusLabel)
  .replace('{{PHOTO_SRC}}', toDataUri(photoPath))
  .replace('{{PHOTO_CAPTION}}', data.photoCaption)
  .replace('{{SEC_EXEC}}', sec.exec)
  .replace('{{EXEC_SUMMARY}}', data.execSummary)
  .replace('{{SEC_SNAPSHOT}}', sec.snapshot)
  .replace('{{SNAPSHOT_ROWS}}', snapshotRows)
  .replace('{{SEC_DELIVERED}}', sec.delivered)
  .replace('{{DELIVERED_ROWS}}', deliveredRows)
  .replace('{{ALSO_SHIPPED}}', data.alsoShipped || '')
  .replace('{{SEC_PROGRESS}}', sec.progress)
  .replace('{{IN_PROGRESS_ITEMS}}', listItems(data.inProgress))
  .replace('{{SEC_UPCOMING}}', sec.upcoming)
  .replace('{{UPCOMING_ITEMS}}', listItems(data.upcoming))
  .replace('{{SEC_RISKS}}', sec.risks)
  .replace('{{RISK_ROWS}}', riskRows)
  .replace('{{SEC_DECISIONS}}', sec.decisions)
  .replace('{{DECISIONS_ITEMS}}', listItems(data.decisions))
  .replace('{{APPROVAL_BOX}}', approvalBox)
  .replace('{{SEC_MILESTONE}}', sec.milestone)
  .replace('{{MILESTONE_TEXT}}', data.milestoneText)
  .replace('{{CLOSING_LINE}}', data.closingLine)

const outHtmlPath = outPath.replace(/\.pdf$/, '.html')
fs.writeFileSync(outHtmlPath, html)

const browser = await chromium.launch()
const page = await browser.newPage()
await page.goto(`file://${outHtmlPath}`)
await page.waitForTimeout(150)
await page.pdf({
  path: outPath,
  format: 'A4',
  printBackground: true,
  margin: { top: '0mm', bottom: '14mm', left: '0mm', right: '0mm' },
})
// quick PNG of page 1 for visual sanity-check without opening the PDF
await page.setViewportSize({ width: 900, height: 1273 })
await page.screenshot({ path: outPath.replace(/\.pdf$/, '-preview.png') })
await browser.close()
console.log('rendered:', outPath)
