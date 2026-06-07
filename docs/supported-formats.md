# Supported Formats

This page summarizes current product support and explicit limits. It is a
conservative contract: support means the behavior is intentionally shipped and
validated on local samples or external quality rows, not that every document in
the wild is fully reconstructed.

## Product Scope

The normal product path targets local files and Markdown-first output.

Current goals:

* useful reading structure
* checked asset export where supported
* optional metadata sidecars
* safe fallback and clear failure for unsupported behavior

Current non-goals:

* browser or Office layout fidelity
* silent OCR fallback for documents
* remote resource fetching
* model-backed runtime classification
* DRM or encrypted-content recovery

## Format Matrix

| Format | Current support | Important limits |
| --- | --- | --- |
| DOCX | v2 runtime; headings, paragraphs, links, tables, images, comments, text boxes, headers/footers, structured footnotes/endnotes | no legacy v1 runtime fallback; not a Word layout engine |
| PPTX | titles, bullets, notes, links, images, grouped shapes, chart data, table-like grids | not a PowerPoint visual renderer |
| XLSX | sheets, typed cells, merged-cell policy, hidden-sheet policy, cached formulas, limited lightweight formula evaluation | no full spreadsheet recalculation engine |
| PDF | native text/assets/metadata extraction, conservative layout cleanup, high-confidence URI annotation links, report-only scan diagnostics | no scanned-PDF OCR; no hidden provider probing; no runtime model JSON |
| Images (`png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff`) | main-CLI image OCR through `convert/vision` | requires local `tesseract` and language data; no provider selection beyond current Tesseract path |
| HTML / HTM | tolerant parsing, structural lowering, links, images, tables, explicit same-document note refs/bodies | no JavaScript, CSS layout, or browser engine |
| EPUB | OPF/spine/nav/NCX/XHTML lowering, assets, metadata, explicit EPUB noteref bodies | unsupported media stays explicit; no broad visual inference |
| ZIP | supported-entry dispatch, path safety, asset remapping, metadata/origin tracking | no recursive archive explosion |
| CSV / TSV | conservative table lowering and dialect handling | not a spreadsheet model |
| JSON / YAML / XML | structured or source-preserving lowering with safe fallback | no schema-driven semantic reconstruction; malformed input fails closed |
| TXT / Markdown | literal or conservative structural handling | no speculative semantic upgrade |

## Notes And Footnotes

Shared note IR is available when a source has enough structure:

* DOCX lowers footnote/endnote references and bodies through the v2 model.
* Markdown native footnotes lower through the same shared note path.
* EPUB and HTML support explicit same-document noteref/body pairs.
* PDF can attach superscript-like markers as marker-only note references but
  does not associate note bodies.

Converters should not emit dangling Markdown footnotes when a body cannot be
resolved safely.

## PDF And OCR Boundary

PDF support means native PDF extraction. It does not imply OCR.

Current PDF facts:

* normal PDF conversion does not OCR
* forcing OCR on PDF fails closed in this build
* report-only scan diagnostics do not change output
* image OCR support does not imply scanned-PDF support
* any future PDF OCR path must remain explicit and provider-audited

Current image OCR facts:

* image inputs auto-OCR through the main CLI
* `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are supported for the current
  image OCR policy
* OCR uses the MoonBit-owned `convert/vision` path
* missing local Tesseract support fails clearly

## Quality-Lab Relation

The main repo remains self-contained for runtime, `moon test`, and
`bash samples/check.sh`.

The optional `markitdown-quality-lab/` checkout is used for larger external
quality rows, benchmark payloads, OCR artifacts, and offline diagnostics. It is
not part of the shipped runtime.

For validation workflow, see [quality-and-release.md](./quality-and-release.md).
For known limits and deferred decisions, see [format-limits.md](./format-limits.md).
