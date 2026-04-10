#!/usr/bin/env python3
"""Generate phase15 regression PDF samples used by samples/check_samples.sh.

This script intentionally avoids third-party dependencies by writing simple PDF
files directly. The generated PDFs are deterministic and lightweight.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


PAGE_WIDTH = 595  # A4-ish width in points
PAGE_HEIGHT = 842  # A4-ish height in points
FONT_SIZE = 12
LEADING = 16


@dataclass(frozen=True)
class TextLine:
    x: int
    y: int
    text: str


class PdfBuilder:
    def __init__(self, width: int = PAGE_WIDTH, height: int = PAGE_HEIGHT) -> None:
        self.width = width
        self.height = height
        self.pages: list[list[TextLine]] = []

    def add_page(self, lines: list[TextLine]) -> None:
        self.pages.append(lines)

    @staticmethod
    def _escape_pdf_text(text: str) -> str:
        return (
            text.replace("\\", "\\\\")
            .replace("(", "\\(")
            .replace(")", "\\)")
            .replace("\r", "")
        )

    def _page_stream(self, lines: list[TextLine]) -> bytes:
        parts = ["BT", f"/F1 {FONT_SIZE} Tf"]
        for line in lines:
            escaped = self._escape_pdf_text(line.text)
            parts.append(f"1 0 0 1 {line.x} {line.y} Tm")
            parts.append(f"({escaped}) Tj")
        parts.append("ET")
        content = "\n".join(parts).encode("latin-1", errors="replace")
        return content

    def build(self) -> bytes:
        objects: list[bytes] = []

        # 1: Catalog, 2: Pages, 3: Font
        objects.append(b"<< /Type /Catalog /Pages 2 0 R >>")
        objects.append(b"__PAGES_PLACEHOLDER__")
        objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

        page_object_ids: list[int] = []
        for lines in self.pages:
            stream = self._page_stream(lines)
            content_obj = (
                f"<< /Length {len(stream)} >>\nstream\n".encode("ascii")
                + stream
                + b"\nendstream"
            )
            objects.append(content_obj)
            content_id = len(objects)

            page_obj = (
                f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {self.width} {self.height}] "
                f"/Resources << /Font << /F1 3 0 R >> >> /Contents {content_id} 0 R >>"
            ).encode("ascii")
            objects.append(page_obj)
            page_object_ids.append(len(objects))

        kids = " ".join(f"{obj_id} 0 R" for obj_id in page_object_ids)
        pages_obj = (
            f"<< /Type /Pages /Count {len(page_object_ids)} /Kids [{kids}] >>"
        ).encode("ascii")
        objects[1] = pages_obj

        pdf = bytearray(b"%PDF-1.4\n")
        offsets = [0]
        for idx, obj in enumerate(objects, start=1):
            offsets.append(len(pdf))
            pdf.extend(f"{idx} 0 obj\n".encode("ascii"))
            pdf.extend(obj)
            pdf.extend(b"\nendobj\n")

        xref_pos = len(pdf)
        pdf.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
        pdf.extend(b"0000000000 65535 f \n")
        for off in offsets[1:]:
            pdf.extend(f"{off:010d} 00000 n \n".encode("ascii"))

        trailer = (
            f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
            f"startxref\n{xref_pos}\n%%EOF\n"
        ).encode("ascii")
        pdf.extend(trailer)
        return bytes(pdf)


def add_lines(start_y: int, lines: list[str], x: int = 56) -> list[TextLine]:
    y = start_y
    result: list[TextLine] = []
    for text in lines:
        result.append(TextLine(x=x, y=y, text=text))
        y -= LEADING
    return result


def write_pdf(path: Path, pages: list[list[TextLine]]) -> None:
    builder = PdfBuilder()
    for page in pages:
        builder.add_page(page)
    path.write_bytes(builder.build())


def build_cross_page_should_merge(target: Path) -> None:
    p1_lines = add_lines(
        780,
        [
            "Cross-page should merge",
            "",
            "This paragraph is intentionally broken at the end of page one and should continue",
            "without opening a new semantic block on next page because the sentence has not ended",
            "yet and still keeps flow with a lowercase starter that semantically continues",
        ],
    )
    p2_lines = add_lines(
        780,
        [
            "previous text. Final sentence ends here.",
        ],
    )
    write_pdf(target, [p1_lines, p2_lines])


def build_cross_page_should_not_merge(target: Path) -> None:
    p1 = add_lines(
        780,
        [
            "Cross-page should NOT merge",
            "",
            "This section ends cleanly here. The next page starts a new numbered topic.",
        ],
    )
    p2 = add_lines(
        780,
        [
            "page 2 new section",
            "",
            "1. New section starts here and must remain separated. This block should not",
            "be attached to previous page paragraph.",
        ],
    )
    write_pdf(target, [p1, p2])


def build_header_footer_variants(target: Path) -> None:
    pages: list[list[TextLine]] = []
    for idx in (1, 2, 3):
        page_lines: list[TextLine] = []
        # Repeated noisy header/footer variants.
        page_lines.extend(add_lines(820, ["Sample Report - Internal Use Only", f"Page {idx}"]))
        page_lines.extend(
            add_lines(
                760,
                [
                    f"Body paragraph page {idx}",
                    "",
                    "The core text should be preserved while noisy repeat lines are filtered.",
                ],
            )
        )
        page_lines.extend(add_lines(70, ["Confidential Footer - Do Not Distribute"]))
        pages.append(page_lines)
    write_pdf(target, pages)


def build_heading_false_positive(target: Path) -> None:
    page = add_lines(
        780,
        [
            "Heading false-positive negative",
            "",
            "OK",
            "",
            "ALL CAPS SENTENCE BUT ACTUALLY BODY TEXT, NOT A TITLE.",
            "",
            "1. this is a numbered sentence inside paragraph context.",
            "",
            "2) another numbered item that should not force heading level.",
            "",
            "Q4 RESULTS REMAIN STABLE ACROSS THE SAME METHOD.",
            "",
            "This is the real paragraph continuation after short/noisy lead lines.",
        ],
    )
    write_pdf(target, [page])


def build_two_column_negative(target: Path) -> None:
    lines = [
        TextLine(56, 790, "Pseudo two-column negative sample"),
        TextLine(56, 742, "LEFT-A1 This paragraph belongs to the left column only."),
        TextLine(320, 742, "RIGHT-B1 This paragraph is independent on the right side."),
        TextLine(56, 706, "LEFT-A2 It should stay before LEFT-A3 and LEFT-A4."),
        TextLine(320, 706, "RIGHT-B2 It should not merge into LEFT-A4."),
        TextLine(56, 670, "LEFT-A3 Do not stitch with RIGHT-B1 lines."),
        TextLine(320, 670, "RIGHT-B3 Keep local order inside right column."),
        TextLine(56, 634, "LEFT-A4 End of left column block."),
        TextLine(320, 634, "RIGHT-B4 End of right column block."),
    ]
    write_pdf(target, [lines])


def main() -> None:
    target_dir = Path(__file__).resolve().parent
    generators = {
        "pdf_cross_page_should_merge_phase15.pdf": build_cross_page_should_merge,
        "pdf_cross_page_should_not_merge_phase15.pdf": build_cross_page_should_not_merge,
        "pdf_header_footer_variants_phase15.pdf": build_header_footer_variants,
        "pdf_heading_false_positive_phase15.pdf": build_heading_false_positive,
        "pdf_two_column_negative_phase15.pdf": build_two_column_negative,
    }

    for filename, builder in generators.items():
        out = target_dir / filename
        builder(out)
        print(f"generated: {out.relative_to(target_dir.parent)}")


if __name__ == "__main__":
    main()
