# PDF v2 Main-chain Parity Gap Report

## 1. Scope

- inspected v1 files:
  - `convert/convert/dispatcher.mbt`
  - `convert/convert/test/dispatcher_registry_test.mbt`
  - `convert/pdf/pdf_parser.mbt`
  - `convert/pdf/pdf_to_ir.mbt`
  - `convert/pdf/pdf_lines.mbt`
  - `convert/pdf/pdf_blocks.mbt`
  - `convert/pdf/pdf_classify.mbt`
  - `convert/pdf/pdf_layout_gate.mbt`
  - `convert/pdf/pdf_noise.mbt`
  - `convert/pdf/pdf_merge.mbt`
  - `convert/pdf/pdf_link_match.mbt`
  - `convert/pdf/pdf_table_detect.mbt`
  - `convert/pdf/pdf_image_caption.mbt`
  - `convert/pdf/pdf_annotation_emit.mbt`
  - `convert/pdf/pdf_form_emit.mbt`
  - `convert/pdf/pdf_outline_emit.mbt`
  - `convert/pdf/test/pdf_parse_test.mbt`
  - `convert/convert/test/origin_metadata_media_test.mbt`
  - `doc_parse/pdf/README.md`
  - `doc_parse/pdf/api/pdf_api.mbt`
  - `doc_parse/pdf/model/pdf_page_model.mbt`
- inspected v2 files:
  - `doc_parse/pdf_v2/*.mbt`
  - `doc_parse/pdf_v2/tests/*.mbt`
  - `convert/pdf_v2/*.mbt`
  - `convert/pdf_v2/tests/*.mbt`
  - `convert/pdf_v2/README.md`
  - `doc_parse/pdf_v2/README.md`
  - `docs/archive/pdf-v2-architecture.md`
- removed diagnostics scaffold:
  - `convert/pdf_v2/pdf_v2_pipeline_diagnostics.mbt`
  - `convert/pdf_v2/tests/goldens/*.diagnostics.txt`
  - diagnostics renderer and golden tests in `convert/pdf_v2/tests/pdf_v2_convert_boundary_test.mbt`
- current HEAD before changes:
  - `c7ff39f pdf-v2: add diagnostics goldens`

## 2. Removed Experimental Scaffold

- deleted files:
  - `convert/pdf_v2/pdf_v2_pipeline_diagnostics.mbt`
  - `convert/pdf_v2/tests/goldens/minimal_text.diagnostics.txt`
  - `convert/pdf_v2/tests/goldens/gate_disabled_text.diagnostics.txt`
  - `convert/pdf_v2/tests/goldens/unsupported_image_abstain.diagnostics.txt`
  - `convert/pdf_v2/tests/goldens/malformed_fail_closed.diagnostics.txt`
  - `convert/pdf_v2/tests/goldens/lowering_cap.diagnostics.txt`
- deleted tests:
  - `pdf v2 pipeline diagnostics render minimal ok result`
  - `pdf v2 pipeline diagnostics render gate disabled marker`
  - `pdf v2 pipeline diagnostics render abstain and skipped lowering`
  - `pdf v2 pipeline diagnostics render malformed err result`
  - `pdf v2 pipeline diagnostics render caps`
  - `pdf v2 pipeline diagnostics render stable text`
  - `pdf v2 diagnostics golden matches minimal text`
  - `pdf v2 diagnostics golden matches gate disabled text`
  - `pdf v2 diagnostics golden matches unsupported image abstain`
  - `pdf v2 diagnostics golden matches malformed fail closed`
  - `pdf v2 diagnostics golden matches lowering cap`
  - `pdf v2 diagnostics golden missing fixture failure is clear`
- removed exports:
  - `pdf_v2_pipeline_diagnostics_from_result`
  - `pdf_v2_render_pipeline_diagnostics_text`
  - `PdfV2PipelineDiagnosticStatus`
  - `PdfV2PipelineDiagnostics`
  - `PdfV2DiagnosticRow`
- README/doc cleanup:
  - `convert/pdf_v2/README.md` now points to main-chain parity and controlled dispatcher registration preparation.
  - `doc_parse/pdf_v2/README.md` now states diagnostics/goldens/adoption scaffold is stopped.
  - `docs/archive/pdf-v2-architecture.md` now records Productization Reset 1 and removes the diagnostics renderer/golden forward route.

## 2.1 Productization Reset 2 Update

- added narrow product bridge:
  - `convert/pdf_v2/pdf_v2_product_bridge.mbt`
  - `PdfV2ConvertPipelineResult -> @core.Document`
  - plain text fragments to paragraph blocks
  - optional visible page-break/empty-page blank-line blocks
  - optional low-confidence and unsupported-object notes as plain paragraphs
  - fail-closed pipeline error mapping to `@core.AppError`
  - minimal block origins from source name, page, block index, and first object reference
- intentionally unchanged:
  - dispatcher registration still points at the shipped v1 PDF path
  - old PDF runtime remains in place
  - no samples expected were updated
  - no quality-lab, model, external data, layout recovery, fallback, or semantic Markdown path was introduced

## 2.2 Productization Reset 3 Update

- active PDF registration:
  - `convert/convert/dispatcher.mbt` now routes the default `.pdf` arm to
    `@pdfv2conv.parse_pdf_v2`.
  - `convert/pdf_v2/pdf_v2_converter.mbt` is the dispatcher-facing wrapper from
    file path to `Result[@core.Document, @core.AppError]`.
  - `pdf/main.mbt` now uses the same v2 bridge because the product CLI sample
    runner delegates PDF conversion through the standalone PDF component.
  - `convert/pdf` v1 remains on disk for rollback/reference; no fallback branch
    calls it from the dispatcher path.
- dispatcher defaults:
  - v2 gate disabled for first diff collection.
  - fact lowering ignores gate decisions.
  - product bridge notes, visible page breaks, and empty-page markers remain off.
  - no diagnostics text, semantic Markdown, image/link/table/form/layout
    recovery, quality-lab, model, or external-data path was added.
