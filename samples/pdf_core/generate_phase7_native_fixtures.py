#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parent


def _append_obj(parts: list[bytes], obj_no: int, body: bytes) -> None:
    parts.append(f"{obj_no} 0 obj\n".encode("latin1"))
    parts.append(body)
    if not body.endswith(b"\n"):
        parts.append(b"\n")
    parts.append(b"endobj\n")


def _text_stream(text: bytes) -> bytes:
    return b"<< /Length %d >>\nstream\n%sendstream\n" % (len(text), text)


def _simple_text_ops(text: str) -> bytes:
    return f"BT\n/F1 12 Tf\n({text}) Tj\nET\n".encode("latin1")


def _build_xref_stream_pdf(
    objs: list[tuple[int, bytes]], root_obj: int, xref_obj: int, extra_dict: bytes = b""
) -> bytes:
    parts: list[bytes] = [b"%PDF-1.5\n"]
    offsets: dict[int, int] = {0: 0}
    for obj_no, body in objs:
        offsets[obj_no] = sum(len(x) for x in parts)
        _append_obj(parts, obj_no, body)

    offsets[xref_obj] = sum(len(x) for x in parts)
    size = max(offsets) + 1

    stream = bytearray()
    for i in range(size):
        if i == 0:
            t, f2, f3 = 0, 0, 0
        else:
            t, f2, f3 = 1, offsets[i], 0
        stream.extend(bytes([t]))
        stream.extend(f2.to_bytes(2, "big"))
        stream.extend(bytes([f3]))

    xref_dict = b"<< /Type /XRef /Size %d /W [1 2 1] /Root %d 0 R %s/Length %d >>\n" % (
        size,
        root_obj,
        extra_dict,
        len(stream),
    )
    _append_obj(parts, xref_obj, xref_dict + b"stream\n" + bytes(stream) + b"\nendstream\n")
    parts.append(b"startxref\n" + str(offsets[xref_obj]).encode("ascii") + b"\n%%EOF\n")
    return b"".join(parts)


def _build_objstm_pdf(page_texts: list[str], with_index: bool) -> bytes:
    page_count = len(page_texts)
    page_objs = list(range(3, 3 + page_count))
    content_objs = list(range(9, 9 + page_count))
    kids = " ".join(f"{x} 0 R" for x in page_objs)

    objs: list[tuple[int, bytes]] = [
        (1, b"<< /Type /Catalog /Pages 2 0 R >>\n"),
        (2, f"<< /Type /Pages /Kids [{kids}] /Count {page_count} >>\n".encode("latin1")),
        (5, b"<< /Producer (objstm-multipage) >>\n"),
    ]

    for page_obj, content_obj in zip(page_objs, content_objs):
        page = (
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 220 220] "
            f"/Resources << /Font << /F1 6 0 R >> >> /Contents {content_obj} 0 R >>\n"
        )
        objs.append((page_obj, page.encode("latin1")))

    objstm_payload = b"6 0 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    objs.append(
        (
            8,
            b"<< /Type /ObjStm /N 1 /First 4 /Length %d >>\nstream\n%s\nendstream\n"
            % (len(objstm_payload), objstm_payload),
        )
    )

    for content_obj, text in zip(content_objs, page_texts):
        objs.append((content_obj, _text_stream(_simple_text_ops(text))))

    parts: list[bytes] = [b"%PDF-1.5\n"]
    offsets: dict[int, int] = {0: 0}
    for obj_no, body in objs:
        offsets[obj_no] = sum(len(x) for x in parts)
        _append_obj(parts, obj_no, body)

    xref_obj = 7
    offsets[xref_obj] = sum(len(x) for x in parts)
    size = max(max(offsets), 6) + 1

    stream = bytearray()
    for i in range(size):
        if i == 0:
            t, f2, f3 = 0, 0, 0
        elif i == 6:
            t, f2, f3 = 2, 8, 0
        elif i in offsets:
            t, f2, f3 = 1, offsets[i], 0
        else:
            t, f2, f3 = 0, 0, 0
        stream.extend(bytes([t]))
        stream.extend(f2.to_bytes(2, "big"))
        stream.extend(bytes([f3]))

    extra = f"/Index [0 {size}] ".encode("ascii") if with_index else b""
    xref_dict = b"<< /Type /XRef /Size %d /W [1 2 1] %s/Root 1 0 R /Length %d >>\n" % (
        size,
        extra,
        len(stream),
    )
    _append_obj(parts, xref_obj, xref_dict + b"stream\n" + bytes(stream) + b"\nendstream\n")
    parts.append(b"startxref\n" + str(offsets[xref_obj]).encode("ascii") + b"\n%%EOF\n")
    return b"".join(parts)


def _write_pdf(name: str, data: bytes) -> None:
    (ROOT / f"{name}.pdf").write_bytes(data)


def generate() -> None:
    xref_multipage = _build_xref_stream_pdf(
        [
            (1, b"<< /Type /Catalog /Pages 2 0 R >>\n"),
            (2, b"<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>\n"),
            (
                3,
                b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 220 220] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>\n",
            ),
            (
                4,
                b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 220 220] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>\n",
            ),
            (5, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n"),
            (6, _text_stream(_simple_text_ops("XRef multipage page one."))),
            (7, _text_stream(_simple_text_ops("XRef multipage page two."))),
        ],
        root_obj=1,
        xref_obj=8,
    )
    _write_pdf("pdf_native_real_xref_stream_multipage", xref_multipage)

    _write_pdf(
        "pdf_native_real_objstm_multipage",
        _build_objstm_pdf(["ObjStm multipage page one.", "ObjStm multipage page two."], with_index=False),
    )
    _write_pdf(
        "pdf_native_real_xref_objstm_multipage",
        _build_objstm_pdf(
            ["XRef ObjStm multipage page one.", "XRef ObjStm multipage page two."], with_index=True
        ),
    )
    _write_pdf(
        "pdf_native_real_mixed_lang_objstm_simple",
        _build_objstm_pdf(["Native mixed EN-123 baseline."], with_index=False),
    )

    fallback_multipage = _build_xref_stream_pdf(
        [
            (1, b"<< /Type /Catalog /Pages 2 0 R >>\n"),
            (2, b"<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>\n"),
            (
                3,
                b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 220 220] /Resources << /Font << /F1 5 0 R >> >> /Contents 6 0 R >>\n",
            ),
            (
                4,
                b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 220 220] /Resources << /Font << /F1 5 0 R >> >> /Contents 7 0 R >>\n",
            ),
            (5, b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\n"),
            (6, _text_stream(b"BT\n/F1 12 Tf\n(\\226 fallback paragraph one.) Tj\nET\n")),
            (7, _text_stream(b"BT\n/F1 12 Tf\n(\\226 fallback paragraph two.) Tj\nET\n")),
        ],
        root_obj=1,
        xref_obj=8,
    )
    _write_pdf("pdf_native_real_font_fallback_multipage", fallback_multipage)

    src = ROOT / "pdf_native_real_text_multipage.pdf"
    dst = ROOT / "pdf_native_real_normal_multipage_current_boundary.pdf"
    dst.write_bytes(src.read_bytes())


if __name__ == "__main__":
    generate()
