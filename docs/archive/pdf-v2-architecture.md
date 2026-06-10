# PDF Architecture v2

Status: proposed architecture contract / experimental v2 design

PDF v2 is a clean experimental architecture for the main-repository PDF stack.
It covers the vendor/core substrate, parser source facts, normalized document
model, layout recovery, model/rule cooperation, and convert lowering. It is not
the current runtime and it is not a patch plan for the old PDF path.

The core design rule is:

```text
PDF input is scanned once by the vendor/raw/parser pipeline.
```

RESET-16 locks the current implementation direction:

```text
mbtpdf owns low-level PDF parsing.
PDF v2 owns diagnostics, source-event contracts, parser facts, feature/export,
classifier gates, and fail-closed lowering policy.
```

PDF v2 is not a full low-level PDF parser rewrite inside `doc_parse/pdf_v2`.
The stable `open_pdf_core_v2(Bytes)` entry remains scaffold-only and
fail-closed; the authorized real reader path is `open_pdf_core_v2_perf(Bytes)`,
a private adapter over mbtpdf. The v2 adapter may add source refs, object refs,
page indices, content order, decode confidence, structured warnings/risks,
reason tags, and tolerant Unicode/ToUnicode handling. It must not regrow a
separate self-written xref/object/content-stream parser. The tonyfettes Unicode
helper may be used only inside tolerant Unicode/ToUnicode normalization, not as
a separate parser backend.

After that one pass, parser-owned facts, source references, layout facts, risks,
and classifier-ready features are the only inputs allowed for convert, model
inference, feature export, debug summaries, and downstream quality analysis.
Convert must never reopen the PDF, reparse content streams, or rebuild canonical
parser layout.

Current reader-foundation hardening record:

* `open_pdf_core_v2(Bytes)` remains scaffold-only and fail-closed.
* `open_pdf_core_v2_perf(Bytes)` remains the only authorized real reader path
  and stays mbtpdf-backed.
* The v2 adapter owns diagnostics, source/object/stream refs, page indices,
  content order, decode confidence, reason tags, provenance tags, and summary
  metrics.
* mbtpdf owns low-level PDF parsing, object/xref/page/resource traversal,
  stream decode, content operators, text/font extraction, and CMap/ToUnicode
  substrate behavior.
* `tonyfettes/encoding` is used for strict UTF-16BE ToUnicode target decode;
  `tonyfettes/unicode/normalization` is used for NFC normalization before text
  enters source events.
* Reader summary metrics are diagnostics/audit facts for later parser features:
  stream counts and decoded-byte counters, text/glyph/char counts,
  low-confidence ratio, font/Type0/CID/subset/embedded counts, ToUnicode/NFC
  counts, bad-ToUnicode counts, unmapped-code counts, warnings, and risks.
* No raw or decoded stream bytes are exposed to convert. Convert consumes only
  parser/model facts and never performs a raw PDF reparse.
* The RESET-11/12A/12B self-written xref/object/content parser is not restored.

PDF-V2-RESET-2 Core Facade And Source Bridge Note:

* Phase 2 introduces the first `doc_parse/pdf_v2` narrow facade types:
  `PdfV2CoreOpenOptions`, `PdfV2CoreDocument`, `PdfV2CorePageFact`, and
  `PdfV2CoreEvent`.
* Phase 2 introduces `PdfV2SourceDocument` and a raw bridge from core events to
  source events. The bridge preserves page/source/object refs, reason tags,
  warnings, risks, and one-pass/no-fallback summary fields.
* This phase intentionally does not perform text reconstruction, line/block
  grouping, layout recovery, convert lowering, dispatcher switching, model file
  reading, or old-runtime fallback.
* The real mbtpdf reader adapter remains the next implementation step. It must
  consume mbtpdf protected facts once, keep performance caps in open options,
  and surface unsupported, malformed, encrypted, rare, and capped capabilities
  as warnings, risks, or capability flags rather than fallback.

PDF-V2-RESET-3 Minimal Real Reader Adapter Note:

* Phase 3 adds a minimal path-based mbtpdf reader adapter in `doc_parse/pdf_v2`.
* The adapter opens real PDF bytes through mbtpdf, extracts page facts, emits
  page/content-stream boundary events, and maps located content operators as
  raw-op-style `Unknown` source events.
* `max_pages` and `max_events` are enforced before facts/events leave the
  adapter, with capped behavior reported as warnings and risks.
* Malformed, unreadable, encrypted, or page-tree failures fail closed through
  structured warnings/risks. No old-runtime fallback, dispatcher switch,
  convert lowering, text reconstruction, glyph decode, image decode, or layout
  recovery is introduced by this phase.

## Runtime Adoption Record

PDF v2 is not adopted yet. The current `doc_parse/pdf` and `convert/pdf`
runtime remains the default PDF path. Dispatcher behavior is unchanged, the old
runtime is untouched, and this document is a contract input for later scaffold
work rather than an implementation record for an active runtime.

Current adoption status:

* Old PDF runtime: still normal path.
* Dispatcher: not switched.
* v2 code scaffold: pending.
* v2 contract: this document plus the existing PDF model-training architecture
  contract.
* Model runtime: not wired.
* Vendor facade split: planned, not implemented here.

Runtime adoption requires all of the following gates:

* Quality gate: v2 output meets documented sample and quality-lab thresholds.
* Performance gate: latency, memory, package closure, and inference overhead
  stay within explicit budgets.
* Model gate: layout recovery and block classifier hints are calibrated,
  fail-closed, and explainable.
* Vendor gate: normal runtime uses the necessary reader/parser subset without
  pulling writer/debug/vendor-slow tests into fast closure.
* No-fallback gate: normal v2 conversion has no hidden fallback to the old PDF
  parser, external tools, model TSVs, or quality-lab artifacts.

## Problem Statement

The existing PDF path contains useful engineering work, but it has reached the
point where further patching would reinforce the wrong architecture.

