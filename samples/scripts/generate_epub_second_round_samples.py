#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZIP_STORED, ZipFile, ZipInfo
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[2]

MAIN_DIR = ROOT / "samples" / "main_process" / "epub"
META_DIR = ROOT / "samples" / "metadata" / "epub"
BENCH_DIR = ROOT / "samples" / "benchmark" / "epub"

IMG_RED = ROOT / "samples" / "main_process" / "html" / "img" / "img_red.jpg"

FIXED_DATE = (2026, 5, 6, 0, 0, 0)


@dataclass(frozen=True)
class ManifestItem:
    item_id: str
    href: str
    media_type: str
    properties: tuple[str, ...] = ()


@dataclass(frozen=True)
class SpineItem:
    idref: str
    linear: bool = True


@dataclass(frozen=True)
class GuideReference:
    ref_type: str
    href: str
    title: str | None = None


@dataclass(frozen=True)
class MetadataFields:
    title: str
    creator: str | None = None
    language: str | None = None
    identifier: str | None = None
    publisher: str | None = None
    subject: str | None = None
    date: str | None = None
    modified: str | None = None


@dataclass(frozen=True)
class NavPoint:
    label: str
    href: str
    children: tuple["NavPoint", ...] = ()


@dataclass
class EpubSpec:
    path: Path
    metadata: MetadataFields
    manifest: list[ManifestItem]
    spine: list[SpineItem]
    parts: dict[str, bytes]
    nav_manifest_id: str | None = None
    nav_points: tuple[NavPoint, ...] = ()
    ncx_manifest_id: str | None = None
    ncx_points: tuple[NavPoint, ...] = ()
    cover_meta_id: str | None = None
    guide_references: tuple[GuideReference, ...] = ()
    opf_path: str = "OPS/package.opf"
    write_order: list[str] | None = None


def zip_info(name: str, compress_type: int = ZIP_DEFLATED) -> ZipInfo:
    info = ZipInfo(name)
    info.date_time = FIXED_DATE
    info.compress_type = compress_type
    return info


def write_epub(path: Path, entries: list[tuple[str, bytes, int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(path, "w") as zf:
        for name, data, compress_type in entries:
            zf.writestr(zip_info(name, compress_type), data)


def text(value: str) -> bytes:
    return value.encode("utf-8")


def read_bytes(path: Path) -> bytes:
    return path.read_bytes()


def xhtml_document(title: str, body: str) -> str:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<html xmlns="http://www.w3.org/1999/xhtml" '
        'xmlns:epub="http://www.idpf.org/2007/ops">\n'
        "<head>\n"
        f"<title>{escape(title)}</title>\n"
        "</head>\n"
        "<body>\n"
        f"{body}\n"
        "</body>\n"
        "</html>\n"
    )


def nav_document(points: tuple[NavPoint, ...]) -> str:
    return xhtml_document("Table of Contents", build_nav_body(points))


def build_nav_body(points: tuple[NavPoint, ...]) -> str:
    return (
        '<nav epub:type="toc">\n'
        "<h1>Table of Contents</h1>\n"
        f"{nav_list(points)}\n"
        "</nav>"
    )


def nav_list(points: tuple[NavPoint, ...]) -> str:
    items: list[str] = []
    for point in points:
        child = ""
        if point.children:
            child = "\n" + nav_list(point.children)
        items.append(
            "<li>"
            f'<a href="{escape(point.href)}">{escape(point.label)}</a>'
            f"{child}</li>"
        )
    return "<ol>\n" + "\n".join(items) + "\n</ol>"


def ncx_document(points: tuple[NavPoint, ...]) -> str:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">\n'
        "<navMap>\n"
        f"{ncx_points(points)}\n"
        "</navMap>\n"
        "</ncx>\n"
    )


def ncx_points(points: tuple[NavPoint, ...], prefix: str = "nav") -> str:
    out: list[str] = []
    for index, point in enumerate(points, start=1):
        node_id = f"{prefix}-{index}"
        child = ""
        if point.children:
            child = "\n" + ncx_points(point.children, node_id)
        out.append(
            f'<navPoint id="{node_id}">\n'
            "<navLabel><text>"
            f"{escape(point.label)}"
            "</text></navLabel>\n"
            f'<content src="{escape(point.href)}"/>{child}\n'
            "</navPoint>"
        )
    return "\n".join(out)


def container_xml(opf_path: str) -> str:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<container version="1.0" '
        'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
        "<rootfiles>\n"
        f'<rootfile full-path="{escape(opf_path)}" '
        'media-type="application/oebps-package+xml"/>\n'
        "</rootfiles>\n"
        "</container>\n"
    )


