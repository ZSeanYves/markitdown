# PDF v2 mbtpdf Upgrade Plan

Status: proposed vendor foundation plan for PDF v2

This document records the vendor/foundation plan for PDF v2. It complements
`docs/archive/pdf-v2-architecture.md` and
`docs/archive/pdf-v2-vendor-test-closure.md`.

The plan is intentionally a construction contract. Future PDF v2 work should
use it to decide which capabilities belong in `mbtpdf`, which facts belong in a
narrow PDF v2 facade, which tests belong in the fast closure, and which gaps
must be represented as warnings, risks, or capability flags. It is not a runtime
adoption record and it is not permission to implement the raw bridge before the
foundation gates below are satisfied.

Core rules:

- PDF v2 does not bypass `mbtpdf` and write a second low-level PDF reader.
- PDF v2 does not expose the coarse `mbtpdf` package closure directly to parser
  or convert code.
- `mbtpdf` is the vendor foundation for PDF v2 through a narrow facade.
- PDF v2 is a complete PDF parsing foundation, not a fallback path.
- Unsupported, malformed, encrypted, partial, rare, or expensive capabilities
  must be exposed as warnings, risks, diagnostics, or capability flags. They
  must not disappear silently and must not trigger hidden fallback.
- Published-package upstream-only tests are not all main-repository
  responsibility. This repository owns local modifications, PDF v2 facade
  contracts, selected fixture smoke tests, and closure guards.

## 1. Executive Summary

`mbtpdf` is capable enough to serve as the PDF v2 substrate. It already contains
low-level PDF syntax, object graph, xref, stream, codec, encryption, page tree,
content operator, font/CMap/text, image, annotation, outline, and metadata
pieces. The current problem is therefore not "there is no foundation." The
problem is that the foundation is too broad to consume directly and needs a
deliberate facade, test closure, and performance plan.

The main foundation risks are:

- The facade boundary is not yet narrow enough. Parser and convert must not see
  arbitrary vendor internals.
- The vendor test closure is too coarse if every upstream writer, debug,
  filesystem, and standalone-library test stays in the normal PDF v2 loop.
- Text/font decode needs hardening before large real-world fixtures become the
  normal validation lane.
- Source events and page-local extraction need to be reshaped around source
  attribution, object refs, stream refs, and content order.
- Object facts need an expanding facade for page boxes, resources, XObjects,
  images, annotations, forms, outlines, destinations, and metadata.
- Performance and tests need explicit lanes. Fast contracts, vendor feature
  tests, vendor slow tests, and performance smoke should not collapse into one
  closure.

The `tonyfettes/encoding` and `tonyfettes/unicode` packages are not the primary
blockers. They are useful for UTF decoding and normalization policy, but owner
boundaries must stay clear: generic Unicode helpers do not own PDF CMap,
ToUnicode, standard font encodings, glyph names, or CJK PDF text decode. Those
remain in the `mbtpdf` font/text layer unless a future facade deliberately
splits them.

The first PDF v2 consumer should consume page-local text, content, and object
source events from the facade. It should not consume `mbtpdf` internals. The
minimum useful path is page-local extraction with located content ops,
font/text decode summaries, object facts, and fail-closed diagnostics. Convert
must receive parser/model facts, not raw vendor objects or a chance to reopen
and rescan the PDF.

## 2. Package Inventory

The audit baseline recorded before the first vendor test-trim batch was:

| Area | Packages | Source `.mbt` | Test `.mbt` | `.mbti` | PDF fixtures | Docs |
|---|---:|---:|---:|---:|---:|---:|
| `mbtpdf` | 34 | 139 | 109 before trim | 34 | 8 | 33 |
| `tonyfettes/encoding` | 1 | 7 | 4 | 1 | 0 | 2 |
| `tonyfettes/unicode` | 5 | 17 | 0 | 0 | 0 | 0 |

