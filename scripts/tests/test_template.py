"""Core acceptance scenarios for people creating apps from this template."""

import base64
import contextlib
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def command(root, *args):
    return subprocess.run(args, cwd=root, text=True, capture_output=True, check=False)


@contextlib.contextmanager
def template_copy():
    with tempfile.TemporaryDirectory(prefix="swiftseed-acceptance-") as directory:
        root = Path(directory)
        paths = (
            subprocess.check_output(
                ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT
            )
            .decode()
            .split("\0")
        )
        for name in filter(None, paths):
            source = ROOT / name
            if source.is_file():
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        (root / ".build").mkdir()
        (root / ".build/tools").symlink_to(ROOT / ".build/tools", target_is_directory=True)
        for args in [
            ("git", "init", "-q"),
            ("git", "config", "user.name", "Template acceptance"),
            ("git", "config", "user.email", "acceptance@example.invalid"),
        ]:
            result = command(root, *args)
            assert result.returncode == 0, result.stderr
        yield root


def commit(root):
    for args in [("git", "add", "."), ("git", "commit", "-qm", "Acceptance fixture")]:
        result = command(root, *args)
        assert result.returncode == 0, result.stderr


class TemplateAcceptance(unittest.TestCase):
    def test_given_template_with_artwork_when_initialized_then_new_app_keeps_artwork(self):
        # Given: a clean template with a real binary asset.
        with template_copy() as root:
            artwork = base64.b64decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jH1sAAAAASUVORK5CYII="
            )
            asset = root / "SwiftSeed/Artwork.png"
            asset.write_bytes(artwork)
            binary_plist = plistlib.dumps({"example": "SwiftSeed"}, fmt=plistlib.FMT_BINARY)
            (root / "SwiftSeed/Example.plist").write_bytes(binary_plist)
            commit(root)
            # When: the developer initializes a new app.
            result = command(
                root,
                "./dev",
                "init",
                "--name",
                "SampleApp",
                "--bundle-id",
                "com.example.sampleapp",
            )
            # Then: the generated app has the new identity and unchanged artwork.
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((root / "SampleApp/Artwork.png").read_bytes(), artwork)
            self.assertEqual((root / "SampleApp/Example.plist").read_bytes(), binary_plist)
            self.assertTrue((root / "SampleApp.xcodeproj/project.pbxproj").is_file())
            self.assertIn("com.example.sampleapp", (root / "project.yml").read_text())
            commit(root)
            checked = command(root, "./dev", "check", "project")
            self.assertEqual(checked.returncode, 0, checked.stdout + checked.stderr)

    def test_given_uncommitted_generated_scheme_when_checked_then_delivery_is_blocked(self):
        # Given: a committed configuration change without its new generated scheme.
        with template_copy() as root:
            project = root / "project.yml"
            project.write_text(
                project.read_text() + "\n  Extra:\n    build:\n      targets:\n        SwiftSeed: all\n"
            )
            commit(root)
            generated = command(root, "python3", "scripts/tools.py", "run", "xcodegen", "generate")
            self.assertEqual(generated.returncode, 0, generated.stderr)
            # When: the developer runs the project consistency gate.
            result = command(root, "./dev", "check", "project")
            # Then: an omitted generated file cannot pass delivery checks.
            self.assertNotEqual(result.returncode, 0, "Missing generated scheme incorrectly passed")
            self.assertIn("Extra.xcscheme", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
