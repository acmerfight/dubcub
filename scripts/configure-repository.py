#!/usr/bin/env python3
"""Explicitly apply template protections to an OWNER/REPO you administer."""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def api(path, method="GET", body=None):
    command = ["gh", "api", "--method", method, path]
    if body is not None:
        command += ["--input", "-"]
    result = subprocess.run(
        command,
        input=json.dumps(body) if body is not None else None,
        text=True,
        check=True,
        capture_output=True,
    )
    return json.loads(result.stdout) if result.stdout.strip() else None


def main():
    if len(sys.argv) != 2 or not re.fullmatch(r"[\w.-]+/[\w.-]+", sys.argv[1]):
        sys.exit("Usage: python3 scripts/configure-repository.py OWNER/REPO")
    repository = sys.argv[1]
    path = "repos/" + repository
    info = api(path)
    if not info["permissions"]["admin"]:
        sys.exit("Administrator access to the target repository is required.")
    rules = json.loads((ROOT / ".github/main-ruleset.json").read_text())
    rules["conditions"]["ref_name"]["include"] = ["refs/heads/" + info["default_branch"]]
    rules["name"] = "main requires PR and passing CI"
    existing = [item for item in api(path + "/rulesets") if item["name"] == rules["name"]]
    if len(existing) > 1:
        sys.exit("Duplicate ruleset names found; review them on GitHub before replacing any ruleset.")
    api(
        path,
        "PATCH",
        {
            "allow_squash_merge": True,
            "allow_merge_commit": False,
            "allow_rebase_merge": False,
            "delete_branch_on_merge": True,
            "allow_auto_merge": True,
        },
    )
    api(
        path + "/actions/permissions",
        "PUT",
        {
            "enabled": True,
            "allowed_actions": "all",
            "sha_pinning_required": True,
        },
    )
    api(
        path + "/actions/permissions/workflow",
        "PUT",
        {
            "default_workflow_permissions": "read",
            "can_approve_pull_request_reviews": False,
        },
    )
    target = path + "/rulesets" + ("/" + str(existing[0]["id"]) if existing else "")
    result = api(target, "PUT" if existing else "POST", rules)
    api(path + "/vulnerability-alerts", "PUT")
    api(path + "/automated-security-fixes", "PUT")
    api(
        path,
        "PATCH",
        {
            "security_and_analysis": {
                "secret_scanning": {"status": "enabled"},
                "secret_scanning_push_protection": {"status": "enabled"},
            }
        },
    )
    print("Applied ruleset: " + result["_links"]["html"]["href"])
    print(
        "Review Actions permissions and the first CI run. Unsupported platform or plan settings fail explicitly; applied settings are not rolled back."
    )


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr, file=sys.stderr)
        sys.exit(error.returncode)
