#!/usr/bin/env python3
"""
sidebar.py - a companion pane for Claude Code.

Claude Code has no file explorer and no arbitrary-file viewer; its only panel
is hardcoded to git-diff content. This runs in an iTerm2 pane beside it and
provides both.

  no target  ->  file tree of the repo Claude Code is working in
  a target   ->  that file, with line numbers, following edits live

Point it at a file by writing the path to ~/.claude/sidebar.target:
    echo /path/to/file.php > ~/.claude/sidebar.target
Clear it to go back to the tree:
    > ~/.claude/sidebar.target

Root is auto-detected from the newest live Claude Code session, so it follows
whatever project you are in. Override with --root.

Ported from claude-setup's sidebar.ps1 (Windows/PowerShell original).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
TARGET_F = HOME / ".claude" / "sidebar.target"
SESSIONS_DIR = HOME / ".claude" / "sessions"
MAX_FILES = 400

ESC = "\033"


def c(t, n):
    return f"{ESC}[38;5;{n}m{t}{ESC}[0m"


# Follow whatever project Claude Code is actually in. The sessions directory's
# own mtime moves whenever a session file is written, so it's a cheap cache key.
_root_cache = None
_root_stamp = None


def resolve_root(root_override):
    global _root_cache, _root_stamp
    if root_override:
        return root_override
    if not SESSIONS_DIR.exists():
        return str(HOME)
    stamp = SESSIONS_DIR.stat().st_mtime
    if _root_cache and stamp == _root_stamp:
        return _root_cache

    r = str(HOME)
    try:
        files = sorted(SESSIONS_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
        if files:
            j = json.loads(files[0].read_text())
            cwd = j.get("cwd")
            if cwd and os.path.isdir(cwd):
                r = cwd
    except Exception:
        pass
    _root_cache = r
    _root_stamp = stamp
    return r


# git ls-files is both faster than walking the tree and already gitignore-aware,
# which is what keeps node_modules out without maintaining an exclude list.
def get_tree(root, rows):
    files = []
    try:
        out = subprocess.run(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard"],
            cwd=root, capture_output=True, text=True, timeout=5,
        )
        if out.returncode == 0:
            files = [f for f in out.stdout.splitlines() if f]
    except Exception:
        pass

    if not files:
        for dirpath, dirnames, filenames in os.walk(root):
            depth = dirpath[len(root):].count(os.sep)
            if depth >= 2:
                dirnames[:] = []
            for fn in filenames:
                full = os.path.join(dirpath, fn)
                files.append(os.path.relpath(full, root).replace(os.sep, "/"))
            if len(files) >= MAX_FILES:
                break

    files = files[:MAX_FILES]

    by_dir = {}
    for f in files:
        d, _, name = f.rpartition("/")
        d = d or "."
        by_dir.setdefault(d, []).append(name)

    out_lines = []
    for d, names in by_dir.items():
        if len(out_lines) >= rows:
            break
        out_lines.append(c(f"{d}/", 111))
        for n in names:
            if len(out_lines) >= rows:
                break
            out_lines.append("  " + c(n, 250))
    return out_lines


def get_file_view(path, rows):
    try:
        with open(path, "r", errors="replace") as fh:
            lines = []
            for i, raw_line in enumerate(fh):
                if i >= rows:
                    break
                lines.append(raw_line.rstrip("\n"))
    except Exception:
        return [c("unreadable", 203)]
    out = []
    for i, l in enumerate(lines, 1):
        out.append(c(f"{i:>4} ", 240) + l.replace("\t", "    "))
    return out


def term_size():
    sz = shutil.get_terminal_size(fallback=(80, 24))
    return sz.columns, sz.lines


def render_once(root_override, last_key, last_body, last_head):
    root = resolve_root(root_override)
    target = None
    if TARGET_F.exists():
        t = TARGET_F.read_text().strip()
        if t and os.path.isfile(t):
            target = t

    cols, term_lines = term_size()
    rows = max(6, term_lines - 4)

    if target:
        # a file has one authoritative stamp, so the cheap key is exact
        stamp = os.stat(target).st_mtime
        key = f"f|{target}|{stamp}|{rows}"
        head = c(os.path.basename(target), 45)
        sub = c(os.path.dirname(target) or "/", 240)
    else:
        # A directory mtime only moves for top-level changes, and .git/index only
        # for git operations, so neither is sufficient alone. Use them to decide
        # when to RECOMPUTE, then redraw only if the rendered text actually
        # differs, so an idle pane doesn't flicker or break text selection.
        stamp = os.stat(root).st_mtime
        idx = os.path.join(root, ".git", "index")
        if os.path.exists(idx):
            stamp = f"{stamp}/{os.stat(idx).st_mtime}"
        bucket = int(time.time() // 3)
        key = f"t|{root}|{rows}|{stamp}|{bucket}"
        head = c(os.path.basename(root.rstrip("/")) or root, 45)
        sub = c(root, 240)

    if key == last_key:
        return last_key, last_body, last_head

    body = get_file_view(target, rows) if target else get_tree(root, rows)
    rendered = "\n".join(body)
    if rendered == last_body and head == last_head:
        return key, last_body, last_head

    sys.stdout.write("\033[2J\033[H")
    print(head)
    print(sub)
    print(c("─" * max(10, cols - 1), 238))
    for line in body:
        print(line)
    sys.stdout.flush()
    return key, rendered, head


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root")
    ap.add_argument("--interval-ms", type=int, default=800)
    args = ap.parse_args()

    last_key = last_body = last_head = ""
    while True:
        last_key, last_body, last_head = render_once(args.root, last_key, last_body, last_head)
        time.sleep(args.interval_ms / 1000)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
