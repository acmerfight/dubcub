#!/usr/bin/env python3
"""Only explicitly known prose changes may omit simulator execution."""
import subprocess
import sys


def requires_tests(paths):
    return not paths or any(
        path not in {"README.md", "AGENTS.md", ".github/pull_request_template.md"}
        for path in paths
    )


if __name__ == "__main__":
    # Disable rename detection so both the old and new names are considered.
    changes = subprocess.check_output(
        ["git", "diff", "--name-only", "--no-renames", "-z", sys.argv[1], "HEAD"]
    )
    paths = [path for path in changes.decode("utf-8").split("\0") if path]
    print(f"run_tests={str(requires_tests(paths)).lower()}")
