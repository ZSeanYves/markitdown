#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path

FIXTURE_ROOT = Path(__file__).resolve().parent
NATIVE_DIR = FIXTURE_ROOT / "native"
GATE_DIR = FIXTURE_ROOT / "gate"
EXPECTED_DIR = FIXTURE_ROOT / "expected"


def b(s: str) -> bytes:
    return s.encode("utf-8")


def zpad(n: int, width: int = 10) -> str:
    return str(n).rjust(width, "0")


def write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def make_traditional_pdf(page_streams: list[str], *, title: str = "fixture") -> bytes:
    parts: list[bytes] = []
    offsets: list[int] = []
    cur = 0

    def add(s: str | bytes) -> None:
        nonlocal cur
        bs = s if isinstance(s, bytes) else b(s)
        parts.append(bs)
        cur += len(bs)

    def add_obj(src: str) -> None:
        offsets.append(cur)
        add(src)

    add("%PDF-1.4\n")
    n_pages = len(page_streams)
    first_page_obj = 3
    first_content_obj = first_page_obj + n_pages
    font_obj = first_content_obj + n_pages

    add_obj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

    kids = " ".join(f"{first_page_obj+i} 0 R" for i in range(n_pages))
    add_obj(f"2 0 obj\n<< /Type /Pages /Kids [{kids}] /Count {n_pages} >>\nendobj\n")

    for i in range(n_pages):
        page_obj = first_page_obj + i
        content_obj = first_content_obj + i
        add_obj(
            f"{page_obj} 0 obj\n"
            "<< /Type /Page\n"
            "   /Parent 2 0 R\n"
            "   /MediaBox [0 0 200 200]\n"
            f"   /Resources << /Font << /F1 {font_obj} 0 R >> >>\n"
            f"   /Contents {content_obj} 0 R\n"
            ">>\nendobj\n"
        )

    for i, s in enumerate(page_streams):
        obj = first_content_obj + i
        add_obj(
            f"{obj} 0 obj\n<< /Length {len(b(s))} >>\nstream\n{s}endstream\nendobj\n"
        )

    add_obj(
        f"{font_obj} 0 obj\n"
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>\n"
        "endobj\n"
    )

    info_obj = font_obj + 1
    add_obj(f"{info_obj} 0 obj\n<< /Title ({title}) >>\nendobj\n")

    xref = cur
    add("xref\n")
    total = info_obj
    add(f"0 {total+1}\n")
    add("0000000000 65535 f \n")
    for off in offsets:
        add(f"{zpad(off)} 00000 n \n")

    add("trailer\n")
    add(f"<< /Size {total+1} /Root 1 0 R >>\n")
    add("startxref\n")
    add(f"{xref}\n%%EOF\n")
    return b"".join(parts)


def append_be(buf: bytearray, value: int, width: int) -> None:
    for i in range(width - 1, -1, -1):
        buf.append((value >> (i * 8)) & 0xFF)


def xref_row(t: int, f1: int, f2: int) -> bytes:
    out = bytearray()
    out.append(t & 0xFF)
    append_be(out, f1, 2)
    out.append(f2 & 0xFF)
    return bytes(out)


def make_xref_stream_pdf(page_streams: list[str], *, with_index: bool = True, title: str = "xref") -> bytes:
    out = bytearray()
    offsets: list[int] = []

    def add(s: str | bytes | bytearray) -> None:
        if isinstance(s, str):
            bs = b(s)
        else:
            bs = bytes(s)
        out.extend(bs)

    def cur() -> int:
        return len(out)

    def add_obj(src: str) -> None:
        offsets.append(cur())
        add(src)

    add("%PDF-1.5\n")
    n_pages = len(page_streams)
    first_page_obj = 3
    font_obj = first_page_obj + n_pages
    first_content_obj = font_obj + 1

    add_obj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    kids = " ".join(f"{first_page_obj+i} 0 R" for i in range(n_pages))
    add_obj(f"2 0 obj\n<< /Type /Pages /Kids [{kids}] /Count {n_pages} >>\nendobj\n")

    for i in range(n_pages):
        page_obj = first_page_obj + i
        content_obj = first_content_obj + i
        add_obj(
            f"{page_obj} 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] "
            f"/Resources << /Font << /F1 {font_obj} 0 R >> >> /Contents {content_obj} 0 R >>\nendobj\n"
        )

    add_obj(f"{font_obj} 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n")

    for i, s in enumerate(page_streams):
        obj = first_content_obj + i
        add_obj(f"{obj} 0 obj\n<< /Length {len(b(s))} >>\nstream\n{s}endstream\nendobj\n")

    info_obj = first_content_obj + n_pages
    add_obj(f"{info_obj} 0 obj\n<< /Title ({title}) >>\nendobj\n")

    xref_obj = info_obj + 1
    xref_offset = cur()

    rows = bytearray()
    rows.extend(xref_row(0, 0, 0))
    for i in range(1, xref_obj + 1):
        off = xref_offset if i == xref_obj else offsets[i - 1]
        rows.extend(xref_row(1, off, 0))

    offsets.append(cur())
    index = f"/Index [0 {xref_obj+1}] " if with_index else ""
    add(
        f"{xref_obj} 0 obj\n<< /Type /XRef /Size {xref_obj+1} {index}/W [1 2 1] /Root 1 0 R /Length {len(rows)} >>\nstream\n"
    )
    add(rows)
    add("\nendstream\nendobj\n")
    add(f"startxref\n{xref_offset}\n%%EOF\n")
    return bytes(out)


