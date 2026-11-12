#!/usr/bin/env python3
"""Install and invoke pinned, verified tools on local Macs and Linux CI."""

import hashlib
import json
import os
import platform
import re
import shutil
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
    if "requirements" in TOOLS[name]:
        return TOOLS[name]
    try:
        return TOOLS[name]["artifacts"][PLATFORM]
    except KeyError as error:
        raise RuntimeError(f"{name} is not supported on {PLATFORM}.") from error


def binary_path(name):
    return ROOT / ".build/tools" / name / TOOLS[name]["version"] / artifact(name)["binary"]


def verify(name):
    binary = binary_path(name)
    resources = artifact(name).get("resources", [])
    destination = ROOT / ".build/tools" / name / TOOLS[name]["version"]
    if not binary.is_file() or any(not (destination / resource).is_dir() for resource in resources):
        raise RuntimeError(f"Missing {name}; run ./dev setup {TOOLS[name]['group']} first.")
    output = subprocess.check_output([str(binary), TOOLS[name]["version_argument"]], text=True)
    if not re.search(r"\b" + re.escape(TOOLS[name]["version"]) + r"\b", output):
        raise RuntimeError("Tool version mismatch: " + name)
    return binary


def install(name):
    release = artifact(name)
    if "requirements" in release:
        expected = (ROOT / release["python_version_file"]).read_text().strip()
        current = f"{sys.version_info.major}.{sys.version_info.minor}"
        candidate = sys.executable if current == expected else shutil.which("python" + expected)
        if not candidate:
            raise RuntimeError(f"Install Python {expected} from .python-version before ./dev setup hooks.")
        actual = subprocess.check_output(
            [candidate, "-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"],
            text=True,
        ).strip()
        if actual != expected:
            raise RuntimeError(f"Expected Python {expected}, found {actual}.")
        print(f"Installing hook tools with Python {actual}: {candidate}", flush=True)
        destination = binary_path(name).parent.parent
        subprocess.run([candidate, "-m", "venv", str(destination)], check=True)
        subprocess.run(
            [
                str(destination / "bin/python"),
                "-m",
                "pip",
                "install",
                "--disable-pip-version-check",
                "--require-hashes",
                "--only-binary=:all:",
                "-r",
                str(ROOT / release["requirements"]),
            ],
            check=True,
        )
        verify(name)
        print(f"{name} {release['version']} verified and installed in an isolated environment.")
        return
    # Extract only the executable and declared support resources from a verified artifact.
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
                files = {release["binary"]: package.read(release["binary"])}
                for prefix in release.get("resources", []):
                    members = [
                        item
                        for item in package.infolist()
                        if item.filename.startswith(prefix) and not item.is_dir()
                    ]
                    if not members:
                        raise RuntimeError("Missing packaged resources: " + name)
                    files.update({item.filename: package.read(item) for item in members})
        else:
            with tarfile.open(archive, "r:gz") as package:
                member = package.getmember(release["binary"])
                if not member.isfile():
                    raise RuntimeError("Expected a regular executable: " + name)
                with package.extractfile(member) as executable:
                    files = {release["binary"]: executable.read()}
        destination = ROOT / ".build/tools" / name / TOOLS[name]["version"]
        for relative, content in files.items():
            path = Path(relative)
            if path.is_absolute() or ".." in path.parts:
                raise RuntimeError("Artifact path escapes the destination: " + name)
            target = destination / path
            target.parent.mkdir(parents=True, exist_ok=True)
            temporary = target.with_suffix(target.suffix + ".installing")
            temporary.write_bytes(content)
            if relative == release["binary"]:
                temporary.chmod(0o755)
            temporary.replace(target)
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
        if group not in ("all", "apple", "portable", "security", "hooks"):
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
    raise RuntimeError("Usage: tools.py install|check [all|apple|portable|security|hooks] | run TOOL [ARGS]")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print("error: " + str(error), file=sys.stderr)
        sys.exit(1)