- expected diff runs:
  - `bash samples/check.sh --format pdf || true`
    - run: `.tmp/check/runs/pdf-20260611-113036-26817`
    - result: failed in the runner probe before comparisons because the active
      PDF output no longer matches the current v1-based expected sample.
  - main diff command with explicit built runners:
    - `MARKITDOWN_CLI="$PWD/_build/native/debug/build/cli/cli.exe" MARKITDOWN_PDF_CLI="$PWD/_build/native/debug/build/pdf/pdf.exe" MARKITDOWN_ZIP_CLI="$PWD/_build/native/debug/build/zip/zip.exe" bash samples/check.sh --format pdf || true`
    - run: `.tmp/check/runs/pdf-20260611-113458-28263`
    - result: Markdown log reports 30 PDF failures, with 26 diff files and 4
      conversion failures. The wrapper summary counters remain zero because the
      check exits through its failure path before row totals are written.
  - metadata-focused command:
    - same runner overrides with `bash samples/check.sh --metadata-only --format pdf || true`
    - run: `.tmp/check/runs/pdf-20260611-113702-28999`
    - result: metadata log reports 13 failures.
  - asset-focused command:
    - same runner overrides with `bash samples/check.sh --assets-only --format pdf || true`
    - run: `.tmp/check/runs/pdf-20260611-113702-29171`
    - result: asset log reports 7 failures.
  - no expected files were updated.
- Markdown failure inventory:
  - `assets/pdf_image_form_xobject`
  - `assets/pdf_image_inline`
  - `assets/pdf_image_xobject`
  - `hardwrap_en`
  - `hardwrap_zh`
  - `heading_basic`
  - `metadata/pdf_image_no_caption_negative`
  - `metadata/pdf_image_single_caption_like`
  - `metadata/pdf_metadata_image_caption`
  - `metadata/pdf_metadata_noise_merge`
  - `metadata/pdf_metadata_table_like`
  - `metadata/pdf_metadata_text_structure`
  - `metadata/pdf_metadata_uri_link`
  - `not_heading_sentence`
  - `pdf_cross_page_paragraph`
  - `pdf_cross_page_should_merge_phase15`
  - `pdf_cross_page_should_not_merge_phase15`
  - `pdf_header_footer_variants_phase15`
  - `pdf_heading_false_positive_phase15`
  - `pdf_heading_vs_short_sentence`
  - `pdf_image_caption_like`
  - `pdf_page_noise_cleanup`
  - `pdf_repeated_header_footer`
  - `pdf_repeated_header_footer_variants`
  - `pdf_simple_table_like`
  - `pdf_two_column_negative_phase15`
  - `pdf_uri_link_basic`
  - `text_hardwrap`
  - `text_multipage`
  - `text_simple`
- first diff categories:
  - fail-closed parser errors: 4 image/caption-related PDFs fail at
    `parse_pdf_v2_model_from_path` with `PdfError.Msg`.
  - decode/control-byte corruption: 13 text-oriented outputs contain NUL or
    invalid control characters, including hardwrap, heading, simple text,
    repeated header/footer, and metadata text/noise samples.
  - spacing/newline/hardwrap/cross-page shaping: broad across most non-empty
    diffs; line fragments often surface as `<br>` instead of paragraph-shaped
    Markdown.
  - page/order/layout/noise: cross-page, two-column, page-noise, repeated
    header/footer, and table-like samples differ because v2 has no product
    ordering repair or noise policy yet.
  - image/assets: 3 asset samples lose image Markdown/asset emission, and 4
    image/caption samples fail closed.
  - links: 2 URI samples emit plain text instead of safe Markdown links.
  - tables: 2 table-like samples emit separate text fragments instead of table
    blocks.
  - metadata/origin: metadata-only run has 6 sidecar failure rows; two samples
    produce invalid JSON sidecars due control characters, and two produce valid
    sidecars with `blocks`, `links`, or `summary` mismatches.
  - forms/annotations/outlines: no dedicated failures observed in this first
    PDF sample batch.
- first blockers to fix after registration:
  - repair parser text decoding/control bytes and the fail-closed image/caption
    parser cases first.
  - then fix text shaping, order, page-crossing behavior, and noise filtering.
  - then add product metadata/origin parity, followed by images, links, and
    tables.
  - keep semantic headings/lists and model integration deferred until the plain
    text/object diff surface is stable.

## 2.3 Productization Reset 4 Update

- encoding/unicode audit:
  - `tonyfettes/encoding` is suitable for strict UTF-8 and UTF-16BE/LE decoding
    and is now used for explicit BOM decoding in the v2 text sanitizer.
  - `tonyfettes/unicode` was inspected but not imported; its useful data is
    internal/normalization-oriented for this need, so Reset 4 keeps a small
    local PDF text control-byte predicate.
  - mbtpdf text APIs already provide the main PDF font/text decode surface:
    `PdfText::text_extractor_of_font`, ToUnicode/CMap handling, WinAnsi/MacRoman
    font tables, PDFDocEncoding, UTF-16BE, UTF-8, GBK, and Shift-JIS helpers.
- parser hardening:
  - decoded text now passes through a parser-layer sanitizer before glyph
    candidates are reconstructed.
  - NUL, unsafe C0/C1 controls, and replacement characters are suppressed with
    decode warnings and reason tags; allowed PDF text whitespace is normalized
    to spaces.
  - sanitized glyph candidates preserve provenance while dropping unsafe product
    text and lowering high/medium decode confidence to low when data was
    suppressed.
  - span text no longer falls back to raw bytes for undecoded chars.
  - PDF object strings for metadata/forms/annotations/outlines decode through
    mbtpdf PDFDocString handling with explicit BOM/control suppression.