The current repository has already changed from that baseline: Phase 1.5d
deleted the first upstream-heavy test batch, and Phase 1.5e added two
object-facts contract files. The baseline remains useful because it describes
the closure that PDF v2 started from.

Notable dependency and ownership findings:

- `doc_parse/pdf/vendor/mbtpdf/io/pdfreadcore` is the narrow reader core. It is
  the preferred foundation for syntax, xref, object, object-stream, and stream
  reading when crypto is not needed.
- `doc_parse/pdf/vendor/mbtpdf/io/pdfread` adds encryption/decryption handling
  and should be treated as the reader-plus-crypto layer.
- `doc_parse/pdf/vendor/mbtpdf/document/pdfpage` is broad. It mixes page tree
  reading, page tree writing, page editing, page extraction, resource handling,
  xobject processing, destination fixups, and helper behavior. PDF v2 should
  consume narrow page facts, not the whole package surface.
- `doc_parse/pdf/vendor/mbtpdf/text/pdftextread` pulls font, CMap, glyph list,
  syntax, transform, PDF object, and Unicode UTF-8 dependencies. It is central
  for PDF text extraction and should be treated as a high-risk, high-value
  foundation package.
- `tonyfettes/unicode/normalization` pulls `tonyfettes/unicode/internal/ucd`.
  It is acceptable for parser-safe normalization policy, especially NFC, but it
  brings Unicode data closure that should be measured.
- `tonyfettes/unicode/idna` is heavier and depends on punycode, normalization,
  internal IDNA data, and UCD data. It is not parser-relevant and should not
  enter the PDF parser closure.
- `tonyfettes/encoding` has no package dependencies. It is useful as a generic
  UTF encode/decode utility but should not become owner of PDF-specific font
  encodings.

## 3. mbtpdf Capability Matrix

The current capability picture is strong enough for a vendor foundation, but it
is uneven. The upgrade recommendation is to expose each capability through a
narrow facade with explicit diagnostics rather than passing vendor internals to
PDF v2.

