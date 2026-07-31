#!/usr/bin/env python3
"""
prompt-boost-context.py — resolve the calling Claude Code session + recent
conversation turns, for prompt-boost.sh (ctrl+g prompt rewriter).

Ported from the session/transcript-resolution half of statusline.ps1's sibling,
prompt-boost.ps1 (Get-SessionInfo / Get-TranscriptPath / Get-RecentTurns /
Get-ContextBlock). PowerShell's Win32_Process parent-walk becomes `ps -o ppid=`;
everything else is a direct logic port.

Prints one JSON object to stdout: {"text","turns","elided","session"} or
{"text": null} if no context could be resolved. Never raises — any failure
degrades to {"text": null} so the caller falls back to context-free rewriting.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
SESSIONS_DIR = HOME / ".claude" / "sessions"
PROJECTS_DIR = HOME / ".claude" / "projects"

CTX_MAX_TURNS = 12
CTX_USER_CAP = 3000
CTX_RECENT_CAP = 8000
CTX_OLDER_CAP = 6000
CTX_TOTAL_CAP = 45000
TAIL_BYTES = 8 * 1024 * 1024


def parent_pid(pid):
    try:
        out = subprocess.run(
            ["ps", "-o", "ppid=", "-p", str(pid)],
            capture_output=True, text=True, timeout=2,
        ).stdout.strip()
        return int(out) if out else None
    except Exception:
        return None


def get_session_info():
    pid = os.getpid()
    for _ in range(12):
        f = SESSIONS_DIR / f"{pid}.json"
        if f.exists():
            try:
                return json.loads(f.read_text())
            except Exception:
                return None
        pid = parent_pid(pid)
        if not pid or pid <= 1:
            break
    return None


def get_transcript_path(sess):
    session_id = sess.get("sessionId")
    if not session_id:
        return None
    cwd = sess.get("cwd")
    if cwd:
        slug = re.sub(r"[^A-Za-z0-9.]", "-", cwd)
        p = PROJECTS_DIR / slug / f"{session_id}.jsonl"
        if p.exists():
            return p
    if PROJECTS_DIR.exists():
        hits = list(PROJECTS_DIR.rglob(f"{session_id}.jsonl"))
        if hits:
            return hits[0]
    return None


def get_message_text(msg):
    if not msg:
        return None
    c = msg.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        parts = [b.get("text") for b in c if isinstance(b, dict) and b.get("type") == "text" and b.get("text")]
        if parts:
            return "\n".join(parts)
    return None


def clean_user_text(t):
    t = re.sub(r"(?s)<system-reminder>.*?</system-reminder>", "", t)
    t = re.sub(r"(?s)<command-(name|message|args)>.*?</command-\1>", "", t)
    t = re.sub(r"(?s)<local-command-(stdout|stderr)>.*?</local-command-\1>", "", t)
    t = t.strip()
    if not t or t.startswith("<") or t.startswith("Caveat:"):
        return None
    return t


def get_trimmed(t, max_len):
    t = re.sub(r"\s+", " ", t).strip()
    if len(t) <= max_len:
        return t
    head = int(max_len * 0.6)
    tail = max_len - head
    return t[:head].rstrip() + " ... " + t[len(t) - tail:].lstrip()


def get_recent_turns(path):
    size = path.stat().st_size
    with open(path, "rb") as fh:
        if size > TAIL_BYTES:
            fh.seek(-TAIL_BYTES, os.SEEK_END)
        raw = fh.read()
    text = raw.decode("utf-8", errors="replace")
    lines = text.split("\n")
    if size > TAIL_BYTES and len(lines) > 1:
        lines = lines[1:]

    turns = []  # newest first
    asst = []   # text blocks of one reply, oldest-of-block first (built by prepending)

    for line in reversed(lines):
        if len(turns) >= CTX_MAX_TURNS:
            break
        if len(line) < 40:
            continue
        if '"isSidechain":true' in line or '"toolUseResult"' in line or '"isMeta":true' in line:
            continue
        is_user = '"type":"user"' in line
        if not is_user and '"type":"assistant"' not in line:
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue
        txt = get_message_text(obj.get("message"))
        if not txt:
            continue

        if not is_user:
            asst.insert(0, txt)
            continue
        if asst:
            turns.append({"role": "assistant", "text": "\n".join(asst)})
            asst = []
        u = clean_user_text(txt)
        if u:
            turns.append({"role": "user", "text": u})

    if asst and len(turns) < CTX_MAX_TURNS:
        turns.append({"role": "assistant", "text": "\n".join(asst)})

    turns.reverse()  # chronological
    return turns


def get_context_block():
    sess = get_session_info()
    if not sess:
        return None
    path = get_transcript_path(sess)
    if not path:
        return None
    turns = get_recent_turns(path)
    if not turns:
        return None

    n = len(turns)
    rendered = []
    elided = 0
    for i, turn in enumerate(turns):
        if turn["role"] == "user":
            cap = CTX_USER_CAP
        elif i >= n - 2:
            cap = CTX_RECENT_CAP
        else:
            cap = CTX_OLDER_CAP
        original_len = len(re.sub(r"\s+", " ", turn["text"]).strip())
        t = get_trimmed(turn["text"], cap)
        if len(t) < original_len:
            elided += 1
        rendered.append(f"{turn['role']}: {t}")

    while len(rendered) > 1 and len("\n".join(rendered)) > CTX_TOTAL_CAP:
        rendered = rendered[1:]

    return {
        "text": "\n".join(rendered),
        "turns": len(rendered),
        "elided": elided,
        "session": sess.get("sessionId"),
    }


def main():
    try:
        ctx = get_context_block()
    except Exception:
        ctx = None
    if ctx is None:
        print(json.dumps({"text": None}))
    else:
        print(json.dumps(ctx))


if __name__ == "__main__":
    main()