- malformed object boundary:
  - v2 now constructs `PdfRead` with mbtpdf malformed-PDF recovery enabled
    (`error_on_malformed=false`).
  - This is still the mbtpdf/v2 parser path, not a v1 fallback; unrecoverable
    documents or missing page trees continue to fail closed.
- focused tests:
  - sanitizer whitebox coverage for controls, CJK preservation, UTF-16BE BOM,
    and binary PDFDocString suppression.
  - parser coverage for sanitized control bytes in a real content stream.
  - malformed-xref recovery coverage proving a recoverable catalog/page tree
    opens without v1 fallback.
- expected diff runs:
  - main command with explicit built runners:
    - `MARKITDOWN_CLI="$PWD/_build/native/debug/build/cli/cli.exe" MARKITDOWN_PDF_CLI="$PWD/_build/native/debug/build/pdf/pdf.exe" MARKITDOWN_ZIP_CLI="$PWD/_build/native/debug/build/zip/zip.exe" bash samples/check.sh --format pdf || true`
    - run: `.tmp/check/runs/pdf-20260611-121940-35097`
    - result: Markdown log still reports 30 PDF failures, now all diff files
      and 0 conversion failure artifacts.
  - metadata-focused command:
    - same runner overrides with `bash samples/check.sh --metadata-only --format pdf || true`
    - run: `.tmp/check/runs/pdf-20260611-122002-35616`
    - result: metadata workspace has 7 diff files and 0 conversion/error
      artifacts.
  - asset-focused command:
    - same runner overrides with `bash samples/check.sh --assets-only --format pdf || true`
    - run: `.tmp/check/runs/pdf-20260611-122002-35628`
    - result: asset workspace has 7 diff files and 0 conversion/error artifacts.
  - generated main/metadata/assets workspaces contain 0 files with disallowed
    control bytes.
  - no expected files were updated.
- remaining blockers:
  - Markdown parity is still dominated by text shaping, hardwrap/cross-page
    merging, page/order/noise behavior, and missing semantic product lowering
    for images, links, and tables.
  - metadata sidecars are now valid enough to diff, but still lack v1 block,
    link, image, and summary parity.

## 3. v1 PDF Main-chain Capability Summary

| capability | v1 behavior | evidence file/test | notes |
|---|---|---|---|
| Dispatcher registration | Before Reset 3, `.pdf` was default-enabled and routed to `@pdf.parse_pdf`; Reset 3 changes the active route to `@pdfv2conv.parse_pdf_v2`. | `convert/convert/dispatcher.mbt`; `convert/convert/test/dispatcher_registry_test.mbt` | v1 behavior is retained here as the parity baseline, while active registration now uses `convert/pdf_v2`. |
| Converter entry | `parse_pdf` returns `@core.Document` and checks file existence. | `convert/pdf/pdf_parser.mbt` | OCR modes fail closed because OCR is not wired in this build. |
| Parser model | v1 lower layer returns `PdfDocumentModel` with metadata, pages, text blocks, images, annotations, forms, outlines, geometry, and source refs. | `doc_parse/pdf/api/pdf_api.mbt`; `doc_parse/pdf/model/pdf_page_model.mbt` | Model is parser-facing, not final Markdown. |
| Text extraction | Raw mbtpdf output is reconstructed into chars, spans, lines, blocks, then convert lines/blocks. | `doc_parse/pdf/README.md`; `convert/pdf/pdf_parser.mbt`; `convert/pdf/pdf_lines.mbt`; `convert/pdf/pdf_blocks.mbt` | Main text path is real PDF path, not synthetic only. |
| Text cleanup and hardwrap | Hardwrapped English, Chinese, and generic text samples match expected Markdown. | `convert/pdf/test/pdf_parse_test.mbt` hardwrap tests | Important expected-diff risk for v2. |
| Heading/list/plain paragraphs | Classify, layout gate, and final IR rules emit headings, paragraphs, and list items. | `convert/pdf/pdf_classify.mbt`; `convert/pdf/pdf_layout_gate.mbt`; `convert/pdf/pdf_to_ir.mbt`; `convert/pdf/pdf_to_ir_wbtest.mbt` | Includes numbered heading repair and conservative list gates. |
| Noise filtering | Header/footer/page-number/noise candidates are filtered before merge and IR. | `convert/pdf/pdf_noise.mbt`; `convert/pdf/pdf_layout_gate.mbt`; related wbtests | Strong sample-regression surface. |
| Paragraph merge | Adjacent text blocks merge through PDF-specific boundary rules. | `convert/pdf/pdf_merge.mbt`; `convert/pdf/pdf_merge_decision.mbt` | Affects spacing/newlines and expected Markdown shape. |
| URI links | High-confidence URI annotations attach as `RichParagraph` links. | `convert/pdf/pdf_link_match.mbt`; `convert/pdf/test/pdf_parse_test.mbt` URI link tests; `convert/convert/test/origin_metadata_media_test.mbt` | Metadata JSON records PDF URI annotation provenance. |
| Internal/named links | Internal destinations are emitted as annotation appendix notes, not inline URI links. | `convert/pdf/pdf_annotation_emit.mbt`; `convert/pdf/test/pdf_parse_test.mbt` internal/named destination tests | Avoids unsafe or ambiguous link Markdown. |
| Images | Image XObjects can be exported to assets and emitted as `ImageBlock`. | `convert/pdf/pdf_lines.mbt`; `convert/pdf/pdf_to_ir.mbt`; origin metadata media tests | Asset origins include page/object provenance. |
| Image captions | Nearby caption pairing is conservative and mirrors asset origin metadata. | `convert/pdf/pdf_image_caption.mbt`; `convert/pdf/test/pdf_parse_test.mbt`; `convert/convert/test/origin_metadata_media_test.mbt` | Ambiguous/missing captions are skipped. |
| Tables | Aligned table-like text can emit `RichTable`, including headerless numeric tables. | `convert/pdf/pdf_table_detect.mbt`; `convert/pdf/pdf_to_ir.mbt`; `convert/pdf/test/pdf_parse_test.mbt`; origin metadata media tests | Metadata JSON includes table payloads. |
| Forms | Visible widget forms append a `Forms` section with normalized values. | `convert/pdf/pdf_form_emit.mbt`; `convert/pdf/test/pdf_parse_test.mbt` text widget test | Hidden no-view widgets are suppressed. |
| Annotations | Visible/printable annotations append an `Annotations` section and dedupe notes. | `convert/pdf/pdf_annotation_emit.mbt`; pdfjs annotation tests | Hidden/no-view behavior is regression-tested. |
| Outlines/bookmarks | Non-redundant outlines append a `Bookmarks` section. | `convert/pdf/pdf_outline_emit.mbt`; `doc_parse/pdf/api/test/pdf_outline_extract_test.mbt`; `convert/pdf/pdf_to_ir_wbtest.mbt` | Redundant visible headings suppress extra outline output. |
| Metadata/origin | Blocks/assets carry origin metadata, page provenance, source names, and table/link/image payload metadata. | `convert/pdf/pdf_to_ir.mbt`; `convert/convert/test/origin_metadata_media_test.mbt` | Main-chain expected outputs depend on this. |
| Page provenance | Product blocks carry page origins; no dedicated page-break Markdown block was found in the v1 product path. | `convert/pdf/pdf_to_ir.mbt`; origin metadata tests | v2 has a fact fragment for page breaks, but not a product bridge. |
| Error/fallback | Missing input raises `AppError`; OCR request raises explicit unsupported error; parser errors propagate through the native path. | `convert/pdf/pdf_parser.mbt`; `doc_parse/pdf/api/pdf_api.mbt` | No v2-style fallback is involved in v1 dispatch. |