Observed problems:

* Parser rules are overfit to accumulated regressions. Text grouping,
  hard-wrap repair, page-number detection, heading candidates, and text artifact
  repair form a nested rule chain.
* Convert compensates for missing parser layout facts. Table-like regions,
  caption proximity, image caption pairing, repeated text, link overlap,
  heading demotion, and list suppression are largely convert-derived.
* Parser and convert both judge adjacent semantics such as heading, list,
  caption, paragraph continuation, and noise, which makes local changes
  difficult to reason about.
* Vendored `mbtpdf` has coarse package granularity. Runtime-adjacent packages
  mix reader, writer, codec, font, crypto, operator, page, and test concerns.
* PDF tests are a heavy closure. Public tests, whitebox tests, debug tests,
  product integration tests, layout-model tests, and vendored tests all exist
  in the same repository tree.
* Debug, export, model TSV, and model JSON paths are useful evidence, but they
  are boundary hazards if they enter normal runtime.
* The current parser-facing API is path-oriented and fully materializes raw,
  text, and model stages before convert can act.
* External `text_block_classifier` iterations have shown that the bottleneck is
  not simply classifier gating; the parser/export foundation lacks enough
  stable facts for captions, list items, headings, and abstain decisions.

PDF v2 therefore needs a full rewrite from vendor/core facade through parser
model and convert lowering. It should reuse facts, tests, and lessons, not the
old patch chain.

## Lessons Learned from PDF v1 / DOCX / PPTX

Keep:

* Geometry facts: bbox, origin, quad, page boxes, page rotation, user unit, and
  relative page position.
* Source and provenance facts: source stream, source op, content order, object
  refs, page refs, raw content stream refs, and stable block ids.
* Page and object facts: images, vectors, annotations, links, forms, outlines,
  destinations, document metadata, and low-level warnings.
* Inspect and risk reporting: empty extraction, low signal, partial support,
  malformed source, unsupported objects, and confidence/risk summaries.
* Fail-closed behavior: ambiguous captions are not attached, uncertain headings
  are demoted, unsupported OCR does not silently pretend to work.
* Reason tags and decision summaries: gates should explain which facts,
  constraints, model hints, and risks produced the final decision.
* Parser-owned model / convert-owned policy, as proven by the DOCX/PPTX/XLSX
  direction: parser facts flow forward, product Markdown policy stays in
  convert.
* Quality-lab error-bucket learning: dominant caption, list item, paragraph,
  and heading errors should inform parser facts and classifier inputs.
* Deterministic regression fixtures: small repo-local fixtures remain useful
  for parser contracts and dispatcher readiness.

Avoid:

* Runtime fallback to old PDF, external tools, or local corpus paths.
* Repeated PDF scanning by parser, convert, feature export, or model inference.
* Convert-owned raw parsing or canonical layout reconstruction.
* Parser-emitted Markdown policy such as final heading/list/caption/table
  output roles.
* Counters, fallback signals, or profile markers as substitutes for typed
  model contracts.
* Broad `fallback_signal`-style fields that hide missing facts.
* Debug/export/model TSV packages in normal runtime closure.
* Hidden environment-variable gates for complex production policy.
* Vendor writer, crypto-heavy, or debug examples in fast runtime/test closure.

## Architecture Layers

### A. `doc_parse/pdf_core_v2` Vendor Facade Layer

Responsibilities:

* Own PDF bytes, object graph, xref tables, xref streams, object streams,
  compressed streams, page tree, resources, content streams, filters, fonts,
  images, vectors, annotations, forms, outlines, metadata, and security
  metadata.
* Provide narrow typed facts to the parser. The facade should expose enough raw
  structure for parser reconstruction without leaking arbitrary vendor object
  types through the rest of the repository.
* Decode streams and content operations needed by parser source events.
* Preserve source/object/content-order references.
* Surface malformed, unsupported, encrypted, or partially supported source as
  structured diagnostics.
* Keep runtime, debug, write, and test-only capabilities separated by facade.

Non-responsibilities:

* Char/span/line/block grouping.
* Layout recovery.
* Markdown, core IR, asset export, or product metadata.
* Model training, TSV export, feature reports, or quality-lab integration.
* Debug-only writer and fixture APIs in normal runtime.

Inputs:

* PDF bytes.
* Path-based convenience openers.
* Future input handles or archive entries, if the repository adds them.

Outputs:

* Typed core document/page/object records.
* Decoded streams and diagnostics.
* Page content streams.
* Text and graphics operations.
* Resource, font, image, annotation, form, outline, destination, and metadata
  records.
* Source/object/content-order references.

Example pseudo APIs:

```moonbit
pub struct PdfCoreV2Document
pub struct PdfCoreV2Page
pub struct PdfCoreV2ObjectRef
pub struct PdfCoreV2StreamRef
pub enum PdfCoreV2Diagnostic

pub fn open_pdf_core_v2(bytes : Bytes) -> PdfCoreV2Document raise PdfV2Error
pub fn open_pdf_core_v2_file(path : String) -> PdfCoreV2Document raise PdfV2Error
pub fn list_pdf_core_v2_pages(doc : PdfCoreV2Document) -> Array[PdfCoreV2Page]
pub fn read_pdf_core_v2_page_content(
  doc : PdfCoreV2Document,
  page : PdfCoreV2Page,
) -> Array[PdfCoreV2ContentOp] raise PdfV2Error
pub fn pdf_core_v2_diagnostics(doc : PdfCoreV2Document) -> Array[PdfCoreV2Diagnostic]
```

### B. `doc_parse/pdf_v2` Raw Source Layer

Responsibilities:

* Consume `pdf_core_v2` facts exactly once per PDF input.
* Normalize vendor/core objects into typed parser source events.
* Preserve content order, source refs, object refs, stream refs, text object
  ids, resource ids, and page indices.
