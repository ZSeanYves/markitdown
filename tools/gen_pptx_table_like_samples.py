#!/usr/bin/env python3
"""Generate table-like PPTX samples for local regression.

Note: this script is optional local tooling and is not invoked in CI.
"""

from pathlib import Path

from pptx import Presentation
from pptx.util import Pt

ROOT = Path(__file__).resolve().parents[1]
SAMPLES = ROOT / "samples" / "pptx"
EXPECTED = ROOT / "samples" / "expected" / "pptx"


def add_textbox(slide, left, top, width, height, text):
    tb = slide.shapes.add_textbox(left, top, width, height)
    tf = tb.text_frame
    tf.clear()
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(20)


def build_strong_row_jitter_sample() -> None:
    prs = Presentation()
    slide = prs.slides.add_slide(prs.slide_layouts[6])

    title = slide.shapes.add_textbox(600000, 200000, 6000000, 500000)
    title_tf = title.text_frame
    title_tf.text = "Row Jitter Matrix"
    title_tf.paragraphs[0].font.size = Pt(32)

    col_x = [700000, 3200000, 5200000]
    row_y = [1200000, 2200000, 3200000]

    # keep header row stable; apply only mild jitter to lower rows
    jitter = [
        [0, 0, 0],
        [2000, -2000, 1000],
        [-1000, 1000, -2000],
    ]

    cells = [
        ["Quarter", "Revenue", "Profit"],
        ["Q1", "120", "40"],
        ["Q2", "140", "55"],
    ]

    w, h = 1800000, 500000
    for r in range(3):
        for c in range(3):
            add_textbox(
                slide,
                col_x[c],
                row_y[r] + jitter[r][c],
                w,
                h,
                cells[r][c],
            )

    out = SAMPLES / "pptx_table_like_strong_row_jitter.pptx"
    prs.save(out)

    expected = EXPECTED / "pptx_table_like_strong_row_jitter.md"
    expected.write_text(
        """## Slide 1

### Row Jitter Matrix

Quarter

Revenue

Profit

Q1

120

40

Q2

140

55
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    SAMPLES.mkdir(parents=True, exist_ok=True)
    EXPECTED.mkdir(parents=True, exist_ok=True)
    build_strong_row_jitter_sample()
    print("Generated: pptx_table_like_strong_row_jitter.pptx")
