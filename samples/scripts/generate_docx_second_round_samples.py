#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from shutil import copyfile
from xml.sax.saxutils import escape
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[2]

MAIN_DIR = ROOT / "samples" / "main_process" / "docx"
META_DIR = ROOT / "samples" / "metadata" / "docx"
BENCH_DIR = ROOT / "samples" / "benchmark" / "docx"

IMG_RED_JPG = ROOT / "samples" / "main_process" / "html" / "img" / "img_red.jpg"
FIXED_DATE = (2026, 5, 6, 0, 0, 0)

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
WP_NS = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"
PIC_NS = "http://schemas.openxmlformats.org/drawingml/2006/picture"
V_NS = "urn:schemas-microsoft-com:vml"

REL_OFFICE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
REL_STYLES = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles"
REL_NUMBERING = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering"
REL_HYPERLINK = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink"
REL_IMAGE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"
REL_FOOTNOTES = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes"
REL_ENDNOTES = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/endnotes"
REL_COMMENTS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments"
REL_HEADER = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header"
REL_FOOTER = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer"
REL_CORE = "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"
REL_APP = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties"


@dataclass(frozen=True)
class Relationship:
    rel_id: str
    rel_type: str
    target: str
    target_mode: str | None = None


@dataclass(frozen=True)
class DocProps:
    title: str | None = None
    subject: str | None = None
    creator: str | None = None
    description: str | None = None
    keywords: str | None = None
    created: str | None = None
    modified: str | None = None
    application: str | None = "fixture"
    pages: str | None = None
    words: str | None = None


@dataclass
class DocxSpec:
    path: Path
    body_blocks: list[str]
    relationships: list[Relationship] = field(default_factory=list)
    styles_xml: str | None = None
    numbering_xml: str | None = None
    footnotes_xml: str | None = None
    endnotes_xml: str | None = None
    comments_xml: str | None = None
    header_parts: dict[str, str] = field(default_factory=dict)
    footer_parts: dict[str, str] = field(default_factory=dict)
    media_parts: dict[str, bytes] = field(default_factory=dict)
    docprops: DocProps = field(default_factory=DocProps)
    section_refs_xml: str = ""


def zip_info(name: str) -> ZipInfo:
    info = ZipInfo(name)
    info.date_time = FIXED_DATE
    info.compress_type = ZIP_DEFLATED
    return info


def write_docx(spec: DocxSpec) -> None:
    spec.path.parent.mkdir(parents=True, exist_ok=True)
    entries = build_docx_entries(spec)
    with ZipFile(spec.path, "w") as zf:
        for name, data in entries:
            zf.writestr(zip_info(name), data)


def xml_text(value: str | None) -> str:
    if value is None:
        return ""
    return escape(value)


def maybe_space_attr(text: str) -> str:
    if text.startswith(" ") or text.endswith(" ") or "  " in text:
        return ' xml:space="preserve"'
    return ""


def text_run(text: str) -> str:
    return f'<w:r><w:t{maybe_space_attr(text)}>{escape(text)}</w:t></w:r>'


def break_run() -> str:
    return "<w:r><w:br/></w:r>"


def tab_run() -> str:
    return "<w:r><w:tab/></w:r>"


def hyperlink(rel_id: str, *runs: str) -> str:
    inner = "".join(runs)
    return f'<w:hyperlink r:id="{rel_id}">{inner}</w:hyperlink>'


def anchor_hyperlink(anchor: str, *runs: str) -> str:
    inner = "".join(runs)
    return f'<w:hyperlink w:anchor="{escape(anchor)}">{inner}</w:hyperlink>'


def footnote_ref(note_id: int) -> str:
    return f'<w:r><w:footnoteReference w:id="{note_id}"/></w:r>'


def endnote_ref(note_id: int) -> str:
    return f'<w:r><w:endnoteReference w:id="{note_id}"/></w:r>'


