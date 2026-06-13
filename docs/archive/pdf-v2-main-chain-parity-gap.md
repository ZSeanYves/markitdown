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
| Object facts | partial | `pdf_v2_object_facts.mbt`; `pdf_v2_object_caps.mbt`; object tests | Images keep metadata facts and can include materializable asset candidates when bytes are available; links/forms/outlines/destinations are partial parser facts. |
| Object caps and unsupported reports | real / partial | `pdf_v2_object_caps.mbt`; object cap tests | Caps and reports are parser facts with warnings/risks. |
| FeatureSet | scaffold / partial | `pdf_v2_features.mbt`; feature tests | Exposes factual rows and risk signals, not semantic labels. |
| No-model gate | synthetic-only / scaffold | `pdf_v2_no_model_gate.mbt`; `pdf_v2_classifier_gate_contract_test.mbt` | Consumes synthetic feature rows in focused tests; not a trained classifier. |
| Semantic role decision shell | synthetic-only / scaffold | `pdf_v2_decision.mbt`; classifier gate tests | `PdfV2BlockRole` includes semantic roles but is not product lowering. Seal or delete before product registration unless intentionally revived later. |
| Fact-only lowerer | partial | `pdf_v2_fact_lowering.mbt`; `pdf_v2_convert_boundary_test.mbt` | Emits plain text, optional page break fragments, optional notes/placeholders. |
| Experimental path pipeline | real / partial | `pdf_v2_pipeline.mbt`; pipeline smoke tests | Runs parser model -> layout -> features -> optional gate -> fact lowerer from real PDF path. |
| Product `@core.Document` output | partial | `pdf_v2_product_bridge.mbt`; product bridge tests; `pdf_v2_converter.mbt`; dispatcher tests | Converts pipeline results to core documents for text blocks, safe URI inline links, materialized image assets when bytes are available, conservative text tables, optional notes, optional explicit page-break blank lines, and fail-closed errors. Reset 3 routes dispatcher-facing PDF through this bridge. |
| Markdown headings/lists/links | partial | product bridge and semantic tests | Text semantics and safe URI inline links are rule/fact based; unsafe/ambiguous/non-URI links stay plain text. |
| Markdown images/assets | partial / materialized when bytes available | product bridge image tests | v2 emits `ImageBlock` only after a real asset path is materialized, writes supported JPEG/BMP assets, suppresses unavailable images from visible Markdown, and still does not infer captions. |
| Markdown tables | partial / conservative | product bridge table tests | v2 emits `RichTable(TableData)` for coherent pipe tables and reliable simple aligned text tables; malformed rows, captions, lists, paragraphs, image tables, and merged/layout tables stay out of scope. |
| Markdown forms/outlines | not implemented | lowerer tests and boundary guard | v2 still does not emit form, outline, caption, or figure product blocks. |
| Metadata/origin product surface | partial | `pdf_v2_product_bridge.mbt`; product bridge origin, metadata, link, image, and table tests | Block origins preserve source name, page, block index, and first object ref; document metadata sidecars use parser metadata. Materialized image assets are indexed in `asset_origins`; richer table/link sidecar payload parity still depends on later metadata work. |
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
| Metadata/origin | Product origins, asset origins, metadata JSON | Block origins, document metadata sidecars, and image placeholder asset origins are partial | Remaining table/link payload and real asset export gap | High | P0/P1 |
| Images | Asset export and `ImageBlock` | Metadata-only `ImageBlock` placeholders with asset origins; no byte export | Export/caption parity gap | High | P1 partial |
| Image captions | Conservative caption association | No caption association/lowering | Capability missing | Medium-high | P1 |
| URI links | Inline `RichParagraph` links for safe high-confidence URI annotations | Safe page-local URI inline links supported; ambiguous/unsafe/non-URI links stay plain | Remaining sidecar/provenance and complex association gap | Medium | P1 partial |
| Internal/named links | Annotation appendix notes | Destination/link facts partial | Product policy missing | Medium | P2 |
| Tables | `RichTable` for selected aligned tables | Conservative pipe/simple aligned text tables lower to `RichTable`; visual/layout tables remain absent | Layout/cell recovery gap | High | P1 partial |
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

## Reset 8A Parser Fact Alignment Audit

- focus:
  - audit v1 parser/convert rule intent and map it to the v2 parser fact model
    needed by the Reset 7 rule-based semantic block system.
  - document the next parser fact batches without changing parser/convert code
    or sample expected outputs.
- v1 rule audit summary:
  - useful v1 intent is fact-driven: text shape, markers, punctuation, page
    labels, caption guards, gaps, indents, font deltas, first/last line
    summaries, page edge zones, repeated edge text, and boundary continuation
    evidence all feed heading/list/paragraph decisions.
  - v1 pitfalls to avoid are the distributed patch shape across line/block
    staging, classify, layout gate, merge, noise, and final IR repair.
- v2 fact coverage summary:
  - present: source refs, source order, decode confidence, geometry confidence,
    candidate line/block arrays, weak block hints, object facts, layout coverage
    scaffold, and feature rows.
  - partial: bbox, baseline, gap, indent, font/style, text shape, and block
    boundary reason tags.
  - convert-only: Reset 7 text-flow marker/page-number/caption/title signals
    and semantic decisions.
  - missing: parser-owned line text signals, marker/body split facts,
    page-number/page-label/caption-like candidates, repeated edge artifacts,
    block boundary scores, text-flow candidates, and page-relative layout/font
    summaries.
- biggest parser fact gaps:
  - `LineTextSignal` for normalized text shape and guards.
  - `LineLayoutSignal` for page-relative geometry, indent, font, and edge-band
    evidence.
  - `BlockBoundarySignal` for continuation/new-paragraph/new-block evidence.
  - `PageArtifactCandidate` for page labels, page numbers, repeated edge text,
    and caption-like guards.
  - `TextFlowCandidate` so convert can consume parser-owned flow units instead
    of rebuilding them from plain fragments.
- proposed fact model:
  - full proposal recorded in
    `docs/archive/pdf-v2-parser-fact-alignment.md`.
  - parser/model produces neutral facts and candidates; convert semantic rules
    remain responsible for final paragraph/heading/list decisions and core
    lowering.
- recommended next implementation batch:
  - Reset 8B: add parser-owned `LineTextSignal` plus marker/page-label/
    caption-like candidates.
  - Reset 8C: add block first/last line summaries and `BlockBoundarySignal`.
  - Reset 8D: add repeated edge artifact aggregation.
  - Reset 8E: make Reset 7 semantic rules consume parser facts and retire
    duplicate convert-only string guesses where parser facts exist.

## Reset 8B-F Parser Facts To Semantic Consumption

- facts implemented:
  - Parser-owned `PdfV2LineTextSignal`, `PdfV2BlockBoundarySignal`,
    `PdfV2TextFlowCandidate`, and `PdfV2PageArtifactCandidate`.
  - Line candidates embed text signals; block candidates embed boundary
    signals.
  - Text-flow candidates preserve original/normalized lines, line indices,
    source refs, parser scores, and page artifact refs.
- model integration:
  - `pdf_v2_build_text_flow_candidates(model)` builds parser-owned flow
    candidates from the document model.
  - Convert fact lowering now carries candidates only for blocks that were
    actually emitted as plain text after gate/cap decisions.
- semantic consumption path:
  - Product bridge consumes parser-owned flow candidates through the semantic
    engine when they carry currently actionable evidence, and preserves the
    fragment-derived flow path for normalized paragraph behavior.
  - Heading/list/continuation/page-noise rules consume parser facts and keep
    final semantic decisions centralized in `pdf_v2_semantic_rules.mbt`.
  - Fragment-derived flow remains as a compatibility path for manually
    constructed pipeline outputs and semantic-disabled behavior, not as v1 PDF
    fallback.
- page artifact behavior:
  - Page-number candidates suppress output when
    `suppress_page_number_like_noise` is enabled.
  - Repeated short-line artifact candidates suppress output when
    `suppress_repeated_page_artifact_noise` is enabled.
  - Normal titles such as `第一章` are guarded from page-number/repeated-artifact
    suppression.
- model hook status:
  - Existing `PdfV2ModelHint`/arbitration API remains present.
  - Runtime model hint remains absent; no model/data file is read or trained.
- commands:
  - `moon info && moon fmt` passed.
  - `moon check doc_parse/pdf_v2 convert/pdf_v2 convert/convert pdf` passed.
  - `moon test doc_parse/pdf_v2/tests convert/pdf_v2/tests convert/convert/test doc_parse/pdf_v2/tests`
    passed: 171 tests.
  - `moon test convert/pdf_v2` passed: 21 tests.
  - `git diff --check` passed.
  - `bash samples/check.sh --format pdf || true` still reports the repository
    default `runner=none`/`rows=0` wrapper behavior.
  - explicit built runner command with `MARKITDOWN_CLI`,
    `MARKITDOWN_PDF_CLI`, and `MARKITDOWN_ZIP_CLI` produced
    `.tmp/check/runs/pdf-20260611-152859-63255`.