* Represent text ops, glyph candidates, graphics ops, image ops, vector/path
  ops, annotation/form refs, outline refs, destinations, resources, and
  malformed/unknown events.
* Carry structured warnings for unsupported filters, malformed operators,
  missing resources, partial page extraction, encrypted-but-readable states,
  and low-signal source.

Non-responsibilities:

* Markdown policy.
* Final block semantic classification.
* Convert policy.
* Model file loading.
* Feature TSV rendering.
* Fallback to the old parser.

### C. `doc_parse/pdf_v2` Text Reconstruction Layer

Responsibilities:

* Build glyph, char, span, line, and block records from source events.
* Preserve geometry, font, writing direction, rotation, fill/stroke color,
  decode confidence, language hints, and source refs.
* Compute line and block facts needed for downstream layout recovery and block
  classifier decisions.
* Produce stable ids for chars/spans/lines/blocks where possible.
* Use bounded, source-first grouping rules.
* Represent list marker, caption prefix, heading shape, body density, and
  continuation shape as facts, not final Markdown decisions.

Non-responsibilities:

* Final heading/list/caption/table/noise Markdown roles.
* Convert-owned block classification.
* Table Markdown rendering.
* Image caption final pairing policy.
* Legacy fallback.

### D. `doc_parse/pdf_v2` Layout Recovery Layer

Responsibilities:

* Recover parser-owned layout facts: page regions, table/figure/caption/header
  /footer/text/title/section-header regions, reading order, multi-column
  structure, cross-page boundary candidates, geometry consistency risks, and
  low-signal/malformed layout risks.
* Use deterministic rules, layout recovery model hints, or both.
* Maintain confidence, source, reason tags, and risk penalties for every hint.
* Build page-local spatial indexes for proximity facts such as near image,
  near figure, near table, near annotation, edge distance, and overlap.
* Feed layout facts into the normalized parser model.

Non-responsibilities:

* Final Markdown output.
* `text_block_classifier` labels.
* Convert policy.
* Feedback loops from convert decisions.

### E. `doc_parse/pdf_v2` Normalized Document Model Layer

Responsibilities:

* Assemble `PdfV2DocumentModel`.
* Include document metadata, source summary, pages, text blocks, lines, spans,
  chars, images, vectors, annotations, forms, links, destinations, outlines,
  layout regions, reading order, cross-page boundaries, risks, warnings,
  source refs, and classifier-ready features.
* Represent unsupported PDF capabilities as structured warnings and risks, not
  fallback or silent loss.
* Expose stable model services to convert and quality-lab feature export.
* Keep model records parser-owned and immutable from convert.

Non-responsibilities:

* Asset path naming.
* Markdown table rendering.
* Final heading depth.
* Image caption final placement.
* Output metadata policy.
* Runtime model parameter loading from external files.

### F. `convert/pdf_v2` Block Classifier / Decision Gate Layer

Responsibilities:

* Consume parser facts and `text_block_classifier` hints.
* Combine deterministic constraints, model confidence, feature support, risk
  penalty, and weighted gates.
* Produce convert-local decisions with label, confidence, abstain state,
  blocked reason, decision source, and reason tags.
* Preserve fail-closed behavior for low confidence, hard constraint conflicts,
  malformed source, and low-signal pages.

Non-responsibilities:

* Parser mutation.
* Layout recovery.
* Raw PDF reading.
* Source/object provenance reconstruction.
* External file/model loading in normal runtime.

### G. `convert/pdf_v2` Lowering Layer

Responsibilities:

* Lower `PdfV2DocumentModel` to core IR.
* Own Markdown-facing policy.
* Own final heading, paragraph, list, caption, table-like, noise, image caption
  pairing, annotation, form, link, asset, origin, metadata, and warning
  presentation decisions.
* Consume model hints and decision gate outputs.
* Fail closed when model/rule conflicts occur or confidence is low.

Non-responsibilities:

* Raw PDF parse.
* Source reconstruction.
* Canonical layout recovery.
* Model training.
* Feature TSV export.
* Old parser fallback.

### H. Historical Legacy Evidence Layer

Responsibilities:

* Preserve notes from the old PDF path, design input matrices, quality triage,
  external training reports, and regression summaries.
* Explain why v1 fallback, old tools, TSV exports, and model JSON paths are
  forbidden in v2 runtime.
* Provide evidence for future milestones and adoption gates.

Non-responsibilities:

* Normal conversion.
* Runtime fallback.
* Product profile counters.
* Hidden compatibility oracle.

## Vendor Facade Details

PDF v2 treats the vendor/core substrate as part of the architecture, not as an
opaque dependency. The goal is a complete PDF parsing foundation with explicit
facades and bounded runtime closure.

In the current scaffold, mbtpdf is the authorized low-level backend for this
foundation. It owns object graph and xref handling, stream decode, page tree
iteration, content operator parsing, text/font extraction, CMap/ToUnicode
experience, and security metadata discovery. PDF v2 owns the adapter contract:
typed records, diagnostics, source refs, confidence, reason tags, normalized
model facts, layout/feature/classifier inputs, and fail-closed convert lowering.
Future work should reshape or upgrade mbtpdf behind this boundary rather than
recreating a parallel PDF engine in `doc_parse/pdf_v2`.

Planned facade components:

```text
pdf_core_read
pdf_core_objects
pdf_core_streams
pdf_core_filters
pdf_core_ops
pdf_core_text
pdf_core_fonts
pdf_core_pages
pdf_core_images
pdf_core_vectors
pdf_core_annotations
pdf_core_forms
pdf_core_outlines
pdf_core_security
pdf_core_debug
pdf_core_write_test_only
```

Normal runtime may depend only on the necessary subset of read, objects,
streams, filters, ops, text, fonts, pages, images, vectors, annotations, forms,
outlines, and security metadata. Writer APIs, debug examples, vendor fixture
builders, and slow vendor tests must not enter normal runtime closure.

Required coverage direction:

* PDF object graph.
* Xref tables and xref streams.
* Object streams.
* Compressed streams.
* Filters and codecs.
* Encryption and permissions metadata.
* Page tree and inherited page attributes.
* Resources.
* Content streams.
* Graphics state and text state.
* Text showing operators.
* Font dictionaries, embedded fonts, font subsets, Type0, Type1, TrueType, and
  CID fonts.
* CMap and ToUnicode.
* Ligature and compatibility glyph handling.
* Images, masks, soft masks, and inline images.
* Vectors, paths, strokes, and fills.
* Annotations, links, URI actions, destinations, and named destinations.
* Forms and AcroForm fields.
* Outlines and bookmarks.
* Metadata, document info, and XMP when available.
* Page boxes, rotation, and user unit.
* Optional content groups if discoverable.
* Malformed, low-signal, and partially supported object reporting.

Security and encryption stance:

* Encryption and permission facts belong in `pdf_core_security`.
* Unsupported encrypted content should produce explicit errors or risks.
* Permission metadata should be surfaced as facts where readable.
* Runtime must not silently skip encrypted pages and pretend extraction
  succeeded.

Filters/codecs stance:

* Common stream decode support is runtime-relevant.
* Rare filters and codecs must not be removed by intuition. They require
  fixture coverage, diagnostics, and package-closure measurement.
* Unsupported filters produce structured warnings/risks.

Font/CMap stance:

* ToUnicode and CMap correctness is essential to text PDFs.
* Font subset naming, embedded fonts, missing encodings, and fallback glyph
  mapping must be represented as decode facts and risks.
* Large glyph tables should be considered for lazy loading or narrower facade
  exposure if closure measurement justifies it.

Images/vectors/annotations/forms stance:

* These objects are parser facts even when convert cannot render them fully.
* Missing object support is a warning/risk, not a reason to fallback.
* Geometry must be captured because caption, table, link, and form policies
  depend on proximity and overlap.

## Raw Source Layer Details

The raw source layer is the first parser-owned layer above the vendor facade.
It should create a stable stream of source events with exact provenance.

Source records should include:

* Page source: page index, raw page object ref, media/crop/bleed/trim/art boxes,
  rotation, user unit, inherited resources, content stream refs, page label, and
  page-level diagnostics.
* Content stream event: stream ref, stream index, op index, content order index,
  graphics state snapshot where bounded, and malformed-op diagnostics.
* Text op event: text object id, operator kind, text state, font ref, font size,
  text matrix, raw bytes, decoded glyph candidates, explicit break signal, and
  source refs.
* Glyph event: unicode text, raw bytes, bbox, origin, quad, advance, glyph
  width, font facts, decode confidence, ligature/compatibility flags, writing
  direction, and source ref.
* Graphics op event: path construction, stroke/fill state, clipping, transform,
  line width, dash, color, and source ref.
* Image event: bbox, pixel size, colorspace, bits per component, filter, mask,
  soft mask, inline flag, object ref, alt text, payload availability, and source
  refs.
* Vector/path event: bbox, path kind, stroke/fill color, stroke width, dash,
  opacity if available, and source refs.
* Annotation/form event: subtype/type, flags, bbox, contents, subject, URI,
  destination, target page, field name/value/options, checked state, object ref,
  and source refs.
* Resource event: font, XObject, color space, pattern, graphic state, procedure
  set, and unresolved resource diagnostics.
* Unknown/malformed event: raw kind, source ref, severity, recoverability,
  message, and suggested parser risk.

The raw source layer must not decide whether a block is a heading, list item,
caption, or Markdown table. It records the source facts that make those later
decisions possible.

## Text Reconstruction Layer Details

Text reconstruction converts source events into a bounded text model:
glyphs/chars, spans, lines, and text blocks.

Rules:

* Source facts first. Grouping must be explainable from geometry, source order,
  font facts, writing direction, and explicit text state.
* No Markdown semantics in grouping. A line can have a heading-like shape or
  list-marker fact, but the parser does not emit final Markdown heading/list
  policy.
* Stable ids. Blocks, lines, spans, chars, objects, and regions need stable ids
  suitable for source refs, quality-lab exports, and convert decision summaries.
* Bounded grouping. Rules should be page-local or block-local unless a
  cross-page boundary service explicitly owns the decision.
* Writing mode and rotation are facts. Horizontal, vertical, rotated, CJK,
  right-to-left, and unknown writing modes should not be collapsed into a
  single left-to-right assumption without a risk.
* Ligature and compatibility glyph handling is captured at glyph/char level,
  with decode confidence available for abstain/risk decisions.
* List marker is a fact: marker text, marker kind, marker bbox, hanging indent,
  continuation counts, and line indentation are parser facts. Final list item
  output belongs to convert.
* Caption prefix is a fact: figure/table/image prefix, enumeration pattern, and
  caption-like text shape are parser facts. Final object binding belongs to
  convert unless layout recovery has a high-confidence region association.
* Heading shape is a fact: font delta, gap before/after, page position, body
  density, and region hints are parser facts. Final heading depth belongs to
  convert.

## Layout Recovery Layer Details

Layout recovery is a parser-layer responsibility. It may be deterministic,
model-assisted, or both, but its outputs are parser-owned layout facts.

Responsibilities:

* Page regions: text, title, section-header, table, figure, caption,
  header-footer, artifact/noise, form, and unknown.
* Reading order: ordered block ids, region order, confidence, and reason tags.
* Multi-column detection and risk.
* Cross-page merge/no-merge candidates.
* Proximity facts: near image, near figure, near table, near vector, near
  annotation, near form, page edge distance, relative page position, overlap
  ratios, and nearest object ids.
* Geometry consistency risks: invalid bboxes, overlapping incompatible objects,
  source order/visual order conflict, rotated text risk, low text density, and
  low native text signal.
* Page-local spatial index to keep proximity feature extraction bounded.

Model cooperation:

