"""Tests for the README badge generator."""

import base64
import struct
import unittest
import zlib

from scripts.generate_addon_badges import (
    BRAND_COLORS,
    PILL_HEIGHT,
    PILL_WIDTH,
    build_badge_svg,
    estimate_text_width,
    logo_geometry,
    png_dimensions,
)


def make_png(width: int, height: int) -> bytes:
    """Build a minimal valid RGB PNG with stdlib only."""
    raw_row = b"\x00" + b"\x40\x80\xc0" * width
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    idat = zlib.compress(raw_row * height)

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )


class BadgeGeneratorTest(unittest.TestCase):
    def test_png_dimensions_reads_ihdr(self) -> None:
        self.assertEqual(png_dimensions(make_png(7, 3)), (7, 3))

    def test_png_dimensions_rejects_non_png(self) -> None:
        with self.assertRaises(ValueError):
            png_dimensions(b"not a png")

    def test_logo_geometry_fits_tall_logo(self) -> None:
        width, height = logo_geometry(0.5)
        self.assertEqual((width, height), (11.0, 22.0))

    def test_logo_geometry_clamps_wide_logo(self) -> None:
        width, height = logo_geometry(4.0)
        self.assertEqual((width, height), (44.0, 11.0))

    def test_every_registered_addon_has_brand_color(self) -> None:
        expected = {
            "authentik",
            "bonds",
            "gluetun",
            "hindsight",
            "n8n",
            "stirling-pdf",
            "traefik-proxy",
            "tududi",
        }
        self.assertEqual(set(BRAND_COLORS), expected)

    def test_badge_svg_is_fixed_size_and_embeds_logo(self) -> None:
        svg = build_badge_svg("Hindsight", "#4F46E5", make_png(10, 10))
        self.assertIn(f'width="{PILL_WIDTH}"', svg)
        self.assertIn(f'height="{PILL_HEIGHT}"', svg)
        self.assertIn("data:image/png;base64,", svg)
        self.assertIn(">Hindsight</text>", svg)
        self.assertIn('fill="#4F46E5"', svg)

    def test_badge_svg_escapes_name(self) -> None:
        svg = build_badge_svg("A<B>", "#000000", make_png(4, 4))
        self.assertIn("A&lt;B&gt;", svg)
        self.assertNotIn("A<B>", svg)

    def test_badge_svg_chip_defaults_to_white(self) -> None:
        svg = build_badge_svg("Hindsight", "#4F46E5", make_png(4, 4))
        self.assertIn('rx="8" fill="#ffffff"', svg)

    def test_badge_svg_chip_color_is_overridable(self) -> None:
        svg = build_badge_svg(
            "Hindsight", "#4F46E5", make_png(4, 4), chip_color="#1E1B4B"
        )
        self.assertIn('rx="8" fill="#1E1B4B"', svg)
        self.assertNotIn('rx="8" fill="#ffffff"', svg)

    def test_text_estimate_grows_with_length(self) -> None:
        self.assertLess(estimate_text_width("n8n"), estimate_text_width("Traefik Proxy"))


if __name__ == "__main__":
    unittest.main()