def comment_ref(comment_id: int) -> str:
    return f'<w:r><w:commentReference w:id="{comment_id}"/></w:r>'


def image_run(rel_id: str, alt: str | None = None, title: str | None = None) -> str:
    descr = escape(alt or "image")
    title_attr = escape(title or "")
    return (
        "<w:r>"
        "<w:drawing>"
        "<wp:inline>"
        f'<wp:docPr id="1" name="Picture 1" descr="{descr}" title="{title_attr}"/>'
        "<a:graphic>"
        "<a:graphicData uri=\"http://schemas.openxmlformats.org/drawingml/2006/picture\">"
        "<pic:pic>"
        "<pic:blipFill>"
        f'<a:blip r:embed="{rel_id}"/>'
        "</pic:blipFill>"
        "</pic:pic>"
        "</a:graphicData>"
        "</a:graphic>"
        "</wp:inline>"
        "</w:drawing>"
        "</w:r>"
    )


def p(
    *content: str,
    style_id: str | None = None,
    num_id: int | None = None,
    ilvl: int | None = None,
) -> str:
    ppr = ""
    if style_id or num_id is not None:
        bits: list[str] = []
        if style_id:
            bits.append(f'<w:pStyle w:val="{escape(style_id)}"/>')
        if num_id is not None:
            bits.append(
                "<w:numPr>"
                f'<w:ilvl w:val="{0 if ilvl is None else ilvl}"/>'
                f'<w:numId w:val="{num_id}"/>'
                "</w:numPr>"
            )
        ppr = "<w:pPr>" + "".join(bits) + "</w:pPr>"
    return "<w:p>" + ppr + "".join(content) + "</w:p>"


def heading(level: int, text: str, style_id: str | None = None) -> str:
    if style_id is None:
        style_id = f"Heading{level}"
    return p(text_run(text), style_id=style_id)


def quote(text: str) -> str:
    return p(text_run(text), style_id="Quote")


def code_block(text: str) -> str:
    runs: list[str] = []
    parts = text.split("\n")
    for index, part in enumerate(parts):
        runs.append(text_run(part))
        if index + 1 < len(parts):
            runs.append(break_run())
    return p(*runs, style_id="CodeBlock")


def table(rows: list[list[str]]) -> str:
    row_xml = []
    for row in rows:
        cells = "".join(normalize_table_cell(cell) for cell in row)
        row_xml.append("<w:tr>" + cells + "</w:tr>")
    return "<w:tbl>" + "".join(row_xml) + "</w:tbl>"


def tc(*paragraphs: str, tcpr: str = "") -> str:
    inner = "".join(paragraphs)
    if tcpr:
        inner = "<w:tcPr>" + tcpr + "</w:tcPr>" + inner
    return "<w:tc>" + inner + "</w:tc>"


def grid_span(val: int) -> str:
    return f'<w:gridSpan w:val="{val}"/>'


def vmerge(val: str | None = None) -> str:
    if val is None:
        return "<w:vMerge/>"
    return f'<w:vMerge w:val="{escape(val)}"/>'


def textbox(*paragraphs: str) -> str:
    return (
        "<w:p><w:r><w:pict><v:shape><v:textbox><w:txbxContent>"
        + "".join(paragraphs)
        + "</w:txbxContent></v:textbox></v:shape></w:pict></w:r></w:p>"
    )


def normalize_table_cell(cell: str) -> str:
    stripped = cell.lstrip()
    if stripped.startswith("<w:tc"):
        return cell
    if stripped.startswith("<w:p") or stripped.startswith("<w:tbl"):
        return tc(cell)
    return tc(p(text_run(cell)))


def header_footer_part(*blocks: str) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<w:hdr xmlns:w="{W_NS}" xmlns:r="{R_NS}" xmlns:v="{V_NS}">' +
        "".join(blocks) +
        "</w:hdr>"
    )