- before:
  - Reset 7/8A baseline: 23 non-empty main Markdown diffs.
- after:
  - explicit built runner
    `.tmp/check/runs/pdf-20260611-152859-63255`: 23 non-empty main Markdown
    diffs, matching the Reset 7/8A baseline.
  - `pdf_page_noise_cleanup` is no longer a non-empty diff after adding the
    semantic page-label sequence guard.
- heading cases:
  - Parser/semantic tests cover parser-backed heading/body split facts.
  - Main sample heading failures remain the same category as Reset 7/8A:
    parser block-boundary splits and heading suffix/prefix noise.
- list cases:
  - parser text-flow candidates split inline bullet runs such as
    `Key points: • First item • Second item`.
  - product bridge tests now cover parser-driven unordered list lowering.
- regressions:
  - none in the comparable main Markdown failure set: 23 before, 23 after.
- remaining failures:
  - main Markdown non-empty diffs: 23.
- remaining categories:
  - parser geometry/font bands and richer block boundaries.
  - repeated header/footer variants that need reliable page-band evidence.
  - non-text product lowering and metadata sidecars remain out of scope.
- next fix batch:
  - tune parser block reconstruction with source/layout evidence before adding
    more semantic rules.
  - add page-band/font-size facts when reliable geometry is available.
  - keep model integration deferred until rule/fact interfaces stabilize.

## Reset 9A Metadata Sidecars And Origin

- focus:
  - add PDF v2 document metadata plumbing for metadata sidecars without changing
    Markdown samples or falling back to v1 PDF.
  - keep block origins on the product bridge path: source name, page, block
    index, and first object ref still come from parser facts.
- v1/core audit:
  - core sidecars receive document properties through
    `write_document_output_with_document_properties` and
    `emit_metadata_json_with_document_properties`.
  - core has no separate `author` document-property slot; PDF `/Creator` maps
    to core `creator`, `/Producer` maps to core `application`, and `/Author` is
    used as creator only when `/Creator` is absent.
  - metadata links/assets/tables remain derived from core blocks.
- implementation:
  - `PdfV2DocumentMetadata` now carries title, author, subject, creator,
    producer, keywords, created, modified, and source refs.
  - model assembly promotes existing Info-dictionary metadata candidates into
    `PdfV2DocumentModel.metadata`.
  - convert exposes `pdf_v2_metadata_document_properties(model)` and
    `parse_pdf_v2_with_metadata(...)`.
  - `pdf/main.mbt` calls the metadata-aware CLI writer for `--with-metadata`.
- validation:
  - focused `moon check doc_parse/pdf_v2 convert/pdf_v2 pdf` passed.
  - `moon test doc_parse/pdf_v2/tests convert/pdf_v2/tests` passed: 149 tests.
  - `moon test convert/pdf_v2` passed: 21 tests.
- before:
  - explicit built PDF baseline: 23 main Markdown failures, 13 metadata-only
    failures, and 7 assets-only diffs.
- after:
  - no expected files were updated in 9A.
  - later Reset 9 batches still need to rerun the full PDF expected diff after
    link/image/table/artifact lowering changes.
- remaining blockers:
  - sidecar block/link/asset/table mismatches still depend on product lowering
    and parser boundary work in later Reset 9 batches.

## Reset 9B URI Link Parity

- focus:
  - consume existing parser/object URI facts for product inline link parity
    without adding image, table, caption, figure, or form lowering.
  - preserve the v2 no-fallback boundary and keep unsafe/ambiguous candidates
    plain.
- v1/core audit:
  - v1 emits safe URI annotations as rich inline links when the text/link
    association is high confidence.
  - internal or named destinations do not become visible fake URI links.
- implementation:
  - `PdfV2ConvertPipelineOutput` carries parser `link_candidates`.
  - the product bridge emits `RichParagraph`, `RichHeading`, or `RichListItem`
    inline links only when semantic URI rules are enabled.
  - association is safe-scheme, page-local, and exact-URI-text-first.
  - fallback is limited to exactly one safe URI annotation and exactly one
    emitted text block on that page.
  - ambiguous same-page links, unsafe/malformed URI candidates, and
    destination-only/non-URI facts stay plain text.
- validation:
  - focused URI bridge tests cover exact match, single-block fallback,
    ambiguous text blocks, multiple annotations, unsafe/malformed candidates,
    destination-only facts, semantic-disabled behavior, and scope guards.
  - `moon check doc_parse/pdf_v2 convert/pdf_v2 convert/convert pdf` passed.
  - `moon test doc_parse/pdf_v2/tests convert/pdf_v2/tests convert/convert/test
    doc_parse/pdf_v2/tests` passed: 179 tests.
  - `moon test convert/pdf_v2` passed: 21 tests.
- still out of scope:
  - image/table/caption/figure/form lowering.
  - complex geometric link association, fake link labels, OCR, v1 fallback, and
    runtime model hooks.
  - link metadata sidecar payload parity beyond the core inline link block.

## Reset 9C Repeated Header Footer Variants

- focus:
  - suppress repeated short line artifacts, repeated top/bottom page-band
    headers/footers, standalone page-number variants, CJK page labels, and
    broken page-prefix patterns.
  - keep suppression high confidence and preserve normal repeated titles,
    `第一章` chapter labels, and numeric body content.
- implementation:
  - parser line signals recognize `p. N`, fraction labels, and spaced CJK page
    labels as page-number-like facts.
  - parser repeated `PageArtifactCandidate` construction tracks page bands and
    avoids promoting body-band repeats.
  - repeated top/bottom band artifacts receive high confidence so the semantic
    noise guard can suppress them; lower-confidence body/unknown repeated facts
    do not cross the product suppression threshold.
  - product bridge candidate mode now treats parser-attached page artifacts as
    actionable evidence.
  - synthetic/fragment fallback repeated-line suppression is less keyword
    fragile but preserves title-shaped and mixed numeric content.
- validation:
  - focused parser tests cover repeated edge header/footer candidates, page
    number variants, repeated body titles, `第一章`, and numeric content.
  - focused product tests cover repeated footer/header suppression, repeated
    short-line variants, page numbers, normal repeated titles, CJK chapter
    labels, parser artifact candidates, and numeric body content.
- still out of scope:
  - image/link/table/caption/form lowering changes.
  - full layout recovery, column detection, OCR, v1 fallback, and runtime model
    hooks.

## Reset 9D Images And Assets

- focus:
  - consume existing parser image and inline-image facts through the product
    bridge.
  - follow core/v1 image conventions where available: emit `ImageBlock` and
    populate `Document.asset_origins`.
  - avoid inventing exported bytes while the parser is metadata-only.
- v1/core audit:
  - core exposes canonical `ImageBlock(ImageData)` with optional origin,
    alt/title/caption fields, and `asset_origins` keyed by relative asset path.
  - v1 PDF emits `ImageBlock` only when it has an exported asset path and
    mirrors image provenance into `asset_origins`.
  - docx/pptx/html converters also rely on `ImageBlock` plus `asset_origins`
    rather than visible diagnostic placeholders.
- implementation:
  - `PdfV2ConvertPipelineOutput` carries parser `image_candidates` and
    `inline_image_candidates`.
  - product bridge emits metadata-only `ImageBlock` placeholders with stable
    paths such as `assets/pdf-v2-image-001.metadata` and
    `assets/pdf-v2-inline-image-001.metadata`.
  - asset origins record source name, one-based page, object ref when present,
    origin id, and a `pdf_v2.image.metadata` or
    `pdf_v2.inline_image.metadata` key path.
  - unsupported/heavy filters are non-fatal and remain visible only as
    metadata/title details, not conversion errors or fallback.
- validation:
  - focused product tests cover metadata image blocks, asset origins,
    unsupported filters, inline image behavior, stable placeholder paths, and
    no fake byte extension/caption/table/OCR overreach.
  - real pipeline smoke covers parser image candidates flowing into pipeline
    output.
- still out of scope:
  - real image byte export/decode, OCR, caption inference, image-table
    recovery, complex placement/order repair, v1 fallback, and runtime model
    hooks.

## Reset 9E Table Parity

- focus:
  - add conservative text-table product parity after link/image/artifact work.
  - emit core `RichTable(TableData)` only for clear text evidence.
  - keep low-confidence or malformed table-like content as paragraphs.
- v1/core audit:
  - core has canonical `RichTable(TableData)` with explicit `header_rows` and
    markdown rendering support.
  - v1 PDF detects aligned text tables conservatively before consuming source
    text blocks; image overlap, captions, list-like text, and paragraph-like
    regions are guarded out.
