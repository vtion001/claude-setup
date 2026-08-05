---
name: packaging-desktop-apps
description: Use when a user wants an existing web app available as a native Windows or macOS desktop install — "make a Windows app", "package this as a desktop app", "add a .exe/.dmg download", "wrap the site in Electron", "add auto-update to the desktop app", or "add a Download/Install desktop app link" to a web app's own UI.
---

# Packaging Web Apps as Desktop Apps

## Overview

A **thin Electron wrapper**: one `BrowserWindow` pointed at the app's already-hosted
URL. No bundled backend, no copy of the frontend build, no local database — it's a
client, identical to a browser tab, just without browser chrome. This is almost always
the right shape: it reuses 100% of the existing app unmodified, and Electron's
per-app session persists the app's existing token/cookie auth exactly as a browser
profile would.

**Do not build a full offline/local-bundle desktop app unless explicitly asked.** That
requires embedding the backend + a database locally, is an order of magnitude more
work, and is a different project (help the user decompose it separately if that's
really what they want — see `brainstorming`).

## When to use

- "Make \[app\] available on Windows/Mac installations."
- "Add a desktop app / .exe / .dmg for \[web app\]."
- "Users keep asking for a native app instead of a browser tab."
- The app has a passwordless/magic-link auth flow and emailed links open in the
  browser instead of the desktop app (see Deep linking below).
- NOT for: an app that must work fully offline with no server at all.

## Gather these before writing any code

1. **Hosted URL** the wrapper will load (e.g. `https://app.example.com`). This is the
   *only* thing that makes it "that app" — everything else is boilerplate.
2. **App name + reverse-DNS app id** (e.g. `com.company.appname`) for the installer.
3. **An existing icon asset** to convert (favicon.svg/png, a logo file). Don't invent
   one — and check it's actually icon-shaped (square-ish mark), not a wordmark/lockup
   with padding; `make-icon.mjs` force-resizes to a square with no cropping step.
4. **Does the app have an email-based magic-link / passwordless sign-in?** If yes, its
   emailed link is a plain `https://` URL and will open in the system browser, not the
   desktop app, no matter what — plan for the deep-link addition (below) from the
   start rather than retrofitting it after users complain. If no, strip every
   deep-link touch point per the checklist below — don't leave inert placeholder code.
5. **Does the user want auto-update?** Changes which blocks survive in both templates
   and adds a hosting requirement for `latest*.yml` (see Auto-update below).
6. **Where can the installer be hosted, and where does the wrapper itself live in the
   repo** (new top-level folder, separate package, separate repo)? Prefer self-hosting
   under the target app's own static-asset folder (see Distribution) over GitHub
   Releases — a private repo's release assets 404/require login for non-collaborators,
   which defeats a "click to download" link aimed at non-technical users. Propose a
   placement and confirm it with the user before creating files — don't assume.
7. **Which NSIS/DMG installer defaults to keep?** The templates ship with opinionated
   defaults (installer lets the user pick a directory, adds desktop + Start Menu
   shortcuts, macOS app category defaults to `productivity`) — treat these as a
   starting point to confirm, not a fixed requirement, same as any other scope choice.

## Windows build

```
npm install --save-dev electron electron-builder sharp to-ico png2icons
npm install electron-updater      # only if adding auto-update
```

Copy this skill's `templates/` files into the wrapper's own directory structure —
they're a starting layout, not something referenced in place:
- `templates/package.json` → `<wrapper-dir>/package.json`
- `templates/main.js` → `<wrapper-dir>/src/main.js`
- `templates/make-icon.mjs` → `<wrapper-dir>/scripts/make-icon.mjs` (matches the
  `make-icon` script's own path in `templates/package.json` — keep them in sync if
  you place it elsewhere)

