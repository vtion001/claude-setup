#!/usr/bin/env python3
"""Create a fully-detailed Todoist task via the API v1. Thin wrapper around
POST /api/v1/tasks — all field decisions (priority, due date, labels, etc.)
are made by the caller; this script just validates and sends them."""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

API_BASE = "https://api.todoist.com/api/v1"
TOKEN_ENV_FILE = os.path.expanduser("~/.config/todoist/.env")


def load_token():
    token = os.environ.get("TODOIST_API_TOKEN")
    if token:
        return token
    if os.path.exists(TOKEN_ENV_FILE):
        with open(TOKEN_ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line.startswith("TODOIST_API_TOKEN="):
                    return line.split("=", 1)[1]
    sys.exit(f"error: TODOIST_API_TOKEN not found in env or {TOKEN_ENV_FILE}")


def api_request(token, method, path, payload=None):
    url = f"{API_BASE}{path}"
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        sys.exit(f"error: {method} {path} -> HTTP {e.code}: {body}")


def resolve_inbox_project_id(token):
    cursor = None
    while True:
        path = "/projects" + (f"?cursor={cursor}" if cursor else "")
        result = api_request(token, "GET", path)
        for project in result.get("results", []):
            if project.get("inbox_project"):
                return project["id"]
        cursor = result.get("next_cursor")
        if not cursor:
            sys.exit("error: no Inbox project found on this account")


def resolve_or_create_section_id(token, project_id, section_name):
    """Exact case-insensitive match on an existing section; create one if none matches."""
    cursor = None
    while True:
        path = f"/sections?project_id={project_id}" + (f"&cursor={cursor}" if cursor else "")
        result = api_request(token, "GET", path)
        for section in result.get("results", []):
            if section.get("name", "").strip().lower() == section_name.strip().lower():
                return section["id"]
        cursor = result.get("next_cursor")
        if not cursor:
            break
    created = api_request(token, "POST", "/sections", {"project_id": project_id, "name": section_name})
    return created["id"]


def main():
    parser = argparse.ArgumentParser(description="Create a Todoist task with full field detail.")
    parser.add_argument("--content", required=True, help="Task title")
    parser.add_argument("--description", default=None, help="Longer detail/body for the task")
    parser.add_argument("--project-id", default=None, help="Defaults to your Inbox, resolved live")
    parser.add_argument("--section-id", default=None)
    parser.add_argument("--section-name", default=None,
                         help="Board-view segment, e.g. 'ALTO Property' — resolved/created within the target project")
    parser.add_argument("--parent-id", default=None)
    parser.add_argument("--labels", default=None, help="Comma-separated label names")
    parser.add_argument("--priority", type=int, choices=[1, 2, 3, 4], default=None,
                         help="API scale: 4=urgent(P1 in app) ... 1=none/default(P4 in app)")
    parser.add_argument("--assignee-id", default=None)
    parser.add_argument("--due-string", default=None, help='Natural language, e.g. "tomorrow 9am"')
    parser.add_argument("--due-date", default=None, help="YYYY-MM-DD")
    parser.add_argument("--due-datetime", default=None, help="ISO 8601")
    parser.add_argument("--due-lang", default=None)
    parser.add_argument("--deadline-date", default=None, help="Hard cutoff date, YYYY-MM-DD")
    parser.add_argument("--deadline-lang", default=None)
    parser.add_argument("--duration", type=int, default=None)
    parser.add_argument("--duration-unit", choices=["minute", "day"], default=None)
    args = parser.parse_args()

    token = load_token()
    project_id = args.project_id or resolve_inbox_project_id(token)

    section_id = args.section_id
    if not section_id and args.section_name:
        section_id = resolve_or_create_section_id(token, project_id, args.section_name)

    payload = {"content": args.content, "project_id": project_id}
    if args.description:
        payload["description"] = args.description
    if section_id:
        payload["section_id"] = section_id
    if args.parent_id:
        payload["parent_id"] = args.parent_id
    if args.labels:
        payload["labels"] = [label.strip() for label in args.labels.split(",") if label.strip()]
    if args.priority:
        payload["priority"] = args.priority
    if args.assignee_id:
        payload["assignee_id"] = args.assignee_id
    if args.due_string:
        payload["due_string"] = args.due_string
        if args.due_lang:
            payload["due_lang"] = args.due_lang
    elif args.due_datetime:
        payload["due_datetime"] = args.due_datetime
    elif args.due_date:
        payload["due_date"] = args.due_date
    if args.deadline_date:
        payload["deadline_date"] = args.deadline_date
        if args.deadline_lang:
            payload["deadline_lang"] = args.deadline_lang
    if args.duration:
        if not args.duration_unit:
            sys.exit("error: --duration requires --duration-unit")
        payload["duration"] = args.duration
        payload["duration_unit"] = args.duration_unit

    task = api_request(token, "POST", "/tasks", payload)
    print(json.dumps({
        "id": task["id"],
        "content": task["content"],
        "url": f"https://app.todoist.com/app/task/{task['id']}",
        "priority": task.get("priority"),
        "due": task.get("due"),
        "deadline": task.get("deadline"),
        "labels": task.get("labels"),
        "project_id": task.get("project_id"),
        "section_id": task.get("section_id"),
    }, indent=2))


if __name__ == "__main__":
    main()