```text
parser facts
  -> deterministic constraints
  -> layout_recovery model hints
  -> confidence calibration
  -> risk penalties
  -> weighted gate
  -> fail-closed layout fact
```

Every layout hint should carry:

* `deterministic_constraint_score`
* `model_confidence`
* `feature_support_score`
* `risk_penalty`
* `final_confidence`
* `decision_source`
* `reason_tags`

Convert feedback is forbidden. Convert may consume layout facts, but it cannot
modify the parser model or become an input to canonical layout recovery.

## Normalized Model Layer Details

`PdfV2DocumentModel` is the normalized parser-owned model. It is not Markdown,
not core IR, and not a convert decision log.

It should include:

* Document metadata: title, author, subject, keywords, creator, producer,
  creation/modification date, XMP summary when available, PDF version, document
  ids, encryption/permission metadata, and source summary.
* Source summary: page count, object count, stream count, unsupported feature
  count, decode warning count, low-signal count, and extraction completeness.
* Pages: page index, label, boxes, rotation, user unit, dimensions, source refs,
  risks, warnings, text blocks, objects, layout regions, and reading order.
* Text blocks: stable id, page index, text, bbox, lines, dominant font, dominant
  font size, writing direction, source refs, geometry features, text shape
  features, layout hints, and classifier-ready features.
* Lines: stable id, text, bbox, spans, baseline, line height, indent left/right,
  gaps, wrapped candidate, continuation candidate, list marker facts, and source
  refs.
* Spans/chars/glyphs: text, bbox, font/style/color, writing direction, decode
  confidence, ligature flags, raw/source refs, and break facts.
* Images: bbox, size, colorspace, filters, masks, inline flag, alt text, object
  refs, source refs, and extraction risk.
* Vectors: bbox, kind, path/stroke/fill facts, source refs, and table/figure
  support hints where factual.
* Annotations: subtype, flags, bbox, contents, subject, URI, destination, target
  page, object ref, color, source refs, and visibility facts.
* Forms: field type, flags, label/name, value, bbox, options, checked state,
  source refs, and visibility facts.
* Outlines/destinations/links: title, page target, named destination, URI
  target, object refs, and source refs.
* Layout regions: id, kind, bbox, confidence, source, member block ids, member
  object ids, and reason tags.
* Reading order: page/region/block order, confidence, source, and reason tags.
* Cross-page boundaries: left/right page and block ids, merge/no-merge hint,
  confidence, source, and risk tags.
* Risks and warnings: kind, severity, reason, affected ids, source refs, and
  recommended abstain behavior.
* Classifier-ready features: compact, stable, parser-owned feature values for
  convert and quality-lab export.
* Provenance: source refs and object refs attached to every represented entity.

Unsupported capabilities should become warnings/risks with source refs. Silent
loss and fallback are not valid parser behavior.

## Model And Rule Cooperation Details

PDF v2 treats models as formal architecture goals:

```text
layout_recovery -> parser layer
text_block_classifier -> convert layer
```

Models and deterministic rules must cooperate through one explicit gate rather
than rewriting the same semantic decision at different stages.

Priority order:

```text
hard constraints > high-confidence model hint > weak heuristic > abstain
```

Hard constraints include invalid geometry, incompatible source facts, explicit
low-signal risk, unsupported encrypted source, page/object visibility facts,
and deterministic contradiction between model label and parser facts. A model
hint can suggest labels, but it cannot hard override parser facts.

For every gated decision, record:

* `deterministic_constraint_score`
* `model_confidence`
* `feature_support_score`
* `risk_penalty`
* `final_confidence`
* `decision_source`
* `reason_tags`
* `abstain_reason` when no safe decision exists

`layout_recovery` cooperation:

* Consumes parser raw/text/geometry/object facts.
* Produces parser-owned regions, reading order, boundaries, and risks.
* Writes to the parser model only through typed layout result records.
* Does not classify final Markdown semantics.

`text_block_classifier` cooperation:

* Consumes parser-owned block/line/span/page/object/layout facts.
* Produces convert-local hints for heading, paragraph, caption, table-like,
  list item, footer/header noise, page number noise, keep-as-text, and
  uncertain.
* May provide confidence and reason tags.
* Does not mutate the parser model.

Runtime readiness is not proven by macro F1 alone. A classifier can have useful
high-confidence precision while still failing macro F1 on weak classes. Runtime
adoption requires calibrated high-confidence slices, explicit abstain behavior,
regression evidence, and blocked-reason reporting.

External model artifacts remain outside normal runtime unless separately
embedded or distilled as reviewed runtime assets. `model.pkl`, feature TSVs,
DocLayNet raw data, quality-lab caches, and training reports are never runtime
inputs.

## Convert Lowering Layer Details

`convert/pdf_v2` consumes only `PdfV2DocumentModel` and conversion options.
It owns all product-facing policy:

* Lowering normalized PDF blocks and objects to core IR.
* Final heading depth and section title policy.
* Paragraph, list, caption, table-like, footer/header noise, page-number noise,
  keep-as-text, and uncertain policy.
* Image caption pairing and placement.
* Link and annotation attachment.
* Form note emission.
* Table rendering or conservative text fallback.
* Asset export, asset path naming, origins, and product metadata.
* Warning presentation.
* Decision summaries and reason tags.

Convert must not:

* Scan raw PDF bytes.
* Reopen the input path.
* Reparse content streams.
* Reconstruct source/object provenance.
* Rebuild canonical layout.
* Call old parser fallback.
* Load external model files or quality-lab files.

If convert needs a fact, the fact belongs in `PdfV2DocumentModel`, a parser
model service, or a reviewed classifier hint. Low-confidence decisions lower to
paragraph, keep-as-text, skip pairing, keep split, or uncertain according to
the decision type.

## Historical Legacy Details

The current PDF path remains active until v2 reaches adoption gates. It is
historical evidence and a production fallback only in the sense that dispatcher
still points to it before v2 adoption; it is not a runtime fallback inside v2.