| Capability | Current support | Evidence path or recent contract | PDF v2 impact | Upgrade recommendation |
|---|---|---|---|---|
| Header, version, trailer, revisions | Reader parses headers, trailers, roots, and object revisions through PDF object structures. | `io/pdfread`, `io/pdfreadcore`, `core/pdf`; malformed/header tests in `io/pdfread`. | Required for opening every PDF and for diagnostics such as bad root, bad trailer, and partial parse. | Keep in reader facade. Expose version, trailer root, revision count if known, and warnings for malformed or repaired inputs. |
| Xref table and xref stream | Reader has xref support and object lookup. | `io/pdfread/xref.mbt`, `io/pdfreadcore/xref.mbt`, `io/pdfread` tests. | Required for object graph integrity and object source refs. | Wrap behind object-ref facade. Add fixture coverage for encrypted xref streams and incremental updates before large adoption. |
| Indirect objects and object graph | Core PDF object model supports indirect refs, direct lookup, object iteration, renumbering, and nametrees. | `core/pdf` object, lookup, iter, nametree, reference tests. | Required for all parser facts and source refs. | Expose typed object refs and object summary facts. Do not expose raw `PdfObject` outside the facade except behind controlled wrappers. |
| Object streams | Reader supports delayed objects from object streams. | `core/pdf/lookup.mbt`, `io/pdfread`; `e727c93` replacement contract for compact object-stream widget boundaries. | Required for modern PDFs and widget/form extraction. | Keep fail-closed behavior for malformed object streams. Add object-stream count and warning diagnostics. |
| Incremental, linearized, malformed | Some reader and malformed behavior exists; linearized marker is represented on `Pdf`. | `io/pdfread_malformed*.mbt`, `pdfread_replacement_contract_wbtest.mbt`, `core/pdf` `was_linearized`. | Required for real-world PDFs where multiple revisions and damaged objects appear. | Treat as risk area. Expose linearized/incremental/malformed flags and keep strict malformed-reader contracts. |
| Stream filters and codecs | ASCII85, ASCIIHex, Flate, LZW, RunLength, CCITT, JBIG2, predictors, and stream filter helpers exist. | `codec/pdfcodec`, `codec/pdfflate`, codec tests. | Required for text/content streams, image metadata, and selective image/vector extraction. | Decode page content and metadata-critical streams first. Bound expensive image decodes and expose unsupported filter warnings. |
| Encryption and security | Crypto primitives and PDF encryption layers exist, including AES and legacy handling. | `core/pdfcryptprimitives`, `crypto/pdfcrypt`, `crypto/pdfcryptcore`, `io/pdfread`. | Required to distinguish readable encrypted PDFs from blocked/unsupported ones. | Put behind a security facade with capability flags. Do not let crypto-heavy tests enter fast closure by default. |
| Page tree, resources, content | Page tree reader handles inherited resources, boxes, crop boxes, rotations, content streams, and rest entries. | `document/pdfpage/pagetree_read.mbt`; `b0a8a3f` object-facts contract. | Required for page-local extraction, content ordering, source refs, image/link proximity, and layout. | Split read-only page facade from page editing/writer helpers. Add typed `UserUnit` later; keep raw `Page.rest` reachability now. |
| Content ops and graphics | Content operator parsing and source attribution exist. | `graphics/pdfops`; `e727c93` `parse_operators_with_source` contract. | Required for located text, graphics, image, and vector source events. | PDF v2 should prefer `parse_operators_with_source` and avoid no-source content concatenation. |
| Text, fonts, CMap | Text extraction, CMap, ToUnicode, glyph list, standard font pieces, GBK and Shift-JIS helpers exist. | `text/pdftextread`, `font/pdfcmap`, `font/pdffont`, `font/pdfglyphlist`; `e727c93` replacement tests. | Central to parser quality. Weak decode confidence or recomputation will dominate failures and performance. | Add decode confidence, font/CMap cache, vertical/CJK fixtures, and normalization policy before large fixture adoption. |
| Images and vectors | Image metadata and decoding helpers exist; graphics operators represent vector and image operations. | `graphics/pdfimage`, `graphics/pdfops`; `b0a8a3f` image metadata contract. | Required for captions, figures, assets, and region recovery. | Start with metadata/source events and bounding facts. Defer full byte decode and asset export until caps exist. |
| Annotations, links, outlines, forms | Destinations, bookmarks/outlines, page annotation raw facts, widgets, and AcroForm dictionaries are reachable. | `document/pdfdest`, `document/pdfmarks`, `document/pdfpage`; `b0a8a3f` annotation/widget/outline contracts. | Required for links, footnote-like refs, form facts, widget geometry, and document navigation. | Add typed facade records incrementally. Keep raw facts and smoke contracts until rich form/outline semantics are designed. |
| Metadata | Core object model can access Info, catalog entries, name trees, and arbitrary metadata objects. XMP-specific facade is not yet split. | `core/pdf`, document packages, architecture contract. | Required for document metadata, provenance, and diagnostics. | Add Info/XMP facade later. Unsupported or malformed metadata should emit warnings, not fallback. |

## 4. encoding / unicode Ownership Matrix

### encoding

`tonyfettes/encoding` is a small generic encoding package with no package
dependencies. It is useful for strict and lossy UTF encode/decode behavior and
for streaming decoder infrastructure. Its error behavior can become a
diagnostic building block for PDF v2 when bytes are decoded into Unicode text.

Ownership rules:

- UTF-8 and UTF-16LE/BE encode/decode are available and can be used for generic
  Unicode boundaries.
- Strict versus lossy errors are useful diagnostic inputs. PDF v2 should record
  whether text was strict, repaired, lossy, or rejected.
- Streaming decoder support is available and may be used where PDF v2 needs
  bounded byte-to-text processing.
