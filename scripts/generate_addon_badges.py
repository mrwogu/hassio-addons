#!/usr/bin/env python3
"""Generate repository-local badge pills for the README.

Each add-on gets a fixed-size SVG pill (220x40) embedding its logo on a
brand-colored background. Slugs come from addons.yaml so the registry stays
the single source of add-on lists. Run with --check in CI to verify the
committed SVGs match the generator output.
"""

from __future__ import annotations

import argparse
import base64
import struct
import sys
from pathlib import Path
from xml.sax.saxutils import escape

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST = REPO_ROOT / "addons.yaml"
OUTPUT_DIR = REPO_ROOT / "assets" / "badges"

PILL_WIDTH = 220
PILL_HEIGHT = 40
LOGO_BOX_HEIGHT = 22
LOGO_BOX_WIDTH = 44

# Brand accent per add-on slug; the rest of the layout is uniform.
BRAND_COLORS = {
    "authentik": "#FD4B2A",
    "bonds": "#7C3AED",
    "gluetun": "#0E7490",
    "hindsight": "#4F46E5",
    "n8n": "#EA4B71",
    "stirling-pdf": "#B91C1C",
    "traefik-proxy": "#24A1C1",
    "tududi": "#059669",
}

FONT_STACK = "-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"


def load_slugs() -> list[str]:
    with MANIFEST.open(encoding="utf-8") as handle:
        manifest = yaml.safe_load(handle)
    return sorted(manifest["addons"])


def read_addon_name(slug: str) -> str:
    config_path = REPO_ROOT / slug / "config.yaml"
    with config_path.open(encoding="utf-8") as handle:
        config = yaml.safe_load(handle)
    name = config.get("name")
    if not isinstance(name, str) or not name.strip():
        raise ValueError(f"Add-on {slug} has no usable name in config.yaml")
    return name.strip()


def png_dimensions(data: bytes) -> tuple[int, int]:
    """Read width/height from a PNG IHDR chunk without Pillow."""
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Not a PNG file")
    width, height = struct.unpack(">II", data[16:24])
    return width, height


def logo_geometry(aspect: float) -> tuple[float, float]:
    """Fit the logo aspect ratio into the badge logo box."""
    width = LOGO_BOX_HEIGHT * aspect
    if width > LOGO_BOX_WIDTH:
        width = float(LOGO_BOX_WIDTH)
        height = LOGO_BOX_WIDTH / aspect
    else:
        height = float(LOGO_BOX_HEIGHT)
    return width, height


def estimate_text_width(name: str) -> float:
    # Rough advance width for 15px semibold system sans; layout only needs an
    # approximation because the pill is fixed-size and content is centered.
    return 0.62 * 15 * len(name)


def build_badge_svg(name: str, color: str, logo_data: bytes) -> str:
    width, height = png_dimensions(logo_data)
    logo_w, logo_h = logo_geometry(width / height)

    chip_w = logo_w + 8
    chip_h = logo_h + 8
    text_w = estimate_text_width(name)
    content_w = chip_w + 8 + text_w
    start_x = (PILL_WIDTH - content_w) / 2
    chip_x = start_x
    chip_y = (PILL_HEIGHT - chip_h) / 2

    encoded = base64.b64encode(logo_data).decode("ascii")
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{PILL_WIDTH}" '
        f'height="{PILL_HEIGHT}" viewBox="0 0 {PILL_WIDTH} {PILL_HEIGHT}" '
        f'role="img" aria-label="{escape(name, {"\"": "&quot;"})}">\n'
        f"  <title>{escape(name)}</title>\n"
        f'  <rect width="{PILL_WIDTH}" height="{PILL_HEIGHT}" rx="20" '
        f'fill="{color}"/>\n'
        f'  <rect x="{chip_x:.1f}" y="{chip_y:.1f}" width="{chip_w:.1f}" '
        f'height="{chip_h:.1f}" rx="8" fill="#ffffff"/>\n'
        f'  <image x="{chip_x + 4:.1f}" y="{chip_y + 4:.1f}" '
        f'width="{logo_w:.1f}" height="{logo_h:.1f}" '
        f'preserveAspectRatio="xMidYMid meet" '
        f'href="data:image/png;base64,{encoded}"/>\n'
        f'  <text x="{chip_x + chip_w + 8:.1f}" y="20" dy=".35em" '
        f'font-family="{FONT_STACK}" font-size="15" font-weight="600" '
        f'fill="#ffffff" letter-spacing="0.3">{escape(name)}</text>\n'
        f"</svg>\n"
    )


def render_badges() -> dict[str, str]:
    badges: dict[str, str] = {}
    for slug in load_slugs():
        if slug not in BRAND_COLORS:
            raise ValueError(f"No brand color registered for add-on {slug}")
        logo_path = REPO_ROOT / slug / "logo.png"
        badges[slug] = build_badge_svg(
            read_addon_name(slug), BRAND_COLORS[slug], logo_path.read_bytes()
        )
    return badges


def write_badges(badges: dict[str, str]) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for slug, svg in badges.items():
        (OUTPUT_DIR / f"{slug}.svg").write_text(svg, encoding="utf-8")


def check_badges(badges: dict[str, str]) -> list[str]:
    stale = []
    for slug, svg in badges.items():
        path = OUTPUT_DIR / f"{slug}.svg"
        if not path.is_file() or path.read_text(encoding="utf-8") != svg:
            stale.append(slug)
    return stale


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify committed badges match generator output without writing",
    )
    args = parser.parse_args(argv)

    badges = render_badges()
    if args.check:
        stale = check_badges(badges)
        if stale:
            print(
                "Stale or missing badges: "
                + ", ".join(stale)
                + ". Re-run scripts/generate_addon_badges.py",
                file=sys.stderr,
            )
            return 1
        print(f"All {len(badges)} badges are up to date.")
        return 0

    write_badges(badges)
    print(f"Wrote {len(badges)} badges to {OUTPUT_DIR.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
