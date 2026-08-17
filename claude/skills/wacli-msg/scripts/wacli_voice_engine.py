#!/usr/bin/env python3
"""
wacli_voice_engine.py — incremental, self-updating voice-training engine for the
wacli-msg skill (skills/wacli-msg/SKILL.md).

Scrapes Vincent's own sent WhatsApp messages (--from-me via wacli) and classifies each
one as:
  green    — looks genuinely typed by him, usable as style evidence
  red      — likely a prior AI-drafted-and-approved send (em dash, stacked po/opo, long
             formal-closer message) — quarantined, never used as style evidence
  neutral  — no strong signal either way, held for manual review, not auto-used

State lives in voice-profile/state.json — the single source of truth, and it is
incremental: each contact's last-seen message timestamp is checkpointed, so re-running
this script only pulls what's new since last time (the "autolearn" loop). Everything
under voice-profile/*.md is a RENDERED VIEW regenerated from state.json on every run —
never hand-edit those files; change classification rules here and re-run instead.

Usage:
  python3 wacli_voice_engine.py                              # incremental, all DM contacts
  python3 wacli_voice_engine.py --full                        # ignore checkpoints, full re-scrape
  python3 wacli_voice_engine.py --contacts "Joshua Kim,Mark Lee"   # name-substring filter
  python3 wacli_voice_engine.py --include-groups               # also scrape group chats
  python3 wacli_voice_engine.py --render-only                  # skip scraping, just re-render .md
"""
import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]  # scripts/ -> wacli-msg/ -> skills/ -> repo root
PROFILE_DIR = REPO_ROOT / "voice-profile"
STATE_FILE = PROFILE_DIR / "state.json"
# Hand-maintained, NEVER written by this script — who this contact actually is: which
# repo/project the conversation is about, and any standing correction (e.g. "call him
# Joshua, never Josh") the operator has given directly. Same philosophy as the em-dash /
# deep-Tagalog rules: an explicit operator correction outranks anything scraped from
# message history, because the scrape can't see facts like "what name does he go by" at
# all, let alone verify them. render_contact_file() below merges this into each contact's
# generated .md as a "## Context" section — it's read, never overwritten, by this engine.
CONTEXT_FILE = PROFILE_DIR / "contact-context.json"

EM_DASH_RE = re.compile(r"[—–]")  # em dash, en dash
PO_RE = re.compile(r"\bpo\b|\bopo\b", re.IGNORECASE)
ELONGATION_RE = re.compile(r"(.)\1{2,}")  # same char 3+ times running ("Sureee", "Shocksss")
LAUGH_RE = re.compile(r"(?i)\b(?:ha){2,}\b|\b(?:he){2,}\b|\b(?:hi){2,}\b")
FORMAL_CLOSER_RE = re.compile(
    r"(?i)salamat po!?\s*$|thank you for your (understanding|help|time)|sincerely|best regards"
)
EXAMPLES_PER_BUCKET_PER_CONTACT = 60


def sh(args):
    out = subprocess.run(args, capture_output=True, text=True, timeout=90)
    if out.returncode != 0:
        raise RuntimeError(f"command failed: {' '.join(args)}\n{out.stderr.strip()}")
    return out.stdout


def wacli_json(args):
    return json.loads(sh(["wacli", "--read-only", *args, "--json"]))


def list_chats(include_groups):
    data = wacli_json(["chats", "list", "--limit", "500"])
    chats = data["data"]
    if not include_groups:
        chats = [c for c in chats if c["kind"] == "dm"]
    return chats


def fetch_messages(jid, after_ts=None, limit=3000):
    args = ["messages", "list", "--chat", jid, "--from-me", "--asc", "--limit", str(limit)]
    if after_ts:
        args += ["--after", after_ts]
    return wacli_json(args)["data"]["messages"]


def classify(text):
    if EM_DASH_RE.search(text):
        return "red", ["em dash present"]
    po_hits = len(PO_RE.findall(text))
    if po_hits >= 2:
        return "red", [f"stacked po/opo ({po_hits}x)"]
    if len(text) > 400 and FORMAL_CLOSER_RE.search(text):
        return "red", ["long message + formal closer"]
    green_hits = []
    if ELONGATION_RE.search(text):
        green_hits.append("letter elongation")
    if LAUGH_RE.search(text):
        green_hits.append("haha/hehe/hihi filler")
    if len(text) <= 80:
        green_hits.append("short/bursty")
    if text[:1].islower():
        green_hits.append("lowercase-start")
    if green_hits:
        return "green", green_hits
    return "neutral", ["no strong signal either way"]