- implementation:
  - product bridge option `enable_table_rules` gates table lowering alongside
    normalized semantic output.
  - pipe tables lower when rows have coherent width, with a Markdown separator
    row treated as header evidence.
  - simple aligned text tables lower when rows split into stable columns and
    have numeric or short-label evidence.
  - parser-candidate semantic mode avoids duplicate raw-fragment table emission
    when a parser text-flow candidate already represents that fragment.
- validation:
  - focused tests cover pipe table recognition, reliable aligned table
    recognition, ordinary paragraph fallback, malformed-row fallback,
    semantic-disabled behavior, image/OCR non-overreach, and duplicate guards.
- still out of scope:
  - image-table OCR, arbitrary visual table detection, merged cells, complex
    layout recovery, multi-column reading order, caption inference, v1 fallback,
    and runtime model hooks.

## Reset 9F Product Parity Sweep Summary

- commits:
  - 9A metadata/origin: `82dbe48 pdf-v2: add metadata origin parity`.
  - 9B URI links: `2a05258 pdf-v2: add URI link parity`.
  - 9C repeated artifacts: `c92a695 pdf-v2: suppress repeated page artifacts`.
  - 9D images/assets: `76ea469 pdf-v2: add image asset parity`.
  - 9E tables: `2320896 pdf-v2: add conservative table parity`.
- validation:
  - `moon info && moon fmt` passed.
  - `moon check doc_parse/pdf_v2 convert/pdf_v2 convert/convert pdf` passed.
  - `moon test doc_parse/pdf_v2/tests convert/pdf_v2/tests
    convert/convert/test doc_parse/pdf_v2/tests` passed: 198 tests.
  - `moon test convert/pdf_v2` passed: 21 tests.
  - `git diff --check` passed.
- final sample runs:
  - main Markdown:
    `.tmp/check/runs/pdf-20260612-071917-15495`, 24 failures.
  - metadata-only:
    `.tmp/check/runs/pdf-20260612-071917-15527`, 15 failures.
  - assets-only:
    `.tmp/check/runs/pdf-20260612-071917-15591`, 13 failures.
  - quality:
    `.tmp/quality/runs/pdf-20260612-071917-15754`, 78 rows, 70 checked, 8
    skipped, 57 failed.
- before/after:
  - comparable Reset 8/9A main Markdown baseline:
    `.tmp/check/runs/pdf-20260611-152859-63255`, 23 failures.
  - comparable metadata-only baseline:
    `.tmp/check/runs/pdf-20260611-160542-65887`, 13 failures.
  - comparable assets-only baseline:
    `.tmp/check/runs/pdf-20260611-160542-66087`, 7 failures.
  - URI link failures dropped out of the main Markdown failure list.
  - image placeholder visibility increased main/metadata/assets expected diffs
    and exposed missing `.metadata` materialized asset files.
- fixed categories:
  - safe URI inline link product lowering.
  - repeated page artifact/page-label suppression variants.
  - metadata-only image `ImageBlock` placeholders with asset origins.
  - conservative pipe/simple aligned text table lowering.
- remaining blockers:
  - real image byte export and asset materialization.
  - image caption pairing for v2, table sidecar parity, and richer table layout
    facts.
  - parser block reconstruction, hardwrap/cross-page shaping, heading false
    positives, and repeated header/footer sample variants.
  - annotations, forms, outlines/bookmarks, internal/named link appendix notes,
    full layout recovery, OCR, and runtime model hooks remain out of scope.
- expected files:
  - no sample expected files were updated.

## Reset 10 Real Image Asset Materialization

- focus:
  - replace PDF v2 visible image placeholders with real asset materialization
    when bytes are available.
  - keep parser image/object facts for unavailable or unsupported images
    without emitting broken Markdown image references.
  - preserve the existing core/v1 asset convention instead of inventing a new
    sidecar format.
- core/v1 asset convention:
  - core image output is `ImageBlock(ImageData)` with `path`, optional
    alt/title/caption, and optional origin.
  - `Document.asset_origins` is keyed by the same relative path rendered in
    Markdown.
  - v1 PDF writes assets into `assets/imageNN.ext` with
    `next_image_asset_rel_path_unique` and emits an image block only after a
    writeable path exists.
  - metadata sidecars derive `assets[]` from `asset_origins`; core carries
    paths/origins, while bytes are written by the converter/CLI path.
- implementation:
  - parser image facts now optionally carry `PdfV2ImageAssetCandidate` with
    byte kind, MIME, extension, byte count, payload bytes before materialization,
    status, and reason tags.
  - supported raw encoded image containers are DCT/JPEG, JPX/JPEG2000, and JBIG2
    when a signature-valid payload is already exposed; XObject wrapper filters
    can be peeled with the existing mbtpdf codec.
  - inline images can materialize decoded RGB pixels through existing mbtpdf
    image decoding and are written as BMP; simple no-filter DeviceRGB/Gray bytes
    remain supported.
  - the convert pipeline accepts `asset_output_dir`, writes assets as
    `assets/image01.jpg`, `assets/image01.bmp`, and so on, then clears in-memory
    bytes from the public pipeline facts.
  - the product bridge emits visible `ImageBlock`s only for candidates with a
    real materialized `rel_path`; unsupported or unavailable images stay
    internal facts and do not create `.metadata` placeholder references.
  - `asset_origins` use source name, one-based page, object ref when available,
    and v1-style `key_path: None`.
- sample before/after:
  - Reset 9F main Markdown: 24 failures; Reset 10 run
    `.tmp/check/runs/pdf-20260612-151858-35170` also has 24 failures.
  - Reset 9F metadata-only: 15 failures; Reset 10 run
    `.tmp/check/runs/pdf-20260612-151859-35930` has 12 failures.
  - Reset 9F assets-only: 13 failures; Reset 10 run
    `.tmp/check/runs/pdf-20260612-151859-35645` has 7 failures.
  - the sample wrapper still prints `rows=0` because its summary regex does not
    parse the current failure header; the log headers above contain the actual
    checked failure counts.
- fixed image cases:
  - XObject DCT images now emit `assets/image01.jpg` and write the JPEG bytes.
  - ReportLab inline images now emit `assets/image01.bmp` and write decoded BMP
    bytes.
  - image metadata samples no longer emit missing `.metadata` asset references.
- remaining limitations:
  - Form XObject image traversal is still missing in the v2 product path.
  - Flate XObject pixels are not exported unless they are decoded through the
    supported inline-image path.
  - captions, table-from-image, OCR, full layout recovery, model loading, v1
    fallback, and sample expected updates remain out of scope.

## Reset 11 Form XObject Images And Caption Facts

- focus:
  - discover images drawn from nested Form XObject content streams when the
    page invokes the Form with `Do`.
  - attach conservative image placement facts from the graphics CTM and content
    order.
  - attach high-confidence caption candidates only for same-page
    single-image/single-figure-caption cases.
- implementation:
  - page resources still emit resource/form facts, but visible image candidates
    are created from actual `Do` invocations so placement/order facts are tied
    to drawn content.
  - Form XObject traversal is depth-capped and cycle-guarded. Cycles record
    warnings/risks and remain non-fatal; there is no v1 fallback.
  - `PdfV2ImageCandidate` now carries optional nesting, placement, and caption
    facts. Nested images include the parent Form object ref and resource path
    when known.
  - the product bridge interleaves materialized images by source order, lowers
    parser caption facts into `ImageBlock.caption`, mirrors them to
    `asset_origins.nearby_caption`, and suppresses only the exact caption text
    consumed for that image.
  - asset origins keep the image object ref and include the resource path in
    `source_path`; `key_path` stays `None` for v1-style PDF asset parity.
- sample signal with explicit prebuilt CLIs:
  - Reset 10 main Markdown: 24 failures; Reset 11 run
    `.tmp/check/runs/pdf-20260612-161426-44853` has 20 failures.
  - Reset 10 assets-only: 7 failures; Reset 11 run
    `.tmp/check/runs/pdf-20260612-161427-45335` has 3 failures.
  - Reset 10 metadata-only: 12 failures; Reset 11 run
    `.tmp/check/runs/pdf-20260612-161427-44852` has 9 failures.
  - `assets/pdf_image_form_xobject` now writes and references
    `assets/image01.jpg`; its remaining diff is heading/text structure.
  - caption-like image samples now render image then caption and mirror
    `nearby_caption` in metadata sidecars.
- unchanged boundaries:
  - no sample expected files were updated.
  - no vendor runtime change, OCR, image-table recovery, full layout recovery,
    aggressive caption inference, v1 fallback, external model/data access, or
    training hook was added.

## Reset 12 Table Structure And Sidecar Parity

- focus:
  - move PDF v2 table parity from bridge-only text heuristics to parser-backed
    `PdfV2TableCandidate` facts.
  - lower only high-confidence text-derived tables to core
    `RichTable(TableData)`.
  - rely on the existing core metadata sidecar table convention instead of
    inventing PDF v2 sidecar fields.
