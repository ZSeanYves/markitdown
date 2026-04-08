#!/usr/bin/env python3
"""Generate caption-like / note-cluster PPTX samples locally.

Note: this script is local tooling and is not invoked in CI.

Dependencies:
  pip install python-pptx
"""

import argparse
from pathlib import Path
import sys

try:
    from pptx import Presentation
    from pptx.util import Pt
except ModuleNotFoundError:  # pragma: no cover - env-dependent
    Presentation = None
    Pt = None

ROOT = Path(__file__).resolve().parents[1]
EMU = int


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def add_textbox(
    slide,
    left: EMU,
    top: EMU,
    width: EMU,
    height: EMU,
    text: str,
    font_size: int = 20,
):
    tb = slide.shapes.add_textbox(left, top, width, height)
    tf = tb.text_frame
    tf.clear()
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(font_size)
    return tb


def add_title(slide, text: str) -> None:
    add_textbox(
        slide,
        left=700000,
        top=180000,
        width=7800000,
        height=500000,
        text=text,
        font_size=32,
    )


def build_pptx_callout_blocks_basic(output_dir: Path) -> str:
    prs = Presentation()
    slide = prs.slides.add_slide(prs.slide_layouts[6])

    add_title(slide, "Release Notes")

    callouts = [
        (850000, 1550000, "Security", "Secure by default"),
        (3400000, 1700000, "Sharing", "Team access controls"),
        (5950000, 1500000, "Export", "Markdown and PDF output"),
    ]

    for left, top, heading, description in callouts:
        add_textbox(
            slide,
            left=left,
            top=top,
            width=2250000,
            height=360000,
            text=heading,
            font_size=23,
        )
        add_textbox(
            slide,
            left=left,
            top=top + 390000,
            width=2350000,
            height=360000,
            text=description,
            font_size=18,
        )

    filename = "pptx_callout_blocks_basic.pptx"
    prs.save(output_dir / filename)
    return filename


def build_pptx_two_note_clusters(output_dir: Path) -> str:
    prs = Presentation()
    slide = prs.slides.add_slide(prs.slide_layouts[6])

    add_title(slide, "Observations")

    add_textbox(
        slide,
        left=900000,
        top=1300000,
        width=1800000,
        height=340000,
        text="Latency",
        font_size=22,
    )
    add_textbox(
        slide,
        left=900000,
        top=1670000,
        width=3000000,
        height=370000,
        text="Improved after cache warm-up.",
        font_size=17,
    )

    add_textbox(
        slide,
        left=5600000,
        top=3150000,
        width=1850000,
        height=340000,
        text="Coverage",
        font_size=22,
    )
    add_textbox(
        slide,
        left=5600000,
        top=3520000,
        width=2600000,
        height=370000,
        text="Best on English queries.",
        font_size=17,
    )

    filename = "pptx_two_note_clusters.pptx"
    prs.save(output_dir / filename)
    return filename


def build_pptx_caption_scatter_one_real_pair(output_dir: Path) -> str:
    prs = Presentation()
    slide = prs.slides.add_slide(prs.slide_layouts[6])

    add_title(slide, "Labels")

    labels = [
        (1050000, 1350000, "Search"),
        (4900000, 1450000, "Ranking"),
        (2400000, 2450000, "Safety"),
        (6000000, 2500000, "Vision"),
        (6150000, 2860000, "Fast setup"),
        (1350000, 3450000, "Internal only"),
    ]

    for left, top, text in labels:
        add_textbox(
            slide,
            left=left,
            top=top,
            width=1750000,
            height=340000,
            text=text,
            font_size=20,
        )

    filename = "pptx_caption_scatter_one_real_pair.pptx"
    prs.save(output_dir / filename)
    return filename


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate PPTX caption-like / note-cluster regression samples.",
    )
    parser.add_argument(
        "output_dir",
        help="Directory to write generated .pptx files (example: samples/pptx).",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    if Presentation is None or Pt is None:
        print("Missing dependency: python-pptx. Install with: pip install python-pptx")
        sys.exit(1)

    out_dir = Path(args.output_dir)
    if not out_dir.is_absolute():
        out_dir = (ROOT / out_dir).resolve()

    ensure_dir(out_dir)

    generated = [
        build_pptx_callout_blocks_basic(out_dir),
        build_pptx_two_note_clusters(out_dir),
        build_pptx_caption_scatter_one_real_pair(out_dir),
    ]

    for name in generated:
        print(f"Generated: {name}")