def slugify(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "unknown"


def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {"contacts": {}, "updated_at": None}


def load_contact_context():
    """Hand-maintained per-contact facts (repo, preferred address, standing corrections).
    Missing file or missing entry is normal, not an error — most contacts won't have one."""
    if CONTEXT_FILE.exists():
        try:
            return json.loads(CONTEXT_FILE.read_text())
        except json.JSONDecodeError as e:
            print(f"  [warn] {CONTEXT_FILE} is not valid JSON, ignoring: {e}", file=sys.stderr)
    return {}


def save_state(state):
    PROFILE_DIR.mkdir(exist_ok=True)
    state["updated_at"] = datetime.now(timezone.utc).isoformat()
    STATE_FILE.write_text(json.dumps(state, indent=2, ensure_ascii=False))


def scrape(contacts_filter, full, include_groups):
    state = load_state()
    chats = list_chats(include_groups)
    if contacts_filter:
        needles = [c.strip().lower() for c in contacts_filter.split(",") if c.strip()]
        chats = [c for c in chats if any(n in c["name"].lower() for n in needles)]

    deltas = {}  # slug -> new messages pulled *this run*, for the inventory report

    for chat in chats:
        jid, name = chat["jid"], chat["name"]
        slug = slugify(name)
        rec = state["contacts"].setdefault(
            slug,
            {
                "jid": jid,
                "name": name,
                "last_ts": None,
                "counts": {"green": 0, "red": 0, "neutral": 0},
                "examples": {"green": [], "red": [], "neutral": []},
            },
        )
        after = None if full else rec["last_ts"]
        try:
            msgs = fetch_messages(jid, after_ts=after)
        except Exception as e:
            print(f"  [skip] {name}: {e}", file=sys.stderr)
            continue
        if not msgs:
            continue

        if full:
            rec["counts"] = {"green": 0, "red": 0, "neutral": 0}
            rec["examples"] = {"green": [], "red": [], "neutral": []}

        new_count = 0
        for m in msgs:
            text = (m.get("Text") or "").strip() or (m.get("MediaCaption") or "").strip()
            if not text:
                continue
            verdict, reasons = classify(text)
            rec["counts"][verdict] += 1
            ex_list = rec["examples"][verdict]
            ex_list.append(
                {"text": text[:300], "ts": m["Timestamp"], "reasons": reasons, "msg_id": m["MsgID"]}
            )
            if len(ex_list) > EXAMPLES_PER_BUCKET_PER_CONTACT:
                del ex_list[: len(ex_list) - EXAMPLES_PER_BUCKET_PER_CONTACT]
            rec["last_ts"] = m["Timestamp"]
            new_count += 1

        deltas[slug] = new_count
        c = rec["counts"]
        print(
            f"  {name}: +{new_count} new  "
            f"(cumulative green={c['green']} red={c['red']} neutral={c['neutral']})"
        )

    save_state(state)
    return state, deltas


def render_examples(entries, limit):
    entries = sorted(entries, key=lambda e: e["ts"], reverse=True)[:limit]
    if not entries:
        return "_none_"
    lines = []
    for e in entries:
        reasons = ", ".join(e["reasons"])
        lines.append(f"- `{e['ts']}` — {e['text']!r}  _(signals: {reasons})_")
    return "\n".join(lines)


def render_contact_file(slug, rec, contexts):
    c = rec["counts"]
    lines = [
        f"# wacli voice profile — {rec['name']} (auto-generated by wacli_voice_engine.py)",
        "",
        f"jid: `{rec['jid']}`  |  green {c['green']} / red {c['red']} / neutral {c['neutral']}  "
        f"|  last message seen: {rec['last_ts']}",
        "",
    ]

    ctx = contexts.get(slug)
    if ctx:
        lines += ["## Context (hand-maintained — read `contact-context.json` to edit, this section is regenerated from it, not the other way around)", ""]
        if ctx.get("preferred_address"):
            never = ctx.get("never_address_as") or []
            never_str = f" — NEVER as: {', '.join(never)}" if never else ""
            lines.append(f"- **Address as:** {ctx['preferred_address']}{never_str}")
        if ctx.get("repo"):
            lines.append(f"- **Repo/project:** `{ctx['repo']}`" + (f" — {ctx['project']}" if ctx.get("project") else ""))
        if ctx.get("relationship"):
            lines.append(f"- **Relationship:** {ctx['relationship']}")
        if ctx.get("notes"):
            lines.append(f"- **Notes:** {ctx['notes']}")
        lines.append("")
    else:
        lines += [
            "## Context",
            "_No entry in `contact-context.json` yet — repo/project and preferred-address unknown. "
            "Add one before drafting anything non-trivial to this contact rather than guessing._",
            "",
        ]

    lines += [
        "## Genuine examples (green-flagged — safe to use as style evidence)",
        "",
        render_examples(rec["examples"]["green"], 30),
    ]
    if c["red"]:
        lines += [
            "",
            f"## ⚠ {c['red']} message(s) from this contact quarantined — see `_quarantine.md`",
            "Do not use this contact's history as a style source without checking which messages",
            "were quarantined and why; a high red count means this thread likely contains prior",
            "AI-drafted-and-approved sends.",
        ]
    (PROFILE_DIR / f"{slug}.md").write_text("\n".join(lines) + "\n")


def render(state):
    PROFILE_DIR.mkdir(exist_ok=True)
    contexts = load_contact_context()
    total = {"green": 0, "red": 0, "neutral": 0}
    contact_rows = []
    all_green, all_red, all_neutral = [], [], []

    for slug, rec in sorted(state["contacts"].items(), key=lambda kv: kv[1]["name"].lower()):
        c = rec["counts"]
        for k in total:
            total[k] += c[k]
        has_ctx = "✓" if slug in contexts else "—"
        contact_rows.append(f"| {rec['name']} | {c['green']} | {c['red']} | {c['neutral']} | {has_ctx} |")
        render_contact_file(slug, rec, contexts)
        all_green += [{**e, "contact": rec["name"]} for e in rec["examples"]["green"]]
        all_red += [{**e, "contact": rec["name"]} for e in rec["examples"]["red"]]
        all_neutral += [{**e, "contact": rec["name"]} for e in rec["examples"]["neutral"]]

    def render_cross(entries, limit):
        entries = sorted(entries, key=lambda e: e["ts"], reverse=True)[:limit]
        if not entries:
            return "_none_"
        return "\n".join(
            f"- `{e['ts']}` ({e['contact']}) — {e['text']!r}  _(signals: {', '.join(e['reasons'])})_"
            for e in entries
        )

    baseline_md = f"""# wacli voice profile — baseline (auto-generated, do not hand-edit)

Regenerated by `skills/wacli-msg/scripts/wacli_voice_engine.py` from `voice-profile/state.json`
— the state file is the source of truth. To change classification behavior, edit the rules in
the engine script and re-run; don't hand-edit this file, it gets overwritten.

Last updated: {state['updated_at']}

## Totals across all tracked contacts

| Bucket | Count | Meaning |
|---|---:|---|
| green | {total['green']} | Usable as style evidence |
| red | {total['red']} | Quarantined — likely a prior AI-drafted-and-approved send |
| neutral | {total['neutral']} | Ambiguous, held for manual review, not auto-used |

## Per-contact breakdown

Context = has an entry in `contact-context.json` (repo/project, preferred address). A `—`
means don't guess — check with the operator before drafting anything non-trivial to that
contact, same discipline as the voice data itself.

| Contact | green | red | neutral | Context |
|---|---:|---:|---:|:---:|
{chr(10).join(contact_rows)}

## Hard rules (apply regardless of what any contact's data shows)

- No em dash. Ever.
- No deep/formal Tagalog, no stacked "po"/"opo". Konyo/La Salle-register Taglish is the target.

## Most recent green examples, cross-contact (capped 40)

{render_cross(all_green, 40)}
"""
    (PROFILE_DIR / "baseline.md").write_text(baseline_md)

    quarantine_md = f"""# wacli voice profile — quarantine log (auto-generated, do not hand-edit)

Last updated: {state['updated_at']}

Messages flagged **red** (em dash / stacked po-opo / long-formal-closer — likely a prior
AI-drafted-and-approved send, not genuinely typed) or **neutral** (no strong signal either way).
Neither bucket is used as style evidence by the skill. Review periodically — if a "red" entry
turns out to actually be genuine, that's a false positive in the classifier; note it and
loosen the corresponding rule in the engine script.

## Red-flagged (quarantined, capped 80)

{render_cross(all_red, 80)}

## Neutral (unclassified, capped 40 — candidates for manual promotion to green)

{render_cross(all_neutral, 40)}
"""
    (PROFILE_DIR / "_quarantine.md").write_text(quarantine_md)

    print(f"\nrendered: baseline.md, _quarantine.md, {len(state['contacts'])} per-contact files")
    print(f"totals — green {total['green']} / red {total['red']} / neutral {total['neutral']}")


def write_inventory_csv(state, deltas):
    """Full tabular snapshot, one row per contact — the artifact that gets sent to Telegram
    after every run so nothing about what got scraped is invisible/unverifiable."""
    import csv

    rows = sorted(state["contacts"].items(), key=lambda kv: kv[1]["name"].lower())
    csv_path = PROFILE_DIR / "inventory.csv"
    with csv_path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["contact", "jid", "new_this_run", "green", "red", "neutral", "total", "last_message_seen"])
        for slug, rec in rows:
            c = rec["counts"]
            total_c = c["green"] + c["red"] + c["neutral"]
            w.writerow(
                [rec["name"], rec["jid"], deltas.get(slug, 0), c["green"], c["red"], c["neutral"],
                 total_c, rec["last_ts"]]
            )
    return csv_path


