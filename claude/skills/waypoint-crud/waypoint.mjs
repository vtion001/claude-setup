#!/usr/bin/env node
// waypoint REST helper. Auth comes from WAYPOINT_TOKEN (never pass tokens on the CLI).
// Base URL from WAYPOINT_BASE_URL, default the Tailscale Funnel URL for the personal instance.
//
// Usage:
//   node waypoint.mjs get    <path>
//   node waypoint.mjs post   <path> '<json>'
//   node waypoint.mjs patch  <path> '<json>'
//   node waypoint.mjs delete <path>
//
// <path> is relative to /api, e.g.  workspaces/<slug>/projects/<p>/work-items
// Examples:
//   node waypoint.mjs get workspaces
//   node waypoint.mjs patch "workspaces/dev/projects/<p>/work-items/<id>" '{"priority":"high"}'
//   node waypoint.mjs post  "workspaces/dev/projects/<p>/milestones" '{"name":"Beta","due_date":"2026-09-01"}'

const BASE = (process.env.WAYPOINT_BASE_URL || "https://macbook-pro.tail7ceefe.ts.net:10000").replace(/\/+$/, "");
const TOKEN = process.env.WAYPOINT_TOKEN || "";
const [, , methodRaw, path, bodyRaw] = process.argv;

function usage(msg) {
  if (msg) console.error("error: " + msg);
  console.error("usage: node waypoint.mjs <get|post|patch|delete> <path-under-/api> ['<json body>']");
  process.exit(msg ? 1 : 0);
}

if (!methodRaw) usage();
if (!TOKEN) usage("set WAYPOINT_TOKEN in the environment first");
const method = methodRaw.toUpperCase();
if (!["GET", "POST", "PATCH", "DELETE"].includes(method)) usage(`unknown method '${methodRaw}'`);
if (!path) usage("missing path");

let body;
if (bodyRaw !== undefined) {
  try { body = JSON.parse(bodyRaw); }
  catch { usage("body is not valid JSON"); }
}

const url = `${BASE}/api/${String(path).replace(/^\/+/, "")}`;
const res = await fetch(url, {
  method,
  headers: {
    Authorization: `Bearer ${TOKEN}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  },
  body: body === undefined ? undefined : JSON.stringify(body),
});

const text = await res.text();
let out = text;
try { out = JSON.stringify(JSON.parse(text), null, 2); } catch { /* leave raw */ }
console.log(`${method} ${url} -> ${res.status}`);
if (out) console.log(out);
// Set exitCode and let the event loop drain the socket. Calling process.exit()
// here races the closing keep-alive socket and aborts on Windows/Node 25.
process.exitCode = res.ok ? 0 : 1;
