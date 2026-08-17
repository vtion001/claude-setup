#!/usr/bin/env python3
"""Verify an orchestrator SKILL.md: valid frontmatter (name matches folder,
description present) and every expected member skill name actually appears
in the routing table. Exit 0 = pass, 1 = fail with reasons printed."""
import sys
import re
import pathlib


def main():
    if len(sys.argv) < 3:
        print("usage: verify_orchestrator.py <path/to/SKILL.md> <member1,member2,...>")
        sys.exit(2)

    path = pathlib.Path(sys.argv[1])
    expected_members = [m for m in sys.argv[2].split(",") if m]

    if not path.exists():
        print(f"FAIL: {path} does not exist")
        sys.exit(1)

    text = path.read_text()
    errors = []

    fm_match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not fm_match:
        errors.append("no valid YAML frontmatter block found (--- ... ---)")
        body = text
    else:
        fm = fm_match.group(1)
        folder_name = path.parent.name
        name_match = re.search(r"^name:\s*(\S+)", fm, re.M)
        if not name_match:
            errors.append("frontmatter missing 'name:' field")
        elif name_match.group(1) != folder_name:
            errors.append(
                f"frontmatter name '{name_match.group(1)}' does not match "
                f"folder name '{folder_name}'"
            )
        if not re.search(r"^description:", fm, re.M):
            errors.append("frontmatter missing 'description:' field")
        body = text[fm_match.end():]

    missing = [m for m in expected_members if f"`{m}`" not in body]
    if missing:
        errors.append(f"routing table missing these members: {', '.join(missing)}")

    if errors:
        print(f"FAIL: {path}")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)

    print(f"PASS: {path} — frontmatter valid, all {len(expected_members)} members present")
    sys.exit(0)


if __name__ == "__main__":
    main()
