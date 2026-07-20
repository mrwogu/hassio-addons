from __future__ import annotations

import unittest

from scripts.validate_addons import package_version_matches_upstream


class ValidateAddonsTest(unittest.TestCase):
    def test_package_version_requires_exact_upstream_prefix(self) -> None:
        self.assertTrue(package_version_matches_upstream("1.2.3-1", "v1.2.3"))
        self.assertFalse(
            package_version_matches_upstream("1.2.3-evil-1", "v1.2.3")
        )
        self.assertFalse(package_version_matches_upstream("1.2.3-0", "v1.2.3"))


if __name__ == "__main__":
    unittest.main()