## 4. v2 Current Capability Summary

| capability | v2 status: real / partial / metadata-only / synthetic-only / scaffold / not implemented | evidence file/test | notes |
|---|---|---|---|
| Real PDF open/source path | real | `doc_parse/pdf_v2/pdf_v2_mbtpdf_adapter.mbt`; `doc_parse/pdf_v2/pdf_v2_parser.mbt`; `pdf_v2_mbtpdf_adapter_test.mbt` | Uses mbtpdf-backed adapter and path APIs. |
| Typed text source events | real / partial | `pdf_v2_text_events.mbt`; `pdf_v2_mbtpdf_adapter_test.mbt` | Covers text operators and conservative decode facts for small fixtures. |
| Char/span/line/block candidates | real / partial | `pdf_v2_char_reconstruction.mbt`; `pdf_v2_span_reconstruction.mbt`; `pdf_v2_line_reconstruction.mbt`; `pdf_v2_block_reconstruction.mbt`; adapter tests | Source-order facts exist; geometry is often unknown. |
| Normalized document model | real / partial | `pdf_v2_model_assembly.mbt`; `pdf_v2_parser.mbt`; model tests | Has pages, candidates, source refs, warnings, risks, summaries. |
| Layout facts | partial / scaffold | `pdf_v2_layout_facts.mbt`; layout tests | Reports status such as source-order-only/not-attempted, not true region recovery. |
| Object facts | metadata-only / partial | `pdf_v2_object_facts.mbt`; `pdf_v2_object_caps.mbt`; object tests | Images are metadata-only; links/forms/outlines/destinations are partial parser facts. |
| Object caps and unsupported reports | real / partial | `pdf_v2_object_caps.mbt`; object cap tests | Caps and reports are parser facts with warnings/risks. |
| FeatureSet | scaffold / partial | `pdf_v2_features.mbt`; feature tests | Exposes factual rows and risk signals, not semantic labels. |
| No-model gate | synthetic-only / scaffold | `pdf_v2_no_model_gate.mbt`; `pdf_v2_classifier_gate_contract_test.mbt` | Consumes synthetic feature rows in focused tests; not a trained classifier. |
| Semantic role decision shell | synthetic-only / scaffold | `pdf_v2_decision.mbt`; classifier gate tests | `PdfV2BlockRole` includes semantic roles but is not product lowering. Seal or delete before product registration unless intentionally revived later. |
| Fact-only lowerer | partial | `pdf_v2_fact_lowering.mbt`; `pdf_v2_convert_boundary_test.mbt` | Emits plain text, optional page break fragments, optional notes/placeholders. |
| Experimental path pipeline | real / partial | `pdf_v2_pipeline.mbt`; pipeline smoke tests | Runs parser model -> layout -> features -> optional gate -> fact lowerer from real PDF path. |
| Product `@core.Document` output | partial / plain text | `pdf_v2_product_bridge.mbt`; product bridge tests; `pdf_v2_converter.mbt`; dispatcher tests | Converts pipeline results to core documents for plain text, optional notes, optional explicit page-break blank lines, and fail-closed errors. Reset 3 routes dispatcher-facing PDF through this bridge. |
| Markdown headings/lists/tables/images/links/forms/outlines | not implemented | lowerer tests assert no semantic Markdown | v2 intentionally does not emit v1 product semantics yet. |
| Metadata/origin product surface | partial / minimal | `pdf_v2_product_bridge.mbt`; product bridge origin test | Block origins preserve source name, page, block index, and first object ref. No asset origin or document-level metadata parity yet. |
| Diagnostics renderer/goldens | removed | this reset | Not current route. |

## 5. v1 vs v2 Gap Matrix

