#!/usr/bin/env python3
"""Painter -> threshold -> AutoTrace centreline -> rounded SVG curves.

Adapted from scripts/build_map_art.py in the earlier NC500 map experiment:
https://ampcode.com/threads/T-01a0cf92-411b-744f-a5e3-fc8ebf343d9a
Requires ImageMagick 7 and AutoTrace fca2c54a2dbd0518fd78595d8d7bc20326fd9094.
See README.md for build instructions and the Painter source/crop provenance.
The castle paths are traced, not hand-drawn or edited point by point.
"""

import argparse
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def build(autotrace, error, output):
    with tempfile.TemporaryDirectory() as tmp:
        raster = Path(tmp) / "input.png"
        traced = Path(tmp) / "traced.svg"
        subprocess.run([
            "magick", str(ROOT / "assets/art/nc500-castle-source.png"),
            "-resize", "1200x", "-threshold", "65%", f"PNG24:{raster}",
        ], check=True)
        subprocess.run([
            autotrace, str(raster), "-centerline", "-background-color", "FFFFFF",
            "-error-threshold", str(error), "-filter-iterations", "6",
            "-despeckle-level", "2", "-output-file", str(traced),
        ], check=True)
        svg = ET.parse(traced).getroot()
        paths = [node.attrib["d"] for node in svg if node.tag.endswith("path")]
        # Preserve the fitted geometry and topology, rounding coordinates only.
        paths = [re.sub(
            r"-?\d+(?:\.\d+)?",
            lambda m: f"{float(m[0]):.1f}".removesuffix(".0"), d,
        ) for d in paths]
        drawing = "".join(f'<path d="{d}"/>' for d in paths)
        result = (
            '<svg xmlns="http://www.w3.org/2000/svg" '
            f'viewBox="0 0 {svg.attrib["width"]} {svg.attrib["height"]}" '
            'fill="none" stroke="currentColor" stroke-width="8" '
            'stroke-linecap="round" stroke-linejoin="round">'
            f'{drawing}</svg>\n'
        )
        output.write_text(result)
        print(f"{output}: {len(result.encode())} bytes, "
              f"{len(re.findall('[Cc]', drawing))} curves")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--autotrace", default="autotrace")
    parser.add_argument("--error-threshold", type=int, choices=[2, 6], default=2)
    parser.add_argument("--output", type=Path,
                        default=ROOT / "priv/static/images/nc500-castle.svg")
    args = parser.parse_args()
    build(args.autotrace, args.error_threshold, args.output)