Fill every placeholder before running anything: `{{PROD_URL}}`, `{{APP_ID}}`,
`{{PRODUCT_NAME}}`, `{{PROTOCOL}}` (only if keeping deep linking), `{{DOWNLOADS_URL}}`
(only if keeping auto-update — the feed URL from Auto-update below). Then generate
the icon (rasterizes an SVG/PNG source into both `build/icon.ico` and
`build/icon.icns` in one pass — same script, either host OS — so run it once
regardless of which platform you build on):
```
node scripts/make-icon.mjs <path-to-source.svg-or-png> build
```

Build: `CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --win --publish never`
(`--publish never` avoids electron-builder attempting an actual publish step against
the `publish` config in `package.json` — safe to include even if not using
auto-update).

**Known gotcha:** electron-builder unconditionally tries to download and unpack a
`winCodeSign` archive (macOS code-signing tool binaries, unused for an unsigned
Windows build) even with `CSC_IDENTITY_AUTO_DISCOVERY=false`. Its 7z archive contains
macOS symlinks, and Windows refuses to create them without either an elevated
process or **Developer Mode** enabled (Settings → System → For developers). Ask the
user to flip that toggle (don't do it yourself — it's a system setting change) rather
than debugging further; the build then completes cleanly.

## macOS build

Same `package.json`, add a `mac` target:
```json
"mac": { "target": "dmg", "icon": "build/icon.icns" }
```

**This step must run on an actual Mac (or macOS CI, e.g. GitHub Actions
`macos-latest`).** electron-builder cannot produce a real signed/notarized `.dmg` from
Windows or Linux — Apple's tooling (`hdiutil`, codesign) doesn't exist there. Tell the
user this plainly rather than attempting it and producing a broken artifact; if they
don't have Mac hardware, point them at a macOS GitHub Actions runner as the pragmatic
option.

**Unsigned-mac caveat:** without a paid Apple Developer ID certificate, Gatekeeper
blocks the *auto-updater's* silent install of a new version (users must re-approve
each version manually, same "right-click → Open" dance as the first install). Manual
install still works fine unsigned. Say this explicitly — don't imply auto-update
parity with Windows unless the user actually has a signing certificate.

## Auto-update (optional, both platforms)

`electron-updater`'s `checkForUpdatesAndNotify()` is the entire feature: called on
launch (and optionally on an interval if the app has no tray/background process, so
only while a window is open), it silently downloads a newer version and fires a
native OS notification once ready — clicking it restarts and installs. No custom
notification UI to write.

```js
const { autoUpdater } = require("electron-updater");
autoUpdater.checkForUpdatesAndNotify().catch(() => {}); // network errors are non-fatal
```

Point it at the same host as the installer itself via a **generic** feed — no
credentials, no GitHub Release needed:
```json
"publish": { "provider": "generic", "url": "https://app.example.com/downloads/" }
```

Build with `--publish never` (emit `latest.yml`/`latest-mac.yml` locally without
attempting to actually publish anywhere — the generic provider doesn't need
credentials, but electron-builder still wants an explicit `--publish` value):
```
electron-builder --win --publish never
electron-builder --mac --publish never
```

**Ship the manifest, not just the installer.** Each build produces a `latest*.yml`
that references the installer **by filename** with a sha512/size the updater
validates against. Both files must land in the same hosted folder on every release,
and the filename in the yml must exactly match what's actually hosted — set
`nsis.artifactName` / `dmg.artifactName` to a fixed, space-free template
(`{{PRODUCT_NAME}}-Setup-${version}.${ext}`) so this stays consistent automatically
instead of relying on a manual rename step.

## Deep linking (only if the app has magic-link/passwordless auth)

An emailed sign-in link is unavoidably a plain `https://` URL — email clients have no
way to route it anywhere but the default browser. The fix is a **second** link in the
same email using a custom protocol (`myapp://token/<value>`) that the installer
registers with the OS; clicking it (on the same machine the app is installed on)
launches/focuses the desktop app instead.

- **Electron side** (in `templates/main.js`): `app.setAsDefaultProtocolClient(...)`,
  plus handling the incoming URL on both cold start (`process.argv`) and while
  already running (`second-instance` event — Windows passes the clicked link as a
  command-line arg to the relaunch, which the existing single-instance-lock handler
  already intercepts).