- v1/core audit:
  - core `RichTable(TableData)` carries `rows`, `header_rows`, and optional
    hints.
  - the Markdown emitter renders `RichTable` as a Markdown table and uses the
    first header row as the Markdown header.
  - metadata sidecars already serialize `block_type: "table"`, flat table text,
    `table.rows`, and `table.header_rows`.
  - v1 PDF detects simple aligned text tables conservatively and leaves weak
    table-like paragraphs as text.
- implementation:
  - parser source/raw/model/page structures now carry `table_candidates`.
  - candidates include page, block, line/source evidence, rows, columns, cell
    records, confidence, kind, and header evidence.
  - supported candidate kinds are pipe-separated text, simple whitespace-aligned
    text, and coordinate grids derived from text-show matrix positions.
  - coordinate grids keep cell block indices so product lowering can consume
    multi-fragment cell output as one table.
  - product lowering maps parser-backed candidates with confidence >= 0.80 to
    `RichTable` with `hints: None`; low-confidence candidates fall back to the
    existing paragraph path.
  - parser table source refs suppress duplicate semantic/text-flow fragments
    after the table has emitted.
- sample signal with explicit prebuilt CLIs:
  - Reset 11 main Markdown: 20 failures; Reset 12 run
    `.tmp/check/runs/pdf-20260612-180306-54858` has 18 failures.
  - Reset 11 metadata-only: 9 failures; Reset 12 run
    `.tmp/check/runs/pdf-20260612-180315-55360` has 8 failures.
  - Reset 11 assets-only: 3 failures; Reset 12 run
    `.tmp/check/runs/pdf-20260612-180322-55586` remains 3 failures.
  - `pdf_simple_table_like` and
    `metadata/pdf_metadata_table_like` now render the expected Markdown table.
  - `pdf_metadata_table_like.metadata.json` now contains a table block with
    rows, `header_rows: 1`, and line range origin; its remaining sidecar diff is
    document-property parity, not table payload.
- unchanged boundaries:
  - no sample expected files were updated.
  - no v1 fallback, v1 PDF runtime change, vendor runtime change, OCR,
    image-table recovery, full layout recovery, fake cells, diagnostics
    Markdown, external model/data access, or training hook was added.

## Reset 13 Metadata Sidecar Key Parity

- focus:
  - align PDF v2 metadata-only sidecar keys with the current core/v1 PDF
    convention.
  - fix document-property, block-origin, link-origin, and image asset-origin
    shape differences without changing visible Markdown.
- failure classification from Reset 12:
  - document properties: every remaining metadata sidecar mismatch carried an
    eager PDF v2 `document` object while current PDF fixtures expect
    `document: null`.
  - asset origins: image metadata samples differed on `origin_id` and leaked
    Form/resource `source_path` in the sidecar.
  - block origins: paragraph/link/image block sidecars leaked text/image object
    refs that v1 PDF omits from block origins.
  - table sidecar: table payload already matched core `RichTable`; the remaining
    table-like sidecar diff was document-property only.
  - remaining text samples: `pdf_metadata_noise_merge` and
    `pdf_metadata_text_structure` still differ because visible text/block
    structure is not v1-parity yet.
- audited conventions:
  - PDF v1 image blocks set block-origin `object_ref` to `None`.
  - PDF v1 asset origins keep the image object ref and use
    `xobj-image-<object-number>` ids.
  - current PDF metadata fixtures use `document: null`; page count and
    producer/application values are not emitted into the PDF sidecar.
  - link sidecar origins follow the block origin, so PDF object refs should not
    leak there either.
- implementation:
  - `parse_pdf_v2_with_metadata` now returns no document properties for the PDF
    metadata sidecar path, so core serializes `document: null`.
  - product bridge block origins now omit PDF object refs from public core
    block origins.
  - materialized XObject image asset origins now use v1-style
    `xobj-image-<object-number>` ids and keep `source_path: None` in the
    sidecar; the parser still retains Form nesting/resource facts internally.
  - inline image asset origin ids use the v1-style `inline-image-N` prefix.
- sample signal with explicit prebuilt CLIs:
  - Reset 12 metadata-only baseline:
    `.tmp/check/runs/pdf-20260612-180315-55360`, 8 failures.
  - Reset 13 metadata-only run:
    `.tmp/check/runs/pdf-20260612-182554-59551`, 4 failures.
  - Reset 13 main Markdown run:
    `.tmp/check/runs/pdf-20260612-182554-59563`, 18 failures, unchanged from
    Reset 12.
  - Reset 13 assets-only run:
    `.tmp/check/runs/pdf-20260612-182554-59567`, 3 failures, unchanged from
    Reset 12.
- fixed cases:
  - `pdf_metadata_table_like` sidecar now matches its expected document shape.
  - image caption metadata samples now match image block origin and asset origin
    key shape.
  - URI link metadata sample no longer leaks text object refs in block/link
    origins.
- remaining limitations:
  - `pdf_metadata_noise_merge` and `pdf_metadata_text_structure` still have
    Markdown/text-block structure differences that produce `blocks` and
    `summary` sidecar mismatches.
  - hardwrap, cross-page merge, heading/header-footer, image placement edge
    cases, and annotation/form/outline product parity remain later phases.
- unchanged boundaries:
  - no sample expected files were updated.
  - no v1 fallback, v1 PDF deletion, vendor runtime change, OCR, image-table
    recovery, full layout recovery, diagnostics text, external model/data
    access, or training hook was added.

## Reset 14 Text Structure And Noise Merge Parity

- focus:
  - close the two remaining Reset 13 metadata-only samples:
    `pdf_metadata_noise_merge` and `pdf_metadata_text_structure`.
  - keep the fix in PDF v2 text/block productization rather than changing
    sample expectations or adding fallback/OCR/layout recovery.
- implementation:
  - fragment text normalization now carries page and block context so repeated
    page artifacts can be filtered after ligature and hardwrap joining.
  - repeated page artifacts are suppressed at paragraph level, allowing split
    `Con` + `fi` + `dential` footers to normalize to `Confidential` and then
    be removed consistently.
  - CJK chapter and decimal-section headings can absorb short split heading
    tails such as `目标`, while following body text remains a paragraph.
  - page-boundary and artifact-boundary guards prevent the new joins from
    merging unrelated pages, titles, or repeated headers/footers into body
    text.
  - parser text-flow candidate mode now requires actionable list-marker
    evidence and avoids treating decimal section labels such as `1.1` as list
    evidence.
- sample signal with explicit prebuilt CLIs:
  - Reset 13 metadata-only baseline:
    `.tmp/check/runs/pdf-20260612-182554-59551`, 4 failures.
  - Reset 14 metadata-only run:
    `.tmp/check/runs/pdf-20260612-191228-66529`, 0 failures.
  - Reset 14 main Markdown run:
    `.tmp/check/runs/pdf-20260612-191248-66777`, 15 failures, improved from
    Reset 13's 18.
  - Reset 14 assets-only run:
    `.tmp/check/runs/pdf-20260612-191248-66837`, 3 failures, unchanged from
    Reset 13.
- fixed cases:
  - `pdf_metadata_noise_merge` now emits only the two expected body paragraphs
    and removes repeated `Project Report` / `Confidential` artifacts.
  - `pdf_metadata_text_structure` now emits chapter headings, the decimal
    section heading `1.1 研究目标`, and the expected body paragraphs.
- unchanged boundaries:
  - no sample expected files were updated.
  - no v1 fallback, v1 PDF deletion, vendor runtime change, OCR, image-table
    recovery, full layout recovery, diagnostics text, external model/data
    access, or training hook was added.

## Reset 15A Main Markdown Failure Taxonomy And Low-Risk Fixes

- focus:
  - classify every remaining Reset 14 main Markdown parity failure before
    taking code changes.
  - apply only evidence-backed text/layout fixes that cover a stable bucket and
    do not touch sample expectations, metadata sidecar schema, asset material
    policy, v1 fallback, OCR, image-table recovery, full layout recovery, model
    loading/training, or external data access.
- Reset 14 starting point:
  - commit: `75c13a5 pdf-v2: improve text structure parity`.
  - main Markdown run:
    `.tmp/check/runs/pdf-20260612-191248-66777`, 15 failures.
  - metadata-only run:
    `.tmp/check/runs/pdf-20260612-191228-66529`, 0 failures.
  - assets-only run:
    `.tmp/check/runs/pdf-20260612-191248-66837`, 3 failures.
