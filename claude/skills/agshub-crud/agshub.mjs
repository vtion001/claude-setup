#!/usr/bin/env node
// agshub REST helper. Auth comes from AGSHUB_TOKEN (never pass tokens on the CLI).
// Base URL from AGSHUB_BASE_URL, default production.
//
// Usage:
//   node agshub.mjs get    <path>
//   node agshub.mjs post   <path> '<json>'
//   node agshub.mjs patch  <path> '<json>'
//   node agshub.mjs delete <path>
//
// <path> is relative to /api, e.g.  workspaces/<ws>/projects/<p>/work-items
// Examples:
//   node agshub.mjs get workspaces
//   node agshub.mjs patch "workspaces/acme/projects/<p>/work-items/<id>" '{"description":"..."}'
//   node agshub.mjs post  "workspaces/acme/projects/<p>/milestones" '{"name":"Beta","due_date":"2026-09-01"}'

const BASE = (process.env.AGSHUB_BASE_URL || "https://agshub.onrender.com").replace(/\/+$/, "");
const TOKEN = process.env.AGSHUB_TOKEN || "";
const [, , methodRaw, path, bodyRaw] = process.argv;

function usage(msg) {
  if (msg) console.error("error: " + msg);
  console.error("usage: node agshub.mjs <get|post|patch|delete> <path-under-/api> ['<json body>']");
  process.exit(msg ? 1 : 0);
}

if (!methodRaw) usage();
if (!TOKEN) usage("set AGSHUB_TOKEN in the environment first");
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
