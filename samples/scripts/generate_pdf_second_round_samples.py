#!/usr/bin/env python3
"""Generate deterministic PDF second-round evidence samples.

This script intentionally keeps generation tiny and explicit:
- one URI-link PDF with a single visible link annotation
- one simple table-like PDF built from aligned text blocks
- checked-in aliases copied from existing PDF fixtures where useful

It does not depend on third-party Python PDF libraries.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MAIN_DIR = ROOT / "samples" / "main_process" / "pdf"
MAIN_EXPECTED_DIR = ROOT / "samples" / "main_process" / "expected" / "pdf"
META_DIR = ROOT / "samples" / "metadata" / "pdf"
META_EXPECTED_DIR = ROOT / "samples" / "metadata" / "expected" / "pdf"
BENCH_DIR = ROOT / "samples" / "benchmark" / "pdf"


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def pdf_escape_text(text: str) -> str:
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def make_text_stream(items: list[tuple[int, int, str]]) -> bytes:
    parts: list[str] = []
    for x, y, text in items:
        parts.append(
            f"BT /F1 12 Tf 1 0 0 1 {x} {y} Tm ({pdf_escape_text(text)}) Tj ET"
        )
    return "\n".join(parts).encode("ascii")


def build_pdf(pages: list[dict[str, object]], output: Path) -> None:
    objects: list[bytes] = []

    def add_object(body: bytes) -> int:
      objects.append(body)
      return len(objects)

    font_num = add_object(
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    )

    page_numbers: list[int] = []
    for page in pages:
        stream = make_text_stream(page["text_items"])  # type: ignore[arg-type]
        content_num = add_object(
            b"<< /Length " + str(len(stream)).encode("ascii") + b" >>\nstream\n"
            + stream + b"\nendstream",
        )

        annot_nums: list[int] = []
        for annot in page.get("annotations", []):  # type: ignore[assignment]
            uri = pdf_escape_text(str(annot["uri"]))
            rect = annot["rect"]  # type: ignore[index]
            rect_str = " ".join(str(v) for v in rect)
            annot_body = (
                "<< /Type /Annot /Subtype /Link "
                f"/Rect [{rect_str}] /Border [0 0 0] "
                f"/A << /S /URI /URI ({uri}) >> >>"
            ).encode("ascii")
            annot_nums.append(add_object(annot_body))

        annots_part = ""
        if annot_nums:
            annots_part = " /Annots [" + " ".join(f"{n} 0 R" for n in annot_nums) + "]"

        page_body = (
            "<< /Type /Page /Parent {PAGES} 0 R "
            "/MediaBox [0 0 612 792] "
            f"/Resources << /Font << /F1 {font_num} 0 R >> >> "
            f"/Contents {content_num} 0 R"
            f"{annots_part} >>"
        ).encode("ascii")
        page_numbers.append(add_object(page_body))

    pages_num = add_object(
        (
            "<< /Type /Pages /Kids ["
            + " ".join(f"{n} 0 R" for n in page_numbers)
            + f"] /Count {len(page_numbers)} >>"
        ).encode("ascii"),
    )

    # Fill parent pointer placeholders after the /Pages object exists.
    for idx in page_numbers:
        objects[idx - 1] = objects[idx - 1].replace(b"{PAGES}", str(pages_num).encode("ascii"))

    catalog_num = add_object(
        f"<< /Type /Catalog /Pages {pages_num} 0 R >>".encode("ascii"),
    )

    assert catalog_num == len(objects)

    out = bytearray()
    out.extend(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for i, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out.extend(f"{i} 0 obj\n".encode("ascii"))
        out.extend(body)
        out.extend(b"\nendobj\n")

    xref_pos = len(out)
    out.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    out.extend(b"0000000000 65535 f \n")
    for off in offsets[1:]:
        out.extend(f"{off:010d} 00000 n \n".encode("ascii"))
    out.extend(
        (
            "trailer\n"
            f"<< /Size {len(objects) + 1} /Root {catalog_num} 0 R >>\n"
            f"startxref\n{xref_pos}\n%%EOF\n"
        ).encode("ascii"),
    )

    ensure_parent(output)
    output.write_bytes(bytes(out))


def copy_file(src: Path, dst: Path) -> None:
    ensure_parent(dst)
    dst.write_bytes(src.read_bytes())


def write_generated_samples() -> None:
    # Main-process evidence samples.
    build_pdf(
        [
            {
                "text_items": [
                    (50, 700, "Visit the example website for details."),
                ],
                "annotations": [
                    {
                        "rect": [49, 688, 308, 706],
                        "uri": "https://example.com",
                    }
                ],
            }
        ],
        MAIN_DIR / "pdf_uri_link_basic.pdf",
    )

    build_pdf(
        [
            {
                "text_items": [
                    (40, 710, "Product"),
                    (180, 710, "Region"),
                    (300, 710, "Status"),
                    (40, 688, "Alpha"),
                    (180, 688, "East"),
                    (300, 688, "Open"),
                    (40, 666, "Beta"),
                    (180, 666, "West"),
                    (300, 666, "Closed"),
                ],
            }
        ],
        MAIN_DIR / "pdf_simple_table_like.pdf",
    )

    # Copy the existing caption-like PDF into the main-process corpus.
    copy_file(
        META_DIR / "pdf_image_single_caption_like.pdf",
        MAIN_DIR / "pdf_image_caption_like.pdf",
    )

    # Metadata benchmark samples used to close sidecar / provenance evidence.
    copy_file(
        MAIN_DIR / "heading_basic.pdf",
        META_DIR / "pdf_metadata_text_structure.pdf",
    )
    copy_file(
        MAIN_DIR / "pdf_repeated_header_footer.pdf",
        META_DIR / "pdf_metadata_noise_merge.pdf",
    )
    copy_file(
        MAIN_DIR / "pdf_uri_link_basic.pdf",
        META_DIR / "pdf_metadata_uri_link.pdf",
    )
    copy_file(
        MAIN_DIR / "pdf_simple_table_like.pdf",
        META_DIR / "pdf_metadata_table_like.pdf",
    )
    copy_file(
        META_DIR / "pdf_image_single_caption_like.pdf",
        META_DIR / "pdf_metadata_image_caption.pdf",
    )

    # Benchmark corpus copies for native text-PDF performance rows.
    copy_file(
        MAIN_DIR / "heading_basic.pdf",
        BENCH_DIR / "pdf_metadata_text_structure.pdf",
    )
    copy_file(
        MAIN_DIR / "pdf_repeated_header_footer.pdf",
        BENCH_DIR / "pdf_metadata_noise_merge.pdf",
    )
    copy_file(
        MAIN_DIR / "pdf_uri_link_basic.pdf",
        BENCH_DIR / "pdf_metadata_uri_link.pdf",
    )
    copy_file(
        MAIN_DIR / "pdf_simple_table_like.pdf",
        BENCH_DIR / "pdf_metadata_table_like.pdf",
    )
    copy_file(
        META_DIR / "pdf_image_single_caption_like.pdf",
        BENCH_DIR / "pdf_metadata_image_caption.pdf",
    )


if __name__ == "__main__":
    write_generated_samples()