- exact taxonomy of the 15 Reset 14 main Markdown failures:
  - `assets/pdf_image_form_xobject`: image/text placement bucket. The nested
    Form image asset is emitted, but the expected nearby heading
    `Image inside Form XObject` is missing before the image. This still needs
    safer image-nearby text placement/caption/title association.
  - `assets/pdf_image_inline`: image sample heading bucket. The leading
    `Inline image sample` line remains a paragraph rather than H1. A generic
    lower-case title promotion would be broad and risky, so it was deferred.
  - `assets/pdf_image_xobject`: image sample heading bucket. The leading
    `XObject image sample` line remains a paragraph rather than H1. Same risk
    profile as the inline image case.
  - `hardwrap_zh`: CJK hardwrap and heading bucket. `技术路线` was not promoted
    and body text split around `IR，`; fixed in this reset.
  - `not_heading_sentence`: CJK punctuation hardwrap bucket. A short body
    sentence split after `，`; fixed in this reset.
  - `pdf_cross_page_paragraph`: cross-page paragraph and heading-level bucket.
    A paragraph still splits at `page` / `break`, and `Next Section` is H1
    rather than H2. Defer until page-boundary facts can distinguish section
    continuation from new section starts.
  - `pdf_cross_page_should_merge_phase15`: cross-page heading/body boundary
    bucket. The title is fused with body text and the lower-case continuation
    still appears as a new paragraph. Defer broad cross-page block recovery.
  - `pdf_cross_page_should_not_merge_phase15`: cross-page non-merge and
    marker-preservation bucket. The lead title is not a heading, and the page-2
    section/list marker is fused into one paragraph. Defer until page-break
    boundary and marker evidence survive together.
  - `pdf_header_footer_variants_phase15`: repeated header/footer variant
    bucket. Header lines with page numbers are fused with body starts and the
    final footer remains attached. Defer because safe removal needs stronger
    repeated-artifact facts for variant lines, not filename-specific filters.
  - `pdf_heading_false_positive_phase15`: paragraph boundary and
    heading/list-negative bucket. Multiple intentionally tricky short/all-caps
    and numbered body lines are collapsed into one paragraph. Defer broad block
    boundary reconstruction.
  - `pdf_heading_vs_short_sentence`: heading/list bucket. The `Method` heading
    level is fixed in this reset; remaining diff is lost unordered list markers
    for `First item` / `Second item`.
  - `pdf_repeated_header_footer_variants`: repeated header/footer plus
    ligature/heading-level bucket. `Details` / `Conclusion` levels and the
    `di ff erent` ligature split were fixed in this reset.
  - `pdf_two_column_negative_phase15`: paragraph boundary and two-column order
    bucket. Left/right column lines are collapsed into one paragraph. Defer
    until column-aware layout recovery is in scope.
  - `text_hardwrap`: CJK punctuation hardwrap bucket. `下一段：` was split from
    its CJK body; fixed in this reset.
  - `text_simple`: CJK/ASCII hardwrap plus heading false-positive bucket. The
    first paragraph split around `PDF` and the prefix was promoted as H1; fixed
    in this reset.
- low-risk fixes applied:
  - text output normalizer now treats conservative CJK punctuation-to-CJK
    breaks and CJK/short-uppercase-ASCII term breaks as hardwrap
    continuations.
  - blank-line handling can ignore a cross-page blank only when the surrounding
    text is an unfinished continuation, keeping sentence-ended page breaks
    separated.
  - heading rules treat common English section labels followed by intro/body
    phrases such as `Key points:` as headings and infer them as subsections
    after the document lead.
  - heading rules reject inline CJK body markers such as
    `第一段：这是...` as heading candidates.
  - common observed ligature repair now covers `di ff erent`.
- regression coverage:
  - CJK/ASCII hardwrap positives and unsafe lowercase/sentence-ended negatives.
  - unfinished cross-page continuation positive and sentence-ended cross-page
    negative.
  - English section-label-before-intro-phrase heading level.
  - intro phrase and short body sentence not promoted.
  - inline CJK body marker not promoted as a heading.
- sample signal with explicit prebuilt CLIs:
  - main Markdown improved from Reset 14's 15 failures to 10 in
    `.tmp/check/runs/pdf-20260612-194329-70975`.
  - metadata-only stayed 0 failures in
    `.tmp/check/runs/pdf-20260612-194340-71480`.
  - assets-only stayed 3 failures in
    `.tmp/check/runs/pdf-20260612-194340-71483`.
- remaining main Markdown failures after Reset 15A:
  - image heading/placement: `assets/pdf_image_form_xobject`,
    `assets/pdf_image_inline`, `assets/pdf_image_xobject`.
  - cross-page paragraph/section boundary:
    `pdf_cross_page_paragraph`,
    `pdf_cross_page_should_merge_phase15`,
    `pdf_cross_page_should_not_merge_phase15`.
  - repeated header/footer variants:
    `pdf_header_footer_variants_phase15`.
  - paragraph boundary/list/heading negatives:
    `pdf_heading_false_positive_phase15`,
    `pdf_heading_vs_short_sentence`.
  - two-column paragraph/order recovery:
    `pdf_two_column_negative_phase15`.
- unchanged boundaries:
  - no sample expected files were updated.
  - no v1 fallback, v1 PDF deletion, mbtpdf vendor runtime change, OCR,
    image-table recovery, full layout recovery, diagnostics text, metadata
    sidecar schema change, public `object_ref` reintroduction, external
    model/data access, or training hook was added.

## Reset 15R Anti-Patch Audit And Model Readiness

Reset 15R was needed because Reset 14 and Reset 15A reduced visible parity gaps
with useful but increasingly string-shaped product rules. The audit stops the
failure-count chase and records which fixes are safe bridges, which belong in
parser/model facts, and why direct training would be premature.

- Patch smell findings:
  - high risk: exact `di ff erent` repair, English lexical body-merge cues,
    CJK/decimal heading-tail splitting in the normalizer, and cross-page
    continuation decisions based mostly on punctuation/page indices.
  - medium risk: CJK punctuation hardwrap, mixed CJK/short-uppercase term
    continuation, common section-label heading inference, and inline CJK
    body-marker heading negatives.
  - lower risk: carrying page/block provenance through normalized lines and
    using parser-backed list/artifact scores as bridge evidence.
- Keep/move/revisit:
  - keep Reset 14/15A as temporary parity bridges; do not revert wholesale.
  - move boundary, heading-tail, repeated-artifact, and cross-page decisions
    toward parser-owned `TextFlowCandidate`, `BlockBoundarySignal`,
    `PageArtifactCandidate`, and later offline classifiers.
  - revisit exact token repair and English lexical merge before any dataset
    labels treat current product output as gold.
- Model readiness conclusion:
  - current facts are useful for offline export and weak-label analysis.
  - current labels and geometry are not sufficient for production training,
    runtime inference, or model arbitration.
- Next recommended action:
  - run `Reset 15B-AuditCleanup` first to tag or contain high-risk bridge
    rules, then proceed to `Reset 16 Dataset Export Scaffold`.

## Reset 15B Audit Cleanup And Anti-Patch Guardrails

Reset 15B intentionally does not reduce sample failure counts. It contains the
Reset 14/15A parity bridges so future work can export evidence without turning
normalizer patches into gold labels.

- Runtime/sample contract:
  - no Markdown expected files were changed.
  - no fallback, v1 deletion, diagnostics text, sidecar schema change,
    public `object_ref`, runtime model, training hook, external data,
    quality-lab dependency, or `.vscode` change was introduced.
- Rules tagged as temporary:
  - exact split ligature repairs.
  - CJK/decimal heading-tail split helpers.
  - hardwrap and cross-page continuation helpers.
  - English lexical body-merge cue helper.
  - repeated artifact suppression after text assembly.
  - common section-label and inline CJK body-marker semantic guards.
- Cleanup:
  - high-risk normalizer decisions now have owner/risk/TODO comments.
  - ligature and artifact suppression logic has explicit helper boundaries.
  - the product bridge documents that it only switches candidate semantic mode
    from parser-backed marker/score evidence, not raw text classification.
- Guard tests:
  - ligature split scope, heading-tail scope, cross-page structural starts,
    repeated artifact evidence, repeated title preservation, Method-like label
    safety, and bridge source ownership.
  - table/image-specific cross-page prevention still needs parser-owned
    boundary/object facts and should be part of the Reset 16 export design.
- Migration targets:
  - boundary classifier for hardwrap, heading-tail, and cross-page decisions.
  - artifact classifier backed by `PdfV2PageArtifactCandidate`.
  - block-kind classifier for headings, intro phrases, and Method-like labels.
  - caption/adjacency and column/read-order classifiers for image placement and
    two-column residual failures.
- Next recommended task:
  - `Reset 16 Dataset Export Scaffold`, non-runtime only, exporting parser
    facts, rule decisions, weak labels, risk tags, and source refs.

## Reset 16A Training Stack Audit And Dataset Export Contract

Reset 16A keeps all product parity behavior unchanged. It defines how future
PDF v2 dataset export should align with the existing external training stack
before any code scaffold is added.

