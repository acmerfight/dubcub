#!/usr/bin/env python3
"""Rename a clean template checkout; keep Git history and remotes intact."""
import argparse
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True, help="For example, MyApp")
    parser.add_argument("--bundle-id", required=True, help="For example, com.example.myapp")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]{1,49}", args.name):
        parser.error("The name must start with an uppercase letter and contain 2–50 letters or digits.")
    if not re.fullmatch(r"[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*){2,}", args.bundle_id):
        parser.error("The Bundle ID must have at least three lowercase alphanumeric segments, each starting with a letter.")
    status = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT)
    if status:
        parser.error("The working tree must be clean; commit or save existing changes first.")
    subprocess.run(["python3", "scripts/tools.py", "check"], cwd=ROOT, check=True)
    paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    changes = []
    for name in filter(None, paths):
        source = ROOT / name
        target = ROOT / name.replace("SwiftSeed", args.name)
        if source.is_symlink():
            parser.error("Initialization does not support symbolic links: " + name)
        content = source.read_text()
        updated = content if name == "TEMPLATE.md" else content.replace(
            "com.acmerfight.swiftseed", args.bundle_id
        ).replace("SwiftSeed", args.name)
        if target != source and target.exists():
            parser.error("Target path already exists: " + str(target))
        if target != source or updated != content:
            changes.append((source, target, updated, source.stat().st_mode))
    for source, target, content, mode in changes:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)
        target.chmod(mode)
        if source != target:
            source.unlink()
    subprocess.run(["python3", "scripts/tools.py", "run", "xcodegen", "generate"], cwd=ROOT, check=True)
    print("Initialized. Review git diff, update README repository links and product copy, then run checks and builds.")


if __name__ == "__main__":
    main()
