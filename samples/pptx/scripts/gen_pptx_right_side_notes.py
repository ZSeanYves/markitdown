#!/usr/bin/env python3
"""Generate samples/pptx/pptx_right_side_notes.pptx.

Dependency: python-pptx
"""

from pathlib import Path

from pptx import Presentation
from pptx.util import Inches, Pt

OUT_PATH = Path(__file__).resolve().parents[1] / "pptx_right_side_notes.pptx"


def add_textbox(slide, left, top, width, height, text, font_size=24, bold=False):
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

    # Main content area (left side).
    add_textbox(
        slide,
        Inches(0.8),
        Inches(0.6),
        Inches(6.6),
        Inches(1.0),
        "Architecture",
        font_size=34,
        bold=True,
    )
    add_textbox(
        slide,
        Inches(0.8),
        Inches(2.1),
        Inches(6.0),
        Inches(1.0),
        "Main flow",
        font_size=26,
    )

    # Right-side note-like cluster.
    notes = slide.shapes.add_textbox(Inches(8.0), Inches(1.9), Inches(2.1), Inches(3.0))
    tf = notes.text_frame
    tf.clear()

    p0 = tf.paragraphs[0]
    p0.text = "Note A"
    p0.font.size = Pt(18)

    p1 = tf.add_paragraph()
    p1.text = "Note B"
    p1.font.size = Pt(18)

    prs.save(OUT_PATH)
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