- External audit:
  - quality-lab path: `markitdown-quality-lab/`.
  - status: clean during audit.
  - existing routes: `text_block_classifier` for convert-layer semantic hints
    and `layout_recovery` for parser/layout recovery.
  - existing DocLayNet adapter TSV fields are documented and concrete; active
    text-block training uses local-only adapter rows and feature TSVs.
- Contract outcome:
  - added `docs/archive/pdf-v2-dataset-export-contract.md`.
  - main row families are `TextFlowRow`, `BoundaryRow`, `ArtifactRow`,
    `AdjacencyRow`, `LayoutRegionRow`, and `ReadingOrderRow`.
  - DocLayNet labels are preserved as layout labels; they become Markdown/block
    labels only through reviewed adapters.
- Product contract:
  - no samples expected changed.
  - no product Markdown or metadata sidecar output changed.
  - no fallback, runtime model, training hook, external data access,
    quality-lab invocation, or `.vscode` change.
- Remaining parity/export connection:
  - image caption/placement residuals map to `AdjacencyRow` and
    `LayoutRegionRow`.
  - cross-page residuals map to `BoundaryRow`.
  - header/footer residuals map to `ArtifactRow`.
  - two-column residuals map to `ReadingOrderRow`.
- Next recommended task:
  - `Reset 16B` should implement an opt-in exporter only after row-id and
    adapter flattening details are reviewed against quality-lab scripts.

## Reset 16B Dataset Exporter Adapter Scaffold

Reset 16B adds an opt-in exporter scaffold and leaves main-chain PDF output
unchanged.

- Product path impact:
  - no default convert-path call to the exporter.
  - no Markdown output, metadata sidecar, sample expected, diagnostics,
    fallback, or v1 PDF deletion change.
- Implemented export rows:
  - `TextFlowRow` from text-flow candidates and semantic rule decisions.
  - `BoundaryRow` from adjacent text-flow candidates, including cross-page
    flags.
  - `ArtifactRow` from parser page artifact candidates referenced by text-flow
    rows.
  - minimal `AdjacencyRow` from table, image, inline-image, and link facts.
- Stable ids:
  - row ids are deterministic `pdfv2:<task>:<safe_doc_id>:p<page>:<suffix>`
    values.
  - `doc_id` is caller-provided; absolute paths and random ids are not used.
- Serialization:
  - JSONL and TSV are deterministic and memory-only.
  - TSV follows quality-lab-style fixed headers; arrays flatten with `|`.
- Parity connection:
  - text structure residuals can now be studied as text-flow weak-label rows.
  - cross-page residuals can be studied as boundary rows.
  - header/footer residuals can be studied as artifact rows.
  - image/table/link residuals can be studied as adjacency rows.
- Still not done:
  - no `LayoutRegionRow` or `ReadingOrderRow` population.
  - no gold labels, split assignment, quality-lab adapter, training, runtime
    model, model hint, or arbitration change.

## Reset 16C Exported Row Quality Audit And Schema Dry-run

Reset 16C does not change main-chain parity behavior. It audits the rows that
Reset 16B can export when explicitly called.

- Runtime boundary:
  - exporter remains absent from pipeline, product bridge, dispatcher, and PDF
    component runtime paths.
  - no Markdown output, metadata sidecar, sample expected, fallback, model, or
    normalizer/semantic patch changed.
- Audit summary:
  - in-memory counters cover row totals, family/task distribution, empty-gold
    counts, weak-label counts, label-source/split distribution, unknown key
    fields, source refs, geometry unknowns, and risk tags.
  - the synthetic test fixture has 7 rows, all empty gold labels, 2 text-flow
    weak labels, and 5 `label_source=none` rows.
- Schema readiness:
  - `TextFlowRow` is the closest fit for the existing text-block adapter route.
  - `BoundaryRow`, `ArtifactRow`, and `AdjacencyRow` need dedicated
    quality-lab-side adapters or report-only audit paths.
  - `LayoutRegionRow` and `ReadingOrderRow` remain blockers for layout and
    read-order parity learning.
- Privacy:
  - caller-provided `doc_id` is preserved; callers should use synthetic stable
    ids, not local paths.

## Reset 16D Quality-lab Adapter Mapping Dry-run

Reset 16D does not change main-chain parity behavior. It documents how the
opt-in PDF v2 exporter could be mapped into existing quality-lab adapter
conventions without creating a default workflow.

- Runtime boundary:
  - no product Markdown, metadata sidecar, sample expected, fallback,
    normalizer/semantic patch, model, training hook, generated dataset, or
    quality-lab invocation changed.
- Mapping result:
  - `TextFlowRow` is still the closest route to the current text-block TSV, but
    remains audit-only until bbox, source-label, reviewed-label, grouped-split,
    and feature-exclusion policy exists.
  - `BoundaryRow` belongs to layout-recovery boundary tooling.
  - `ArtifactRow` and `AdjacencyRow` remain review/audit rows; parser facts are
    not promoted to labels.
- Remaining parity learning blockers:
  - no gold labels, no populated layout-region/read-order rows, incomplete
    geometry/font/column facts, and no quality-lab-side adapter gate.

## Reset 17A Parser/Layout-backed Parity Facts

Reset 17A adds parser-side facts for the remaining parity gap families and
keeps main-chain output unchanged.

- Facts added:
  - `PdfV2CrossPageBoundaryFact` targets cross-page merge/split decisions.
  - `PdfV2ImageTextBoundaryFact` targets image placement, captions, and nearby
    headings.
  - `PdfV2HeaderFooterVariantFact` targets repeated and numbered edge
    header/footer variants.
  - `PdfV2HeadingBoundaryFact` targets heading false positives and short
    sentence ambiguity.
  - `PdfV2ColumnLayoutFact` targets two-column ordering risk and source-order
    confidence.
- Product path impact:
  - no Markdown output, metadata sidecar, sample expected, fallback,
    normalizer patch, semantic string patch, model, training hook, generated
    dataset, or quality-lab invocation changed.
  - convert tests guard that product bridge, pipeline, and fact lowerer do not
    call `pdf_v2_parity_facts_from_model`.
- Remaining blockers:
  - facts are not labels.
  - true visual distances, full column/read-order ids, font/style deltas,
    layout-region rows, review labels, and quality-lab gates remain future
    work.

## Reset 17B Parity Facts Audit And Calibration

Reset 17B audits and calibrates the Reset 17A facts without changing
main-chain output.

- Audit helper:
  - `pdf_v2_parity_fact_audit(...)` counts fact families, pages, confidence
    buckets, reason tags, unknown/low-confidence facts, source-ref coverage,
    insufficient geometry, and audit-only versus future-arbitration candidates.
- Calibration:
  - image nearby text without caption evidence is tagged
    `nearby_text_not_caption` and kept low confidence.
  - header/footer variants require repeated edge evidence.
  - heading-risk facts do not demote headings by themselves.
  - unknown or two-column layout facts do not imply reorder.
- Gap coverage:
  - image/caption, cross-page, header/footer, heading-risk, and two-column
    categories now have auditable parser signals.
- Boundary:
  - no product Markdown, metadata sidecar, sample expected, fallback,
    normalizer/semantic patch, model, training hook, generated dataset, or
    quality-lab invocation changed.

## Reset 17C Cross-page Boundary Fact Arbitration

Reset 17C consumes only high-confidence `PdfV2CrossPageBoundaryFact` for the
remaining cross-page merge/split parity gap.

- Product behavior:
  - a cross-page paragraph may now join when the parser fact has confidence
    `>= 0.60`, source refs for both sides, open-ended previous text, no next
    marker/list/heading-like blocker, and no low-confidence/ambiguity/audit-only
    tag.
  - if no qualifying fact exists, the previous product path and split behavior
    are preserved.
- Static guard:
  - convert may call `pdf_v2_cross_page_boundary_facts_from_candidates(...)`.
  - convert still does not call `pdf_v2_parity_facts_from_model(...)`.
  - image-text, header/footer, heading-boundary, and column-layout facts remain
    unconsumed by product code.
- Untouched gaps:
  - image placement/caption/nearby heading, header/footer variants, heading
    classification, and two-column ordering are intentionally unchanged.
- No metadata sidecar, assets, sample expected, fallback, quality-lab, model,
  training hook, or generated dataset changed.

## Reset 17D Cross-page Arbitration Effectiveness Audit

Reset 17D originally audited why Reset 17C did not reduce the visible PDF
Markdown parity failure count on that checkout. A fresh June 13, 2026
repo-local `samples/check.sh --format pdf` run still reproduces that same
10-failure Markdown parity state, and no sample expected files were changed.

Current failure taxonomy:

