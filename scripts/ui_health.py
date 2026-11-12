#!/usr/bin/env python3
"""Fail visibly when default-branch UI verification is disabled, failing, or stale."""

import argparse
import json
import subprocess
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode


def assess(workflow, runs, branch, now):
    if workflow["state"] != "active":
        raise ValueError(
            "UI workflow is disabled; enable it and dispatch ui-tests.yml on the default branch."
        )
    completed = [
        run
        for run in runs
        if run["head_branch"] == branch
        and run["event"] in ("schedule", "workflow_dispatch")
        and run["status"] == "completed"
    ]
    if not completed:
        raise ValueError("No completed default-branch UI verification; dispatch ui-tests.yml first.")
    latest = max(completed, key=lambda run: (run["created_at"], run["run_attempt"]))
    if latest["conclusion"] != "success":
        raise ValueError("Latest completed UI verification did not pass: " + latest["html_url"])
    started = datetime.fromisoformat(latest["created_at"].replace("Z", "+00:00"))
    if now - started > timedelta(hours=8):
        raise ValueError(
            "UI verification is stale (>8 hours since the last successful run started): " + latest["html_url"]
        )
    return "Recent default-branch UI verification passed: " + latest["html_url"]


def api(path):
    return json.loads(subprocess.check_output(["gh", "api", path], text=True))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("repository", help="OWNER/REPO")
    args = parser.parse_args()
    repository = api("repos/" + args.repository)
    workflow_path = f"repos/{args.repository}/actions/workflows/ui-tests.yml"
    workflow = api(workflow_path)
    # Bound history to two days; no successful run in that window can satisfy the 8-hour limit.
    now = datetime.now(timezone.utc)
    since = (now - timedelta(days=2)).strftime("%Y-%m-%dT%H:%M:%SZ")
    query = (
        workflow_path
        + "/runs?"
        + urlencode({"branch": repository["default_branch"], "created": ">=" + since, "per_page": 100})
    )
    runs = api(query)["workflow_runs"]
    try:
        print(assess(workflow, runs, repository["default_branch"], now))
    except ValueError as error:
        raise SystemExit(str(error)) from error


if __name__ == "__main__":
    main()
