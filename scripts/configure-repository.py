#!/usr/bin/env python3
"""Explicitly apply template protections to an OWNER/REPO you administer."""
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def api(path, method="GET", body=None):
    command = ["gh", "api", "--method", method, path]
    if body is not None:
        command += ["--input", "-"]
    result = subprocess.run(command, input=json.dumps(body) if body is not None else None,
                            text=True, check=True, capture_output=True)
    return json.loads(result.stdout) if result.stdout.strip() else None


def main():
    if len(sys.argv) != 2 or not re.fullmatch(r"[\w.-]+/[\w.-]+", sys.argv[1]):
        sys.exit("用法：python3 scripts/configure-repository.py OWNER/REPO")
    repository = sys.argv[1]
    path = "repos/" + repository
    info = api(path)
    if not info["permissions"]["admin"]:
        sys.exit("需要目标仓库的管理员权限。")
    rules = json.loads((ROOT / ".github/main-ruleset.json").read_text())
    rules["conditions"]["ref_name"]["include"] = ["refs/heads/" + info["default_branch"]]
    rules["name"] = "main requires PR and passing CI"
    existing = [item for item in api(path + "/rulesets") if item["name"] == rules["name"]]
    if len(existing) > 1:
        sys.exit("存在重名规则，需先在 GitHub 上确认，不能猜测覆盖。")
    api(path, "PATCH", {
        "allow_squash_merge": True, "allow_merge_commit": False,
        "allow_rebase_merge": False, "delete_branch_on_merge": True,
        "allow_auto_merge": True,
    })
    target = path + "/rulesets" + ("/" + str(existing[0]["id"]) if existing else "")
    result = api(target, "PUT" if existing else "POST", rules)
    api(path + "/vulnerability-alerts", "PUT")
    api(path + "/automated-security-fixes", "PUT")
    api(path, "PATCH", {"security_and_analysis": {
        "secret_scanning": {"status": "enabled"},
        "secret_scanning_push_protection": {"status": "enabled"},
    }})
    print("已应用规则：" + result["_links"]["html"]["href"])
    print("请检查 Actions 权限及首次 CI。平台或套餐不支持的设置会明确失败；已成功设置的部分不会回滚。")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        print(error.stderr, file=sys.stderr)
        sys.exit(error.returncode)