| category | samples | Reset 17D finding |
| --- | --- | --- |
| cross-page merge should happen | `pdf_cross_page_paragraph`, `pdf_cross_page_should_merge_phase15` | still visible; diffs also involve heading level or title/body boundary issues |
| cross-page split should happen / marker preservation | `pdf_cross_page_should_not_merge_phase15` | still visible; diff is mixed with heading/list marker structure |
| image placement/caption/nearby heading | `assets/pdf_image_form_xobject`, `assets/pdf_image_inline`, `assets/pdf_image_xobject` | intentionally untouched by 17C/17D |
| header/footer variants | `pdf_header_footer_variants_phase15` | intentionally untouched by 17C/17D |
| heading/list false positives or negatives | `pdf_heading_false_positive_phase15`, `pdf_heading_vs_short_sentence` | intentionally untouched by 17C/17D |
| column/reading order | `pdf_two_column_negative_phase15` | intentionally untouched by 17C/17D |

Audit helper added:

```text
pdf_v2_cross_page_arbitration_audit(blocks, facts)
pdf_v2_cross_page_fragment_arbitration_audit(fragments, options, facts)
```

The helpers are opt-in and in-memory only. They count generated facts, facts
that would reach product arbitration, product-candidate facts, per-gate pass
counts, confidence rejections, missing or mismatched source refs, previous side
not open-ended, next marker/list/page-number blockers, next heading/title-like
blockers, ambiguity/audit-only tags, no matching fragment or semantic pair,
actual join decisions, split decisions, and fallback-to-existing-behavior
counts.

Focused synthetic audit distribution:

| case | key counters |
| --- | --- |
| valid high-confidence fact | generated `1`, product candidate `1`, join decision `1`, fallback `0` |
| low confidence | `confidence_below_threshold` rejected `1`, product candidate `0`, fallback `1` |
| mismatched source refs | product candidate `1`, `mismatched_source_refs` rejected `1`, fallback `1` |
| heading/title-like next block | product candidate `1`, `next_heading_title_like_blocker` rejected `1`, fallback `1` |
| mismatched block pair | product candidate `1`, `no_matching_fragment_or_semantic_pair` rejected `1`, fallback `1` |
| no fact | generated `0`, join decision `0`, fallback `1` |

Real sample inspection remains limited because the sample check/debug CLI path
does not yet expose PDF v2 candidate/fact audit counters for the failing PDFs.
The top-level sample wrapper can also still print `rows=0` on failing runs
because its summary parser does not read the current failure header; the
matching `markdown-only.entrypoint.log` remains the authoritative log for the
10 Markdown failures.
Reset 17D therefore retains Reset 17C behavior as-is: no threshold lowering, no
blocker removal, no image/header/footer/heading/column change, no generated
artifacts, and no sample expected update. The recommended next action is a
repo-local PDF v2 diagnostic entrypoint that prints candidate facts and this
audit summary for existing failing samples before any further product change.

## Reset 17E Cross-page Structural Handoff Arbitration

Reset 17E converts the earlier audit finding into a narrow implementation:
cross-page handling is now modeled as structural handoff rather than as
paragraph join/split alone.

- New abstraction:
  - `PdfV2CrossPageStructuralHandoff` in `convert/pdf_v2`.
  - fields cover page pair, refs, block kinds, heading/list/title-body
    evidence, join intent, preserve intent, blockers, confidence, and matched
    cross-page fact.
- Useful v1 intent retained:
  - explicit page-boundary blockers for heading/list/title-like starts.
  - conservative fallback when evidence is weak.
- Useful v1 intent rejected:
  - no phrase- or sample-specific overrides.
  - no normalizer patch forest.
- Narrow bug fixed:
  - the bridge now threads structural-handoff candidate blocks through
    candidate-mode emission explicitly, instead of computing candidate-backed
    semantic blocks and then accidentally lowering them through the fragment
    path.
- New 17E gates:
  - paragraph join requires a qualifying fact and a paragraph continuation pair.
  - heading-level preservation requires a qualifying fact.
  - preserve-next-structure is limited to parser-backed list evidence,
    title/body boundary evidence, or qualifying heading/following-page
    structure evidence.
  - repeated-artifact boundaries and weak heading-like boundaries do not
    activate structural handoff.
- Focused regression coverage added:
  - mixed next-page structure remains out of the previous paragraph join.
  - repeated heading-like footer does not trigger structural-handoff mode.
  - weak heading-like next-page evidence without a qualifying fact does not
    activate structural-handoff mode.
- Sample result after Reset 17E:
  - repo-local `samples/check.sh --format pdf` still shows the same 10
    Markdown failures.
  - no sample expected files changed.
  - the three cross-page-labeled diffs remain visibly unchanged:
    - `pdf_cross_page_paragraph`: paragraph still splits at `page` / `break`,
      and `Next Section` remains H1.
    - `pdf_cross_page_should_merge_phase15`: title/body still collapses into one
      line.
    - `pdf_cross_page_should_not_merge_phase15`: next-page heading/list still
      flatten to plain text.
  - the wrapper summary may still print `rows=0`; the markdown-only log remains
    authoritative.
- Reset 17E closeout:
  - product code changed narrowly.
  - visible repo-local PDF sample parity did not improve yet.
  - expected next action is parser/candidate evidence improvement for the three
    remaining cross-page structure cases, not gate relaxation.

## Reset 17F Target Sample Signal Trace

Reset 17F does not broaden product behavior. It adds only an opt-in,
repo-local trace surface so the remaining structural-handoff targets can be
classified end to end:

- raw/parser block previews near page boundaries
- source refs and text-flow candidates
- `PdfV2CrossPageBoundaryFact` and `PdfV2HeadingBoundaryFact`
- list-marker and title/body evidence
- `PdfV2CrossPageStructuralHandoff`
- semantic block previews
- final bridge/lowering selection path

Trace entrypoints:

- convert helper:
  `pdf_v2_target_signal_trace_from_path(path, pipeline_options, bridge_options)`
- local debug command:
  `moon run debug -- debug pdf-v2-trace <sample.pdf>` with optional `--json`

Repo-local June 13, 2026 outcome:

- `samples/check.sh --format pdf` still reports the same 10 Markdown failures.
- no sample expected files changed.
- no product Markdown changed.
- the wrapper summary may still print `rows=0`; the matching
  `markdown-only.entrypoint.log` remains authoritative.

Target sample evidence-loss matrix:

| sample | owned by | trace summary |
| --- | --- | --- |
| `pdf_cross_page_paragraph` | parser candidate/fact loss plus structural-handoff rejection | one cross-page fact exists, but it aligns to a repeated-artifact/page-number boundary, so the visible `page` / `break` split and H1 `Next Section` remain outside candidate structural-handoff ownership |
| `pdf_cross_page_should_merge_phase15` | semantic candidate/block loss | title/body structure is already merged before semantic handoff owns the visible block boundary, so the diff remains a one-line collapse |
| `pdf_cross_page_should_not_merge_phase15` | semantic candidate/block loss | next-page heading/list structure is already flattened before lowering, and the low-confidence fact does not justify structural-handoff activation |
| `pdf_heading_false_positive_phase15` | expected-output-owned, not structural-handoff-owned | single-page failure with no cross-page fact or handoff entry |
| `pdf_heading_vs_short_sentence` | expected-output-owned, not structural-handoff-owned | single-page failure where remaining visible loss is list-marker structure, not page-boundary arbitration |

Reset 17F closeout:

- keep the 17E structural-handoff gates and bridge-threading fix.
- no additional narrow fix was proven.
- visible PDF parity remains unchanged at 10 Markdown failures.
- expected next reset should target parser/candidate preservation of
  title/body and next-page heading/list structure instead of threshold
  lowering, blocker removal, or string-specific patches.

## Reset 17G Parser/Candidate-side Structure Preservation

Reset 17G moves the next parity attempt upstream. Instead of broadening the
cross-page handoff gates or repairing Markdown after lowering, it preserves
title/body, heading/list, list-marker, and visible boundary evidence on the
parser/candidate side.

- Evidence-preservation model:
  - explicit parser-backed structure tags were added to
    `PdfV2TextFlowCandidate` reason tags:
    `structure_boundary_candidate`,
    `title_body_boundary_candidate`,
    `heading_list_boundary_candidate`,
    `list_marker_body_boundary_candidate`.
  - repeated-artifact/page-number page edges no longer have to be the only
    `PdfV2CrossPageBoundaryFact`; when a visible non-artifact continuation
    boundary exists nearby, 17G now targets that visible boundary and keeps the
    artifact edge only as audit signal.
- PDF v1 intent reused only as direction:
  - retain explicit title/body and list/body boundary preservation.
  - retain visible-content-over-artifact boundary preference.
  - reject phrase-specific patches, normalizer overrides, and broad heading
    rewrites.

Repo-local June 13, 2026 sample result:

- the 10-failure taxonomy did not change:
  - image placement/caption: `pdf_image_form_xobject`,
    `pdf_image_inline`, `pdf_image_xobject`
  - cross-page merge should happen: `pdf_cross_page_paragraph`,
    `pdf_cross_page_should_merge_phase15`
  - cross-page split/next-page structure should happen:
    `pdf_cross_page_should_not_merge_phase15`
  - header/footer: `pdf_header_footer_variants_phase15`
  - heading/list structure: `pdf_heading_false_positive_phase15`,
    `pdf_heading_vs_short_sentence`
  - column/reading order: `pdf_two_column_negative_phase15`
