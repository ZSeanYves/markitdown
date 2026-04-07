#!/usr/bin/env python3
"""Generate selected PPTX table-like regression samples locally.

Note: this script is optional local tooling and is not invoked in CI.

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


def build_pptx_table_like_header_edge_basic(output_dir: Path) -> str:
    prs = Presentation()
    slide = prs.slides.add_slide(prs.slide_layouts[6])

    add_title(slide, "Header Edge Matrix")

    col_x = [900000, 3300000, 5500000]
    row_y = [1200000, 2200000, 3200000]
    cells = [
        ["Quarter", "Revenue", "Profit"],
        ["Q1", "120", "40"],
        ["Q2", "140", "55"],
    ]

    w, h = 1700000, 520000
    for r in range(3):
        for c in range(3):
            add_textbox(slide, col_x[c], row_y[r], w, h, cells[r][c], font_size=20)

    filename = "pptx_table_like_header_edge_basic.pptx"
    prs.save(output_dir / filename)
    return filename


def build_pptx_table_like_header_edge_with_note(output_dir: Path) -> str:
    prs = Presentation()
    slide = prs.slides.add_slide(prs.slide_layouts[6])

    add_title(slide, "Header Edge With Note")

    col_x = [900000, 3300000, 5500000]
    row_y = [1200000, 2200000, 3200000]
    cells = [
        ["Model", "Score", "Delta"],
        ["A", "91", "+3"],
        ["B", "88", "0"],
    ]

    w, h = 1700000, 520000
    for r in range(3):
        for c in range(3):
            add_textbox(slide, col_x[c], row_y[r], w, h, cells[r][c], font_size=20)

    # keep this near the table boundary but not aligned to existing row/col buckets
    add_textbox(
        slide,
        left=7050000,
        top=3850000,
        width=2100000,
        height=420000,
        text="Best result highlighted.",
        font_size=16,
    )

    filename = "pptx_table_like_header_edge_with_note.pptx"
    prs.save(output_dir / filename)
    return filename


def build_pptx_table_like_negative_header_cards(output_dir: Path) -> str:
    prs = Presentation()
    slide = prs.slides.add_slide(prs.slide_layouts[6])

    add_title(slide, "Capability Cards")

    header_x = [700000, 3350000, 6000000]
    detail_x = [700000, 3350000, 6000000]

    header_y = 1400000
    detail_y = 2100000

    header_w, header_h = 1850000, 460000
    detail_w, detail_h = 2350000, 820000

    headers = ["Search", "Vision", "Agents"]
    details = ["Fast retrieval", "Image parsing", "Task execution"]

    for i in range(3):
        add_textbox(
            slide,
            left=header_x[i],
            top=header_y,
            width=header_w,
            height=header_h,
            text=headers[i],
            font_size=22,
        )
        add_textbox(
            slide,
            left=detail_x[i],
            top=detail_y,
            width=detail_w,
            height=detail_h,
            text=details[i],
            font_size=20,
        )

    filename = "pptx_table_like_negative_header_cards.pptx"
    prs.save(output_dir / filename)
    return filename


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate selected PPTX table-like regression samples.",
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
        build_pptx_table_like_header_edge_basic(out_dir),
        build_pptx_table_like_header_edge_with_note(out_dir),
        build_pptx_table_like_negative_header_cards(out_dir),
    ]

    for name in generated:
        print(f"Generated: {name}")
