#!/usr/bin/env python3
"""Build deterministic showcase formats from reviewed real-world sources."""

from __future__ import annotations

import csv
from email.message import EmailMessage
from email.policy import SMTP
from html import escape
import json
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZIP_STORED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parent


def write_package(path: Path, mimetype: str, entries: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(path, "w") as archive:
        for name, payload, compression in [
            ("mimetype", mimetype, ZIP_STORED),
            *[(name, value, ZIP_DEFLATED) for name, value in entries.items()],
        ]:
            info = ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = compression
            info.external_attr = 0o100644 << 16
            archive.writestr(info, payload.encode("utf-8"))


def build_vtt() -> None:
    source = (ROOT / "srt/tears-of-steel-en.srt").read_text(encoding="utf-8")
    lines = [re.sub(r"(?<=\d),(?=\d{3}(?:\s|$))", ".", line) for line in source.splitlines()]
    (ROOT / "vtt/tears-of-steel-en.vtt").write_text(
        "WEBVTT\n\n" + "\n".join(lines) + "\n", encoding="utf-8"
    )


def earthquake_rows() -> tuple[list[str], list[dict[str, str]]]:
    with (ROOT / "csv/usgs-all-day.csv").open(encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        return list(reader.fieldnames or []), list(reader)


def build_structured_data() -> None:
    fields, records = earthquake_rows()
    encoded = "".join(json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n" for row in records)
    (ROOT / "jsonl/usgs-earthquakes.jsonl").write_text(encoded, encoding="utf-8")
    (ROOT / "ndjson/usgs-earthquakes.ndjson").write_text(encoded, encoding="utf-8")
    body = ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "<earthquakes>"]
    for record in records:
        body.append("  <earthquake>")
        for field in fields:
            body.append(f"    <{field}>{escape(record[field])}</{field}>")
        body.append("  </earthquake>")
    body.append("</earthquakes>")
    (ROOT / "xml/usgs-earthquakes.xml").write_text("\n".join(body) + "\n", encoding="utf-8")


def build_eml() -> None:
    rfc = (ROOT / "txt/rfc3986.txt").read_text(encoding="utf-8")
    message = EmailMessage(policy=SMTP)
    message["From"] = "standards-review@example.invalid"
    message["To"] = "architecture-team@example.invalid"
    message["Date"] = "Mon, 03 Jul 2023 09:00:00 +0000"
    message["Subject"] = "URI architecture review: RFC 3986"
    message["Message-ID"] = "<rfc3986-review@example.invalid>"
    message.set_content(
        "Team,\n\nAttached is the complete RFC 3986 review copy. The sections on "
        "generic syntax, relative references, normalization, and security "
        "considerations are in scope for this review.\n\nRegards,\nArchitecture Team\n"
    )
    message.add_attachment(rfc, subtype="plain", filename="rfc3986.txt")
    message.set_boundary("===============markitdown-showcase-rfc3986==")
    (ROOT / "eml/rfc3986-review.eml").write_bytes(message.as_bytes())


def odf_manifest(media_type: str) -> str:
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.3">
 <manifest:file-entry manifest:full-path="/" manifest:media-type="{media_type}"/>
 <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
 <manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/>
</manifest:manifest>'''


def odf_meta(title: str, source: str) -> str:
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<office:document-meta xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:dc="http://purl.org/dc/elements/1.1/" office:version="1.3"><office:meta><dc:title>{escape(title)}</dc:title><dc:creator>markitdown showcase deterministic derivative</dc:creator><dc:source>{escape(source)}</dc:source><dc:language>en</dc:language></office:meta></office:document-meta>'''


def build_odt() -> None:
    rfc = (ROOT / "txt/rfc3986.txt").read_text(encoding="utf-8")
    paragraphs = []
    for line in rfc.splitlines():
        stripped = line.strip()
        if re.match(r"^\d+(?:\.\d+)*\.?(?:\s|$)", stripped):
            paragraphs.append(f'<text:h text:outline-level="2">{escape(stripped)}</text:h>')
        elif stripped:
            paragraphs.append(f"<text:p>{escape(stripped)}</text:p>")
        else:
            paragraphs.append("<text:p/>")
    content = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.3"><office:body><office:text>''' + "".join(paragraphs) + "</office:text></office:body></office:document-content>"
    media = "application/vnd.oasis.opendocument.text"
    write_package(ROOT / "odt/rfc3986.odt", media, {
        "META-INF/manifest.xml": odf_manifest(media),
        "meta.xml": odf_meta("RFC 3986: Uniform Resource Identifier Syntax", "https://www.rfc-editor.org/rfc/rfc3986.txt"),
        "content.xml": content,
    })


def build_ods() -> None:
    fields, records = earthquake_rows()
    def cell(value: str) -> str:
        return f'<table:table-cell office:value-type="string"><text:p>{escape(value)}</text:p></table:table-cell>'
    header = "<table:table-row>" + "".join(cell(field) for field in fields) + "</table:table-row>"
    data = "".join("<table:table-row>" + "".join(cell(row[field]) for field in fields) + "</table:table-row>" for row in records)
    summary = "".join(
        "<table:table-row>" + cell(key) + cell(value) + "</table:table-row>"
        for key, value in (("Dataset", "USGS all-day earthquakes"), ("Source", "USGS Earthquake Hazards Program"), ("Records", str(len(records))))
    )
    content = f'''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.3"><office:body><office:spreadsheet><table:table table:name="About">{summary}</table:table><table:table table:name="Earthquakes">{header}{data}</table:table></office:spreadsheet></office:body></office:document-content>'''
    media = "application/vnd.oasis.opendocument.spreadsheet"
    write_package(ROOT / "ods/usgs-earthquakes.ods", media, {
        "META-INF/manifest.xml": odf_manifest(media),
        "meta.xml": odf_meta("USGS all-day earthquake feed", "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.csv"),
        "content.xml": content,
    })


def pptx_slides() -> list[list[str]]:
    source = ROOT / "pptx/nhs-diabetes-programme.pptx"
    with ZipFile(source) as archive:
        names = sorted(
            (name for name in archive.namelist() if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)),
            key=lambda name: int(re.search(r"\d+", name).group()),
        )
        return [
            [escape(text) for text in re.findall(r"<a:t>(.*?)</a:t>", archive.read(name).decode("utf-8"), re.DOTALL)]
            for name in names
        ]


def build_odp() -> None:
    pages = []
    for index, texts in enumerate(pptx_slides(), 1):
        paragraphs = "".join(f"<text:p>{text}</text:p>" for text in texts)
        pages.append(f'<draw:page draw:name="Slide {index}"><draw:frame><draw:text-box>{paragraphs}</draw:text-box></draw:frame></draw:page>')
    content = '''<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.3"><office:body><office:presentation>''' + "".join(pages) + "</office:presentation></office:body></office:document-content>"
    media = "application/vnd.oasis.opendocument.presentation"
    write_package(ROOT / "odp/nhs-diabetes-programme.odp", media, {
        "META-INF/manifest.xml": odf_manifest(media),
        "meta.xml": odf_meta("Diabetes Prevention Programme 2017-18", "https://files.digital.nhs.uk/A6/CD0E5A/NDA_DPP_MainReport_1718_1.1.pptx"),
        "content.xml": content,
    })


def main() -> None:
    for directory in ("vtt", "jsonl", "ndjson", "xml", "eml", "odt", "ods", "odp"):
        (ROOT / directory).mkdir(parents=True, exist_ok=True)
    build_vtt()
    build_structured_data()
    build_eml()
    build_odt()
    build_ods()
    build_odp()


if __name__ == "__main__":
    main()
