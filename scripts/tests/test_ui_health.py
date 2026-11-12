"""Core maintainer-visible promises of UI verification health reporting."""

import unittest
from datetime import datetime, timezone

from scripts.ui_health import assess


class UIHealthAcceptance(unittest.TestCase):
    def test_given_recent_success_when_checked_then_maintainer_sees_verification_link(self):
        run = self.run_record("2026-11-12T06:17:00Z", "success")
        self.assertIn(run["html_url"], assess({"state": "active"}, [run], "main", self.now()))

    def test_given_missing_or_failed_verification_when_checked_then_maintainer_is_alerted(self):
        # A passing run on a feature branch must not conceal stale main verification.
        recent_branch = self.run_record("2026-11-12T12:17:00Z", "success", branch="feature")
        cases = [
            ({"state": "disabled_inactivity"}, []),
            ({"state": "active"}, []),
            ({"state": "active"}, [self.run_record("2026-11-12T00:17:00Z", "success"), recent_branch]),
            ({"state": "active"}, [self.run_record("2026-11-12T06:17:00Z", "failure")]),
        ]
        for workflow, runs in cases:
            with self.subTest(workflow=workflow, runs=runs), self.assertRaises(ValueError):
                assess(workflow, runs, "main", self.now())

    @staticmethod
    def now():
        return datetime(2026, 11, 12, 13, tzinfo=timezone.utc)

    @staticmethod
    def run_record(created, conclusion, branch="main"):
        return {
            "head_branch": branch,
            "created_at": created,
            "event": "schedule",
            "status": "completed",
            "conclusion": conclusion,
            "run_attempt": 1,
            "html_url": "https://github.com/example/template/actions/runs/1",
        }


if __name__ == "__main__":
    unittest.main()