def make_objstm_pdf(page_streams: list[str], *, title: str = "objstm") -> bytes:
    out = bytearray()
    offsets: list[int] = []

    def add(s: str | bytes | bytearray) -> None:
        if isinstance(s, str):
            out.extend(b(s))
        else:
            out.extend(bytes(s))

    def cur() -> int:
        return len(out)

    def add_obj(src: str) -> None:
        offsets.append(cur())
        add(src)

    add("%PDF-1.5\n")
    n_pages = len(page_streams)
    first_page_obj = 3
    page_content_start = first_page_obj + n_pages

    add_obj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    kids = " ".join(f"{first_page_obj+i} 0 R" for i in range(n_pages))
    add_obj(f"2 0 obj\n<< /Type /Pages /Kids [{kids}] /Count {n_pages} >>\nendobj\n")

    for i in range(n_pages):
        page_obj = first_page_obj + i
        content_obj = page_content_start + i
        add_obj(
            f"{page_obj} 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] "
            "/Resources << /Font << /F1 20 0 R >> >> "
            f"/Contents {content_obj} 0 R >>\nendobj\n"
        )

    for i, s in enumerate(page_streams):
        obj = page_content_start + i
        add_obj(f"{obj} 0 obj\n<< /Length {len(b(s))} >>\nstream\n{s}endstream\nendobj\n")

    info_obj = page_content_start + n_pages
    add_obj(f"{info_obj} 0 obj\n<< /Title ({title}) >>\nendobj\n")

    objstm_obj = info_obj + 1
    embedded_obj_num = 20
    embedded = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    header = f"{embedded_obj_num} 0 "
    objstm_stream = header + embedded
    add_obj(
        f"{objstm_obj} 0 obj\n<< /Type /ObjStm /N 1 /First {len(b(header))} /Length {len(b(objstm_stream))} >>\nstream\n{objstm_stream}\nendstream\nendobj\n"
    )

    xref_obj = objstm_obj + 1
    xref_offset = cur()

    rows = bytearray()
    max_obj = embedded_obj_num
    rows.extend(xref_row(0, 0, 0))
    for i in range(1, max_obj + 1):
        if i < embedded_obj_num:
            if i == xref_obj:
                rows.extend(xref_row(1, xref_offset, 0))
            elif i - 1 < len(offsets):
                rows.extend(xref_row(1, offsets[i - 1], 0))
            else:
                rows.extend(xref_row(0, 0, 0))
        else:
            rows.extend(xref_row(2, objstm_obj, 0))

    add(
        f"{xref_obj} 0 obj\n<< /Type /XRef /Size {max_obj+1} /W [1 2 1] /Index [0 {max_obj+1}] /Root 1 0 R /Length {len(rows)} >>\nstream\n"
    )
    add(rows)
    add("\nendstream\nendobj\n")
    add(f"startxref\n{xref_offset}\n%%EOF\n")
    return bytes(out)


def mk_stream(text: str) -> str:
    return f"BT\n/F1 12 Tf\n72 120 Td\n({text}) Tj\nET\n"