- PDFDocEncoding, WinAnsi, MacRoman, StandardEncoding, Symbol, and
  ZapfDingbats should not move into the generic `encoding` package. They remain
  PDF font/glyph responsibilities.
- CMap and ToUnicode remain `mbtpdf` responsibilities.
- CJK multibyte handling should remain in `mbtpdf/text/pdftextread` in the
  short term. Moving it requires a separate owner and fixture plan.

### unicode

`tonyfettes/unicode` is useful, but only selected pieces belong in PDF parser
closure.

Ownership rules:

- Normalization is available through `tonyfettes/unicode/normalization`.
- NFC is the parser-safe default policy candidate because it preserves raw
  parser fidelity while stabilizing canonically equivalent text.
- NFKC and NFKD are better suited to convert, model, search, or derived feature
  layers. They should not mutate raw parser text by default because
  compatibility folding can erase distinctions that are meaningful for source
  fidelity.
- `tonyfettes/unicode/idna` should not enter PDF parser closure. It is domain
  name machinery, not PDF text extraction machinery.
- Public helpers for CJK categories, punctuation, whitespace, width, grapheme
  boundaries, and layout-sensitive Unicode classes remain future gaps. If added,
  they should be facade-level helpers with tests and performance measurements.

## 5. Vendor Test Closure Strategy

The canonical closure policy is recorded in
`docs/archive/pdf-v2-vendor-test-closure.md`. This plan adopts that policy as
part of the upgrade contract.

The strategy is:

- Upstream-only heavy tests may be deleted from normal main-repository closure
  when they protect writer, debug, filesystem, examples, or standalone upstream
  behavior rather than PDF v2 parser contracts.
- Local modifications must be protected by small replacement tests before old
  mixed coverage is removed.
- PDF v2 facade capabilities must be protected by object-facts contracts before
  mixed page/document tests are trimmed.
- Unknown or mixed tests are not deleted directly. Their useful facts are split
  into small contracts first.
- Writer, debug, and vendor-slow tests do not enter ordinary PDF v2 fast
  closure. They may live in a separate optional lane if needed.

Current state:

- Replacement tests added: `e727c93 pdf-v2: add vendor replacement contract tests`.
- First upstream-heavy deletion batch: `3ed2e68 pdf-v2: trim upstream-heavy vendor tests`.
- Object-facts contracts added: `b0a8a3f pdf-v2: add vendor object facts contract tests`.

Phase 1.5c added replacement contract tests for:

- Compact object-stream widget dictionary boundaries.
- `parse_operators_with_source` source attribution.
- ToUnicode and CMap tolerance.
- GBK fallback and ToUnicode precedence.
- Malformed reader fail-closed smoke.

Phase 1.5d deleted nine test files in the first low-risk batch:

- Writer-only tests.
- Root, filesystem, and debug helper tests.
- Page-output editing tests.

Phase 1.5d explicitly did not delete:

- Replacement tests.
- Real widget e2e coverage.
- Text/font edge tests.
- Image/vector tests.
- Annotation/form tests.
- Malformed-reader and source-attribution tests.

Phase 1.5e added object-facts contracts for:

- Page boxes, rotation, and raw `UserUnit` facts.
- Resources inheritance and XObject references.
- Annotation/link geometry.
- Widget and AcroForm facts.
- Outline/destination smoke.
- Image metadata.

Future trimming should continue in small, verifiable batches. A test file is not
safe to delete merely because another test touches the same package. It is safe
to delete only when its PDF v2-relevant facts are covered by narrower contracts
or when the test is clearly upstream-only and irrelevant to the facade.

## 6. Performance Risk Matrix

Performance is a first-class foundation goal. PDF v2 must not postpone closure,
memory, and latency work until after the raw bridge grows large.