| capability | v1 status | v2 status | gap type | expected diff risk | priority |
|---|---|---|---|---|---|
| Dispatcher entry | Previously registered default PDF path to v1 | Registered through v2 product bridge in Reset 3 | First-diff integration complete; parity gaps remain | High, confirmed by first diff | P0 closed for routing |
| Product output bridge | Returns `@core.Document` | Narrow plain-text bridge returns `@core.Document` from pipeline result | Remaining integration/semantic gap | High | P0 mostly closed before dispatcher |
| Plain text extraction | Real PDF to Markdown paragraphs | Real parser path, fact fragments, and plain paragraph bridge | Text shaping/order gap | High | P0 |
| Page/block ordering | Convert page objects interleave text/images by page object order | Source-order block candidates only | Ordering gap | High | P0 |
| Default gate behavior | v1 does not block plain text through a v2 no-model gate | v2 default gate can abstain on unsupported/capped context | First diff suppression risk | High | P0 |
| Error behavior | Raises app errors / native parse failures through main chain | Bridge maps pipeline errors to `@core.AppError`; dispatcher now returns the v2 bridge result | Parity/error-message gap | High | P0 routing closed |
| Metadata/origin | Product origins, asset origins, metadata JSON | Minimal block origins only | Product metadata gap | High | P0/P1 |
| Images | Asset export and `ImageBlock` | Image metadata candidates only | Capability missing | High | P1 |
| Image captions | Conservative caption association | No caption association/lowering | Capability missing | Medium-high | P1 |
| URI links | Inline `RichParagraph` links for safe high-confidence URI annotations | Link candidates/features only | Capability missing | High | P1 |
| Internal/named links | Annotation appendix notes | Destination/link facts partial | Product policy missing | Medium | P2 |
| Tables | `RichTable` for selected aligned tables | No table recovery/lowering | Capability missing | High | P1 |
| Forms | Visible forms appendix | Form facts partial | Product policy missing | Medium | P2 |
| Annotations | Visible/printable annotation appendix | Annotation facts partial | Product policy missing | Medium | P2 |
| Outlines | Optional bookmarks section | Outline/destination metadata candidates | Product policy missing | Medium | P2 |
| Headings/lists | Rule-heavy product semantics | Semantic role scaffold only; no output | Capability missing | High | P2 after text baseline |
| Noise/header/footer | Filtered/gated in v1 | No product noise policy | Capability missing | Medium-high | P2 |
| Hardwrap/spacing | Regression-tested expected Markdown | Basic source-order text fragments | Text shaping gap | High | P1 |
| Page breaks/provenance | Page origins in metadata; no dedicated product page-break block found | Default bridge ignores page breaks; opt-in explicit fragments become blank lines | Product policy mostly set for first diff | Medium | P2 |
| Model integration | No v2 model runtime | Deferred | Deferred plan | Low before parity | P3 |

## 6. Scaffold / Interface-only Items Still Present

- `PdfV2FeatureSet`:
  - Factual feature rows exist and are useful, but they are not trained model input in runtime yet.
- `pdf_v2_run_no_model_block_gate`:
  - Useful as a conservative guard, but it is not classifier inference and must not suppress the first dispatcher diff run by default.
- `PdfV2LayoutFactSet` and layout statuses:
  - Current layout is status/audit evidence, not true region recovery or reading-order repair.
- Object capability reports:
  - Valuable parser facts, but images are metadata-only and links/forms/annotations/outlines remain partial facts until convert policy lowers them.
- `PdfV2BlockRole` / `PdfV2BlockClassifierHint` / `decide_pdf_v2_block_role`:
  - Semantic role scaffold is still present.
  - Recommendation: seal behind tests only or delete before dispatcher registration unless the next model-integration batch explicitly revives it. It must not leak into product Markdown during main-chain parity work.
- `PdfV2FactFragmentKind::PageBreak`:
  - Default product bridge ignores page breaks.
  - Opt-in page break emission and explicit empty-page preservation use blank-line blocks.
- `lower_pdf_v2_document_scaffold`:
  - Historical scaffold output exists for boundary testing, not main-chain product output.

## 7. Dispatcher Registration Guards

- v2 pipeline result -> main convert output bridge:
  - Narrow plain-text `@core.Document` bridge exists.
  - Reset 3 connects it to the controlled dispatcher path.
  - Remaining work: add asset origins/document metadata only when corresponding
    product features exist.
- Plain text block/page ordering:
  - Produce useful paragraph blocks from real PDF path.
  - Keep page order and source order deterministic enough for expected diffs.
- Error behavior:
  - Map parser/pipeline failure into the dispatcher-facing `Result[@core.Document, @core.AppError]` contract.
  - Keep fail-closed behavior with no old PDF fallback.
- Default options:
  - Choose product-run defaults that keep text flowing for first diff collection.
  - Do not let no-model gate abstain block all text in the first controlled registration run.
- Product bridge defaults:
  - Keep visible page breaks disabled by default.
  - Keep low-confidence and unsupported-object notes disabled by default.
- No diagnostics in product output:
  - Warnings/risks can stay internal/audit facts.
  - Removed diagnostics renderer text must not be reintroduced as Markdown.
- No gate blocking first diff run:
  - Run gate disabled or text-preserving by default during the first expected-diff batch.
- Boundary guards:
  - Keep the dispatcher from importing old PDF runtime, mbtpdf vendor internals,
    quality-lab assets, or external model/data files.

## 8. Capabilities To Improve After Expected Diff

- Text missing:
  - Fill gaps in text events, decode, candidate grouping, block assembly.
- Decode:
  - Improve ToUnicode/CMap/encoding behavior only where expected diffs show missing or corrupted text.
- Spacing/newline:
  - Tune line and block grouping, hardwrap repair, hyphenation, CJK spacing, and paragraph joins.
- Page break/provenance:
  - Compare page-origin metadata and decide whether any visible page separator policy is needed.
- Links:
  - Add safe URI link lowering after plain text baseline is stable.
- Images:
  - Add image export/product image blocks after metadata-only facts are trusted.
- Tables:
  - Add conservative table lowering for aligned table cases after text ordering stabilizes.
- Metadata:
  - Add document/block/asset origin parity and metadata JSON parity.
- Forms/annotations/outlines:
  - Add appendix sections and bookmark handling after the core text/image/link/table diffs are understood.