- **Installer side**: `build.protocols` in `package.json` — NSIS/DMG then write the OS
  registration at install time. **A reinstall is required** for anyone who already
  installed a version built before this was added.
- **Backend side**: keep the original `https://` link as the primary/only-guaranteed
  option (works on phones, on machines without the app, for the first-ever sign-in
  before anything is installed) and add the `myapp://` link as a clearly-labeled
  secondary ("Using the desktop app? Open it there instead") — never replace the
  universal link with the custom-scheme one.

**If the target app has no magic-link auth, remove deep linking from all five
touch points** — it's scattered across the template, not one block:
1. `main.js`'s marked deep-link block (protocol registration + `resolveDeepLink`/
   `findDeepLink`).
2. The `second-instance` handler — delete the deep-link lines, keep the
   focus/restore lines (that part is unrelated to deep linking).
3. The `open-url` handler — delete entirely.
4. The `loadURL(findDeepLink(...) ?? PROD_URL)` call — replace with plain
   `loadURL(PROD_URL)`.
5. `package.json`'s `build.protocols` key — delete entirely (unlike the other four,
   nothing marks this one inline, so it's easy to miss).

## Distribution

**Self-host under the target app's own static-serving path** rather than GitHub
Releases: a private repo's release assets return 404 or demand a GitHub login for
anyone without collaborator access, which breaks a plain "click to download" link for
non-technical users. If the app already serves a built SPA (Vite, CRA, etc.) from a
container/VM you control, dropping the installer + `latest*.yml` into that same
public/static folder usually needs no new infrastructure — the existing build/deploy
pipeline ships them for free.

**This does mean committing large binaries to the app's own repo** (an installer is
typically 60–150MB). Flag this trade-off to the user explicitly before doing it —
repo size grows permanently with every release unless something like Git LFS is
adopted; that's a call worth letting them make rather than assuming. **On serverless
or edge-deployed hosts (Vercel, Netlify, Cloudflare Pages, etc.), flag this
separately and explicitly** — every push redeploying a 60–150MB+ binary can measurably
slow build/deploy time on platforms not designed around large static assets, which is
a real cost specific to that hosting shape, not just "repo size" in the abstract.

## Quick reference

| Task | Command |
|---|---|
| Install deps | `npm install --save-dev electron electron-builder sharp to-ico png2icons` (+ `electron-updater` if auto-update) |
| Generate icons (ico + icns) | `node scripts/make-icon.mjs <source.svg> <out-dir>` (path after copying from `templates/`, see Windows build) |
| Dev run | `npx electron .` |
| Windows build | `CSC_IDENTITY_AUTO_DISCOVERY=false npx electron-builder --win --publish never` |
| macOS build (on a Mac) | `npx electron-builder --mac --publish never` |
| Verify a hosted feed | `curl -sI <url>/<installer>` + `curl -s <url>/latest.yml` — size in headers must match the yml |

## Common mistakes

| Mistake | Fix |
|---|---|
| Building a full offline app when a thin wrapper was what's actually needed | Confirm scope first — see "Gather these before writing any code" |
| Assuming the magic-link email will "just work" in the app | It won't — plan the `myapp://` deep link from the start if the app has passwordless auth |
| Hosting the installer on a private GitHub repo's Releases | Self-host it instead (see Distribution) |
| Manually renaming installer output to a URL-safe filename each release | Set `artifactName` in the build config instead |
| Building the `.dmg` on Windows/Linux | Not possible for a real signed build — needs an actual Mac or macOS CI |
| Assuming mac auto-update behaves like Windows unsigned | It doesn't — Gatekeeper blocks unsigned auto-installs; say so |
| Testing GUI launch success via a headless/service shell | May report false failures (no real desktop session) — verify via `--version` (headless-safe) plus a syntax check, and let the actual user do the first real click-test |
| Only deleting the marked deep-link block, missing the other four touch points | Use the five-point removal checklist above — `package.json`'s `protocols` key in particular has no inline marker |
