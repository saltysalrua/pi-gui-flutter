"""Build the Windows ICO directly from the bundled SVG, or check for drift.

Setup: python -m pip install -r tool/icon_requirements.txt
Usage: python tool/generate_app_icon.py [--check]
"""

from __future__ import annotations

import argparse
import struct
from importlib import import_module
from pathlib import Path

try:
    # Optional development tool, installed in the icon-generation environment.
    resvg_py = import_module("resvg_py")
except ImportError as error:
    raise SystemExit(
        "Install icon tools first: python -m pip install -r tool/icon_requirements.txt"
    ) from error

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/images/pi_logo_dark.svg"
TARGET = ROOT / "windows/runner/resources/app_icon.ico"
SIZES = (16, 20, 24, 32, 40, 48, 64, 128, 256)


def build_icon() -> bytes:
    """ICO directory + independently rasterized PNG frames (Windows Vista+)."""
    svg = SOURCE.read_text(encoding="utf-8")
    frames = []
    for size in SIZES:
        png = resvg_py.svg_to_bytes(
            svg_string=svg,
            width=size,
            height=size,
            skip_system_fonts=True,
        )
        if (
            png[:8] != b"\x89PNG\r\n\x1a\n"
            or len(png) < 24
            or struct.unpack(">II", png[16:24]) != (size, size)
        ):
            raise ValueError(f"SVG renderer did not produce a {size}x{size} PNG")
        frames.append(png)

    # ICONDIR is 6 bytes; every ICONDIRENTRY is 16 bytes. A dimension of 0 = 256px.
    directory = bytearray(struct.pack("<HHH", 0, 1, len(frames)))
    offset = 6 + 16 * len(frames)
    for size, png in zip(SIZES, frames, strict=True):
        dimension = 0 if size == 256 else size
        directory.extend(
            struct.pack(
                "<BBBBHHII", dimension, dimension, 0, 0, 1, 32, len(png), offset
            )
        )
        offset += len(png)
    return bytes(directory) + b"".join(frames)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check", action="store_true", help="Fail if the ICO differs from the SVG"
    )
    args = parser.parse_args()
    icon = build_icon()
    if args.check:
        if not TARGET.exists() or TARGET.read_bytes() != icon:
            print("Icon is out of date. Run: python tool/generate_app_icon.py")
            return 1
        print("Windows icon matches the SVG source.")
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_bytes(icon)
    print(f"Generated {TARGET.relative_to(ROOT)}: {len(icon)} bytes, sizes {SIZES}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