| Risk | Where observed | Runtime / compile / test | Severity | Mitigation |
|---|---|---|---|---|
| Broad vendor closure | `mbtpdf` spans reader, writer, crypto, codecs, page editing, text, images, and tests. | Compile and test. | High | Split facade and test lanes. Keep writer/debug/vendor-slow out of fast PDF v2 closure. |
| Object graph growth | `core/pdf` stores objects, delayed object streams, object iteration, deep copy, renumbering, and nametrees. | Runtime memory. | High | Use page-local object traversal, object refs, lazy summaries, and explicit caps. Avoid whole-document copies in parser flow. |
| Stream decode and copy | `pdfcodec`, `pdfread`, `pdfimage`, and content streams can decode or copy bytes. | Runtime memory and latency. | High | Decode only streams needed for page-local source events. Add decoded-byte counters, stream caps, and unsupported-filter diagnostics. |
| Content concatenation | Page content can be arrays of streams; no-source concatenation loses provenance and can copy bytes. | Runtime and diagnostics. | High | Prefer `parse_operators_with_source`. Preserve stream/source refs instead of flattening content without source. |
| Font/CMap recomputation | `pdftextread`, `pdfcmap`, glyph lists, and CJK helpers can be repeatedly consulted per page or text object. | Runtime latency. | High | Add font/CMap cache before large fixtures. Record decode confidence and cache hit/miss metrics. |
| Image/vector extraction | `pdfimage` can decode image bytes; `pdfops` can expose vector operations. | Runtime memory and latency. | Medium to high | Initial PDF v2 should emit metadata and source events first. Defer full image bytes and advanced vector semantics behind caps. |
| Unicode table closure | `unicode/normalization` pulls UCD data; `idna` pulls heavier non-parser data. | Compile and runtime. | Medium | Use normalization only where policy requires it. Keep `unicode/idna` out of parser closure. Measure normalization cost. |
| Source event allocation | Page-local text/content/object source events can produce many small records. | Runtime memory. | Medium to high | Design compact source refs, page-local arenas or indexes, and event summaries. Keep convert from duplicating raw facts. |

Three rules are mandatory:

- PDF v2 should use `parse_operators_with_source` first and avoid no-source
  content concatenation.
- Text/font cache is a hard requirement before large fixtures become a normal
  lane.
- Image/vector extraction should initially output metadata and source events,
  not decode all image bytes by default.

Page-local processing is the basic performance strategy. PDF v2 should open the
document once, enumerate pages and needed shared resources, then process each
page with bounded local state. Whole-document object sweeps should be diagnostic
or maintenance operations, not the core parser loop.

## 7. mbtpdf Upgrade Milestones

### M0: Inventory and closure map

Goal: Establish the exact package, dependency, fixture, test, and performance
map that future PDF v2 work must respect.

Scope:

- Packages, tests, large tables, codecs, crypto, unicode closure, and fixtures.
- Dependency map for reader, page, content ops, text/font, image, annotation,
  metadata, writer, debug, and test-only packages.
- Lane ownership: fast contracts, vendor feature tests, vendor slow tests,
  performance smoke, and closure guards.

Likely packages:

- `doc_parse/pdf/vendor/mbtpdf/**`
- `.mooncakes/tonyfettes/encoding`
- `.mooncakes/tonyfettes/unicode/normalization`

Validation:

- Inventory document updated.
- Test closure document agrees with inventory.
- No runtime code changes.

Risk:

- Hidden test-only imports can keep writer/debug packages in normal closure.
- Unicode or crypto dependencies can enter through a broad import path.

Exit criteria:

- Package map and test lane ownership are explicit.
- Closure guard candidates are known.
- No unknown heavy package is required by the minimal PDF v2 facade.

### M1: Vendor facade design

Goal: Design the narrow facade that lets PDF v2 consume `mbtpdf` without seeing
the whole vendor surface.

Scope:

- Read facade.
- Object facade.
- Stream/filter facade.
- Page facade.
- Content ops facade.
- Text/font facade.
- Image/vector facade.
- Annotation, form, and outline facade.
- Security facade.
- Debug/write-test-only facade boundary.

Likely packages:

- `io/pdfreadcore`
- `io/pdfread`
- `core/pdf`
- `codec/pdfcodec`
- `document/pdfpage`
- `graphics/pdfops`
- `text/pdftextread`
- `font/pdfcmap`
- `graphics/pdfimage`
- `document/pdfdest`
- `document/pdfmarks`

Validation:

- Facade API sketch reviewed against `pdf-v2-architecture.md`.
- No convert API exposes vendor internals.
- Fast contract tests identify facade responsibilities.

Risk:

- Overexposing `PdfObject` recreates the coarse vendor boundary.
- Underexposing object/source refs blocks parser facts.

Exit criteria:

- Minimal facade types and ownership are written down.
- Reader, object, source op, text decode, page fact, and diagnostic records are
  separated.
- Debug/write behavior is outside normal runtime facade.

### M2: Text/font foundation hardening

Goal: Make text extraction reliable enough to support parser source events and
large fixtures without silent loss.

Scope:

- ToUnicode.
- CMap.
- Standard encodings.
- Glyph names.
- CJK.
- Vertical writing.
- Ligatures and compatibility glyphs.
- Decode confidence.
- Font/CMap cache.
- Normalization policy.

Likely packages:

- `text/pdftextread`
- `font/pdfcmap`
- `font/pdffont`
- `font/pdfglyphlist`
- `.mooncakes/tonyfettes/encoding`
- `.mooncakes/tonyfettes/unicode/normalization`

Validation:

- Replacement tests from `e727c93` remain passing.
- Additional vertical/CJK/ligature fixtures are added before large adoption.
- Cache metrics and decode confidence appear in diagnostics.

Risk:

- Text extraction can appear to work while silently losing low-confidence glyphs.
- Repeated CMap work can dominate large PDFs.
- NFKC/NFKD can damage raw parser fidelity if applied too early.

Exit criteria:

- Text decode emits confidence and reason tags.
- Font/CMap cache exists or has a measured replacement strategy.
- NFC policy is explicit; compatibility normalization is deferred to derived
  layers.

### M3: Page/content/object foundation hardening

Goal: Ensure page-local object traversal and content op extraction are robust,
source-attributed, and bounded.

Scope:

- Xref streams.
- Object streams.
- Incremental updates.
- Resources inheritance.
- Multiple content streams.
- Marked content and artifacts.
- Graphics state and CTM.
- Form XObject handling.
- Source attribution.

Likely packages:

- `io/pdfreadcore`
- `io/pdfread`
- `core/pdf`
- `document/pdfpage`
- `graphics/pdfops`
- `graphics/pdfspace`

Validation:

- Object-stream widget contract from `e727c93` remains passing.
- `parse_operators_with_source` contract remains passing.
- New page-local source-event tests cover multiple content streams and Form
  XObject source boundaries.

Risk:

- Flattening content streams can lose source refs.
- Resources inheritance and Form XObjects can create duplicate or missing
  source events.
- Marked content/artifact policy can affect layout and accessibility facts.

Exit criteria:

- Page-local content events preserve stream refs and content order.
- Form XObject and inherited resource facts are represented as source refs or
  warnings.
- Malformed pages fail closed with diagnostics.

### M4: Object facts expansion

Goal: Expand narrow object facts from the Phase 1.5e contracts into facade
records suitable for parser and convert decisions.

Scope:

- Images.
- Vectors.
- Annotations.
- Links and destinations.
- Forms and widgets.
- Outlines.
- Metadata, XMP, and Info dictionaries.

Likely packages:

- `document/pdfpage`
- `document/pdfdest`
- `document/pdfmarks`
- `graphics/pdfimage`
- `graphics/pdfops`
- `core/pdf`

