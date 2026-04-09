#!/usr/bin/env python3
"""Generate samples/pptx/pptx_table_like_negative_two_column_labels.pptx.

Dependency: python-pptx
"""

from pathlib import Path

from pptx import Presentation
from pptx.util import Inches, Pt

OUT_PATH = (
    Path(__file__).resolve().parents[1]
    / "pptx_table_like_negative_two_column_labels.pptx"
)


def add_textbox(slide, left, top, width, height, text, font_size=22, bold=False):
    box = slide.shapes.add_textbox(left, top, width, height)
    tf = box.text_frame
    tf.clear()
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(font_size)
    p.font.bold = bold


def main() -> None:
    prs = Presentation()
    slide = prs.slides.add_slide(prs.slide_layouts[6])

    add_textbox(
        slide,
        Inches(0.9),
        Inches(0.6),
        Inches(8.2),
        Inches(1.0),
        "Use Cases",
        font_size=34,
        bold=True,
    )

    # Two-column labels (negative case for table-like detection):
    # row-like alignment but no table shape/grid/borders.
    col_gap = Inches(4.8)
    row_pairs = [
        (Inches(2.0), Inches(1.00), "Sales", "Support"),
        (Inches(3.45), Inches(1.18), "Ops", "Forecasting"),
        (Inches(4.90), Inches(0.92), "Triage", "Monitoring"),
    ]

    for y, left_x, left, right in row_pairs:
        right_x = left_x + col_gap
        add_textbox(slide, left_x, y, Inches(3.0), Inches(0.8), left, font_size=24)
        add_textbox(
            slide,
            right_x,
            y,
            Inches(3.2),
            Inches(0.8),
            right,
            font_size=24,
        )

    prs.save(OUT_PATH)
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
