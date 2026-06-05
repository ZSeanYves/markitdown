# Supported Formats

This page is the current support and limits contract for the normal product
path.

It describes what the shipped runtime is meant to do, what it explicitly does
not do, and how to read support claims conservatively.

## Scope

Current goals:

* recover useful Markdown structure from common document formats
* emit assets and metadata sidecars where explicitly supported
* degrade conservatively on ambiguous behavior
* fail closed on unsupported or unsafe inputs

Current non-goals for the default path:

* browser-grade rendering
* hidden OCR fallback
* visual page reconstruction
* remote fetch
* DRM handling
* model-backed runtime classification

## Format Matrix

| Format | Current support | Important limits |
| --- | --- | --- |
| DOCX | headings, paragraphs, links, structured footnotes/endnotes, comments, images, tables, text boxes | not a Word layout engine |
| PPTX | titles, bullets, links, notes, tables, grouped content, images | not a PowerPoint visual layout engine |
| XLSX | workbook/sheet/cell lowering, typed cells, conservative formula handling | no full spreadsheet recalculation engine |
| PDF | native text-PDF extraction, high-confidence URI annotation links, images, annotations, narrow text-flow/layout cleanup; report-only scan diagnostics on explicit debug/helper paths | no scanned/image-only OCR in the normal path; PDF OCR not wired; no PDF footnote body association yet |
| PNG / JPG / JPEG / BMP / WEBP / TIF / TIFF | image OCR supported through `convert/vision` on the main CLI | requires local `tesseract`; `--ocr-lang <LANG>` is supported for image OCR; `--no-ocr` fails clearly because no native image path exists; PDF OCR is still not wired |
| ZIP | supported-entry dispatch, assets, metadata, origin tracking | no recursive archive explosion |
| EPUB | OPF/spine/nav/NCX/XHTML chapter lowering, explicit `epub:type="noteref"` / `role="doc-noteref"` footnotes | unsupported media stays explicit; broad HTML-style footnote inference is not attempted |
| HTML / HTM | safe tolerant parsing, structural lowering, explicit same-document noteref/body pairs | no JS, CSS layout, or browser engine; ordinary superscript text is not treated as a footnote by itself; broader conservative noteref inference is future work |
| CSV / TSV | conservative table lowering and dialect handling | not an arbitrary spreadsheet model |
| JSON / YAML | source-preserving or conservative structured lowering | malformed input fails closed |
| XML | conservative source-preserving and structure-aware lowering | no schema-driven semantic reconstruction |
| TXT / Markdown | literal or conservative structural handling | no speculative semantic upgrade |

## Note Support Matrix

Notes lower through the shared IR when a converter has enough evidence to do so
safely. Full Markdown footnotes require both a reference and a resolved body;
otherwise the output stays conservative.

| Format | Note refs | Note definitions | Output mode | Safety policy | Status |
| --- | --- | --- | --- | --- | --- |
| DOCX | `footnoteReference` and `endnoteReference` | `footnotes.xml` and `endnotes.xml` | full Markdown footnotes | uses OOXML structure instead of visual guessing | supported |
| Markdown | native `[^id]` references | native `[^id]: body` definitions | passthrough or normalized full Markdown footnotes | missing bodies stay marker-only instead of inventing definitions | supported |
| EPUB | explicit `epub:type="noteref"` or `role="doc-noteref"` with same-document `href="#id"` | footnote-like target body in the same XHTML document | full Markdown footnotes with spine-scoped ids | missing targets stay normal links; ids are namespaced by spine entry | supported for strong noteref |
| HTML / HTM | explicit same-document noteref/body pairs only | footnote-like body target when explicitly referenced | full Markdown footnotes only for resolved explicit pairs | ordinary links remain links; bare `<sup>` remains text | limited explicit support; conservative inference is future |
| PDF | detected superscript-like markers | not associated yet | marker-only fallback such as `^3` | does not emit dangling `[^3]` Markdown footnotes without a resolved body | partial safe fallback |

Metadata sidecars currently describe document blocks, assets, origin metadata,
and document-level `note_definitions` when resolved note bodies are present.

## Cross-Cutting Rules

Across the normal product path:

* Markdown is the primary reading output
* assets and metadata are companion engineering outputs
* `--with-metadata` is opt-in
* stdout mode emits Markdown only
* ambiguous features should degrade conservatively

## PDF And OCR Limits

Current PDF/OCR rules:

* the normal path targets native text PDFs
* normal conversion never OCRs and never probes OCR providers
* main-CLI OCR policy flags `--ocr`, `--no-ocr`, and `--ocr-lang <LANG>` are
  supported
* image inputs now auto-OCR through `convert/vision`
* product image OCR depends on a local `tesseract` executable and language
  data
* `markitdown-mb image.png --ocr-lang eng` passes `eng` to Tesseract image OCR
  and still requires installed tessdata; there is no language auto-detection
* current image OCR is shipped for common image formats
* no `--psm`, `--oem`, or OCR provider-selection CLI options are wired yet
* encrypted PDFs fail closed
* image/scanned PDFs are not silently upgraded into OCR
* scanned PDF OCR is not supported yet
* image inputs fail clearly when local `tesseract` is unavailable instead of
  silently falling through the native converter
* forcing `--ocr` on PDF currently fails closed because no explicit PDF OCR
  provider path is wired
* report-only PDF scan diagnostics may flag low-text or image-heavy PDFs on
  explicit debug/helper paths, but they do not change normal conversion output
* image OCR support does not imply scanned-PDF OCR support
* PDF OCR remains a future explicit provider path
* any future PDF OCR path must stay explicit opt-in and must not auto-fallback
  from native PDF extraction
* default layout cleanup stays narrow and deterministic
* PDF text-flow cleanup can merge high-confidence same-flow fragments, split
  numbered headings, attach superscript markers, and preserve conservative
  two-column guards
* PDF URI annotation links can become Markdown links only when visible text and
  URI annotation alignment is high-confidence
* image OCR shares the MoonBit-owned `convert/vision` path
* the current Vision/OCR chain remains the only OCR implementation path:
  `tesseract TSV -> OCRPageModel -> layout -> Markdown preview`
* current semantic hints such as `TableLike`, `KeyValueLike`, and
  `CaptionLike` are a side-channel only
* those hints do not currently reconstruct Markdown tables, key-value layouts,
  or captions

Still out of scope for the normal path:

* page-raster inference
* provider-backed runtime model loading
* broad offline-model-driven heading or receipt classification
* hidden OCR promotion

OCR groundwork now lives under `convert/vision`; the PDF converter does not own
OCR providers, and the normal dispatcher still does not route through OCR.

Main-repo OCR samples should stay tiny, license-clean, and provider-independent
where possible. Real-world OCR corpora belong in `markitdown-quality-lab`.

See [pdf.md](./pdf.md) for the detailed PDF text/layout/OCR boundary.

## Quality-Lab Relation

The main repo remains self-contained for:

* runtime
* `moon test`
* `bash samples/check.sh`

The optional repo-root quality-lab is used for:

* full quality rows
* external corpus payloads
* offline PDF layout training/eval/model/report assets

## How To Read Support Claims

Support claims in this repository are:

* local validation-backed
* sample-scoped
* format-scoped
* boundary-aware

They are not:

* blanket compatibility guarantees
* universal completeness percentages
* claims that every edge case is covered

For validation workflow, use [quality-and-release.md](./quality-and-release.md).
For sample-scoped performance interpretation, use [performance.md](./performance.md).