def footer_part(*blocks: str) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<w:ftr xmlns:w="{W_NS}" xmlns:r="{R_NS}" xmlns:v="{V_NS}">' +
        "".join(blocks) +
        "</w:ftr>"
    )


def build_document_xml(body_blocks: list[str], section_refs_xml: str) -> str:
    sect_pr = (
        "<w:sectPr>"
        + section_refs_xml
        + '<w:pgSz w:w="12240" w:h="15840"/>'
        + '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>'
        + "</w:sectPr>"
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<w:document xmlns:w="{W_NS}" xmlns:r="{R_NS}" xmlns:wp="{WP_NS}" xmlns:a="{A_NS}" xmlns:pic="{PIC_NS}" xmlns:v="{V_NS}">'
        "<w:body>"
        + "".join(body_blocks)
        + sect_pr
        + "</w:body></w:document>"
    )


def build_document_rels(spec: DocxSpec) -> str:
    rels = [Relationship("rIdStyles", REL_STYLES, "styles.xml")]
    if spec.numbering_xml is not None:
        rels.append(Relationship("rIdNumbering", REL_NUMBERING, "numbering.xml"))
    if spec.footnotes_xml is not None:
        rels.append(Relationship("rIdFootnotes", REL_FOOTNOTES, "footnotes.xml"))
    if spec.endnotes_xml is not None:
        rels.append(Relationship("rIdEndnotes", REL_ENDNOTES, "endnotes.xml"))
    if spec.comments_xml is not None:
        rels.append(Relationship("rIdComments", REL_COMMENTS, "comments.xml"))
    rels.extend(spec.relationships)
    return relationships_xml(rels)


def relationships_xml(rels: list[Relationship]) -> str:
    items = []
    for rel in rels:
        mode = f' TargetMode="{rel.target_mode}"' if rel.target_mode else ""
        items.append(
            f'<Relationship Id="{rel.rel_id}" Type="{rel.rel_type}" Target="{escape(rel.target)}"{mode}/>'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        + "".join(items)
        + "</Relationships>"
    )


def build_content_types(spec: DocxSpec) -> str:
    defaults = [
        ('Extension="rels"', 'application/vnd.openxmlformats-package.relationships+xml'),
        ('Extension="xml"', 'application/xml'),
    ]
    if any(name.endswith(".jpg") or name.endswith(".jpeg") for name in spec.media_parts):
        defaults.append(('Extension="jpg"', "image/jpeg"))
        defaults.append(('Extension="jpeg"', "image/jpeg"))
    if any(name.endswith(".png") for name in spec.media_parts):
        defaults.append(('Extension="png"', "image/png"))
    default_xml = "".join(
        f"<Default {attr} ContentType=\"{ctype}\"/>" for attr, ctype in defaults
    )
    overrides = [
        ("/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"),
        ("/word/styles.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"),
        ("/docProps/core.xml", "application/vnd.openxmlformats-package.core-properties+xml"),
        ("/docProps/app.xml", "application/vnd.openxmlformats-officedocument.extended-properties+xml"),
    ]
    if spec.numbering_xml is not None:
        overrides.append(("/word/numbering.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"))
    if spec.footnotes_xml is not None:
        overrides.append(("/word/footnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml"))
    if spec.endnotes_xml is not None:
        overrides.append(("/word/endnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.endnotes+xml"))
    if spec.comments_xml is not None:
        overrides.append(("/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml"))
    for name in spec.header_parts:
        overrides.append((f"/word/{name}", "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"))
    for name in spec.footer_parts:
        overrides.append((f"/word/{name}", "application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"))
    override_xml = "".join(
        f'<Override PartName="{path}" ContentType="{ctype}"/>'
        for path, ctype in overrides
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        + default_xml
        + override_xml
        + "</Types>"
    )