def notify_telegram(state, deltas, csv_path):
    """Send the full inventory (as a file) plus a short top-line summary (as the caption) to
    the operator's own Telegram, every run — not just when something changed, per explicit
    instruction. Never let a notify failure fail the whole run."""
    total = {"green": 0, "red": 0, "neutral": 0}
    for rec in state["contacts"].values():
        for k in total:
            total[k] += rec["counts"][k]

    changed = sorted(
        ((slug, n) for slug, n in deltas.items() if n > 0),
        key=lambda kv: kv[1],
        reverse=True,
    )
    n_new = sum(n for _, n in changed)
    n_contacts_changed = len(changed)
    top_movers = ", ".join(
        f"{state['contacts'][slug]['name']} (+{n})" for slug, n in changed[:5]
    ) or "none"

    caption = (
        f"wacli-msg autolearn — {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}\n"
        f"New messages this run: {n_new} across {n_contacts_changed} contact(s)\n"
        f"Cumulative — green {total['green']} / red {total['red']} / neutral {total['neutral']} "
        f"across {len(state['contacts'])} contacts\n"
        f"Top movers: {top_movers}\n"
        f"Full per-contact table attached."
    )

    tg_script = Path.home() / ".claude" / "scripts" / "tg_send.py"
    if not tg_script.exists():
        print(f"  [notify skipped] {tg_script} not found", file=sys.stderr)
        return
    try:
        subprocess.run(
            [sys.executable, str(tg_script), "--file", str(csv_path), "--caption", caption],
            check=True, capture_output=True, text=True, timeout=60,
        )
        print("  notified: sent inventory.csv to Telegram")
    except Exception as e:
        print(f"  [notify failed] {e}", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--full", action="store_true", help="ignore checkpoints, full re-scrape")
    ap.add_argument("--contacts", default=None, help="comma-separated name substrings to filter to")
    ap.add_argument("--include-groups", action="store_true", help="also scrape group chats")
    ap.add_argument("--render-only", action="store_true", help="skip scraping, just re-render .md from state.json")
    ap.add_argument("--no-notify", action="store_true", help="skip sending the inventory to Telegram")
    args = ap.parse_args()

    if args.render_only:
        state, deltas = load_state(), {}
    else:
        state, deltas = scrape(args.contacts, args.full, args.include_groups)

    render(state)

    if not args.render_only:
        csv_path = write_inventory_csv(state, deltas)
        print(f"inventory: {csv_path}")
        if not args.no_notify:
            notify_telegram(state, deltas, csv_path)


if __name__ == "__main__":
    main()