- Headings/lists/noise:
  - Reintroduce semantic Markdown only as explicit parity work after plain-text diff noise is under control.

## 9. Model Integration Deferred Plan

- Two model paths are not done:
  - layout recovery model integration is not wired.
  - text/block classifier model integration is not wired.
- Rule/model cooperation is not done:
  - no runtime model artifact format exists.
  - no inference path exists.
  - no rule/model arbitration exists.
  - no confidence thresholds are calibrated.
  - no abstain policy is product-connected.
  - no v2 convert semantic policy consumes model output.
- Current preserved value:
  - parser facts, object facts, layout statuses, feature rows, warnings, risks, source refs, one-pass, and no-fallback flags.
- Deferred sequence:
  - stabilize main-chain text/object/layout signals.
  - extract training data from stable signals.
  - train and evaluate models outside runtime.
  - only after model quality is acceptable, design:
    - model artifact format
    - inference path
    - rule/model arbitration
    - confidence threshold
    - abstain policy
    - v2 convert semantic policy

## 10. Recommended Next Batch

- Do not rebuild diagnostics/adoption scaffolding.
- Do not load or train models.
- Narrow v2 product bridge is now present for plain text, minimal block origins,
  and fail-closed error mapping.
- Reset 3 has configured first-run defaults so no-model gate does not hide text
  during diff collection.
- Controlled dispatcher registration is active and first expected diffs are
  recorded above.
- Next fix text/decode/spacing/order first, then link/image/table/metadata, then forms/annotations/outlines, then headings/lists/noise.
- Start model integration only after the diff-driven parser signals are stable.

## Reset 5 Text Shaping And Noise Pass

- commit:
  - this change, target message `pdf-v2: improve text shaping and cleanup`
- focus:
  - product-level plain text shaping, conservative block/line ordering, CJK
    compatibility radical cleanup, hardwrap/hyphen repair, and narrow
    page-artifact suppression.
  - no fallback, no semantic Markdown lowering, no image/link/table/form or
    metadata lowering.
- commands:
  - `moon info && moon fmt`
  - `moon check doc_parse/pdf_v2 convert/pdf_v2 convert/convert pdf`
  - `moon test doc_parse/pdf_v2/tests convert/pdf_v2/tests convert/convert/test doc_parse/pdf_v2/tests`
  - `moon test convert/pdf_v2`
  - `git diff --check`
  - `moon build cli pdf zip`
  - `MARKITDOWN_CLI="$PWD/_build/native/debug/build/cli/cli.exe" MARKITDOWN_PDF_CLI="$PWD/_build/native/debug/build/pdf/pdf.exe" MARKITDOWN_ZIP_CLI="$PWD/_build/native/debug/build/zip/zip.exe" bash samples/check.sh --format pdf || true`
  - same explicit runner command with `--metadata-only --format pdf || true`
  - same explicit runner command with `--assets-only --format pdf || true`
- before:
  - main PDF run `.tmp/check/runs/pdf-20260611-121940-35097`: 30 Markdown
    failures, all diffs, 0 conversion failure artifacts, 0 generated files with
    disallowed control bytes.
  - metadata-only run `.tmp/check/runs/pdf-20260611-122002-35616`: 7 Markdown
    diff files, 0 conversion/error artifacts, 0 disallowed control-byte files.
  - assets-only run `.tmp/check/runs/pdf-20260611-122002-35628`: 7 Markdown
    diff files, 0 conversion/error artifacts, 0 disallowed control-byte files.
- after:
  - main PDF run `.tmp/check/runs/pdf-20260611-130026-40884`: log reports 29
    Markdown failures. Workspace has 30 diff files, 29 non-empty diffs, and one
    empty `text_multipage.diff` artifact. Conversion/error artifacts: 0.
    Disallowed control-byte files: 0.
  - metadata-only run `.tmp/check/runs/pdf-20260611-130055-41422`: log reports
    13 metadata failures, with 7 Markdown diff files plus sidecar mismatches.
    Conversion/error artifacts: 0. Disallowed control-byte files: 0.
  - assets-only run `.tmp/check/runs/pdf-20260611-130055-41453`: 7 Markdown
    diff files. Conversion/error artifacts: 0. Disallowed control-byte files: 0.
- fixed cases:
  - `text_multipage` Markdown now matches expected; only an empty diff artifact
    remains in the workspace.
  - `hardwrap_en` is reduced to heading-only difference: paragraphs, ligature
    output, and `inter-` line wrap are repaired.
  - `text_hardwrap` is reduced to heading-only difference: English and CJK
    hardwraps are joined and observed CJK radical glyphs normalize.
  - `pdf_cross_page_paragraph` now emits paragraph-shaped text without `<br>`
    artifacts, expands common ligature glyphs, and drops the isolated page
    number inside the paragraph.
  - `pdf_repeated_header_footer` drops repeated `Project Report` headers and
    repairs common `fi` ligature-word splits; remaining footer/body merge still
    needs stronger line/block facts.
- regressions:
  - none observed in validation. Some CJK heading-like lines now remain plain
    paragraphs rather than headings; heading semantics are still intentionally
    out of scope.
- remaining failures:
  - 29 non-empty main Markdown diffs remain.
  - Text-only remaining issues are dominated by missing heading semantics,
    limited block boundary inference, footer/header variants embedded in
    multi-line fragments, and table/two-column ordering.
  - Non-text remaining issues are unchanged: images/assets, URI links, table
    lowering, and metadata sidecar parity.
- remaining categories:
  - text: heading/list semantics deferred, more line/block boundaries, stronger
    page-label cleanup for split `第/页` fragments, repeated footer variants.
  - layout/order: two-column and table-like source-order limitations.
  - product lowering: image/link/table/metadata parity still not implemented.
- next fix batch:
  - move simple page-artifact and hardwrap cues closer to parser block/line
    facts where source boundaries are available.
  - add conservative heading/list/table/link/image product lowering only after
    plain text boundaries are stable.

