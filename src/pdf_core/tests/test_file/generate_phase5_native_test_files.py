#!/usr/bin/env python3
"""Generate phase-5 PDF native low-level test fixtures.

This script intentionally generates deterministic tiny PDF files used by
`src/pdf_core/tests` low-level parsing validation.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass
class PdfFixture:
    name: str
    pdf_bytes: bytes
    expected_markdown: str


class PdfWriter:
    def __init__(self) -> None:
        self.objects: list[bytes] = []

    def add_object(self, payload: bytes) -> int:
        self.objects.append(payload)
        return len(self.objects)

    def build(self, root_obj_id: int) -> bytes:
        out = bytearray(b"%PDF-1.4\n")
        offsets = [0]
        for idx, obj in enumerate(self.objects, start=1):
            offsets.append(len(out))
            out.extend(f"{idx} 0 obj\n".encode("ascii"))
            out.extend(obj)
            out.extend(b"\nendobj\n")

        xref = len(out)
        out.extend(f"xref\n0 {len(self.objects) + 1}\n".encode("ascii"))
        out.extend(b"0000000000 65535 f \n")
        for off in offsets[1:]:
            out.extend(f"{off:010d} 00000 n \n".encode("ascii"))

        out.extend(
            (
                f"trailer\n<< /Size {len(self.objects) + 1} /Root {root_obj_id} 0 R >>\n"
                f"startxref\n{xref}\n%%EOF\n"
            ).encode("ascii")
        )
        return bytes(out)


# --- helpers -----------------------------------------------------------------

def _stream_obj(stream_data: bytes) -> bytes:
    return (
        f"<< /Length {len(stream_data)} >>\nstream\n".encode("ascii")
        + stream_data
        + b"\nendstream"
    )


def _ascii_single_or_multi_page_pdf(pages: list[list[str]]) -> bytes:
    """Generate simple ASCII pages using Type1 Helvetica."""
    writer = PdfWriter()

    catalog_id = writer.add_object(b"__CATALOG__")
    pages_id = writer.add_object(b"__PAGES__")
    font_id = writer.add_object(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

    page_obj_ids: list[int] = []
    for lines in pages:
        parts = ["BT", "/F1 12 Tf"]
        y = 760
        for line in lines:
            esc = line.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
            parts.append(f"1 0 0 1 56 {y} Tm")
            parts.append(f"({esc}) Tj")
            y -= 20
        parts.append("ET")
        stream = "\n".join(parts).encode("latin-1", errors="replace")
        content_id = writer.add_object(_stream_obj(stream))
        page_id = writer.add_object(
            (
                "<< /Type /Page /Parent {pages} 0 R "
                "/MediaBox [0 0 595 842] "
                "/Resources << /Font << /F1 {font} 0 R >> >> "
                "/Contents {content} 0 R >>"
            )
            .format(pages=pages_id, font=font_id, content=content_id)
            .encode("ascii")
        )
        page_obj_ids.append(page_id)

    kids = " ".join(f"{i} 0 R" for i in page_obj_ids)
    writer.objects[catalog_id - 1] = f"<< /Type /Catalog /Pages {pages_id} 0 R >>".encode("ascii")
    writer.objects[pages_id - 1] = (
        f"<< /Type /Pages /Count {len(page_obj_ids)} /Kids [{kids}] >>".encode("ascii")
    )
    return writer.build(root_obj_id=catalog_id)


def _tounicode_pdf(hex_lines: list[bytes], bfchar: list[tuple[int, str]]) -> bytes:
    """Generate single-page PDF with Type0 font + ToUnicode map."""
    writer = PdfWriter()

    catalog_id = writer.add_object(b"__CATALOG__")
    pages_id = writer.add_object(b"__PAGES__")

    cmap_lines = [
        b"/CIDInit /ProcSet findresource begin",
        b"12 dict begin",
        b"begincmap",
        b"/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> def",
        b"/CMapName /Custom-UTF16 def",
        b"/CMapType 2 def",
        b"1 begincodespacerange",
        b"<00> <FF>",
        b"endcodespacerange",
        f"{len(bfchar)} beginbfchar".encode("ascii"),
    ]
    for code, ch in bfchar:
        cmap_lines.append(f"<{code:02X}> <{ord(ch):04X}>".encode("ascii"))
    cmap_lines.extend([b"endbfchar", b"endcmap", b"CMapName currentdict /CMap defineresource pop", b"end", b"end"])
    cmap_id = writer.add_object(_stream_obj(b"\n".join(cmap_lines)))

    descendant_id = writer.add_object(
        b"<< /Type /Font /Subtype /CIDFontType2 /BaseFont /DummyCID "
        b"/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> >>"
    )
    font_id = writer.add_object(
        (
            "<< /Type /Font /Subtype /Type0 /BaseFont /DummyType0 "
            "/Encoding /Identity-H /DescendantFonts [{desc} 0 R] /ToUnicode {cmap} 0 R >>"
        )
        .format(desc=descendant_id, cmap=cmap_id)
        .encode("ascii")
    )

    parts = [b"BT", b"/F1 12 Tf"]
    y = 760
    for line in hex_lines:
        parts.append(f"1 0 0 1 56 {y} Tm".encode("ascii"))
        parts.append(b"<" + line + b"> Tj")
        y -= 20
    parts.append(b"ET")
    content_id = writer.add_object(_stream_obj(b"\n".join(parts)))

    page_id = writer.add_object(
        (
            "<< /Type /Page /Parent {pages} 0 R /MediaBox [0 0 595 842] "
            "/Resources << /Font << /F1 {font} 0 R >> >> /Contents {content} 0 R >>"
        )
        .format(pages=pages_id, font=font_id, content=content_id)
        .encode("ascii")
    )

    writer.objects[catalog_id - 1] = f"<< /Type /Catalog /Pages {pages_id} 0 R >>".encode("ascii")
    writer.objects[pages_id - 1] = f"<< /Type /Pages /Count 1 /Kids [{page_id} 0 R] >>".encode("ascii")
    return writer.build(root_obj_id=catalog_id)


def build_fixtures() -> list[PdfFixture]:
    en_text = [
        "# MarkItDown MoonBit MVP Test (Simple)",
        "First paragraph for simple PDF extraction baseline.",
        "Second paragraph in English.",
    ]
    zh_expected = "# 研究内容\n\n本项目主要研究多格式文档到 Markdown 的统一转换问题。\n"

    fixtures = [
        PdfFixture(
            name="pdf_native_real_en_single_page",
            pdf_bytes=_ascii_single_or_multi_page_pdf([en_text]),
            expected_markdown="# MarkItDown MoonBit MVP Test (Simple)\n\nFirst paragraph for simple PDF extraction baseline.\n\nSecond paragraph in English.\n",
        ),
        PdfFixture(
            name="pdf_native_real_text_multipage",
            pdf_bytes=_ascii_single_or_multi_page_pdf([["This is page one."], ["This is page two."]]),
            expected_markdown="This is page one.\n\nThis is page two.\n",
        ),
        PdfFixture(
            name="pdf_native_real_header_footer_simple",
            pdf_bytes=_ascii_single_or_multi_page_pdf(
                [
                    ["Header", "This is the first page body.", "Footer"],
                    ["Header", "This is the second page body.", "Footer"],
                ]
            ),
            expected_markdown="This is the first page body.\n\nThis is the second page body.\n",
        ),
        PdfFixture(
            name="pdf_native_real_tounicode_basic",
            pdf_bytes=_tounicode_pdf(
                [b"0102030405"],
                [(0x01, "H"), (0x02, "e"), (0x03, "l"), (0x04, "l"), (0x05, "o")],
            ),
            expected_markdown="Hello\n",
        ),
        PdfFixture(
            name="pdf_native_real_zh_single_page",
            pdf_bytes=_tounicode_pdf(
                [b"0102030405060708090A0B0C0D0E0F10"],
                [
                    (0x01, "#"),
                    (0x02, " "),
                    (0x03, "研"),
                    (0x04, "究"),
                    (0x05, "内"),
                    (0x06, "容"),
                    (0x07, "\n"),
                    (0x08, "\n"),
                    (0x09, "本"),
                    (0x0A, "项"),
                    (0x0B, "目"),
                    (0x0C, "测"),
                    (0x0D, "试"),
                    (0x0E, "中"),
                    (0x0F, "文"),
                    (0x10, "。"),
                ],
            ),
            expected_markdown=zh_expected,
        ),
    ]
    return fixtures


def main() -> None:
    out_dir = Path(__file__).resolve().parent
    fixtures = build_fixtures()
    for f in fixtures:
        pdf_path = out_dir / f"{f.name}.pdf"
        expected_path = out_dir / f"{f.name}.expected.md"
        pdf_path.write_bytes(f.pdf_bytes)
        expected_path.write_text(f.expected_markdown, encoding="utf-8")
        print(f"generated: {pdf_path.name}, {expected_path.name}")


if __name__ == "__main__":
    main()