def build_core_props(props: DocProps) -> str:
    items = []
    if props.title is not None:
        items.append(f"<dc:title>{xml_text(props.title)}</dc:title>")
    if props.subject is not None:
        items.append(f"<dc:subject>{xml_text(props.subject)}</dc:subject>")
    if props.creator is not None:
        items.append(f"<dc:creator>{xml_text(props.creator)}</dc:creator>")
        items.append(f"<cp:lastModifiedBy>{xml_text(props.creator)}</cp:lastModifiedBy>")
    if props.description is not None:
        items.append(f"<dc:description>{xml_text(props.description)}</dc:description>")
    if props.keywords is not None:
        items.append(f"<cp:keywords>{xml_text(props.keywords)}</cp:keywords>")
    if props.created is not None:
        items.append(f'<dcterms:created xsi:type="dcterms:W3CDTF">{xml_text(props.created)}</dcterms:created>')
    if props.modified is not None:
        items.append(f'<dcterms:modified xsi:type="dcterms:W3CDTF">{xml_text(props.modified)}</dcterms:modified>')
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" '
        'xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        + "".join(items)
        + "</cp:coreProperties>"
    )


def build_app_props(props: DocProps) -> str:
    application = xml_text(props.application or "fixture")
    pages = xml_text(props.pages or "1")
    words = xml_text(props.words or "0")
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
        'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
        f"<Application>{application}</Application>"
        f"<Pages>{pages}</Pages>"
        f"<Words>{words}</Words>"
        "</Properties>"
    )


def build_styles_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<w:styles xmlns:w="{W_NS}">'
        '<w:style w:type="paragraph" w:styleId="Normal"><w:name w:val="Normal"/></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="Heading 1"/><w:outlineLvl w:val="0"/></w:style>'
        '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="Heading 2"/><w:outlineLvl w:val="1"/></w:style>'
        '<w:style w:type="paragraph" w:styleId="CustomHeading"><w:name w:val="Heading 2"/><w:outlineLvl w:val="1"/></w:style>'
        '<w:style w:type="paragraph" w:styleId="AnchorHeading"><w:name w:val="Heading 1"/><w:outlineLvl w:val="0"/></w:style>'
        '<w:style w:type="paragraph" w:styleId="Quote"><w:name w:val="Quote"/></w:style>'
        '<w:style w:type="paragraph" w:styleId="CodeBlock"><w:name w:val="Code Block"/></w:style>'
        "</w:styles>"
    )


def build_numbering_xml() -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<w:numbering xmlns:w="{W_NS}">'
        '<w:abstractNum w:abstractNumId="1">'
        '<w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/></w:lvl>'
        '<w:lvl w:ilvl="1"><w:numFmt w:val="bullet"/></w:lvl>'
        "</w:abstractNum>"
        '<w:abstractNum w:abstractNumId="2">'
        '<w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/></w:lvl>'
        '<w:lvl w:ilvl="1"><w:numFmt w:val="decimal"/></w:lvl>'
        "</w:abstractNum>"
        '<w:abstractNum w:abstractNumId="3">'
        '<w:lvl w:ilvl="0"><w:numFmt w:val="decimal"/></w:lvl>'
        "</w:abstractNum>"
        '<w:num w:numId="10"><w:abstractNumId w:val="1"/></w:num>'
        '<w:num w:numId="20"><w:abstractNumId w:val="2"/></w:num>'
        '<w:num w:numId="30"><w:abstractNumId w:val="3"/></w:num>'
        "</w:numbering>"
    )


