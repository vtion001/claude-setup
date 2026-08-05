// Thin Electron wrapper. This process owns no data of its own — it just opens
// the hosted app in a native window. Auth, sessions, and all app state live
// entirely on {{PROD_URL}}, same as a browser tab; Electron's BrowserWindow
// keeps its own on-disk session, so the existing token/cookie auth persists
// across launches with no changes on the web app's side.
//
// Fill in every {{PLACEHOLDER}} before use. Delete the auto-update block and
// the deep-link block (both clearly marked) if the target app doesn't need
// them — don't leave inert placeholder code behind.
const { app, BrowserWindow, Menu, shell } = require("electron");
const path = require("node:path");

const PROD_URL = "{{PROD_URL}}";
const ICON_PATH = path.join(__dirname, "..", "build", "icon.ico");
// Delete this line too if removing deep linking — nothing else uses it.
const PROTOCOL = "{{PROTOCOL}}"; // e.g. "myapp"

// ---- Auto-update (delete this block if not wanted) -------------------------
// checkForUpdatesAndNotify() is the entire feature: silently downloads a newer
// version in the background, then fires a native OS notification once ready;
// clicking it restarts and installs. No custom notification UI needed.
const { autoUpdater } = require("electron-updater");
const UPDATE_CHECK_INTERVAL_MS = 4 * 60 * 60 * 1000; // 4h — only fires while a
// window is open, since this wrapper has no tray/background process.
function startUpdateChecks() {
  autoUpdater.checkForUpdatesAndNotify().catch(() => {}); // network errors are non-fatal
  setInterval(() => autoUpdater.checkForUpdatesAndNotify().catch(() => {}), UPDATE_CHECK_INTERVAL_MS);
}
// ---- end auto-update block --------------------------------------------------

// ---- Deep linking (delete this block if the app has no magic-link auth) ----
// process.defaultApp is true only when running unpackaged (`electron .`).
if (process.defaultApp) {
  if (process.argv.length >= 2) {
    app.setAsDefaultProtocolClient(PROTOCOL, process.execPath, [path.resolve(process.argv[1])]);
  }
} else {
  app.setAsDefaultProtocolClient(PROTOCOL);
}

// Turns "myapp://token/<value>" into the real page the web app already knows
// how to verify. Adjust the regex/URL shape to match your own backend's
// secondary link format. Anything that doesn't match is ignored, not
// crashed on — a malformed or foreign deep link should fall through to the
// normal app URL rather than take down the window.
function resolveDeepLink(rawUrl) {
  const m = new RegExp(`^${PROTOCOL}://token/([a-f0-9]+)$`).exec(rawUrl);
  return m ? `${PROD_URL}/auth/magic?token=${m[1]}` : null; // <-- adjust path
}
function findDeepLink(argv) {
  const raw = argv.find((a) => a.startsWith(`${PROTOCOL}://`));
  return raw ? resolveDeepLink(raw) : null;
}
// ---- end deep-link block ----------------------------------------------------

// Second launch focuses the existing window instead of opening a duplicate —
// there is nothing for two windows of the same account to do independently.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  let mainWindow = null;

  // Deep linking: Windows relaunches the app as a "second instance" when a
  // registered link is clicked while it's already running, passing the link
  // as a command-line arg — this is the "already open" half of deep linking.
  // Delete this handler's body (keep window focus/restore) if not deep linking.
  app.on("second-instance", (_event, argv) => {
    if (!mainWindow) return;
    const target = findDeepLink(argv);
    if (target) mainWindow.loadURL(target);
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  });

  // macOS delivers deep links through this event instead of argv, even on
  // first launch. Delete if not deep linking.
  app.on("open-url", (event, url) => {
    event.preventDefault();
    const target = resolveDeepLink(url);
    if (target && mainWindow) mainWindow.loadURL(target);
  });

  function createWindow() {
    mainWindow = new BrowserWindow({
      width: 1400,
      height: 900,
      minWidth: 1024,
      minHeight: 700,
      title: "{{PRODUCT_NAME}}",
      icon: ICON_PATH,
      webPreferences: {
        contextIsolation: true,
        nodeIntegration: false,
      },
    });

    // Cold start via a clicked deep link (app wasn't already running) arrives
    // as a normal launch with the link in this process's own argv. Replace
    // with `mainWindow.loadURL(PROD_URL)` if not deep linking.
    mainWindow.loadURL(findDeepLink(process.argv) ?? PROD_URL);

    // Links that ask for a new window (attachments, "open in new tab", etc.)
    // go to the user's real default browser instead of a chromeless second
    // Electron window with no address bar or back button. Restricted to
    // http(s)/mailto so a compromised page (XSS) can't hand this window an
    // arbitrary URI scheme to launch — everything else is silently dropped.
    mainWindow.webContents.setWindowOpenHandler(({ url }) => {
      if (/^(https?|mailto):/i.test(url)) shell.openExternal(url);
      return { action: "deny" };
    });
  }

  // Default File/Window menu items don't apply to a single-window wrapper;
  // Edit is kept so Cut/Copy/Paste/Undo work in the app's text fields, and
  // View is kept for support/troubleshooting (reload, DevTools).
  Menu.setApplicationMenu(
    Menu.buildFromTemplate([
      {
        label: "Edit",
        submenu: [
          { role: "undo" },
          { role: "redo" },
          { type: "separator" },
          { role: "cut" },
          { role: "copy" },
          { role: "paste" },
          { role: "selectAll" },
        ],
      },
      {
        label: "View",
        submenu: [{ role: "reload" }, { role: "toggleDevTools" }],
      },
    ]),
  );

  app.whenReady().then(() => {
    createWindow();
    startUpdateChecks(); // delete this line if not adding auto-update
  });

  // No tray, no background process — closing the window quits the app like
  // any normal program. Change this if the target app wants a tray/minimize-
  // to-background instead (a bigger scope decision — confirm with the user
  // first rather than silently expanding beyond the thin-wrapper shape).
  app.on("window-all-closed", () => app.quit());
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
}
