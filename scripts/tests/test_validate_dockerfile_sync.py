from __future__ import annotations

import unittest

from scripts.validate_dockerfile_sync import validate_changed_files


class DockerfileSyncValidationTest(unittest.TestCase):
    addons = {
        "n8n": {
            "image": "ghcr.io/mrwogu/hassio-n8n",
            "dockerfile": "n8n/Dockerfile",
            "test_script": "n8n/tests/run.sh",
        }
    }

    def test_requires_all_metadata_for_dockerfile_change(self) -> None:
        errors = validate_changed_files(
            self.addons,
            ["n8n/Dockerfile", "n8n/config.yaml"],
        )

        self.assertEqual(
            errors,
            [
                "n8n/Dockerfile: Dockerfile changes require synchronized metadata: "
                "n8n/upstream.yaml, n8n/CHANGELOG.md"
            ],
        )

    def test_accepts_synchronized_dockerfile_change(self) -> None:
        errors = validate_changed_files(
            self.addons,
            [
                "n8n/Dockerfile",
                "n8n/config.yaml",
                "n8n/upstream.yaml",
                "n8n/CHANGELOG.md",
            ],
        )

        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