Historical references:

* `doc_parse/pdf`: raw/text/model/API/inspect lessons and parser facts.
* `convert/pdf`: lowering, fail-closed, reason tags, table/caption/link/noise
  lessons.
* `doc_parse/pdf/layout_model_tool`: development/export history only.
* `convert/pdf_layout`: feature/model/TSV history only.
* `convert/pdf_debug`: debug assist history only.
* `markitdown-quality-lab`: training/evaluation evidence only.

Forbidden in v2 runtime:

* Old parser fallback.
* Old layout tool as oracle.
* Model TSV/export feature files.
* Quality-lab cache or derived datasets.
* Product profile counters as semantic controls.
* Environment-variable hidden complex gates.

Quality-lab reports are evidence. They can shape feature contracts, labels,
and thresholds, but they are not runtime dependencies.

## Performance Contract

Performance is a first-class architecture goal, not a post-hoc optimization.

Required properties:

* One-pass scan: PDF bytes/content streams are consumed once by the
  vendor/raw/parser pipeline.
* Bounded memory: source events, parser model, spatial indexes, and classifier
  features should be bounded by pages, objects, and configured document limits.
* Bounded feature extraction: features must be page-local or use explicit
  indexed structures; no repeated full-document scans for each block.
* Minimal vendor runtime closure: writer/debug/vendor-slow tests are outside
  normal runtime and fast v2 tests.
* Batchable model inference: block and layout hints should be collected into
  page/document batches rather than per-rule ad hoc calls.
* Page-local spatial index: proximity features for images, vectors, tables,
  annotations, forms, edges, and regions should be near-linear.
* Linear or near-linear convert pass: lowering consumes ordered model records
  and decision summaries without raw reparse.
* Debug/export separated from runtime: feature TSV, debug dumps, and model
  reports live in dev or quality-lab lanes.
* Benchmark lanes begin during scaffold, not after dispatcher switch.

Metrics to track:

* Small PDF latency.
* Medium PDF latency.
* Large PDF memory.
* Batch throughput.
* Vendor closure compile time.
* `pdf_v2` package check/test time.
* Model inference overhead.
* Convert-only overhead.

Performance gates should be recorded as implementation milestones once v2 code
exists.

## MVP Scope

V2 MVP includes:

* One-pass core read.
* Page tree, boxes, rotation, user unit, and page labels where available.
* Text ops, font facts, ToUnicode/CMap basics, and glyph decode basics.
* Char/span/line/block parser model with geometry, source refs, and classifier
  ready features.
* Images, annotations, forms, and vectors as structured facts.
* Outlines and destinations where available.
* Layout recovery deterministic baseline for regions, reading order, edge
  risks, low-signal risks, and proximity facts.
* Runtime path for `text_block_classifier` only if the artifact is embedded or
  distilled as a reviewed runtime asset.
* Fail-closed convert decision gate with confidence, abstain, blocked reason,
  and reason tags.
* Structured warnings/risks for unsupported rare capabilities.
* No legacy fallback.

V2 MVP does not include:

* Pixel-perfect PDF rendering.
* OCR or scanned-PDF automatic fallback.
* Guaranteed full table reconstruction.
* JavaScript/action execution.
* Full interactive form semantics.
* Perfect reading order for every multi-column or highly designed PDF.

These are product output limits, not permission for the parser substrate to
ignore those objects. The parser should still surface objects and unsupported
capabilities as facts, warnings, or risks.

## Capability Roadmap

* V2-M0: architecture contract.
* V2-M1: vendor facade split plan.
* V2-M2: core object/page/stream read.
* V2-M3: text ops, glyph, and font extraction.
* V2-M4: char/span/line/block reconstruction.
* V2-M5: image, vector, annotation, form, outline, and destination facts.
* V2-M6: layout regions, reading order, cross-page boundaries, and risks.
* V2-M7: `text_block_classifier` runtime gate with embedded/distilled artifact
  path or deterministic no-model gate.
* V2-M8: convert baseline.
* V2-M9: quality-lab feature export from parser-owned facts.
* V2-M10: performance smoke and closure budget.
* V2-M11: dispatcher switch readiness.
* V2-M12: advanced PDF capabilities such as richer vectors, forms, rare
  codecs, optional content groups, and improved encrypted-document metadata.

## API Sketch

This is pseudo MoonBit. It is a contract sketch, not compile-ready code.

