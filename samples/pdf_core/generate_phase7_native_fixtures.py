#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parent

def zpad(n, width):
    s = str(n)
    return "0" * (width - len(s)) + s

def b(s:str)->bytes:
    return s.encode('utf-8')

def build_pdf_with_font_and_contents(stream_data: str, font_dict_src: str) -> bytes:
    chunks=[]
    offsets=[]
    cur=0
    def add(bs:bytes):
        nonlocal cur
        chunks.append(bs); cur += len(bs)
    def add_obj(src:str):
        offsets.append(cur); add(b(src))

    add(b("%PDF-1.4\n"))
    add_obj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    add_obj("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    add_obj("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>\nendobj\n")
    add_obj(f"4 0 obj\n<< /Length {len(b(stream_data))} >>\nstream\n{stream_data}endstream\nendobj\n")
    add_obj(f"5 0 obj\n{font_dict_src}\nendobj\n")
    xoff=cur
    add(b("xref\n0 6\n0000000000 65535 f \n"))
    for off in offsets: add(b(f"{zpad(off,10)} 00000 n \n"))
    add(b(f"trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n{xoff}\n%%EOF\n"))
    return b"".join(chunks)

def append_be(out, value, width):
    for i in range(width-1,-1,-1): out.append((value >> (i*8)) & 0xFF)

def xref_row_bytes(t,f1,f2):
    out=[t & 0xFF]; append_be(out,f1,2); out.append(f2 & 0xFF); return out

def build_pdf_with_xref_stream(with_index=False, with_type2_entry=False, text="Hello XRefStream"):
    out=bytearray(); offsets=[]; cur=0
    def add(bs:bytes):
        nonlocal cur
        out.extend(bs); cur += len(bs)
    def add_obj(src:str):
        offsets.append(cur); add(b(src))

    add(b("%PDF-1.5\n"))
    add_obj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    add_obj("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    add_obj("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n")
    add_obj("4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n")
    stream_data=f"BT\n/F1 12 Tf\n({text}) Tj\nET\n"
    add_obj(f"5 0 obj\n<< /Length {len(b(stream_data))} >>\nstream\n{stream_data}endstream\nendobj\n")

    xref_obj_num=6
    xref_offset=cur
    rows=[]
    rows+=xref_row_bytes(0,0,0)
    rows+=xref_row_bytes(1,offsets[0],0)
    rows+=xref_row_bytes(1,offsets[1],0)
    rows+=xref_row_bytes(1,offsets[2],0)
    rows+=xref_row_bytes(1,offsets[3],0)
    if with_type2_entry:
        rows+=xref_row_bytes(2,9,3)
    else:
        rows+=xref_row_bytes(1,offsets[4],0)
    rows+=xref_row_bytes(1,xref_offset,0)

    index_part = "/Index [0 7] " if with_index else ""
    offsets.append(cur)
    add(b(f"{xref_obj_num} 0 obj\n<< /Type /XRef /Size 7 {index_part}/W [1 2 1] /Root 1 0 R /Length {len(rows)} >>\nstream\n"))
    add(bytes(rows))
    add(b("\nendstream\nendobj\n"))
    add(b(f"startxref\n{xref_offset}\n%%EOF\n"))
    return bytes(out)

def build_pdf_with_xref_stream_objstm(text="Hello ObjStm", with_index=False):
    out=bytearray(); offsets=[]; cur=0
    def add(bs:bytes):
        nonlocal cur
        out.extend(bs); cur += len(bs)
    def add_obj(src:str):
        offsets.append(cur); add(b(src))

    add(b("%PDF-1.5\n"))
    add_obj("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
    add_obj("2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n")
    add_obj("3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << /Font << /F1 5 0 R >> >> /Contents 8 0 R >>\nendobj\n")
    add_obj("4 0 obj\n<< /Producer (objstm-min) >>\nendobj\n")

    header="5 0 "
    embedded="<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    objstm_stream=header+embedded
    add_obj(f"7 0 obj\n<< /Type /ObjStm /N 1 /First {len(b(header))} /Length {len(b(objstm_stream))} >>\nstream\n{objstm_stream}\nendstream\nendobj\n")

    page_stream=f"BT\n/F1 12 Tf\n({text}) Tj\nET\n"
    add_obj(f"8 0 obj\n<< /Length {len(b(page_stream))} >>\nstream\n{page_stream}endstream\nendobj\n")

    xref_offset=cur
    rows=[]
    rows+=xref_row_bytes(0,0,0)
    rows+=xref_row_bytes(1,offsets[0],0)
    rows+=xref_row_bytes(1,offsets[1],0)
    rows+=xref_row_bytes(1,offsets[2],0)
    rows+=xref_row_bytes(1,offsets[3],0)
    rows+=xref_row_bytes(2,7,0)
    rows+=xref_row_bytes(1,xref_offset,0)
    rows+=xref_row_bytes(1,offsets[4],0)
    rows+=xref_row_bytes(1,offsets[5],0)

    index_part="/Index [0 9] " if with_index else ""
    add_obj(f"6 0 obj\n<< /Type /XRef /Size 9 /W [1 2 1] {index_part}/Root 1 0 R /Length {len(rows)} >>\nstream\n")
    add(bytes(rows))
    add(b("\nendstream\nendobj\n"))
    add(b(f"startxref\n{xref_offset}\n%%EOF\n"))
    return bytes(out)


def main():
    fixtures = {
        "pdf_native_real_xref_stream_simple.pdf": build_pdf_with_xref_stream(text="Hello XRef Gate"),
        "pdf_native_real_objstm_simple.pdf": build_pdf_with_xref_stream_objstm(text="Hello ObjStm Gate"),
        "pdf_native_real_xref_objstm_simple_text.pdf": build_pdf_with_xref_stream_objstm(text="Hello XRef ObjStm Gate", with_index=True),
        "pdf_native_real_simple_font_fallback.pdf": build_pdf_with_font_and_contents(
            "BT\n/F1 12 Tf\n<9620> Tj\nET\n",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
        ),
    }
    for name, data in fixtures.items():
        (ROOT / name).write_bytes(data)

    (ROOT / "pdf_native_real_xref_stream_simple.expected.md").write_text("Hello XRef Gate\n", encoding="utf-8")
    (ROOT / "pdf_native_real_objstm_simple.expected.md").write_text("Hello ObjStm Gate\n", encoding="utf-8")
    (ROOT / "pdf_native_real_xref_objstm_simple_text.expected.md").write_text("Hello XRef ObjStm Gate\n", encoding="utf-8")
    (ROOT / "pdf_native_real_simple_font_fallback.expected.md").write_text("– \n", encoding="utf-8")

if __name__ == "__main__":
    main()