## Reset 6 Heading And Block Boundary Pass

- commit:
  - this change, target message `pdf-v2: add minimal heading and boundary parity`
- focus:
  - minimal product-bridge heading parity for obvious title-shaped plain text.
  - stronger output block-boundary cues for title/body separation and hardwrap
    continuation, including split CJK body fragments.
  - narrow page-label cleanup for `第` / `页` and joined `第页` prefixes.
  - no fallback, model, image/link/table/form/metadata lowering, or v1 PDF
    runtime changes.
- commands:
  - `moon info && moon fmt`
  - `moon check doc_parse/pdf_v2 convert/pdf_v2 convert/convert pdf`
  - `moon test doc_parse/pdf_v2/tests convert/pdf_v2/tests convert/convert/test doc_parse/pdf_v2/tests`
  - `moon test convert/pdf_v2`
  - `git diff --check`
  - `moon build cli pdf zip`
  - `MARKITDOWN_CLI="$PWD/_build/native/debug/build/cli/cli.exe" MARKITDOWN_PDF_CLI="$PWD/_build/native/debug/build/pdf/pdf.exe" MARKITDOWN_ZIP_CLI="$PWD/_build/native/debug/build/zip/zip.exe" bash samples/check.sh --format pdf || true`
  - same explicit runner command with `--metadata-only --format pdf || true`
  - same explicit runner command with `--assets-only --format pdf || true`
- before:
  - Reset 5 main PDF run `.tmp/check/runs/pdf-20260611-130026-40884`: log
    reports 29 Markdown failures, with 30 diff files and 29 non-empty diffs.
  - `hardwrap_en` and `text_hardwrap` were reduced to heading-only or mostly
    heading/block-boundary diffs.
  - `hardwrap_zh` still had missing headings plus CJK body line splits.
  - `pdf_page_noise_cleanup` still surfaced split `第` / `页` artifacts.
  - metadata-only and assets-only runs remained at 13 metadata failures and 7
    asset Markdown diff files.
- after:
  - main PDF run `.tmp/check/runs/pdf-20260611-133518-45770`: log reports 23
    Markdown failures. Workspace has 30 diff files, 23 non-empty diffs, and 7
    empty diff artifacts for now-matching samples. Conversion/error artifacts:
    0. Disallowed control-byte files: 0.
  - metadata-only run `.tmp/check/runs/pdf-20260611-133559-46341`: log reports
    13 metadata failures, with 7 Markdown diff files plus sidecar mismatches.
    Conversion/error artifacts: 0. Disallowed control-byte files: 0.
  - assets-only run `.tmp/check/runs/pdf-20260611-133559-46376`: 7 Markdown
    diff files. Conversion/error artifacts: 0. Disallowed control-byte files: 0.
- fixed cases:
  - `hardwrap_en` now matches expected Markdown, including `# Document
    Conversion Pipeline`.
  - `text_hardwrap` now matches expected Markdown, including `# Hard Wrap Test`
    and joined English/CJK hardwraps.
  - `hardwrap_zh` now matches expected Markdown, including `# 研究内容`, `#
    技术路线`, joined CJK body text, and `统一 IR` repair.
  - `pdf_page_noise_cleanup` now matches expected Markdown by removing split and
    joined CJK page-label prefixes.
  - `not_heading_sentence`, `text_simple`, and `text_multipage` remain matching
    and only produce empty diff artifacts in the runner workspace.
- regressions:
  - none observed in check/test/sample validation.
  - Remaining heading-heavy samples such as `heading_basic`,
    `pdf_heading_vs_short_sentence`, and
    `pdf_heading_false_positive_phase15` still need parser-level block
    boundaries and richer heading/list policy; this reset intentionally did not
    implement full classifier semantics.
- remaining failures:
  - 23 non-empty main Markdown diffs remain.
  - Metadata-only remains at 13 failures; asset-only remains at 7 Markdown diff
    files.
- remaining categories:
  - text: complex heading samples, list bullets, cross-page paragraph edge cases,
    repeated header/footer variants, and table/two-column ordering.
  - product lowering: images/assets, image captions, URI links, tables, and
    metadata sidecar parity are still not implemented.
  - model/layout: no layout recovery model or semantic classifier path is wired.
- next fix batch:
  - improve parser block reconstruction around real heading/body boundaries,
    especially `heading_basic` and `pdf_heading_vs_short_sentence`.
  - add conservative list-item lowering only after block boundaries are stable.
  - then tackle URI links and image/table product lowering before metadata
    sidecar parity.

## Reset 7 v1 Rule Audit

- v1 useful ideas:
  - run hard guards before promotion: page-number/noise, caption-like prefixes,
    list markers, intro phrases, sentence punctuation, and overlong bodies block
    heading promotion.
  - require context for weak headings: short title-shaped lines need following
    body/list context, parser heading evidence, geometry gaps, or font support.
  - keep list lowering anchored at block start and use the core
    `Block::ListItem(ordered, level, text)` representation.
  - normalize obvious heading text only at the product boundary, such as CJK
    chapter spacing and clear numbered subsection depth.
- v1 pitfalls to avoid:
  - heading/list behavior is split across classify, layout gate, merge, and IR
    lowering, which makes later fixes patch-shaped and hard to replace.
  - final IR still contains special-case repairs such as run-in heading splits
    and list gates, so semantic policy is not a single module boundary.
  - layout/image/table/link rules live close to text semantics; copying that
    shape into v2 would widen this reset beyond heading/list/paragraph scope.
- v2 design choices:
  - introduce a centralized text-only semantic system:
    `PdfV2TextFlow -> PdfV2RuleDecision -> arbitration -> PdfV2SemanticBlock`.
  - keep heading/list/paragraph/noise decisions in `pdf_v2_semantic_rules.mbt`
    and leave product bridge as a mapper to `@core.Document`.
  - add a future model hint interface with rule-hard-constraint precedence, but
    keep runtime model hints absent and do not read model/data files.
  - preserve parser/fact source refs and block/page indexes through flow units
    and semantic blocks.