def build_opf(spec: EpubSpec) -> str:
    metadata = build_metadata_xml(spec.metadata, spec.cover_meta_id)
    manifest = build_manifest_xml(spec.manifest)
    spine = build_spine_xml(spec.spine, spec.ncx_manifest_id)
    guide = build_guide_xml(spec.guide_references)
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<package xmlns="http://www.idpf.org/2007/opf" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'version="3.0" unique-identifier="bookid">\n'
        f"{metadata}\n"
        f"{manifest}\n"
        f"{spine}\n"
        f"{guide}\n"
        "</package>\n"
    )


def build_metadata_xml(meta: MetadataFields, cover_meta_id: str | None) -> str:
    lines = [
        "<metadata>",
        f"<dc:title>{escape(meta.title)}</dc:title>",
    ]
    if meta.creator:
        lines.append(f"<dc:creator>{escape(meta.creator)}</dc:creator>")
    if meta.language:
        lines.append(f"<dc:language>{escape(meta.language)}</dc:language>")
    if meta.identifier:
        lines.append(f'<dc:identifier id="bookid">{escape(meta.identifier)}</dc:identifier>')
    if meta.publisher:
        lines.append(f"<dc:publisher>{escape(meta.publisher)}</dc:publisher>")
    if meta.subject:
        lines.append(f"<dc:subject>{escape(meta.subject)}</dc:subject>")
    if meta.date:
        lines.append(f"<dc:date>{escape(meta.date)}</dc:date>")
    if meta.modified:
        lines.append(
            f'<meta property="dcterms:modified">{escape(meta.modified)}</meta>'
        )
    if cover_meta_id:
        lines.append(f'<meta name="cover" content="{escape(cover_meta_id)}"/>')
    lines.append("</metadata>")
    return "\n".join(lines)


def build_manifest_xml(items: list[ManifestItem]) -> str:
    lines = ["<manifest>"]
    for item in items:
        attrs = [
            f'id="{escape(item.item_id)}"',
            f'href="{escape(item.href)}"',
            f'media-type="{escape(item.media_type)}"',
        ]
        if item.properties:
            attrs.append(
                f'properties="{escape(" ".join(item.properties))}"'
            )
        lines.append("<item " + " ".join(attrs) + "/>")
    lines.append("</manifest>")
    return "\n".join(lines)


def build_spine_xml(items: list[SpineItem], toc_id: str | None) -> str:
    attrs = []
    if toc_id:
        attrs.append(f'toc="{escape(toc_id)}"')
    header = "<spine" + (" " + " ".join(attrs) if attrs else "") + ">"
    lines = [header]
    for item in items:
        attrs = [f'idref="{escape(item.idref)}"']
        if not item.linear:
            attrs.append('linear="no"')
        lines.append("<itemref " + " ".join(attrs) + "/>")
    lines.append("</spine>")
    return "\n".join(lines)


def build_guide_xml(refs: tuple[GuideReference, ...]) -> str:
    if not refs:
        return ""
    lines = ["<guide>"]
    for ref in refs:
        attrs = [
            f'type="{escape(ref.ref_type)}"',
            f'href="{escape(ref.href)}"',
        ]
        if ref.title:
            attrs.append(f'title="{escape(ref.title)}"')
        lines.append("<reference " + " ".join(attrs) + "/>")
    lines.append("</guide>")
    return "\n".join(lines)


