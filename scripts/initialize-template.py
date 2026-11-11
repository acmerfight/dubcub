#!/usr/bin/env python3
"""Rename a clean template checkout; keep Git history and remotes intact."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True, help="例如 MyApp")
    parser.add_argument("--bundle-id", required=True, help="例如 com.example.myapp")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]{1,49}", args.name):
        parser.error("名称须以大写字母开头，仅含字母和数字，长度 2–50。")
    if not re.fullmatch(r"[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*){2,}", args.bundle_id):
        parser.error("Bundle ID 须为至少三段的小写字母或数字，以字母开头。")
    status = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT)
    if status:
        parser.error("工作区必须干净，请先提交或自行保存现有改动。")
    subprocess.run(["python3", "scripts/tools.py", "check"], cwd=ROOT, check=True)
    paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    changes = []
    for name in filter(None, paths):
        source = ROOT / name
        target = ROOT / name.replace("SwiftSeed", args.name)
        if source.is_symlink():
            parser.error("初始化不处理符号链接：" + name)
        content = source.read_text()
        updated = content if name == "TEMPLATE.md" else content.replace(
            "com.acmerfight.swiftseed", args.bundle_id
        ).replace("SwiftSeed", args.name)
        if target != source and target.exists():
            parser.error("目标路径已存在：" + str(target))
        if target != source or updated != content:
            changes.append((source, target, updated, source.stat().st_mode))
    for source, target, content, mode in changes:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        target.chmod(mode)
        if source != target:
            source.unlink()
    subprocess.run(["python3", "scripts/tools.py", "run", "xcodegen", "generate"], cwd=ROOT, check=True)
    print("已初始化。检查 git diff，更新 README 仓库链接和产品介绍，再运行检查与编译。")


if __name__ == "__main__":
    main()