def main() -> None:
    fixtures_native = {
        "pdf_native_real_en_single_page": make_traditional_pdf([mk_stream("Hello native english")]),
        "pdf_native_real_tounicode_basic": make_traditional_pdf([mk_stream("Cafe ToUnicode")]),
        "pdf_native_real_normal_multipage_current_boundary": make_traditional_pdf([
            mk_stream("Page one normal"),
            mk_stream("Page two normal"),
        ]),
        "pdf_native_real_xref_stream_simple": make_xref_stream_pdf([mk_stream("Hello xref stream")]),
        "pdf_native_real_xref_stream_multipage": make_xref_stream_pdf([
            mk_stream("Xref page one"),
            mk_stream("Xref page two"),
        ]),
        "pdf_native_real_objstm_simple": make_objstm_pdf([mk_stream("Hello objstm")]),
        "pdf_native_real_objstm_multipage": make_objstm_pdf([
            mk_stream("Objstm page one"),
            mk_stream("Objstm page two"),
        ]),
        "pdf_native_real_xref_objstm_simple_text": make_objstm_pdf([mk_stream("Hello xref plus objstm")]),
        "pdf_native_real_xref_objstm_multipage": make_objstm_pdf([
            mk_stream("Xref objstm page one"),
            mk_stream("Xref objstm page two"),
        ]),
        "pdf_native_real_simple_font_fallback": make_traditional_pdf([mk_stream("Dash - fallback")]),
        "pdf_native_real_mixed_language_simple": make_traditional_pdf([mk_stream("Hello 你好 simple")]),
    }

    expected = {
        "pdf_native_real_en_single_page": "Hello native english\n",
        "pdf_native_real_tounicode_basic": "Cafe ToUnicode\n",
        "pdf_native_real_normal_multipage_current_boundary": "Page one normal\n\nPage two normal\n",
        "pdf_native_real_xref_stream_simple": "Hello xref stream\n",
        "pdf_native_real_xref_stream_multipage": "Xref page one\n\nXref page two\n",
        "pdf_native_real_objstm_simple": "Hello objstm\n",
        "pdf_native_real_objstm_multipage": "Objstm page one\n\nObjstm page two\n",
        "pdf_native_real_xref_objstm_simple_text": "Hello xref plus objstm\n",
        "pdf_native_real_xref_objstm_multipage": "Xref objstm page one\n\nXref objstm page two\n",
        "pdf_native_real_simple_font_fallback": "Dash - fallback\n",
        "pdf_native_real_mixed_language_simple": "Hello 你好 simple\n",
    }

    gate_names = [
        "gated_should_use_native_en_single_page",
        "gated_should_use_native_tounicode_basic",
        "gated_should_use_native_normal_multipage_current_boundary",
        "gated_should_use_native_xref_stream_simple",
        "gated_should_use_native_xref_stream_multipage",
        "gated_should_use_native_objstm_simple",
        "gated_should_use_native_objstm_multipage",
        "gated_should_use_native_xref_objstm_simple_text",
        "gated_should_use_native_xref_objstm_multipage",
        "gated_should_use_native_simple_font_fallback",
    ]

    gate_bytes = {
        "gated_should_use_native_en_single_page": fixtures_native["pdf_native_real_en_single_page"],
        "gated_should_use_native_tounicode_basic": fixtures_native["pdf_native_real_tounicode_basic"],
        "gated_should_use_native_normal_multipage_current_boundary": fixtures_native["pdf_native_real_normal_multipage_current_boundary"],
        "gated_should_use_native_xref_stream_simple": fixtures_native["pdf_native_real_xref_stream_simple"],
        "gated_should_use_native_xref_stream_multipage": fixtures_native["pdf_native_real_xref_stream_multipage"],
        "gated_should_use_native_objstm_simple": fixtures_native["pdf_native_real_objstm_simple"],
        "gated_should_use_native_objstm_multipage": fixtures_native["pdf_native_real_objstm_multipage"],
        "gated_should_use_native_xref_objstm_simple_text": fixtures_native["pdf_native_real_xref_objstm_simple_text"],
        "gated_should_use_native_xref_objstm_multipage": fixtures_native["pdf_native_real_xref_objstm_multipage"],
        "gated_should_use_native_simple_font_fallback": fixtures_native["pdf_native_real_simple_font_fallback"],
        "gated_should_use_external_encrypted_marker": b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R /Encrypt 9 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [] /Count 0 >>\nendobj\nxref\n0 3\n0000000000 65535 f \n0000000009 00000 n \n0000000074 00000 n \ntrailer\n<< /Size 3 /Root 1 0 R >>\nstartxref\n127\n%%EOF\n",
    }

    for name, data in fixtures_native.items():
        write(NATIVE_DIR / f"{name}.pdf", data)
    for name, text in expected.items():
        write_text(EXPECTED_DIR / f"{name}.expected.md", text)
    for name in gate_names + ["gated_should_use_external_encrypted_marker"]:
        write(GATE_DIR / f"{name}.pdf", gate_bytes[name])


if __name__ == "__main__":
    main()