```moonbit
pub struct PdfV2SourceRef {
  page_index : Int
  object_ref : String?
  stream_index : Int?
  op_index : Int?
  content_order_index : Int?
  text_object_id : Int?
}

pub struct PdfV2CoreDocument {
  version : String
  page_count : Int
  diagnostics : Array[PdfV2Warning]
}

pub struct PdfV2RawPage {
  page_index : Int
  boxes : PdfV2PageBoxes
  rotation : Int
  user_unit : Double?
  events : Array[PdfV2SourceEvent]
  source_refs : Array[PdfV2SourceRef]
  warnings : Array[PdfV2Warning]
}

pub enum PdfV2SourceEvent {
  TextOp(PdfV2TextOp)
  Glyph(PdfV2Glyph)
  GraphicsOp(PdfV2GraphicsOp)
  Image(PdfV2Image)
  Vector(PdfV2Vector)
  Annotation(PdfV2Annotation)
  Form(PdfV2Form)
  Resource(PdfV2ResourceRef)
  Unknown(PdfV2UnknownSource)
}

pub struct PdfV2Glyph {
  unicode : String
  raw_bytes : Bytes?
  bbox : PdfV2Rect
  origin : PdfV2Point
  font_name : String?
  font_size : Double?
  decode_confidence : Double?
  source_ref : PdfV2SourceRef
}

pub struct PdfV2Char {
  text : String
  bbox : PdfV2Rect
  origin : PdfV2Point
  font : PdfV2FontRun?
  decode_confidence : Double?
  source_ref : PdfV2SourceRef
}

pub struct PdfV2Span {
  id : String
  text : String
  bbox : PdfV2Rect
  font_name : String?
  font_size : Double?
  style_flags : Array[String]
  color : PdfV2Color?
  chars : Array[PdfV2Char]
  source_refs : Array[PdfV2SourceRef]
}

pub struct PdfV2Line {
  id : String
  text : String
  bbox : PdfV2Rect
  spans : Array[PdfV2Span]
  baseline_y : Double?
  line_height : Double?
  indent_left : Double?
  indent_right : Double?
  gap_before : Double?
  gap_after : Double?
  wrapped_candidate : Bool
  continuation_candidate : Bool
  list_marker : PdfV2ListMarker?
  source_refs : Array[PdfV2SourceRef]
}

pub struct PdfV2TextBlock {
  id : String
  page_index : Int
  text : String
  bbox : PdfV2Rect
  lines : Array[PdfV2Line]
  dominant_font : String?
  dominant_font_size : Double?
  writing_direction : PdfV2WritingDirection
  geometry_features : Map[String, Double]
  text_shape_features : Map[String, Double]
  layout_hints : Array[PdfV2LayoutHint]
  classifier_ready_features : Map[String, Double]
  source_refs : Array[PdfV2SourceRef]
}

pub struct PdfV2Image
pub struct PdfV2Vector
pub struct PdfV2Annotation
pub struct PdfV2Form

pub struct PdfV2LayoutRegion {
  id : String
  kind : PdfV2LayoutRegionKind
  bbox : PdfV2Rect
  confidence : Double
  source : PdfV2DecisionSource
  member_block_ids : Array[String]
  member_object_ids : Array[String]
  reason_tags : Array[String]
}

pub struct PdfV2ReadingOrder {
  page_index : Int
  ordered_block_ids : Array[String]
  confidence : Double
  source : PdfV2DecisionSource
  reason_tags : Array[String]
}

pub struct PdfV2CrossPageBoundary {
  left_page_index : Int
  right_page_index : Int
  left_block_id : String?
  right_block_id : String?
  hint : PdfV2BoundaryHint
  confidence : Double
  reason_tags : Array[String]
}

pub struct PdfV2Risk {
  kind : PdfV2RiskKind
  severity : PdfV2RiskSeverity
  reason : String
  affected_ids : Array[String]
  source_refs : Array[PdfV2SourceRef]
}

pub struct PdfV2Warning {
  kind : PdfV2WarningKind
  severity : PdfV2RiskSeverity
  message : String
  source_refs : Array[PdfV2SourceRef]
}

pub struct PdfV2DocumentModel {
  metadata : PdfV2Metadata
  source_summary : PdfV2SourceSummary
  pages : Array[PdfV2Page]
  outlines : Array[PdfV2OutlineItem]
  destinations : Array[PdfV2Destination]
  risks : Array[PdfV2Risk]
  warnings : Array[PdfV2Warning]
}

pub struct PdfV2ClassifierHint {
  block_id : String
  suggested_label : String
  confidence : Double
  abstain : Bool
  blocked_reason : String?
  reason_tags : Array[String]
}

pub struct PdfV2Decision {
  block_id : String
  final_label : String
  confidence : Double
  decision_source : PdfV2DecisionSource
  abstain : Bool
  reason_tags : Array[String]
}

pub fn open_pdf_core_v2(bytes : Bytes) -> PdfV2CoreDocument raise PdfV2Error
pub fn parse_pdf_v2_source(
  core : PdfV2CoreDocument,
) -> PdfV2SourceDocument raise PdfV2Error
pub fn build_pdf_v2_text_model(
  source : PdfV2SourceDocument,
) -> PdfV2TextModel
pub fn recover_pdf_v2_layout(
  model : PdfV2TextModel,
  options : PdfV2LayoutOptions,
) -> PdfV2LayoutResult
pub fn build_pdf_v2_document_model(
  source : PdfV2SourceDocument,
  text : PdfV2TextModel,
  layout : PdfV2LayoutResult,
) -> PdfV2DocumentModel
pub fn lower_pdf_v2_document(
  doc : PdfV2DocumentModel,
  options : PdfV2LoweringOptions,
) -> @core.Document raise
```

## Implementation Record

PDF v2 is not implemented yet. This document records the intended architecture
contract for later scaffold and migration work.

Current record:

* v2 not implemented yet.
* Old PDF remains the normal path.
* Dispatcher is not switched.
* External `text_block_classifier` iterations reached useful high-confidence
  precision slices but not full macro F1 readiness.
* `layout_recovery` still needs parser-owned foundation and stable export
  facts.
* A design input matrix exists from previous PDF v2 preparation work.
* This document is contract input for later scaffold, not proof of adoption.

Implemented packages will be recorded here once they exist. Adoption notes
should include commit ids, validation commands, quality-lab rows, performance
numbers, package closure measurements, and no-fallback guard results.

## Test Strategy

PDF v2 tests should be separated by lane so the scaffold can move without
pulling the full old PDF closure.

Lanes:

* `contract-fast`: minimal parser model, one-pass invariant, source refs,
  layout result shape, classifier hint shape, and convert boundary tests. This
  lane blocks v2 scaffold.
* `parser-source snapshots`: raw/source events for small deterministic fixtures,
  with source refs and warnings. This lane blocks parser milestone adoption.
* `normalized model snapshots`: pages, blocks, objects, regions, risks, and
  classifier-ready features. This lane blocks parser/model readiness.
* `layout recovery tests`: deterministic baseline, spatial index, regions,
  reading order, cross-page boundaries, low-signal risks, and model conflict
  gates. This lane blocks layout milestone readiness.
* `classifier gate tests`: confidence, hard constraints, risk penalties,
  abstain, reason tags, and blocked reasons. This lane blocks model gate
  readiness.
* `lowering golden tests`: core IR/Markdown for representative text, heading,
  list, caption, table-like, annotation, form, link, and image cases. This lane
  blocks convert baseline readiness.
