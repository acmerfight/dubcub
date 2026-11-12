#!/usr/bin/env python3
"""Compare committed generated files with a clean generation of the current inputs."""

import shutil
import subprocess
import tempfile
from pathlib import Path

from tools import ROOT, verify

PROJECT = "SwiftSeed.xcodeproj"


def main():
    names = (
        subprocess.check_output(
            [
                "git",
                "ls-files",
                "--cached",
                "--others",
                "--exclude-standard",
                "-z",
            ],
            cwd=ROOT,
        )
        .decode()
        .split("\0")
    )
    tracked = set(
        subprocess.check_output(
            [
                "git",
                "ls-files",
                "-z",
                "--",
                PROJECT,
            ],
            cwd=ROOT,
        )
        .decode()
        .split("\0")
    ) - {""}
    with tempfile.TemporaryDirectory(prefix="swiftseed-project-") as directory:
        snapshot = Path(directory)
        for name in filter(None, names):
            source = ROOT / name
            if name.startswith(PROJECT + "/") or not source.is_file():
                continue
            target = snapshot / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        subprocess.run([str(verify("xcodegen")), "generate"], cwd=snapshot, check=True)
        if not (snapshot / PROJECT / "project.pbxproj").is_file():
            raise SystemExit("Expected Xcode project was not generated: " + PROJECT)
        generated = {
            str(path.relative_to(snapshot)) for path in (snapshot / PROJECT).rglob("*") if path.is_file()
        }
        differences = tracked ^ generated
        for name in generated & tracked:
            path = ROOT / name
            if not path.is_file() or path.read_bytes() != (snapshot / name).read_bytes():
                differences.add(name)
        if differences:
            raise SystemExit(
                "Generated project is out of date or untracked. Run ./dev generate and stage "
                "the generated files:\n" + "\n".join(sorted(differences))
            )
    print("Generated project matches current inputs and all generated files are tracked.")


if __name__ == "__main__":
    main()
