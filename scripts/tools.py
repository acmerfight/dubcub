#!/usr/bin/env python3
"""Install and invoke the same verified macOS tools locally and in CI."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
TOOLS = json.loads((ROOT / "tools.lock.json").read_text())


def binary_path(name):
    tool = TOOLS[name]
    return ROOT / ".build/tools" / name / tool["version"] / tool["binary"]


def verify(name):
    binary = binary_path(name)
    if not binary.is_file():
        raise RuntimeError("Missing tool; run python3 scripts/tools.py install first: " + name)
    version = subprocess.check_output(
        [str(binary), TOOLS[name]["version_argument"]], text=True
    ).strip().split()[-1]
    if version != TOOLS[name]["version"]:
        raise RuntimeError("Tool version mismatch: " + name)
    return binary


def install():
    for name, tool in TOOLS.items():
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "download.zip"
            subprocess.run([
                "curl", "--fail", "--location", "--retry", "3", "--silent", "--show-error",
                tool["url"], "--output", str(archive)
            ], check=True)
            if hashlib.sha256(archive.read_bytes()).hexdigest() != tool["sha256"]:
                raise RuntimeError("Download verification failed: " + name)
            destination = ROOT / ".build/tools" / name / tool["version"]
            with zipfile.ZipFile(archive) as package:
                for member in package.namelist():
                    target = (destination / member).resolve()
                    if destination.resolve() not in target.parents:
                        raise RuntimeError("Artifact path escapes the destination: " + name)
                package.extractall(destination)
            binary_path(name).chmod(0o755)
            verify(name)
            print(name + " " + tool["version"] + " verified and installed.")


def main():
    if sys.platform != "darwin":
        raise RuntimeError("These development tools require macOS.")
    os.chdir(ROOT)
    arguments = sys.argv[1:]
    if arguments == ["install"]:
        install()
    elif arguments == ["check"]:
        for name in TOOLS:
            verify(name)
            print(name + " " + TOOLS[name]["version"] + " OK")
    elif len(arguments) >= 2 and arguments[0] == "run" and arguments[1] in TOOLS:
        name = arguments[1]
        subprocess.run([str(verify(name)), *arguments[2:]], check=True)
    else:
        raise RuntimeError("Usage: tools.py install | check | run <tool> [arguments...]")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print("error: " + str(error), file=sys.stderr)
        sys.exit(1)