## Reset 7 Rule-based Semantic Block System

- commit:
  - this change, target message `pdf-v2: add rule-based semantic blocks`
- focus:
  - replace Reset 6 minimal heading helper with a centralized rule-based
    semantic block system for text flow, headings, ordered/unordered list
    items, continuation paragraphs, plain text, and unknown fallback.
  - keep scope text-only; no caption/table/image/link/form/OCR/layout-model
    lowering.
- v1 rule audit:
  - useful guard/context ideas were retained, but v1's distributed nested
    classify/layout/IR patch route was not copied.
- v2 semantic rule design:
  - `pdf_v2_text_flow.mbt` builds source-ref preserving flow units with marker,
    page-number, caption, body-following, previous-heading, and continuation
    signals.
  - `pdf_v2_semantic_rules.mbt` owns all heading/list/paragraph/noise decisions
    with numbered rule IDs.
  - `pdf_v2_semantic_model.mbt` defines internal semantic kinds, flow signals,
    decisions, semantic blocks, and future model hint shapes.
  - `pdf_v2_semantic_arbitration.mbt` accepts high-confidence rules, forces
    hard-negative rule fallback, and degrades weak rules to plain paragraph
    fallback.
- model hook status:
  - `PdfV2ModelHint`, `PdfV2SemanticArbitrationInput`, and
    `PdfV2SemanticArbitrationResult` exist.
  - model hint is absent in runtime, ignored by first-version arbitration, and
    no model file/data is read or trained.
- commands:
  - `moon info && moon fmt`
  - `moon check doc_parse/pdf_v2 convert/pdf_v2 convert/convert pdf`
  - `moon test doc_parse/pdf_v2/tests convert/pdf_v2/tests convert/convert/test doc_parse/pdf_v2/tests`
  - `moon test convert/pdf_v2`
  - `git diff --check`
  - `moon build cli pdf zip`
  - `bash samples/check.sh --format pdf || true`
  - explicit built runner command with `bash samples/check.sh --format pdf || true`
  - same explicit built runner command with
    `bash samples/check.sh --metadata-only --format pdf || true`
  - same explicit built runner command with
    `bash samples/check.sh --assets-only --format pdf || true`
- before:
  - Reset 6 main PDF run `.tmp/check/runs/pdf-20260611-133518-45770`: 23
    non-empty Markdown diffs, 30 diff files, 7 empty matching artifacts.
- after:
  - default command run `.tmp/check/runs/pdf-20260611-140357-49287`: runner
    summary still exits before row accounting, so explicit built runners remain
    the comparable source.
  - main explicit run `.tmp/check/runs/pdf-20260611-140732-51143`: log reports
    23 Markdown failures. Workspace has 30 diff files, 23 non-empty diffs, and
    7 empty matching artifacts. Conversion/error artifacts: 0.
  - metadata-only run `.tmp/check/runs/pdf-20260611-140932-52035`: log reports
    13 metadata failures, with 7 Markdown diff files plus sidecar mismatches.
    Conversion/error artifacts: 0.
  - assets-only run `.tmp/check/runs/pdf-20260611-140932-52036`: log reports 7
    asset-scope Markdown failures. Conversion/error artifacts: 0.
- heading cases:
  - `heading_basic` and `metadata/pdf_metadata_text_structure` still fail
    because parser block boundaries merge top-level CJK heading/body and split
    `1.1 研究目标`; semantic rules now infer the visible `1.1 研究` fragment as
    H2 instead of Reset 6's H1.
  - `pdf_heading_vs_short_sentence` improves over Reset 6 for the first title
    and `Introduction`: output now has `# Heading vs Short Sentence` and
    `## Introduction`; `Method` is still H1 because current context does not
    know a preceding same-depth section, and list/body lines remain merged.
  - `pdf_repeated_header_footer_variants` improves `Summary` from merged
    paragraph text to `## Summary`; later headings still carry parser noise
    prefixes (`/ Details`, `/ Conclusion`).
- list cases:
  - synthetic/system tests cover `-`, `*`, `•`, `1.`, `1)`, `(1)`, and
    `（一）` marker lowering to core `ListItem`.
  - sample list bullets in `pdf_heading_vs_short_sentence` remain unlowered
    because parser/fact output currently merges `Key points: • First item •
    Second item ...` into one flow unit.
- regressions:
  - no failure-count regression observed: main Markdown remains at 23 non-empty
    diffs, metadata-only remains 13 failures, and assets-only remains 7
    failures.
  - Some individual diff shapes changed as semantic rules now emit more
    headings; remaining mismatches are documented above and stem from parser
    block-boundary/noise limits rather than fallback or non-text lowering.
- remaining failures:
  - main Markdown non-empty diffs: 23.
  - unchanged matching/empty-diff artifacts: `hardwrap_en`, `hardwrap_zh`,
    `not_heading_sentence`, `pdf_page_noise_cleanup`, `text_hardwrap`,
    `text_multipage`, and `text_simple`.
  - metadata-only: 13 failures.
  - assets-only: 7 failures.
- remaining categories:
  - parser text boundaries: CJK heading/body merges, split heading suffixes,
    list bullets merged into lead-in paragraphs, and page-noise prefixes.
  - layout/order/noise: cross-page paragraph variants, repeated header/footer
    variants, two-column ordering, and table-like ordering.
  - product lowering: images/assets, image captions, URI links, tables, and
    metadata sidecar parity remain intentionally out of this reset.
- next fix batch:
  - improve parser/fact block reconstruction around heading/body/list
    boundaries before adding richer semantic rules.
  - add a narrow cleanup for repeated header/footer variant prefixes only after
    source-boundary evidence is available.
  - then tackle URI links and image/table product lowering before metadata
    sidecar parity.
