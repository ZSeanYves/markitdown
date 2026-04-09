#!/usr/bin/env python3
"""Generate the missing DOCX blockquote regression sample.

By default this script writes:
  - samples/docx/docx_blockquote_basic.docx
  - samples/expected/docx/docx_blockquote_basic.md

Usage:
  python tools/gen_docx_blockquote_sample.py
  python tools/gen_docx_blockquote_sample.py --docx-out /tmp/a.docx --expected-out /tmp/a.md
"""

from __future__ import annotations

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

DOCX_NAME = "docx_blockquote_basic.docx"
EXPECTED_NAME = "docx_blockquote_basic.md"
EXPECTED_CONTENT = """Intro paragraph.

> This is a quoted paragraph.

After quote.
"""

CONTENT_TYPES_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
"""

ROOT_RELS_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"""

DOCUMENT_XML = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
  xmlns:o="urn:schemas-microsoft-com:office:office"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
  xmlns:v="urn:schemas-microsoft-com:vml"
  xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:w10="urn:schemas-microsoft-com:office:word"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
  xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
  xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
  xmlns:wne="http://schemas.microsoft.com/office/2006/wordml"
  xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
  mc:Ignorable="w14 wp14">
  <w:body>
    <w:p>
      <w:r><w:t>Intro paragraph.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:pStyle w:val="Quote"/></w:pPr>
      <w:r><w:t>This is a quoted paragraph.</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>After quote.</w:t></w:r>
    </w:p>
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
      <w:cols w:space="720"/>
      <w:docGrid w:linePitch="360"/>
    </w:sectPr>
  </w:body>
</w:document>
"""


def write_docx(docx_out: Path) -> None:
    docx_out.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(docx_out, "w", ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", CONTENT_TYPES_XML)
        zf.writestr("_rels/.rels", ROOT_RELS_XML)
        zf.writestr("word/document.xml", DOCUMENT_XML)


def write_expected(expected_out: Path) -> None:
    expected_out.parent.mkdir(parents=True, exist_ok=True)
    expected_out.write_text(EXPECTED_CONTENT, encoding="utf-8")


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[1]
    default_docx = repo_root / "samples" / "docx" / DOCX_NAME
    default_expected = repo_root / "samples" / "expected" / "docx" / EXPECTED_NAME

    parser = argparse.ArgumentParser(
        description="Generate missing DOCX blockquote regression sample and its expected markdown."
    )
    parser.add_argument("--docx-out", type=Path, default=default_docx, help=f"output DOCX path (default: {default_docx})")
    parser.add_argument(
        "--expected-out",
        type=Path,
        default=default_expected,
        help=f"output expected markdown path (default: {default_expected})",
    )
    parser.add_argument(
        "--docx-only",
        action="store_true",
        help="only generate DOCX input sample (skip expected markdown)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    write_docx(args.docx_out)
    print(f"[ok] wrote docx sample: {args.docx_out}")

    if not args.docx_only:
        write_expected(args.expected_out)
        print(f"[ok] wrote expected markdown: {args.expected_out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
