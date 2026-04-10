#!/usr/bin/env python3
"""Generate phase-1.5 PDF regression candidate samples (no binary files committed).

Usage:
  python3 samples/tools/gen_phase15_pdf_samples.py
"""
from __future__ import annotations

import random
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[2]
PDF_DIR = ROOT / "samples" / "pdf"
OCR_DIR = ROOT / "samples" / "ocr_pdf"

PAGE_W = 595
PAGE_H = 842


@dataclass
class PDFObject:
    obj_id: int
    data: bytes


class MiniPDF:
    def __init__(self) -> None:
        self._objects: list[PDFObject] = []
        self._next_id = 1

    def _add_obj(self, data: bytes) -> int:
        obj_id = self._next_id
        self._next_id += 1
        self._objects.append(PDFObject(obj_id, data))
        return obj_id

    @staticmethod
    def _escape_text(s: str) -> str:
        return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

    def build_text_pdf(self, pages: list[list[tuple[int, int, int, str]]], out_path: Path) -> None:
        font_id = self._add_obj(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

        page_ids = []
        content_ids = []
        for page_lines in pages:
            chunks = [b"BT\n"]
            for x, y, size, text in page_lines:
                line = f"/F1 {size} Tf {x} {y} Td ({self._escape_text(text)}) Tj\n".encode("utf-8")
                chunks.append(line)
            chunks.append(b"ET\n")
            content = b"".join(chunks)
            stream = b"<< /Length %d >>\nstream\n%sendstream" % (len(content), content)
            content_id = self._add_obj(stream)
            content_ids.append(content_id)

            page_obj = (
                b"<< /Type /Page /Parent 0 0 R /MediaBox [0 0 595 842] "
                + f"/Resources << /Font << /F1 {font_id} 0 R >> >> /Contents {content_id} 0 R >>".encode()
            )
            page_id = self._add_obj(page_obj)
            page_ids.append(page_id)

        kids = " ".join(f"{pid} 0 R" for pid in page_ids)
        pages_id = self._add_obj(f"<< /Type /Pages /Kids [{kids}] /Count {len(page_ids)} >>".encode())

        self._patch_page_parent(page_ids, pages_id)
        catalog_id = self._add_obj(f"<< /Type /Catalog /Pages {pages_id} 0 R >>".encode())
        self._write(out_path, catalog_id)

    def build_image_pdf(self, img_w: int, img_h: int, gray: bytes, out_path: Path) -> None:
        fontless = zlib.compress(gray)
        img_id = self._add_obj(
            (
                f"<< /Type /XObject /Subtype /Image /Width {img_w} /Height {img_h} "
                f"/ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode /Length {len(fontless)} >>\n"
            ).encode()
            + b"stream\n"
            + fontless
            + b"\nendstream"
        )

        content = f"q {PAGE_W} 0 0 {PAGE_H} 0 0 cm /Im0 Do Q\n".encode()
        content_id = self._add_obj(b"<< /Length %d >>\nstream\n" % len(content) + content + b"endstream")

        page_id = self._add_obj(
            f"<< /Type /Page /Parent 0 0 R /MediaBox [0 0 {PAGE_W} {PAGE_H}] "
            f"/Resources << /XObject << /Im0 {img_id} 0 R >> >> /Contents {content_id} 0 R >>".encode()
        )
        pages_id = self._add_obj(f"<< /Type /Pages /Kids [{page_id} 0 R] /Count 1 >>".encode())
        self._patch_page_parent([page_id], pages_id)
        catalog_id = self._add_obj(f"<< /Type /Catalog /Pages {pages_id} 0 R >>".encode())
        self._write(out_path, catalog_id)

    def _patch_page_parent(self, page_ids: Iterable[int], pages_id: int) -> None:
        for i, obj in enumerate(self._objects):
            if obj.obj_id in page_ids:
                self._objects[i] = PDFObject(obj.obj_id, obj.data.replace(b"/Parent 0 0 R", f"/Parent {pages_id} 0 R".encode()))

    def _write(self, out_path: Path, catalog_id: int) -> None:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        body = bytearray(b"%PDF-1.4\n")
        offsets = [0]
        for obj in self._objects:
            offsets.append(len(body))
            body.extend(f"{obj.obj_id} 0 obj\n".encode())
            body.extend(obj.data)
            body.extend(b"\nendobj\n")

        xref_pos = len(body)
        body.extend(f"xref\n0 {len(self._objects) + 1}\n".encode())
        body.extend(b"0000000000 65535 f \n")
        for i in range(1, len(self._objects) + 1):
            body.extend(f"{offsets[i]:010d} 00000 n \n".encode())

        body.extend(
            f"trailer\n<< /Size {len(self._objects) + 1} /Root {catalog_id} 0 R >>\nstartxref\n{xref_pos}\n%%EOF\n".encode()
        )
        out_path.write_bytes(bytes(body))


def mk_lines(title: str, lines: list[str], x: int = 60, y: int = 780) -> list[tuple[int, int, int, str]]:
    out = [(x, y, 16, title)]
    yy = y - 28
    for line in lines:
        out.append((x, yy, 11, line))
        yy -= 16
    return out


def gen_two_column_negative() -> None:
    left = [
        "LEFT-A1 This paragraph belongs to the left column only.",
        "LEFT-A2 It should stay before LEFT-A3 and LEFT-A4.",
        "LEFT-A3 Do not stitch with RIGHT-B1 lines.",
        "LEFT-A4 End of left column block.",
    ]
    right = [
        "RIGHT-B1 This paragraph is independent on the right side.",
        "RIGHT-B2 It should not merge into LEFT-A4.",
        "RIGHT-B3 Keep local order inside right column.",
        "RIGHT-B4 End of right column block.",
    ]
    page: list[tuple[int, int, int, str]] = [(60, 810, 14, "Pseudo two-column negative sample")]
    y = 770
    for l, r in zip(left, right):
        page.append((55, y, 11, l))
        page.append((320, y, 11, r))
        y -= 18

    pdf = MiniPDF()
    pdf.build_text_pdf([page], PDF_DIR / "pdf_two_column_negative_phase15.pdf")


def gen_header_footer_variants() -> None:
    pages = []
    for i in range(1, 4):
        lines = [
            (70, 812, 10, f"Project Alpha 2026 - Draft v{i}"),
            (70, 798, 10, f"Section 2 | Internal Copy | page {i}"),
            (70, 760, 13, f"Body paragraph page {i}"),
            (70, 740, 11, "The core text should be preserved while noisy repeat lines are filtered."),
            (70, 86, 10, f"Confidential footer / rev-{i} / contact@example.com"),
            (70, 72, 10, f"Generated timestamp 2026-04-0{i} 10:0{i}"),
        ]
        pages.append(lines)

    pdf = MiniPDF()
    pdf.build_text_pdf(pages, PDF_DIR / "pdf_header_footer_variants_phase15.pdf")


def gen_heading_false_positive() -> None:
    lines = [
        "OK",
        "ALL CAPS SENTENCE BUT ACTUALLY BODY TEXT, NOT A TITLE.",
        "1. this is a numbered sentence inside paragraph context.",
        "2) another numbered item that should not force heading level.",
        "Q4 RESULTS REMAIN STABLE ACROSS THE SAME METHOD.",
        "This is the real paragraph continuation after short/noisy lead lines.",
    ]
    pdf = MiniPDF()
    pdf.build_text_pdf([mk_lines("Heading false-positive negative", lines)], PDF_DIR / "pdf_heading_false_positive_phase15.pdf")


def gen_cross_page_pairs() -> None:
    merge_p1 = mk_lines(
        "Cross-page should merge",
        [
            "This paragraph is intentionally broken at the end of page one and",
            "should continue without opening a new semantic block on next page",
            "because the sentence has not ended yet and still keeps flow",
        ],
    )
    merge_p2 = mk_lines(
        "(page 2 continuation)",
        [
            "with a lowercase starter that semantically continues previous text.",
            "Final sentence ends here.",
        ],
    )

    no_merge_p1 = mk_lines(
        "Cross-page should NOT merge",
        [
            "This section ends cleanly here.",
            "The next page starts a new numbered topic.",
        ],
    )
    no_merge_p2 = mk_lines(
        "(page 2 new section)",
        [
            "1. New section starts here and must remain separated.",
            "This block should not be attached to previous page paragraph.",
        ],
    )

    pdf = MiniPDF()
    pdf.build_text_pdf([merge_p1, merge_p2], PDF_DIR / "pdf_cross_page_should_merge_phase15.pdf")

    pdf2 = MiniPDF()
    pdf2.build_text_pdf([no_merge_p1, no_merge_p2], PDF_DIR / "pdf_cross_page_should_not_merge_phase15.pdf")


def draw_text_bitmap(text: str, w: int, h: int, noise: float = 0.0) -> bytes:
    # 8-bit grayscale canvas
    img = [255] * (w * h)

    def put(x: int, y: int, v: int) -> None:
        if 0 <= x < w and 0 <= y < h:
            img[y * w + x] = v

    x0, y0 = 30, 50
    for ch in text:
        if ch == "\n":
            y0 += 22
            x0 = 30
            continue
        # draw a very simple blocky glyph (enough for OCR baseline scaffolding)
        seed = ord(ch)
        for yy in range(12):
            for xx in range(8):
                bit = ((seed + xx * 3 + yy * 5) % 11) < 4
                if bit:
                    put(x0 + xx, y0 + yy, 20)
        x0 += 10

    if noise > 0:
        rnd = random.Random(42)
        n = int(w * h * noise)
        for _ in range(n):
            idx = rnd.randrange(0, w * h)
            img[idx] = rnd.randrange(0, 255)

    return bytes(img)


def gen_ocr_baselines() -> None:
    clear = draw_text_bitmap(
        "OCR CLEAR BASELINE\ninvoice 2026-04\namount 1280.55\n", 1000, 1400, noise=0.005
    )
    medium = draw_text_bitmap(
        "OCR MEDIUM BASELINE\nscan copy quality medium\npage text sample\n", 1000, 1400, noise=0.08
    )

    p1 = MiniPDF()
    p1.build_image_pdf(1000, 1400, clear, OCR_DIR / "ocr_clear_baseline_phase15.pdf")

    p2 = MiniPDF()
    p2.build_image_pdf(1000, 1400, medium, OCR_DIR / "ocr_medium_baseline_phase15.pdf")


def main() -> None:
    gen_two_column_negative()
    gen_header_footer_variants()
    gen_heading_false_positive()
    gen_cross_page_pairs()
    gen_ocr_baselines()
    print("Generated phase-1.5 PDF sample candidates into samples/pdf and samples/ocr_pdf")


if __name__ == "__main__":
    main()
