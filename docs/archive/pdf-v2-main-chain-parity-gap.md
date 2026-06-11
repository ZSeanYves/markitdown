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

## 3. v1 PDF Main-chain Capability Summary

| capability | v1 behavior | evidence file/test | notes |
|---|---|---|---|
| Dispatcher registration | `.pdf` is default-enabled and routes to `@pdf.parse_pdf`. | `convert/convert/dispatcher.mbt`; `convert/convert/test/dispatcher_registry_test.mbt` | Registry notes explicitly say native PDF through `convert/pdf`. |
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
| Product `@core.Document` output | not implemented | absence in `convert/pdf_v2`; pipeline returns `PdfV2ConvertPipelineResult` | Largest blocker before dispatcher registration. |
| Markdown headings/lists/tables/images/links/forms/outlines | not implemented | lowerer tests assert no semantic Markdown | v2 intentionally does not emit v1 product semantics yet. |
| Metadata/origin product surface | not implemented | no `@core.Origin`/asset origin bridge in v2 convert | Needed for parity with v1 main chain. |
| Diagnostics renderer/goldens | removed | this reset | Not current route. |

## 5. v1 vs v2 Gap Matrix

| capability | v1 status | v2 status | gap type | expected diff risk | priority |
|---|---|---|---|---|---|
| Dispatcher entry | Registered default PDF path to v1 | Not registered by constraint | Integration gap | High once switched | P0 later, after bridge |
| Product output bridge | Returns `@core.Document` | Returns pipeline result/fragments only | Product bridge missing | High | P0 |
| Plain text extraction | Real PDF to Markdown paragraphs | Real parser path, fact fragments only | Product lowering gap | High | P0 |
| Page/block ordering | Convert page objects interleave text/images by page object order | Source-order block candidates only | Ordering gap | High | P0 |
| Default gate behavior | v1 does not block plain text through a v2 no-model gate | v2 default gate can abstain on unsupported/capped context | First diff suppression risk | High | P0 |
| Error behavior | Raises app errors / native parse failures through main chain | Pipeline has fail-closed result, not dispatcher error contract | Contract gap | High | P0 |
| Metadata/origin | Product origins, asset origins, metadata JSON | Parser source refs only | Product metadata gap | High | P0 |
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
| Page breaks/provenance | Page origins in metadata; no dedicated product page-break block found | Optional PageBreak fact fragment, no product bridge | Product policy gap | Medium | P2 |
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
  - Interface exists, but product semantics are not connected.
- `lower_pdf_v2_document_scaffold`:
  - Historical scaffold output exists for boundary testing, not main-chain product output.

## 7. Capabilities To Complete Before Dispatcher Registration

- v2 pipeline result -> main convert output bridge:
  - Build `@core.Document` output from v2 facts/fragments.
  - Preserve source name, page origin, block origin, and asset origin hooks.
- Plain text block/page ordering:
  - Produce useful paragraph blocks from real PDF path.
  - Keep page order and source order deterministic enough for expected diffs.
- Error behavior:
  - Map parser/pipeline failure into the dispatcher-facing `Result[@core.Document, @core.AppError]` contract.
  - Keep fail-closed behavior with no old PDF fallback.
- Default options:
  - Choose product-run defaults that keep text flowing for first diff collection.
  - Do not let no-model gate abstain block all text in the first controlled registration run.
- No diagnostics in product output:
  - Warnings/risks can stay internal/audit facts.
  - Removed diagnostics renderer text must not be reintroduced as Markdown.
- No gate blocking first diff run:
  - Run gate disabled or text-preserving by default during the first expected-diff batch.
- Boundary guards:
  - Keep convert from importing old PDF runtime, mbtpdf vendor internals, quality-lab assets, or external model/data files.

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
- First implement a narrow v2 product bridge:
  - `convert_pdf_v2_experimental_from_path`
  - plain text fragments
  - `@core.Document`
  - origin metadata
  - fail-closed error mapping
- Configure first-run defaults so no-model gate does not hide text during diff collection.
- Then prepare controlled dispatcher registration and inspect expected diffs.
- After dispatcher registration, fix text/decode/spacing/order first, then link/image/table/metadata, then forms/annotations/outlines, then headings/lists/noise.
- Start model integration only after the diff-driven parser signals are stable.