def build_docx_entries(spec: DocxSpec) -> list[tuple[str, bytes]]:
    entries: list[tuple[str, bytes]] = []
    entries.append(("[Content_Types].xml", build_content_types(spec).encode("utf-8")))
    entries.append(("_rels/.rels", relationships_xml([
        Relationship("rId1", REL_OFFICE, "word/document.xml"),
        Relationship("rId2", REL_CORE, "docProps/core.xml"),
        Relationship("rId3", REL_APP, "docProps/app.xml"),
    ]).encode("utf-8")))
    entries.append(("docProps/core.xml", build_core_props(spec.docprops).encode("utf-8")))
    entries.append(("docProps/app.xml", build_app_props(spec.docprops).encode("utf-8")))
    entries.append(("word/document.xml", build_document_xml(spec.body_blocks, spec.section_refs_xml).encode("utf-8")))
    entries.append(("word/_rels/document.xml.rels", build_document_rels(spec).encode("utf-8")))
    entries.append(("word/styles.xml", (spec.styles_xml or build_styles_xml()).encode("utf-8")))
    if spec.numbering_xml is not None:
        entries.append(("word/numbering.xml", spec.numbering_xml.encode("utf-8")))
    if spec.footnotes_xml is not None:
        entries.append(("word/footnotes.xml", spec.footnotes_xml.encode("utf-8")))
    if spec.endnotes_xml is not None:
        entries.append(("word/endnotes.xml", spec.endnotes_xml.encode("utf-8")))
    if spec.comments_xml is not None:
        entries.append(("word/comments.xml", spec.comments_xml.encode("utf-8")))
    for name, xml in spec.header_parts.items():
        entries.append((f"word/{name}", xml.encode("utf-8")))
    for name, xml in spec.footer_parts.items():
        entries.append((f"word/{name}", xml.encode("utf-8")))
    for name, data in spec.media_parts.items():
        entries.append((f"word/media/{name}", data))
    return entries


def note_xml(tag: str, entries: list[tuple[int, str]]) -> str:
    nodes = [f'<w:{tag} w:id="{note_id}"><w:p><w:r><w:t>{escape(text)}</w:t></w:r></w:p></w:{tag}>' for note_id, text in entries]
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<w:{tag}s xmlns:w="{W_NS}">' + "".join(nodes) + f"</w:{tag}s>"
    )


def comments_xml(entries: list[tuple[int, str | None, str]]) -> str:
    nodes = []
    for note_id, author, text in entries:
        attrs = f' w:id="{note_id}"'
        if author is not None:
            attrs += f' w:author="{escape(author)}"'
        nodes.append(
            f'<w:comment{attrs}><w:p><w:r><w:t>{escape(text)}</w:t></w:r></w:p></w:comment>'
        )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        f'<w:comments xmlns:w="{W_NS}">' + "".join(nodes) + "</w:comments>"
    )


