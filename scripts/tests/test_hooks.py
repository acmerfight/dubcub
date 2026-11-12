"""Core developer promises of the installed commit hook."""

import unittest

from test_template import command, commit, template_copy


class HookAcceptance(unittest.TestCase):
    def install(self, root):
        result = command(root, "./dev", "hooks", "install")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_given_partial_changes_when_committing_then_only_staged_content_is_checked(self):
        with template_copy() as root:
            commit(root)
            self.install(root)
            path = root / "Example with spaces.swift"
            staged = 'let greeting = "Hello"\n'
            unstaged = 'let greeting="Unfinished work"\n'
            path.write_text(staged)
            command(root, "git", "add", path.name).check_returncode()
            path.write_text(unstaged)
            result = command(root, "git", "commit", "-qm", "Valid staged change")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(path.read_text(), unstaged)
            self.assertEqual(command(root, "git", "show", "HEAD:" + path.name).stdout, staged)

    def test_given_invalid_staged_swift_when_committing_then_commit_is_blocked_without_edits(self):
        with template_copy() as root:
            commit(root)
            self.install(root)
            path = root / "Example.swift"
            staged = 'let greeting="Hello"\n'
            working = 'let greeting = "Hello"\n'
            path.write_text(staged)
            command(root, "git", "add", path.name).check_returncode()
            path.write_text(working)
            head = command(root, "git", "rev-parse", "HEAD").stdout
            result = command(root, "git", "commit", "-qm", "Invalid staged change")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Swift format", result.stdout + result.stderr)
            self.assertEqual(command(root, "git", "rev-parse", "HEAD").stdout, head)
            self.assertEqual(command(root, "git", "show", ":" + path.name).stdout, staged)
            self.assertEqual(path.read_text(), working)

    def test_given_staged_secret_when_committing_then_commit_is_blocked_and_secret_is_redacted(self):
        with template_copy() as root:
            commit(root)
            self.install(root)
            token = "ghp_" + "aB3dE6gH9jK2mN5pQ8sT1vW4yZ7cF0iL3oR6"
            (root / "credentials.txt").write_text('github_token = "' + token + '"\n')
            command(root, "git", "add", "credentials.txt").check_returncode()
            head = command(root, "git", "rev-parse", "HEAD").stdout
            result = command(root, "git", "commit", "-qm", "Synthetic secret example")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Staged secrets", result.stdout + result.stderr)
            self.assertNotIn(token, result.stdout + result.stderr)
            self.assertEqual(command(root, "git", "rev-parse", "HEAD").stdout, head)


if __name__ == "__main__":
    unittest.main()