* `integration samples`: selected repo samples and small pdfjs fixtures. This
  lane blocks dispatcher switch.
* `quality-lab bridge`: external feature export, reports, label provenance, and
  model evaluation. This lane informs thresholds but does not block scaffold.
* `vendor-slow`: vendor reader/writer/codec/crypto/font fixtures. This lane
  blocks vendor facade changes, not every v2 parser edit.
* `performance-smoke`: small/medium/large PDF latency, memory, package closure,
  model overhead, and convert-only overhead. This lane blocks dispatcher switch.
* `closure guard tests`: ensure fast v2 packages do not import old PDF runtime,
  debug/model/export tools, writer-only facades, or quality-lab files. This
  lane blocks scaffold and adoption.

Scaffold is blocked only by `contract-fast` and closure guards. Dispatcher
switch is blocked by integration samples, lowering golden tests,
performance-smoke, selected quality thresholds, and no-fallback guard tests.

## Runtime Invariants

PDF v2 remains valid only while:

* Normal conversion has no legacy fallback.
* Parser scans PDF input once.
* Convert never reads raw PDF, reopens paths, or reparses content streams.
* Vendor runtime closure stays bounded and excludes write/debug/vendor-slow
  test surfaces.
* Model artifacts do not come from external files at runtime.
* Unsupported capabilities become warnings/risks, not silent loss.
* Parser facts cover common PDF object capabilities even when product output is
  conservative.
* Model/rule conflicts go through an explicit gate.
* Hard constraints outrank model hints.
* Low-confidence decisions abstain or fail closed.
* Performance is tracked from the scaffold phase.
* Documentation accurately states runtime limits and unsupported capabilities.

## Open Questions

* What embedded or distilled runtime model artifact format is acceptable?
* How should unsupported encryption states be represented across core, parser,
  risk, and convert warning layers?
* How far should vector/table reconstruction go in the MVP?
* When should bytes/input-handle APIs land relative to the path convenience API?
* Which stages can stream and which must fully materialize?
* What fixture coverage is enough before trimming rare filters/codecs/fonts?
* How should vendor package closure and compile time be benchmarked?
* What configurable caps should protect very large PDFs?
* What exact quality, performance, model, and no-fallback thresholds are needed
  for dispatcher switch?
* How should optional content groups and page visibility states be represented
  if only partially discoverable?
* How should parser-owned `classifier_ready_features` be versioned for
  quality-lab export and runtime gates?

## Next Steps

* Commit this architecture document.
* Create the v2 scaffold with no dispatcher switch.
* Write the vendor facade split plan.
* Build the raw bridge over the narrowed core facade.
* Implement text reconstruction with parser-owned facts and source refs.
* Implement deterministic layout recovery baseline and risk reporting.
* Add model gate abstractions and no-model fail-closed behavior.
* Add convert baseline consuming only `PdfV2DocumentModel`.
* Add quality-lab feature export from parser-owned facts.
* Add performance and closure gates.
* Consider dispatcher switch only after quality, performance, model, vendor, and
  no-fallback gates pass.

## Historical Reset Notes

The following notes are planned milestone placeholders. Each future reset note
should record what changed, which runtime boundaries were preserved, what tests
or quality rows passed, and which risks remain.

### PDF-V2-RESET-0 Architecture Contract Note

This note records the architecture contract before implementation. It should
confirm that v2 is parallel to the old runtime, dispatcher behavior is
unchanged, and no code scaffold is implied by the document alone. It should
also list the one-pass, parser-owned facts, convert-owned policy, vendor facade,
model cooperation, and performance invariants.

### PDF-V2-RESET-1 Vendor Facade Note

This note should record the initial vendor facade split plan and package
closure measurements. It should identify which core read/text/page/object
facades are in the fast runtime subset and which writer/debug/crypto/vendor
test surfaces stay outside fast closure.

#### PDF-V2-RESET-1 Scaffold Note

`doc_parse/pdf_v2` and `convert/pdf_v2` now contain an experimental scaffold for
parser facts, source events, warnings/risks, layout recovery no-op behavior,
convert classifier gates, and contract-fast tests. The old PDF runtime is not
switched, dispatcher behavior is unchanged, fallback is not introduced, and no
model file, Python runtime, or external quality-lab dependency is read.

### PDF-V2-RESET-2 One-pass Parser Scaffold Note

This note should record the first parser scaffold that consumes PDF input once
and emits source refs and typed source events. It should explicitly state that
convert does not read raw PDF and that the scaffold does not fallback to the old
parser.

### PDF-V2-RESET-3 Text Reconstruction Note

This note should record the first char/span/line/block reconstruction milestone.
It should focus on stable ids, source refs, geometry, font facts, list marker
facts, caption prefix facts, heading shape facts, and decode confidence without
final Markdown semantics.

### PDF-V2-RESET-4 Layout Recovery Note

This note should record deterministic layout recovery baseline behavior,
spatial index construction, layout regions, reading order, cross-page boundary
hints, and risk summaries. It should state how confidence, source, and reason
tags are represented.

### PDF-V2-RESET-5 Model Gate Note

This note should record model/rule gate scaffolding for `layout_recovery` and
`text_block_classifier`. It should document hard constraints, model confidence,
feature support, risk penalty, final confidence, abstain behavior, and
blocked-reason reporting.

### PDF-V2-RESET-6 Convert Baseline Note

This note should record the first `PdfV2DocumentModel -> core IR` lowering
baseline. It should confirm that convert consumes only the normalized parser
model and options, owns product policy, emits reason-tagged decisions, and does
not mutate parser facts.

### PDF-V2-RESET-7 Quality Gate Note

This note should record the first quality, performance, and closure gate review
for dispatcher readiness. It should include sample results, quality-lab report
summaries, model calibration status, memory/latency/package closure numbers,
and unresolved adoption blockers.