def copy_existing(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    copyfile(src, dst)


def build_samples() -> None:
    # Reuse stable existing samples where they already express the target shape.
    copy_existing(MAIN_DIR / "docx_list_mixed.docx", MAIN_DIR / "docx_nested_lists_mixed.docx")
    copy_existing(MAIN_DIR / "docx_link_multiple_runs.docx", MAIN_DIR / "docx_multirun_hyperlink.docx")
    copy_existing(META_DIR / "docx_image_alt_title_basic.docx", MAIN_DIR / "docx_image_alt_title.docx")

    image_bytes = IMG_RED_JPG.read_bytes()

    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_list_links_linebreaks.docx",
            body_blocks=[
                heading(1, "DOCX List Links And Line Breaks"),
                p(text_run("List intro.")),
                p(
                    text_run("Open "),
                    hyperlink("rIdHyper1", text_run("OpenAI Docs")),
                    text_run(" now."),
                    num_id=20,
                    ilvl=0,
                ),
                p(
                    text_run("Step line 1"),
                    break_run(),
                    text_run("Step line 2"),
                    num_id=30,
                    ilvl=0,
                ),
            ],
            relationships=[
                Relationship("rIdHyper1", REL_HYPERLINK, "https://openai.com/docs", "External"),
            ],
            numbering_xml=build_numbering_xml(),
            docprops=DocProps(title="DOCX List Links And Line Breaks"),
        )
    )

    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_style_linked_headings.docx",
            body_blocks=[
                p(text_run("Styled section"), style_id="CustomHeading"),
                p(text_run("Paragraph under custom heading.")),
                p(text_run("Sub heading"), style_id="Heading2"),
                p(text_run("Nested paragraph.")),
            ],
            numbering_xml=build_numbering_xml(),
            docprops=DocProps(title="DOCX Style Linked Headings"),
        )
    )

    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_hyperlink_spacing.docx",
            body_blocks=[
                p(
                    text_run("Before "),
                    hyperlink("rIdHyper1", text_run("OpenAI")),
                    text_run(" after."),
                )
            ],
            relationships=[
                Relationship("rIdHyper1", REL_HYPERLINK, "https://openai.com", "External"),
            ],
            docprops=DocProps(title="DOCX Hyperlink Spacing"),
        )
    )

    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_internal_anchor_boundary.docx",
            body_blocks=[
                p(anchor_hyperlink("local-anchor", text_run("Jump local"))),
                p(text_run("Anchor target"), style_id="AnchorHeading"),
            ],
            docprops=DocProps(title="DOCX Internal Anchor Boundary"),
        )
    )

    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_table_links_lists.docx",
            body_blocks=[
                table(
                    [
                        [p(text_run("Action")), p(text_run("Notes"))],
                        [
                            p(hyperlink("rIdHyper1", text_run("OpenAI Docs"))),
                            p(text_run("Line one")),
                        ],
                        [
                            p(text_run("Checklist")),
                            p(text_run("bullet one"), break_run(), text_run("bullet two")),
                        ],
                    ]
                )
            ],
            relationships=[
                Relationship("rIdHyper1", REL_HYPERLINK, "https://openai.com/docs", "External"),
            ],
            docprops=DocProps(title="DOCX Table Links Lists"),
        )
    )

    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_table_merged_cells_boundary.docx",
            body_blocks=[
                table(
                    [
                        [
                            tc(p(text_run("Merged Head")), tcpr=grid_span(2)),
                            tc(p(text_run("Right"))),
                        ],
                        [
                            tc(p(text_run("A"))),
                            tc(p(text_run("B"))),
                            tc(p(text_run("C"))),
                        ],
                        [
                            tc(p(text_run("Vert Start")), tcpr=vmerge("restart")),
                            tc(p(text_run("Body 1"))),
                            tc(p(text_run("Body 2"))),
                        ],
                        [
                            tc(p(text_run("")), tcpr=vmerge()),
                            tc(p(text_run("Tail 1"))),
                            tc(p(text_run("Tail 2"))),
                        ],
                    ]
                )
            ],
            docprops=DocProps(title="DOCX Table Merged Cells Boundary"),
        )
    )

    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_table_multiline_complex.docx",
            body_blocks=[
                table(
                    [
                        [p(text_run("Step")), p(text_run("Detail"))],
                        [p(text_run("1")), p(text_run("Line 1"), break_run(), text_run("Line 2"))],
                        [p(text_run("2")), p(text_run("See "), hyperlink("rIdHyper1", text_run("OpenAI")), text_run(" docs"))],
                    ]
                )
            ],
            relationships=[
                Relationship("rIdHyper1", REL_HYPERLINK, "https://openai.com/docs", "External"),
            ],
            docprops=DocProps(title="DOCX Table Multiline Complex"),
        )
    )

    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_image_in_table.docx",
            body_blocks=[
                table(
                    [
                        [p(text_run("Figure")), p(text_run("Detail"))],
                        [p(image_run("rIdImg1", "Table image", "Table title")), p(text_run("Image inside table."))],
                    ]
                )
            ],
            relationships=[Relationship("rIdImg1", REL_IMAGE, "media/image1.jpg")],
            media_parts={"image1.jpg": image_bytes},
            docprops=DocProps(title="DOCX Image In Table"),
        )
    )

    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_image_caption_like_boundary.docx",
            body_blocks=[
                p(image_run("rIdImg1", "Caption-like image", "Caption-like title")),
                p(text_run("Figure 1. Caption-like paragraph after image.")),
            ],
            relationships=[Relationship("rIdImg1", REL_IMAGE, "media/image1.jpg")],
            media_parts={"image1.jpg": image_bytes},
            docprops=DocProps(title="DOCX Image Caption Like Boundary"),
        )
    )

    footnotes = note_xml("footnote", [(1, "Footnote body.")])
    endnotes = note_xml("endnote", [(1, "Endnote body.")])
    comments = comments_xml([(1, "Alice", "Comment body.")])
    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_footnotes_endnotes_comments.docx",
            body_blocks=[
                p(text_run("Footnote"), footnote_ref(1), text_run(" then comment"), comment_ref(1)),
                p(text_run("Endnote"), endnote_ref(1)),
            ],
            footnotes_xml=footnotes,
            endnotes_xml=endnotes,
            comments_xml=comments,
            docprops=DocProps(title="DOCX Footnotes Endnotes Comments"),
        )
    )

    rich_footnotes = note_xml("footnote", [(1, "Note line one.\nNote line two.")])
    rich_comments = comments_xml([(1, "Reviewer", "Comment line one.\nComment line two.")])
    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_note_comment_rich_content_boundary.docx",
            body_blocks=[
                p(text_run("Body"), footnote_ref(1), text_run(" "), comment_ref(1)),
            ],
            footnotes_xml=rich_footnotes,
            comments_xml=rich_comments,
            docprops=DocProps(title="DOCX Note Comment Rich Boundary"),
        )
    )

    body_box = textbox(p(text_run("Body text box.")))
    table_box = table([[tc(p(text_run("Cell before")))], [tc(textbox(p(text_run("Table text box."))))]])
    write_docx(
        DocxSpec(
            path=MAIN_DIR / "docx_textbox_body_and_table.docx",
            body_blocks=[
                p(text_run("Body paragraph.")),
                body_box,
                table_box,
            ],
            docprops=DocProps(title="DOCX Text Box Body And Table"),
        )
    )

    # Metadata docs
    write_docx(
        DocxSpec(
            path=META_DIR / "docx_metadata_docprops_rich.docx",
            body_blocks=[p(text_run("Metadata rich body."))],
            docprops=DocProps(
                title="DOCX Rich Metadata",
                subject="Fixture subject",
                creator="Docx Fixture",
                keywords="alpha,beta",
                created="2026-05-06T00:00:00Z",
                modified="2026-05-06T00:10:00Z",
                application="fixture",
                pages="2",
                words="42",
            ),
        )
    )

    write_docx(
        DocxSpec(
            path=META_DIR / "docx_metadata_links_images.docx",
            body_blocks=[
                p(text_run("See "), hyperlink("rIdHyper1", text_run("OpenAI")), text_run(".")),
                p(image_run("rIdImg1", "Meta image", "Meta image title")),
            ],
            relationships=[
                Relationship("rIdHyper1", REL_HYPERLINK, "https://openai.com", "External"),
                Relationship("rIdImg1", REL_IMAGE, "media/image1.jpg"),
            ],
            media_parts={"image1.jpg": image_bytes},
            docprops=DocProps(title="DOCX Metadata Links Images"),
        )
    )

    write_docx(
        DocxSpec(
            path=META_DIR / "docx_metadata_table_complex.docx",
            body_blocks=[
                table(
                    [
                        [p(text_run("A")), p(text_run("B"))],
                        [p(text_run("Line 1"), break_run(), text_run("Line 2")), p(text_run("Merged?"))],
                        [tc(p(text_run("Span")), tcpr=grid_span(2)), tc(p(text_run("Tail")))],
                    ]
                )
            ],
            docprops=DocProps(title="DOCX Metadata Table Complex"),
        )
    )

    write_docx(
        DocxSpec(
            path=META_DIR / "docx_metadata_notes_comments.docx",
            body_blocks=[
                p(text_run("Body"), footnote_ref(1), text_run(" "), comment_ref(1)),
                p(text_run("End"), endnote_ref(1)),
            ],
            footnotes_xml=footnotes,
            endnotes_xml=endnotes,
            comments_xml=comments,
            docprops=DocProps(title="DOCX Metadata Notes Comments"),
        )
    )

    header_xml = header_footer_part(p(text_run("Meta Header")), textbox(p(text_run("Header text box."))))
    footer_xml = footer_part(p(text_run("Meta Footer")))
    section_refs = '<w:headerReference r:id="rIdHeader1" w:type="default"/><w:footerReference r:id="rIdFooter1" w:type="default"/>'
    write_docx(
        DocxSpec(
            path=META_DIR / "docx_metadata_textbox_header_footer.docx",
            body_blocks=[p(text_run("Metadata body."))],
            relationships=[
                Relationship("rIdHeader1", REL_HEADER, "header1.xml"),
                Relationship("rIdFooter1", REL_FOOTER, "footer1.xml"),
            ],
            header_parts={"header1.xml": header_xml},
            footer_parts={"footer1.xml": footer_xml},
            section_refs_xml=section_refs,
            docprops=DocProps(title="DOCX Metadata TextBox Header Footer"),
        )
    )

    # Bench docs
    write_docx(
        DocxSpec(
            path=BENCH_DIR / "docx_table_heavy.docx",
            body_blocks=[
                table(
                    [["Col 1", "Col 2", "Col 3"]]
                    + [[p(text_run(f"R{i}C1")), p(text_run(f"R{i}C2")), p(text_run(f"R{i}C3"))] for i in range(1, 41)]
                )
            ],
            docprops=DocProps(title="DOCX Table Heavy"),
        )
    )

    link_relationships = [
        Relationship(f"rIdHyper{i}", REL_HYPERLINK, f"https://example.com/{i}", "External")
        for i in range(1, 41)
    ]
    link_blocks = [
        p(text_run("Link "), hyperlink(f"rIdHyper{i}", text_run(f"Item {i}")), text_run(" tail."))
        for i in range(1, 41)
    ]
    write_docx(
        DocxSpec(
            path=BENCH_DIR / "docx_link_heavy.docx",
            body_blocks=link_blocks,
            relationships=link_relationships,
            docprops=DocProps(title="DOCX Link Heavy"),
        )
    )

    image_relationships = [
        Relationship(f"rIdImg{i}", REL_IMAGE, f"media/image{i}.jpg") for i in range(1, 9)
    ]
    image_parts = {f"image{i}.jpg": image_bytes for i in range(1, 9)}
    image_blocks = [p(image_run(f"rIdImg{i}", f"Image {i}", f"Title {i}")) for i in range(1, 9)]
    write_docx(
        DocxSpec(
            path=BENCH_DIR / "docx_image_heavy.docx",
            body_blocks=image_blocks,
            relationships=image_relationships,
            media_parts=image_parts,
            docprops=DocProps(title="DOCX Image Heavy"),
        )
    )

    heavy_footnotes = note_xml("footnote", [(i, f"Footnote {i}.") for i in range(1, 8)])
    heavy_comments = comments_xml([(i, "Reviewer", f"Comment {i}.") for i in range(1, 8)])
    note_blocks = [
        p(text_run(f"Body {i}"), footnote_ref(i), text_run(" "), comment_ref(i))
        for i in range(1, 8)
    ]
    write_docx(
        DocxSpec(
            path=BENCH_DIR / "docx_notes_comments_heavy.docx",
            body_blocks=note_blocks,
            footnotes_xml=heavy_footnotes,
            comments_xml=heavy_comments,
            docprops=DocProps(title="DOCX Notes Comments Heavy"),
        )
    )


def main() -> None:
    build_samples()


if __name__ == "__main__":
    main()
