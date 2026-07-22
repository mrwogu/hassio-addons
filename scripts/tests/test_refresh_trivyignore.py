from __future__ import annotations

import json
import sys
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import refresh_trivyignore as refresh  # noqa: E402


class RefreshTrivyignoreTest(unittest.TestCase):
    def _file(self, text: str) -> Path:
        path = Path(tempfile.mkdtemp()) / ".trivyignore.yaml"
        path.write_text(text, encoding="utf-8")
        return path

    def test_bump_expiry_updates_and_is_idempotent(self):
        path = self._file(
            "---\nvulnerabilities:\n"
            "  - id: CVE-2026-1\n    paths: [x]\n"
            "    statement: s\n    expired_at: 2026-01-01\n"
        )
        self.assertTrue(refresh.bump_expiry(path, "2026-12-31"))
        self.assertIn("expired_at: 2026-12-31", path.read_text(encoding="utf-8"))
        self.assertFalse(refresh.bump_expiry(path, "2026-12-31"))

    def test_soonest_expiry(self):
        path = self._file(
            "---\nvulnerabilities:\n"
            "  - id: CVE-2026-1\n    expired_at: 2026-09-01\n"
            "  - id: CVE-2026-2\n    expired_at: 2026-08-15\n"
        )
        self.assertEqual(refresh.soonest_expiry(path), date(2026, 8, 15))
        self.assertIsNone(refresh.soonest_expiry(self._file("---\nvulnerabilities: []\n")))

    def test_render_groups_paths_keeps_ghsa_and_handles_empty(self):
        scan = Path(tempfile.mkdtemp()) / "scan.json"
        scan.write_text(
            json.dumps(
                {
                    "Results": [
                        {
                            "Vulnerabilities": [
                                {"VulnerabilityID": "CVE-2026-9", "PkgPath": "app/a.jar"},
                                {"VulnerabilityID": "CVE-2026-9", "PkgPath": "app/b.jar"},
                                {"VulnerabilityID": "GHSA-aaaa-bbbb-cccc", "PkgPath": None},
                            ]
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        out = refresh.render("stirling-pdf", scan, "2026-12-31")
        self.assertEqual(out.count("- id:"), 2)
        self.assertIn("paths: [app/a.jar, app/b.jar]", out)
        self.assertIn("  - id: GHSA-aaaa-bbbb-cccc", out)
        self.assertIn("expired_at: 2026-12-31", out)

        empty = Path(tempfile.mkdtemp()) / "scan.json"
        empty.write_text('{"Results": []}', encoding="utf-8")
        self.assertEqual(
            refresh.render("stirling-pdf", empty, "2026-12-31"),
            "---\nvulnerabilities: []\n",
        )


if __name__ == "__main__":
    unittest.main()