def spec_entries(spec: EpubSpec) -> list[tuple[str, bytes, int]]:
    parts = dict(spec.parts)
    parts[spec.opf_path] = text(build_opf(spec))
    opf_dir = str(Path(spec.opf_path).parent).replace("\\", "/")
    if spec.nav_manifest_id:
        nav_item = next(
            item for item in spec.manifest if item.item_id == spec.nav_manifest_id
        )
        parts[f"{opf_dir}/{nav_item.href}"] = text(nav_document(spec.nav_points))
    if spec.ncx_manifest_id:
        ncx_item = next(
            item for item in spec.manifest if item.item_id == spec.ncx_manifest_id
        )
        parts[f"{opf_dir}/{ncx_item.href}"] = text(ncx_document(spec.ncx_points))

    ordered = ["mimetype", "META-INF/container.xml"]
    if spec.write_order:
        ordered.extend(spec.write_order)

    names = list(parts.keys())
    for name in sorted(names):
        if name not in ordered:
            ordered.append(name)

    entries: list[tuple[str, bytes, int]] = [
        ("mimetype", text("application/epub+zip"), ZIP_STORED),
        ("META-INF/container.xml", text(container_xml(spec.opf_path)), ZIP_DEFLATED),
    ]
    for name in ordered:
        if name in {"mimetype", "META-INF/container.xml"}:
            continue
        entries.append((name, parts[name], ZIP_DEFLATED))
    return entries


def write_spec(spec: EpubSpec) -> None:
    write_epub(spec.path, spec_entries(spec))


def chapter(title: str, body: str) -> bytes:
    return text(xhtml_document(title, body))


def basic_nav_points() -> tuple[NavPoint, ...]:
    return (
        NavPoint("Section One", "chapter.xhtml#section-1"),
        NavPoint("Section Two", "chapter.xhtml#section-2"),
    )


def chapter_with_sections(title: str, body_intro: str) -> bytes:
    return chapter(
        title,
        (
            f"<h1>{escape(title)}</h1>\n"
            f"<p>{body_intro}</p>\n"
            '<h2 id="section-1">Section 1</h2>\n'
            "<p>Anchored body one.</p>\n"
            '<h2 id="section-2">Section 2</h2>\n'
            "<p>Anchored body two.</p>"
        ),
    )


