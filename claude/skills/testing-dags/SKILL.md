---
name: testing-dags
description: Use when testing a real-time or media/AI-pipeline app (audio, video, mic, camera, transcription, STT/ASR, streaming, WebSocket) where CI/automation has no hardware, or when a bug shows as "nothing renders" and you can't tell if it's the data pipeline or the UI. Covers layering tests as a dependency graph and injecting synthetic media at the app's own seam.
---

# Testing DAGs

## Overview

Test an app as a **DAG of layers** — cheapest and most deterministic checks first, then integration reproduction, then expensive headed end-to-end — and **reproduce every bug at the lowest layer that isolates it**. For media/AI apps, feed *synthetic* input at the app's own seam, because automation has no microphone or camera.

**Core principle:** the layer where you can reproduce a bug is the layer where you should test it. Never debug a data-pipeline bug through the UI.

## When to Use

- The app needs a mic / camera / screen that the CI box doesn't have (transcription, calls, screen capture, streaming).
- The symptom is "nothing shows up" and you don't yet know if it's a **data** problem or a **render** problem.
- An E2E test is flaky because it's gated on a slow or nondeterministic dependency (LLM, remote API, network).
- Any real-time pipeline shaped `capture → transport (WS/HTTP) → process → render`.

## The DAG: build bottom-up, gate top-down

| Layer | Scope | Deterministic? | Cost | Reproduces… |
|---|---|---|---|---|
| **Unit** | pure logic — parsers, delta/dedup, request shape, provider selection | yes | ms | logic bugs |
| **Integration** | drive the transport directly (WebSocket/API) exactly like the client does — **no UI** | mostly | seconds | data-flow bugs |
| **E2E** | real app, headed, synthetic media injected, content asserted, video recorded | no | ~minutes | wiring/render bugs |

Reproduce at the **lowest** layer first. Example: a "blank transcript overlay" bug was reproduced by driving the WebSocket directly (no UI, no flake), which proved data delivery worked and pinned the bug to the server's buffer handling — *then* the E2E confirmed the fix. Reproducing that through the UI would have been slow and ambiguous.

## Inject synthetic media at the app's seam (no hardware)

Automation has no mic. Overriding `getUserMedia` returns a stream, but **`MediaRecorder.start()` frequently throws `NotSupportedError` on a Web-Audio stream** (Electron/Chromium). So override **`MediaRecorder` itself** to emit pre-encoded chunks — the app's own "send chunk" path then streams *real* bytes through the real pipeline. Install via `addInitScript` so it's in place before the app's scripts run.

```js
// Playwright: before the app loads, replace MediaRecorder so recording "just
// works" and emits our own webm/opus in timed slices — the app forwards each
// ondataavailable blob exactly as if a mic produced it.
await page.addInitScript((b64) => {
  const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const md = navigator.mediaDevices;
  // getUserMedia must still succeed (a silent Web-Audio stream is enough — the
  // audio content comes from the fake recorder below, not this stream).
  md.getUserMedia = async () => {
    const ctx = new (window.AudioContext || window.webkitAudioContext)();
    const dest = ctx.createMediaStreamDestination();
    ctx.createOscillator().connect(dest); // any live track
    return dest.stream;
  };
  const slices = [];
  for (let i = 0; i < bytes.length; i += 16 * 1024) slices.push(bytes.subarray(i, i + 16 * 1024));
  window.MediaRecorder = class {
    static isTypeSupported() { return true; }
    constructor() { this.state = 'inactive'; this.mimeType = 'audio/webm;codecs=opus'; this._i = 0; this._cb = {}; }
    addEventListener(ev, cb) { this._cb[ev] = cb; }
    _fire(ev, d) { (this['on' + ev] || this._cb[ev])?.(d); }
    start(timeslice) {                       // app calls start(2000)
      this.state = 'recording';
      this._iv = setInterval(() => {
        if (this._i >= slices.length) return clearInterval(this._iv);
        this._fire('dataavailable', { data: new Blob([slices[this._i++]], { type: this.mimeType }) });
      }, timeslice || 2000);
    }
    stop() { this.state = 'inactive'; clearInterval(this._iv); this._fire('stop', {}); }
    requestData() {} pause() {} resume() {}
  };
}, WEBM_BASE64);
```

Why chunks and not one blob: a server that accumulates a rolling buffer reassembles the slices into a valid container — feeding realistic streaming, not a single upload.

## Assert content, not presence

`text.length > 0` passes on a **demo fallback**, a placeholder, or a stale render. Assert words that can only appear if the real pipeline ran on your known input (e.g. the fixture says "cough / throat / chest" → assert those). This is what distinguishes "the modal rendered *something*" from "the modal rendered *the transcription*".

## Decouple slow / nondeterministic layers

If a surface is gated on an LLM or remote call, **hard-assert the deterministic surface and make the slow one best-effort** (generous timeout, warn-don't-fail). A transcript test must not fail because note-drafting was slow — that's a different subsystem. Match the assertion strength to the determinism of what it's checking.

## Portability (so a fresh clone / CI passes)

- **Commit the fixture** (the audio/video/media) into the repo.
- Default paths to `__dirname`-relative for inputs and `os.tmpdir()` for outputs — never hardcode an absolute scratch path.
- Record **video + screenshots** to the temp dir for human review.
- Put the runtime prerequisites (services up, env mode, keys) in the test file header.

## Fix the tests that encode the bug

When you fix a bug, existing tests may assert the **old, buggy** behavior (someone wrote a test for the "optimization" that caused it). Rewrite those to the corrected behavior. A green suite that locks in the bug is worse than no test.

## Common Mistakes

- **Debugging a data bug through the UI** — slow, flaky, ambiguous. Reproduce at the WS/API layer first.
- **Relying on `--use-file-for-fake-audio-capture`** — Electron ignores it; override `MediaRecorder`.
- **Overriding only `getUserMedia`** — `MediaRecorder.start()` still throws on the synthetic stream.
- **Asserting presence, not content** — passes on a demo/placeholder render.
- **One E2E gated on an LLM/network** — chronic flake; split deterministic vs best-effort assertions.
- **Hardcoded absolute fixture paths** — green on your box, broken on every other clone.
