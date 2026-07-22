#!/usr/bin/env python3
"""Keep an add-on ``.trivyignore.yaml`` current without manual work.

Two modes:

``--bump-expiry`` (default)
    Rewrite only the ``expired_at`` dates so the time-boxed exceptions never
    lapse. No image scan, so it is cheap enough to run on a schedule.

``--from-scan FILE``
    Regenerate the whole file from a Trivy JSON report: drop entries whose
    finding is gone, keep the ones still present, and set a fresh expiry.

Exit status is 0 whether or not anything changed; ``--check`` makes it exit 2
when a change was written (useful to gate a follow-up step).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXPIRY_LINE = re.compile(r"^(?P<prefix>\s*expired_at:\s*)\d{4}-\d{2}-\d{2}\s*$")
NAME_LINE = re.compile(r"^name:\s*(.+?)\s*$", re.MULTILINE)


def addon_name(slug: str) -> str:
    config = (ROOT / slug / "config.yaml").read_text(encoding="utf-8")
    match = NAME_LINE.search(config)
    return match.group(1).strip('"') if match else slug


def statement_for(slug: str) -> str:
    return (
        "Temporary upstream image dependency pending a newer "
        f"{addon_name(slug)} image."
    )


def soonest_expiry(path: Path) -> date | None:
    dates = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = EXPIRY_LINE.match(line)
        if match:
            dates.append(date.fromisoformat(line.split(":", 1)[1].strip()))
    return min(dates) if dates else None


def bump_expiry(path: Path, expiry: str) -> bool:
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    changed = False
    for index, line in enumerate(lines):
        match = EXPIRY_LINE.match(line.rstrip("\n"))
        if not match:
            continue
        replacement = f"{match.group('prefix')}{expiry}\n"
        if replacement != line:
            lines[index] = replacement
            changed = True
    if changed:
        path.write_text("".join(lines), encoding="utf-8")
    return changed


def render(slug: str, scan: Path, expiry: str) -> str:
    report = json.loads(scan.read_text(encoding="utf-8"))
    paths_by_id: dict[str, set[str]] = {}
    for result in report.get("Results") or []:
        for vuln in result.get("Vulnerabilities") or []:
            entry = paths_by_id.setdefault(vuln["VulnerabilityID"], set())
            pkg_path = vuln.get("PkgPath")
            if pkg_path:
                entry.add(pkg_path)

    entries = sorted(
        ((vid, sorted(paths)) for vid, paths in paths_by_id.items()),
        key=lambda item: (item[1][0] if item[1] else "", item[0]),
    )
    if not entries:
        return "---\nvulnerabilities: []\n"

    statement = statement_for(slug)
    lines = ["---", "vulnerabilities:"]
    for vid, paths in entries:
        lines.append(f"  - id: {vid}")
        if paths:
            lines.append(f"    paths: [{', '.join(paths)}]")
        lines.append(f"    statement: {statement}")
        lines.append(f"    expired_at: {expiry}")
    return "\n".join(lines) + "\n"


def from_scan(path: Path, slug: str, scan: Path, expiry: str) -> bool:
    content = render(slug, scan, expiry)
    if path.exists() and path.read_text(encoding="utf-8") == content:
        return False
    path.write_text(content, encoding="utf-8")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("slug", help="add-on directory name")
    parser.add_argument("--from-scan", type=Path, help="Trivy JSON report")
    parser.add_argument("--days", type=int, default=28, help="days until expiry")
    parser.add_argument(
        "--min-remaining",
        type=int,
        default=10,
        help="bump only when the soonest expiry is this many days away or less",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="exit 2 when the file changed",
    )
    args = parser.parse_args()

    path = ROOT / args.slug / ".trivyignore.yaml"
    if not path.exists():
        print(f"error: {path} not found", file=sys.stderr)
        return 1
    expiry = (date.today() + timedelta(days=args.days)).isoformat()

    if args.from_scan:
        changed = from_scan(path, args.slug, args.from_scan, expiry)
    else:
        soonest = soonest_expiry(path)
        if soonest is None or (soonest - date.today()).days > args.min_remaining:
            print(f"unchanged (not near expiry): {path.relative_to(ROOT)}")
            return 0
        changed = bump_expiry(path, expiry)

    print(f"{'changed' if changed else 'unchanged'}: {path.relative_to(ROOT)}")
    return 2 if (changed and args.check) else 0


if __name__ == "__main__":
    raise SystemExit(main())
