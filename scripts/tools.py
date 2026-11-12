#!/usr/bin/env python3
"""Install and invoke pinned, verified tools on local Macs and Linux CI."""

import hashlib
import json
import os
import platform
import re
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = json.loads((ROOT / "tools.lock.json").read_text())
PLATFORM = f"{sys.platform}-{'arm64' if platform.machine() in ('arm64', 'aarch64') else platform.machine()}"


def artifact(name):
    try:
        return TOOLS[name]["artifacts"][PLATFORM]
    except KeyError as error:
        raise RuntimeError(f"{name} is not supported on {PLATFORM}.") from error


def binary_path(name):
    return ROOT / ".build/tools" / name / TOOLS[name]["version"] / artifact(name)["binary"]


def verify(name):
    binary = binary_path(name)
    if not binary.is_file():
        raise RuntimeError(f"Missing {name}; run ./dev setup {TOOLS[name]['group']} first.")
    output = subprocess.check_output([str(binary), TOOLS[name]["version_argument"]], text=True)
    if not re.search(r"\b" + re.escape(TOOLS[name]["version"]) + r"\b", output):
        raise RuntimeError("Tool version mismatch: " + name)
    return binary


def install(name):
    release = artifact(name)
    # Only extract the required standalone executable, never arbitrary archive paths or links.
    with tempfile.TemporaryDirectory() as directory:
        archive = Path(directory) / "download"
        subprocess.run(
            [
                "curl",
                "--fail",
                "--location",
                "--retry",
                "3",
                "--silent",
                "--show-error",
                release["url"],
                "--output",
                str(archive),
            ],
            check=True,
        )
        if hashlib.sha256(archive.read_bytes()).hexdigest() != release["sha256"]:
            raise RuntimeError("Download verification failed: " + name)
        if release["url"].endswith(".zip"):
            with zipfile.ZipFile(archive) as package:
                content = package.read(release["binary"])
        else:
            with tarfile.open(archive, "r:gz") as package:
                member = package.getmember(release["binary"])
                if not member.isfile():
                    raise RuntimeError("Expected a regular executable: " + name)
                with package.extractfile(member) as executable:
                    content = executable.read()
        binary = binary_path(name)
        binary.parent.mkdir(parents=True, exist_ok=True)
        temporary = binary.with_suffix(".installing")
        temporary.write_bytes(content)
        temporary.chmod(0o755)
        temporary.replace(binary)
        verify(name)
        print(f"{name} {TOOLS[name]['version']} verified and installed.")


def main():
    os.chdir(ROOT)
    args = sys.argv[1:]
    if len(args) >= 2 and args[0] == "run" and args[1] in TOOLS:
        subprocess.run([str(verify(args[1])), *args[2:]], check=True)
        return
    if args and args[0] in ("install", "check") and len(args) <= 2:
        group = args[1] if len(args) == 2 else "all"
        if group not in ("all", "apple", "portable", "security"):
            raise RuntimeError("Unknown tool group: " + group)
        names = [name for name, tool in TOOLS.items() if group == "all" or tool["group"] == group]
        for name in names:
            artifact(name)  # Reject unsupported groups before installing anything.
        for name in names:
            if args[0] == "install":
                install(name)
            else:
                verify(name)
                print(f"{name} {TOOLS[name]['version']} OK")
        return
    raise RuntimeError("Usage: tools.py install|check [all|apple|portable|security] | run TOOL [ARGS]")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print("error: " + str(error), file=sys.stderr)
        sys.exit(1)