def main_specs(img: bytes) -> list[EpubSpec]:
    return [
        EpubSpec(
            path=MAIN_DIR / "epub_basic_package.epub",
            metadata=MetadataFields(title="EPUB Basic Package"),
            manifest=[
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Basic Chapter",
                    "<h1>Basic Chapter</h1>\n<p>Basic EPUB package body.</p>",
                ),
            },
            write_order=["OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_metadata_rich.epub",
            metadata=MetadataFields(
                title="EPUB Rich Metadata",
                creator="Metadata Author",
                language="en",
                identifier="urn:isbn:9780000000001",
                publisher="MoonBit Press",
                date="2024-02-01",
                modified="2024-02-02T10:30:00Z",
            ),
            manifest=[
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Metadata Rich Chapter",
                    "<h1>Metadata Rich Chapter</h1>\n<p>Richer package metadata sample body.</p>",
                ),
            },
            write_order=["OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_spine_order.epub",
            metadata=MetadataFields(title="EPUB Spine Order"),
            manifest=[
                ManifestItem("ch1", "text/chapter-01.xhtml", "application/xhtml+xml"),
                ManifestItem("ch2", "text/chapter-02.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("ch2"), SpineItem("ch1")],
            parts={
                "OPS/text/chapter-01.xhtml": chapter(
                    "Chapter One",
                    "<h1>Chapter One</h1>\n<p>First chapter appears second.</p>",
                ),
                "OPS/text/chapter-02.xhtml": chapter(
                    "Chapter Two",
                    "<h1>Chapter Two</h1>\n<p>Second chapter appears first in the spine.</p>",
                ),
            },
            write_order=["OPS/text/chapter-01.xhtml", "OPS/text/chapter-02.xhtml"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_spine_missing_item_boundary.epub",
            metadata=MetadataFields(title="EPUB Missing Spine Item"),
            manifest=[
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("missing"), SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Valid Chapter",
                    "<h1>Valid Chapter</h1>\n<p>Valid chapter after missing manifest item.</p>",
                ),
            },
            write_order=["OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_spine_unsupported_item_boundary.epub",
            metadata=MetadataFields(title="EPUB Unsupported Spine Item"),
            manifest=[
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
                ManifestItem("audio", "media/audio.mp3", "audio/mpeg"),
            ],
            spine=[SpineItem("chapter"), SpineItem("audio")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Supported Chapter",
                    "<h1>Supported Chapter</h1>\n<p>This chapter is converted normally.</p>",
                ),
                "OPS/media/audio.mp3": b"ID3fake-audio",
            },
            write_order=["OPS/chapter.xhtml", "OPS/media/audio.mp3"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_nav_toc_basic.epub",
            metadata=MetadataFields(title="EPUB Nav TOC Basic"),
            manifest=[
                ManifestItem("nav", "nav.xhtml", "application/xhtml+xml", ("nav",)),
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            nav_manifest_id="nav",
            nav_points=basic_nav_points(),
            parts={
                "OPS/chapter.xhtml": chapter_with_sections(
                    "Chapter Body", "Nav sample body."
                ),
            },
            write_order=["OPS/nav.xhtml", "OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_ncx_toc_basic.epub",
            metadata=MetadataFields(title="EPUB NCX TOC Basic"),
            manifest=[
                ManifestItem("ncx", "toc.ncx", "application/x-dtbncx+xml"),
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            ncx_manifest_id="ncx",
            ncx_points=(NavPoint("Chapter One", "chapter.xhtml#section-1"),),
            parts={
                "OPS/chapter.xhtml": chapter_with_sections(
                    "NCX Chapter", "NCX sample body."
                ),
            },
            write_order=["OPS/toc.ncx", "OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_chapter_html_structures.epub",
            metadata=MetadataFields(title="EPUB HTML Structures"),
            manifest=[
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Structures Chapter",
                    (
                        "<h1>Structures Chapter</h1>\n"
                        "<p>Intro paragraph with <a href=\"docs/guide.html\">Guide</a>.</p>\n"
                        "<ul><li>Level 1<ul><li>Level 2</li></ul></li></ul>\n"
                        "<table><thead><tr><th>Name</th><th>Score</th></tr></thead>"
                        "<tbody><tr><td>Alice</td><td>95</td></tr></tbody></table>\n"
                        "<pre><code>&lt;tag&gt;\nline &amp; two</code></pre>"
                    ),
                ),
            },
            write_order=["OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_cover_image.epub",
            metadata=MetadataFields(title="EPUB Cover Image"),
            manifest=[
                ManifestItem(
                    "cover", "images/cover.jpg", "image/jpeg", ("cover-image",)
                ),
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Cover Chapter",
                    "<h1>Cover Chapter</h1>\n<p>Cover should appear before this chapter.</p>",
                ),
                "OPS/images/cover.jpg": img,
            },
            write_order=["OPS/chapter.xhtml", "OPS/images/cover.jpg"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_guide_cover_image.epub",
            metadata=MetadataFields(title="EPUB Guide Cover Image"),
            manifest=[
                ManifestItem("cover", "images/cover.jpg", "image/jpeg"),
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            guide_references=(
                GuideReference("cover", "images/cover.jpg", "Guide Cover"),
            ),
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Guide Cover Chapter",
                    "<h1>Guide Cover Chapter</h1>\n<p>Guide cover should appear before this chapter.</p>",
                ),
                "OPS/images/cover.jpg": img,
            },
            write_order=["OPS/chapter.xhtml", "OPS/images/cover.jpg"],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_duplicate_asset_names.epub",
            metadata=MetadataFields(title="EPUB Duplicate Asset Names"),
            manifest=[
                ManifestItem("ch1", "text/chapter-01.xhtml", "application/xhtml+xml"),
                ManifestItem("ch2", "text/chapter-02.xhtml", "application/xhtml+xml"),
                ManifestItem("img1", "text/images/pic.jpg", "image/jpeg"),
                ManifestItem("img2", "text/shared/pic.jpg", "image/jpeg"),
            ],
            spine=[SpineItem("ch1"), SpineItem("ch2")],
            parts={
                "OPS/text/chapter-01.xhtml": chapter(
                    "Chapter One",
                    (
                        "<h1>Chapter One</h1>\n"
                        "<figure><img src=\"images/pic.jpg\" alt=\"first art\" title=\"First Title\"/>"
                        "<figcaption>First caption.</figcaption></figure>"
                    ),
                ),
                "OPS/text/chapter-02.xhtml": chapter(
                    "Chapter Two",
                    (
                        "<h1>Chapter Two</h1>\n"
                        "<figure><img src=\"shared/pic.jpg\" alt=\"second art\" title=\"Second Title\"/>"
                        "<figcaption>Second caption.</figcaption></figure>"
                    ),
                ),
                "OPS/text/images/pic.jpg": img,
                "OPS/text/shared/pic.jpg": img,
            },
            write_order=[
                "OPS/text/chapter-01.xhtml",
                "OPS/text/chapter-02.xhtml",
                "OPS/text/images/pic.jpg",
                "OPS/text/shared/pic.jpg",
            ],
        ),
        EpubSpec(
            path=MAIN_DIR / "epub_remote_data_image_boundary.epub",
            metadata=MetadataFields(title="EPUB Remote Data Image Boundary"),
            manifest=[
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Boundary Chapter",
                    (
                        "<h1>Boundary Chapter</h1>\n"
                        '<img src="https://example.com/a.png" alt="remote"/>\n'
                        '<img src="data:image/png;base64,AA==" alt="inline data"/>'
                    ),
                ),
            },
            write_order=["OPS/chapter.xhtml"],
        ),
    ]


def metadata_specs(img: bytes) -> list[EpubSpec]:
    return [
        EpubSpec(
            path=META_DIR / "epub_metadata_package_rich.epub",
            metadata=MetadataFields(
                title="EPUB Metadata Package Rich",
                creator="Metadata Author",
                language="en",
                identifier="urn:isbn:9780000000002",
                publisher="MoonBit Press",
                date="2024-03-01",
                modified="2024-03-02T09:45:00Z",
            ),
            manifest=[ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml")],
            spine=[SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Metadata Package Rich",
                    "<h1>Metadata Package Rich</h1>\n<p>Metadata package body.</p>",
                ),
            },
            write_order=["OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=META_DIR / "epub_metadata_spine_order.epub",
            metadata=MetadataFields(title="EPUB Metadata Spine Order"),
            manifest=[
                ManifestItem("ch1", "text/chapter-01.xhtml", "application/xhtml+xml"),
                ManifestItem("ch2", "text/chapter-02.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("ch2"), SpineItem("ch1")],
            parts={
                "OPS/text/chapter-01.xhtml": chapter(
                    "Origin One",
                    "<h1>Origin One</h1>\n<p>First spine origin block.</p>",
                ),
                "OPS/text/chapter-02.xhtml": chapter(
                    "Origin Two",
                    "<h1>Origin Two</h1>\n<p>Second spine origin block.</p>",
                ),
            },
            write_order=["OPS/text/chapter-01.xhtml", "OPS/text/chapter-02.xhtml"],
        ),
        EpubSpec(
            path=META_DIR / "epub_metadata_nav_toc.epub",
            metadata=MetadataFields(title="EPUB Metadata Nav TOC"),
            manifest=[
                ManifestItem("nav", "nav.xhtml", "application/xhtml+xml", ("nav",)),
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            nav_manifest_id="nav",
            nav_points=basic_nav_points(),
            parts={
                "OPS/chapter.xhtml": chapter_with_sections(
                    "Metadata Chapter", "Metadata nav sample body."
                ),
            },
            write_order=["OPS/nav.xhtml", "OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=META_DIR / "epub_metadata_assets_cover.epub",
            metadata=MetadataFields(title="EPUB Metadata Assets Cover"),
            manifest=[
                ManifestItem(
                    "cover", "images/cover.jpg", "image/jpeg", ("cover-image",)
                ),
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
                ManifestItem("pic", "images/pic.jpg", "image/jpeg"),
            ],
            spine=[SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Asset Chapter",
                    (
                        "<h1>Asset Chapter</h1>\n<p>Asset metadata sample body.</p>\n"
                        "<figure><img src=\"images/pic.jpg\" alt=\"asset art\" title=\"Asset title\"/>"
                        "<figcaption>Asset caption.</figcaption></figure>"
                    ),
                ),
                "OPS/images/cover.jpg": img,
                "OPS/images/pic.jpg": img,
            },
            write_order=["OPS/chapter.xhtml", "OPS/images/cover.jpg", "OPS/images/pic.jpg"],
        ),
        EpubSpec(
            path=META_DIR / "epub_metadata_warning_item.epub",
            metadata=MetadataFields(title="EPUB Metadata Warning Item"),
            manifest=[ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml")],
            spine=[SpineItem("missing"), SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Warning Chapter",
                    "<h1>Warning Chapter</h1>\n<p>This chapter follows a warning block.</p>",
                ),
            },
            write_order=["OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=META_DIR / "epub_metadata_duplicate_asset_names.epub",
            metadata=MetadataFields(title="EPUB Metadata Duplicate Assets"),
            manifest=[
                ManifestItem("ch1", "text/chapter-01.xhtml", "application/xhtml+xml"),
                ManifestItem("ch2", "text/chapter-02.xhtml", "application/xhtml+xml"),
                ManifestItem("img1", "text/images/pic.jpg", "image/jpeg"),
                ManifestItem("img2", "text/shared/pic.jpg", "image/jpeg"),
            ],
            spine=[SpineItem("ch1"), SpineItem("ch2")],
            parts={
                "OPS/text/chapter-01.xhtml": chapter(
                    "Asset One",
                    (
                        "<h1>Asset One</h1>\n"
                        "<figure><img src=\"images/pic.jpg\" alt=\"first art\" title=\"First Title\"/>"
                        "<figcaption>First caption.</figcaption></figure>"
                    ),
                ),
                "OPS/text/chapter-02.xhtml": chapter(
                    "Asset Two",
                    (
                        "<h1>Asset Two</h1>\n"
                        "<figure><img src=\"shared/pic.jpg\" alt=\"second art\" title=\"Second Title\"/>"
                        "<figcaption>Second caption.</figcaption></figure>"
                    ),
                ),
                "OPS/text/images/pic.jpg": img,
                "OPS/text/shared/pic.jpg": img,
            },
            write_order=[
                "OPS/text/chapter-01.xhtml",
                "OPS/text/chapter-02.xhtml",
                "OPS/text/images/pic.jpg",
                "OPS/text/shared/pic.jpg",
            ],
        ),
    ]


def benchmark_specs(img: bytes) -> list[EpubSpec]:
    chapter_manifest = [
        ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
    ]
    return [
        EpubSpec(
            path=BENCH_DIR / "epub_unsupported_degrade.epub",
            metadata=MetadataFields(title="EPUB Unsupported Degrade"),
            manifest=[
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
                ManifestItem("audio", "media/audio.mp3", "audio/mpeg"),
            ],
            spine=[SpineItem("chapter"), SpineItem("audio")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Bench Chapter",
                    "<h1>Bench Chapter</h1>\n<p>Benchmark warning sample body.</p>",
                ),
                "OPS/media/audio.mp3": b"ID3fake-audio",
            },
            write_order=["OPS/chapter.xhtml", "OPS/media/audio.mp3"],
        ),
        EpubSpec(
            path=BENCH_DIR / "epub_ncx_toc.epub",
            metadata=MetadataFields(title="EPUB NCX Bench"),
            manifest=[
                ManifestItem("ncx", "toc.ncx", "application/x-dtbncx+xml"),
                ManifestItem("chapter", "chapter.xhtml", "application/xhtml+xml"),
            ],
            spine=[SpineItem("chapter")],
            ncx_manifest_id="ncx",
            ncx_points=(NavPoint("Bench Chapter", "chapter.xhtml#section-1"),),
            parts={
                "OPS/chapter.xhtml": chapter_with_sections(
                    "Bench Chapter", "Benchmark NCX body."
                ),
            },
            write_order=["OPS/toc.ncx", "OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=BENCH_DIR / "epub_metadata_case.epub",
            metadata=MetadataFields(
                title="EPUB Metadata Bench",
                creator="Bench Author",
                language="en",
                identifier="urn:uuid:bench-epub",
                publisher="Bench Press",
                modified="2024-04-01T08:00:00Z",
            ),
            manifest=chapter_manifest,
            spine=[SpineItem("chapter")],
            parts={
                "OPS/chapter.xhtml": chapter(
                    "Bench Metadata Chapter",
                    "<h1>Bench Metadata Chapter</h1>\n<p>Benchmark metadata body.</p>",
                )
            },
            write_order=["OPS/chapter.xhtml"],
        ),
        EpubSpec(
            path=BENCH_DIR / "epub_assets_duplicate.epub",
            metadata=MetadataFields(title="EPUB Asset Heavy Duplicate"),
            manifest=[
                ManifestItem("ch1", "text/chapter-01.xhtml", "application/xhtml+xml"),
                ManifestItem("ch2", "text/chapter-02.xhtml", "application/xhtml+xml"),
                ManifestItem("img1", "text/images/pic.jpg", "image/jpeg"),
                ManifestItem("img2", "text/shared/pic.jpg", "image/jpeg"),
            ],
            spine=[SpineItem("ch1"), SpineItem("ch2")],
            parts={
                "OPS/text/chapter-01.xhtml": chapter(
                    "Asset One",
                    (
                        "<h1>Asset One</h1>\n"
                        "<figure><img src=\"images/pic.jpg\" alt=\"first art\" title=\"First Title\"/>"
                        "<figcaption>First caption.</figcaption></figure>"
                    ),
                ),
                "OPS/text/chapter-02.xhtml": chapter(
                    "Asset Two",
                    (
                        "<h1>Asset Two</h1>\n"
                        "<figure><img src=\"shared/pic.jpg\" alt=\"second art\" title=\"Second Title\"/>"
                        "<figcaption>Second caption.</figcaption></figure>"
                    ),
                ),
                "OPS/text/images/pic.jpg": img,
                "OPS/text/shared/pic.jpg": img,
            },
            write_order=[
                "OPS/text/chapter-01.xhtml",
                "OPS/text/chapter-02.xhtml",
                "OPS/text/images/pic.jpg",
                "OPS/text/shared/pic.jpg",
            ],
        ),
    ]


def generate_specs(specs: list[EpubSpec]) -> None:
    for spec in specs:
        write_spec(spec)


def main() -> None:
    img = read_bytes(IMG_RED)
    generate_specs(main_specs(img))
    generate_specs(metadata_specs(img))
    generate_specs(benchmark_specs(img))


if __name__ == "__main__":
    main()