- no sample expected files changed.
- the wrapper summary may still print `rows=0`; the run's
  `markdown-only.entrypoint.log` remains authoritative.

Target sample outcome matrix:

| sample | 17G evidence change | visible result after 17G | still failing because |
| --- | --- | --- | --- |
| `pdf_cross_page_paragraph` | cross-page fact retargeted from repeated-artifact/page-number edge to the visible continuation boundary | visible `page` / `break` paragraph join now happens | following `Next Section` still stays H1 instead of the expected level |
| `pdf_cross_page_should_merge_phase15` | no additional structure survives before semantic ownership | no visible output change | title/body collapse still happens before structural-handoff ownership |
| `pdf_cross_page_should_not_merge_phase15` | parser-backed next-page paragraph/list structure now survives into candidate-backed emission | next-page structure no longer flattens into one line | heading/list classification and full body continuation still differ from expected |
| `pdf_heading_false_positive_phase15` | none by design | no visible output change | failure is not owned by cross-page structure preservation |
| `pdf_heading_vs_short_sentence` | none by design | no visible output change | remaining diff is list/heading structure, not cross-page arbitration |

Reset 17G closeout:

- product output changed narrowly, but visible sample parity count remained 10.
- no expected outputs changed.
- the narrow preserved-evidence changes are retained.
- the next reset should target remaining heading/list/title-body structure
  ownership instead of gate relaxation or string-specific repair.

## Reset 17H Consume Preserved Structure Evidence In Semantic Arbitration

Reset 17H keeps the 17G evidence-preservation model but moves one step further:
consume the preserved typed structure evidence inside semantic arbitration
instead of relying only on text shape after candidate mode is selected.

- Evidence consumed:
  - `structure_boundary_candidate`
  - `title_body_boundary_candidate`
  - `list_marker_body_boundary_candidate`
- Narrow semantic changes:
  - parser-backed title/body title lines may now classify as `Heading` before
    lowering when the candidate already carries title/body boundary evidence and
    following-body evidence.
  - parser-backed list/body candidates may now classify as list items from the
    preserved structure evidence path instead of relying only on raw marker
    parsing.
  - multi-line parser-backed list items now preserve the full list body text in
    semantic output.
- What 17H still rejects:
  - no normalizer patching.
  - no phrase-specific or sample-specific rules.
  - no broad heading rewrite.
  - no bridge-owned classifier behavior.

Repo-local June 13, 2026 sample result:

- the 10-failure taxonomy still does not change.
- no sample expected files changed.
- the wrapper summary may still print `rows=0`; the run's
  `markdown-only.entrypoint.log` remains authoritative.

Target sample outcome matrix:

| sample | 17H semantic change | visible result after 17H | still failing because |
| --- | --- | --- | --- |
| `pdf_cross_page_paragraph` | none; no new stable title/heading evidence reached semantic arbitration | no visible output change in 17H | `Next Section` still remains H1 instead of the expected level |
| `pdf_cross_page_should_merge_phase15` | none; title/body evidence is still missing before semantic ownership | no visible output change | title/body collapse still happens before semantic arbitration can consume preserved structure evidence |
| `pdf_cross_page_should_not_merge_phase15` | full ordered-list body text now survives semantic output | paragraph/list split remains preserved and the list body is now complete | title and heading levels are still wrong, so expected output is still not reached |
| `pdf_heading_false_positive_phase15` | none by design | no visible output change | failure is outside this narrow preserved-evidence path |
| `pdf_heading_vs_short_sentence` | none by design | no visible output change | remaining diff is still single-page heading/list structure, not this cross-page semantic-evidence path |

Reset 17H closeout:

- product output changed narrowly again, but visible PDF parity count remained
  10.
- no expected outputs changed because the only visible 17H improvement was
  partial.
- the next reset should inspect missing heading/title evidence for the
  remaining heading-level mismatches rather than widen semantic rules broadly.

## Reset 17I Heading/Title Evidence Modeling

Reset 17I adds a typed heading/title evidence layer and a narrow parser-side
document-lead title/body split, but it does not reduce visible PDF parity.

Repo-local June 13, 2026 outcome:

- `samples/check.sh --format pdf` still shows the same 10 failing PDF Markdown
  samples when run with explicit native runner overrides.
- the wrapper summary may still print `rows=0`; the
  `markdown-only.entrypoint.log` remains authoritative.
- no expected outputs changed.
- direct CLI output for:
  - `pdf_cross_page_paragraph`
  - `pdf_cross_page_should_merge_phase15`
  - `pdf_cross_page_should_not_merge_phase15`
  - `pdf_heading_false_positive_phase15`
  - `pdf_heading_vs_short_sentence`
  is byte-for-byte identical to Reset 17H output.

Practical effect:

- 17I improves evidence typing, coverage, and diagnostics.
- 17I does not yet move ownership of the remaining visible heading/title
  mismatches.
- the parity gap therefore remains exactly where 17H left it:
  - one cross-page sample still misses only heading level (`Next Section` H1
    vs expected H2),
  - two phase15 samples still miss title/body or heading/title ownership,
  - two single-page heading/list samples still fail outside cross-page
    handoff.

## Reset 17J Parity Line Closeout And Next-gap Selection

Reset 17J closes out the 17C-17I parity line without changing product output.

Closeout summary:

- 17C introduced fact-backed cross-page arbitration.
- 17D added opt-in audit counters and proved the visible failures were still
  mixed with heading/title/list structure.
- 17E added structural handoff and fixed a narrow bridge-threading bug.
- 17F added target signal tracing and localized ownership of the remaining
  target failures.
- 17G moved evidence preservation upstream and produced the last visible
  cross-page parity improvements.
- 17H consumed preserved structure evidence and produced the last visible
  list-body preservation improvement.
- 17I modeled typed heading/title evidence explicitly, but produced no visible
  Markdown delta relative to 17H.

Why parity stayed at 10:

- the remaining cross-page-labeled failures are no longer clean
  paragraph-handoff bugs; they are mixed with heading/title ownership.
- the remaining single-page and asset/layout failures were intentionally out of
  scope for 17C-17I.
- no sample expected files changed, and no string-specific patching was used.

Remaining-failure readiness matrix:

| sample | owner layer | available evidence | missing evidence | string-patch risk | next-fix readiness |
| --- | --- | --- | --- | --- | --- |
| `pdf_cross_page_paragraph` | semantic arbitration | visible-boundary cross-page fact, structural handoff, typed heading/title evidence | stable heading-level evidence | medium | audit first |
| `pdf_cross_page_should_merge_phase15` | parser/model | cross-page fact and typed title/body model | real parser-owned title/body split in sample shape | high | blocked |
| `pdf_cross_page_should_not_merge_phase15` | semantic arbitration | preserved split, list-body evidence, typed heading/title evidence | stable title/heading-level evidence | medium | audit first |
| `assets/pdf_image_form_xobject` | asset placement | image extraction | typed caption / nearby-heading placement evidence | high | audit first |
| `assets/pdf_image_inline` | asset placement | inline image extraction | typed title-vs-caption placement evidence | medium | audit first |
| `assets/pdf_image_xobject` | asset placement | image extraction | typed title-vs-caption placement evidence | medium | audit first |
| `pdf_header_footer_variants_phase15` | insufficient geometry/font evidence | repeated-artifact filtering | stronger page-to-page repetition evidence | medium | ready |
| `pdf_heading_false_positive_phase15` | parser/model | typed heading/title blockers | stronger multi-line structure and font/geometry evidence | high | blocked |
| `pdf_heading_vs_short_sentence` | semantic arbitration | typed heading/title blockers, intro-phrase guard | stable list-marker ownership | medium | ready |
| `pdf_two_column_negative_phase15` | insufficient geometry/font evidence | current block/candidate flow | column-aware geometry/reading-order evidence | low | defer |

Freeze decision:

- Pause the cross-page / heading-title line here.
- Return only after parser-owned geometry/font/level evidence or stronger
  parser-owned title/body and single-page structure evidence is available.

Chosen next target:

- next highest-value PDF v2 gap: `header/footer variants`
- rationale:
  - isolated failing sample,
  - existing repeated-artifact suppression already provides a fact-backed
    starting point,
  - likely narrower than column/reading-order and less string-patch-prone than
    remaining heading/title cleanup.
- recommended next reset name:
  - `PDF v2 Productization Reset 17K: header/footer repetition evidence audit`

Explicit anti-patch warning:

- do not add string-specific normalizer patches.
- do not add sample-name-specific semantic rules.
- if the missing signal is geometry/font/repetition evidence, add that evidence
  first or defer the fix.