Validation:

- Phase 1.5e object-facts contracts remain passing.
- New contracts are added before deleting mixed tests that touch rich
  image/vector/form/outline behavior.
- Facade records include source refs and diagnostics.

Risk:

- Rich forms and outlines are easy to overmodel too early.
- Image decode can become an asset extraction project before metadata is
  stable.
- Metadata can be malformed or duplicated across Info and XMP.

Exit criteria:

- Parser can receive image, vector, annotation, link, widget, outline, and
  metadata summaries without vendor internals.
- Unsupported rich fields emit capability warnings rather than fallback.
- Mixed tests have clear replacement contracts before further trim.

### M5: Performance and memory caps

Goal: Make PDF v2 viable for large PDFs before the bridge becomes feature-rich.

Scope:

- Lazy streams.
- Page-local processing.
- Font/CMap caches.
- Bounded image/vector extraction.
- Source ref allocation strategy.
- Large PDF caps and degradation policy.

Likely packages:

- `io/pdfreadcore`
- `io/pdfread`
- `codec/pdfcodec`
- `text/pdftextread`
- `graphics/pdfimage`
- `graphics/pdfops`
- `doc_parse/pdf_v2` facade/adapter packages when they exist.

Validation:

- Performance smoke fixtures record stream counts, decoded bytes, event counts,
  text decode counts, and cache metrics.
- Large PDFs degrade with warnings rather than hidden fallback.
- Fast tests remain fast after cache and cap instrumentation.

Risk:

- Source event richness can allocate too much.
- Image decode can dwarf text extraction.
- Whole-document traversals can hide behind convenience APIs.

Exit criteria:

- Page-local memory budget is defined.
- Decode and image/vector caps exist.
- Text/font cache is measured.
- Large fixture smoke reports diagnostics and does not fallback.

### M6: Test lane split

Goal: Keep PDF v2 validation strong without returning to a single huge vendor
closure.

Scope:

- Fast contract tests.
- Vendor feature tests.
- Vendor slow tests.
- Performance smoke.
- Closure guard tests.

Likely packages:

- `doc_parse/pdf/vendor/mbtpdf/**`
- `doc_parse/pdf_v2/**`
- `convert/pdf_v2/**`
- docs/archive policy files.

Validation:

- Fast lane covers replacement contracts, object facts, malformed reader smoke,
  source attribution, and facade contracts.
- Vendor feature lane covers selected upstream behavior still relevant to PDF
  v2.
- Vendor slow lane covers crypto, codecs, image decode, and broad fixture
  tests when needed.

Risk:

- Deleting tests without replacement can remove local modification coverage.
- Keeping all upstream tests in fast lane can block normal development.

Exit criteria:

- Test lane names and commands are documented.
- Mixed tests are classified before deletion.
- Closure guard prevents writer/debug packages from reentering fast PDF v2
  closure accidentally.

### M7: PDF v2 raw bridge integration

Goal: Connect the narrow `mbtpdf` facade to `doc_parse/pdf_v2` only after the
foundation and closure gates are ready.

Scope:

- Connect facade to `doc_parse/pdf_v2`.
- One-pass source events.
- No vendor internals exposed to convert.
- Warnings and risks instead of fallback.

Likely packages:

- Future `doc_parse/pdf_core_v2` or equivalent facade package.
- `doc_parse/pdf_v2`.
- `convert/pdf_v2`.
- Selected `mbtpdf` foundation packages through the facade only.

Validation:

- First bridge tests use page-local source events.
- Convert consumes parser/model facts only.
- No old PDF runtime fallback, external tool fallback, or model-data fallback is
  introduced.
- Diagnostics include unsupported and malformed capabilities.

Risk:

- Implementing bridge before facade design will leak vendor internals.
- Convert may reparse or reconstruct raw PDF facts if parser facts are missing.

Exit criteria:

- Raw bridge emits page-local text/content/object source events.
- Source refs, object refs, decode summaries, and warnings are stable.
- Convert has no raw vendor dependency.

## 8. First Consumption Plan for PDF v2

The first PDF v2 consumer should be deliberately small. It should prove the
foundation contracts before pursuing full feature parity.

Minimum safe facade:

- `pdfreadcore` reader behavior for object/xref/stream reading where crypto is
  not needed.
- `io/pdfread` only when encryption support is required.
- `core/pdf` object refs behind wrappers.
- `pdfops::parse_operators_with_source`.
- `pdftextread` text decode behind decode summaries.
- `pdfcmap` as the CMap/ToUnicode substrate.
- Warning/risk adapter for malformed, unsupported, encrypted, partial, and
  low-confidence states.

First raw bridge target:

- Page-local page/content/text source events.
- Located ops.
- Font decode summaries.
- Page and object facts covered by the Phase 1.5e contracts.
- Fail-closed diagnostics.

Defer:

- Full image bytes.
- Rich form facts.
- Advanced vector semantics.
- Full metadata/XMP.

Text/font blockers:

- Decode confidence type.
- Font/CMap cache.
- Vertical/CJK fixtures.
- Normalization policy.

Object/page blockers:

- Typed `UserUnit`.
- Form XObject source attribution.
- Marked content and artifact policy.
- Nested outline expansion.

Performance blockers:

- Stream and image caps.
- Page-local memory bounds.
- Source ref allocation strategy.

The first bridge must not be a fallback. It may be incomplete, but incomplete
features must be visible as diagnostics, warnings, risks, or capability flags.

## 9. Open Questions

These questions should be answered with small contracts, fixture smoke tests,
or facade design notes before broad raw bridge work:

- Exact AcroForm field coverage: which field types, value forms, appearance
  streams, inherited field properties, and widget geometry are required first?
- OCG/layer support: should optional content groups become source facts,
  warnings, or deferred metadata?
- XMP/Info metadata facade: how should duplicated or conflicting document
  metadata be represented?
- Soft mask and color conversion completeness: which color facts are parser
  metadata and which require asset/image decode?
- Encrypted object streams fixtures: what encrypted modern PDFs are needed for
  fail-closed and readable-encrypted coverage?
- Incremental real-world PDFs: which fixtures represent multiple revisions,
  updated objects, or damaged trailers?
- Vertical CJK fixtures: which Type0/CID/ToUnicode combinations are required
  before large text adoption?
- Malformed PDFs: which malformed cases are hard failures, warnings, or partial
  extraction states?
- Widget/form geometry: which page-local geometry facts are required for
  convert and quality-lab features?
- JPX, JBIG2, and image masks: which metadata facts are enough before decoding
  bytes?
- Large object streams benchmark: what object counts and stream sizes define
  the first performance smoke lane?
- Repeated CMap/text decode benchmark: how much cache benefit is required
  before large fixtures?
- Unicode normalization cost: how much NFC work is acceptable in parser
  closure?
- Test closure timings: what target duration separates fast, feature, slow, and
  performance lanes?

## 10. Next Steps

The recommended order is:

1. Commit this mbtpdf upgrade plan.
2. Audit mixed page/document tests against the Phase 1.5e contracts.
3. Add selected contracts for image/vector decode and annotation/form geometry
   if the audit shows those facts are still protected only by broad tests.
4. Design the `pdf_core_v2` facade API in `doc_parse/pdf_v2` or a dedicated
   facade package.
5. Add text/font cache and decode confidence before large fixtures.
6. Build the first page-local raw source event bridge.
7. Only after those gates, proceed to real raw bridge implementation.

Until M7, PDF v2 implementation work should treat this document as a guardrail:
`mbtpdf` is the foundation, but it must be consumed through a narrow facade;
unsupported capabilities are diagnostics, not fallback; and performance plus
test closure are first-order requirements.
