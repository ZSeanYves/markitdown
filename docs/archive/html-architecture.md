# HTML Architecture Contract

Status: current architecture contract / Option 2 refactor plan. M11 has
switched the normal HTML runtime to parser-owned semantic facts inside the
existing packages.

HTML should continue in the existing `doc_parse/html` and `convert/html`
packages. Do not create `doc_parse/html_v2` or `convert/html_v2`, and do not
switch dispatcher wiring for the current cleanup path.

This differs from the other format decisions:

* XLSX is Option 1 because `convert/xlsx` already mostly consumes the typed
  workbook model from `doc_parse/xlsx`; remaining work is local typed facts,
  warning, metadata, and guard cleanup.
* DOCX and PPTX needed replacement because their old runtime boundaries,
  legacy/fallback glue, and repeated source parsing made local cleanup too
  risky.
* HTML is Option 2 because `doc_parse/html` provides the parser foundation and
  semantic facts, while `convert/html` can keep product lowering policy without
  creating a replacement package.

## Current Pipeline

```text
HTML bytes
 -> doc_parse/html tokenizer + tolerant DOM + validation/events
 -> doc_parse/html semantic facts
 -> convert/html fact runtime lowering
 -> core Document / Markdown / metadata / origins
```

## Target Pipeline

```text
HTML bytes
 -> tokenizer
 -> tolerant DOM/source model
 -> semantic HTML facts
 -> convert lowering policy
 -> core Document / Markdown / metadata / origins
```

## Layer Responsibilities

### `doc_parse/html`

Responsibilities:

* Tokenize HTML source.
* Provide entity decoding primitives.
* Build a tolerant DOM/source model.
* Preserve tag names, attributes, text, comments, and doctype nodes.
* Preserve source order, source spans, and token events.
* Grow semantic facts for headings, paragraphs, lists, tables, links, images,
  figures, blockquotes, pre/code blocks, and notes.
* Emit validation and warning facts.
* Emit size, depth, unsupported-structure, and guard facts.

Non-responsibilities:

* Markdown rendering.
* RichTable policy.
* Asset export or asset path naming.
* Product heading, list, table, or image placement policy.
* Remote fetching.
* Browser layout, CSS rendering, or JavaScript execution.

### `convert/html`

Responsibilities:

* Consume parser DOM and semantic facts.
* Own Markdown and IR lowering.
* Own heading, list, table, image, link, figure, pre/code, and blockquote output
  policy.
* Own product whitespace normalization policy.
* Own asset export, metadata, and origin policy.
* Own unsupported-warning presentation policy.
* Preserve quality-driven product behavior.

Non-responsibilities:

* Raw HTML reparsing long term.
* Private tag, attribute, table, link, or image scanners long term.
* Tokenization.
* Parser validation.
* Fallback, oracle, or counter runtime logic.

## Current Boundary Risks

The following `convert/html` areas are obsolete raw scanning surfaces. After
M11 they are not normal-runtime source-discovery inputs, but they remain as
quarantined deletion/audit surfaces or product helper surfaces until a dedicated
scanner deletion slice removes them:

* `html_parser.mbt`: entrypoint, parser validation/profile, product document
  assembly, and no normal-runtime raw scope fallback.
* `html_dom.mbt`: private block scanner.
* `html_inlines.mbt`: raw inline, link, and image scanner plus reusable
  convert-owned inline rendering helpers.
* `html_table.mbt`: table scanner.
* `html_notes.mbt`: footnote reference and body scanner.
* `html_bytes.mbt`: raw tag matching and byte search helpers.
* `html_tag_attrs.mbt`: raw tag-string attribute helper bridge.
* `html_noise_rules.mbt`: product noise policy; raw subtree scanning helpers
  are obsolete, while product skip/preserve rules remain convert-owned.

## Semantic Facts Roadmap

The exact compile-time API can evolve, but the stable contract shape should move
semantic source facts into `doc_parse/html`.

Conceptual parser facts:

* `HtmlSemanticDocument`: source metadata, root DOM, block facts, validation
  issues, unsupported facts, guard facts, and warning facts.
* `HtmlBlockFact`: headings, paragraphs, lists, tables, figures, blockquotes,
  pre/code blocks, thematic breaks, and note bodies.
* `HtmlInlineFact`: text, breaks, links, images, inline code, emphasis-like
  spans where useful, and note references.
* `HtmlTableFact`: rows, cells, header hints, row/column spans, text/inline
  content, and source ranges.
* `HtmlLinkFact`: href, text facts, title/rel/class/id attrs where useful,
  source range, and URL safety classification.
* `HtmlImageFact`: src, alt, title, dimensions where discoverable, locality,
  source range, and unsupported/remote/data classification.
* `HtmlFigureFact`: image facts, caption facts, and source range.
* `HtmlListFact`: ordered/unordered state, nesting level, items, and child
  block facts.
* `HtmlNoteFact`: explicit same-document note refs, note bodies, note IDs,
  markers, and confidence.
* `HtmlUnsupportedFact`: typed facts for unsupported or ignored structures.
* `HtmlValidationIssue` / `HtmlWarning`: parser-owned diagnostics with stable
  kind, severity, location, tag, and message fields.

Convert should consume these facts and decide how to lower them into core IR.

## Warning Taxonomy Roadmap

The parser warning taxonomy should cover:

* `script` and `style` elements.
* `iframe`, `embed`, and `object`.
* `svg`, `math`, and `template`.
* `form`, `input`, `select`, `textarea`, and `button`.
* `video`, `audio`, and `source`.
* `canvas`.
* Unsafe URLs.
* Remote and data URI images.
* Broken local image references where the converter or caller can provide file
  context.
* Malformed tags.
* Huge or deeply nested structures.
* Huge tables.
* Unsupported charset or encoding.

Parser should classify structure and safety. Convert should decide whether the
warning is rendered, summarized in metadata, or only counted for diagnostics.

## Performance Guard Roadmap

HTML cleanup should add bounded behavior for:

* Max parse bytes and validation skip semantics.
* Max nesting depth.
* Max table rows, columns, and cells.
* Max attribute count and attribute value bytes.
* Max text node bytes.
* Max entity expansion and repeated decode work.
* Bounded malformed stack repair.
* Avoiding repeated raw rescans by lowering from parser DOM/facts.

The long-term goal is one parser pass plus one semantic traversal, followed by
convert policy lowering.

## Migration Roadmap

* M0: architecture contract.
* M1: parser semantic block facts.
* M2: inline, link, and image facts.
* M3: table facts.
* M4: figure, blockquote, pre/code, and list facts.
* M5: unsupported taxonomy.
* M6: migrate one convert slice to parser facts.
* M7: replace raw scanners slice by slice.
* M8: guards and performance tests.
* M9: samples, quality, and bench parity.
* M10: delete obsolete raw scanners.
* M11: switch normal runtime input to a single parser-owned fact path.

Implementation principles:

* Start with parser facts and tests before changing converter output.
* Keep complex tables, notes, and deep list behavior on existing scanners until
  parser facts cover them.
* Preserve samples expected output unless a behavior change is deliberate and
  separately approved.
* Remove raw scanners only after equivalent parser-backed behavior is covered
  by unit, samples, quality, and bench checks.

## M8b Raw Scanner Audit Map

Classification legend:

* A: already semantically covered for the safe subset.
* B: still required for guarded complex cases.
* C: candidate for next migration.
* D: candidate for eventual deletion after M9 parity.
* E: helper-only or test-only support surface.
* F: product policy that should remain in `convert/html`.

| File | Class | Current role | Keep or migrate decision |
| --- | --- | --- | --- |
| `convert/html/html_dom.mbt` | A, B, C, D | Private raw block scanner for headings, paragraphs, figures, lists, blockquotes, pre/code, tables, details/summary, comments, script/style/head/noscript skipping, note-body skipping, and noise subtree skipping. | Safe headings, simple paragraphs/inlines, blockquotes, pre/code, safe lists, safe image/figure, and safe simple tables now have semantic-path coverage. Keep for guarded complex tables, nested/deep lists, malformed block boundaries, details/summary flattening, note-body exclusion, and current fallback behavior. M9 should isolate raw fallback coverage; M10 can delete migrated slices only after parity. |
| `convert/html/html_inlines.mbt` | A, B, C, D, F | Raw inline scanner for text cleanup, `<br>`, links, images, note refs, figure image/caption extraction, URL sanitizing, and product rendering identity. | Simple text/break/code-ish spans, safe links, safe image paragraphs, and safe figures have semantic coverage. Keep for complex inline spacing/escaping, note ref matching, unsafe/empty link fallback, image fallback, nested inline edge cases, and current render identity guards. Product Markdown rendering and image fallback text remain convert policy. |
| `convert/html/html_table.mbt` | A, B, C, D, F | Raw table scanner for rows/cells, header-row inference, row/col span expansion hints, ragged-row normalization, and inline cell rendering. | Safe simple tables are semantically covered. Keep for row/col spans, captions, ragged tables, nested tables, images/lists/blockquotes/pre/figures inside cells, malformed table boundaries, and current RichTable compatibility. M9 can migrate complex table facts or quarantine scanner-backed fallback; M10 deletion waits for sample and quality parity. |
| `convert/html/html_notes.mbt` | B, C, D, F | Raw footnote/reference planner using IDs, `epub:type`, roles, class heuristics, note body ranges, and note definition construction. | Keep for notes/footnotes. Parser has no complete `HtmlNoteFact` lowering contract yet. M9 can add parser note facts and compare note refs/bodies; convert should retain note rendering, placement, and confidence policy. |
| `convert/html/html_bytes.mbt` | B, D, E | Shared byte-search, case-insensitive matching, tag-block extraction, matching close-tag helpers, list/li matching, tag stripping, and entity bridge. | Helper-only but runtime-critical while raw scanners remain. M9 should quarantine it behind fallback-only scanner modules. M10 can delete pieces as callers disappear. |
| `convert/html/html_tag_attrs.mbt` | D, E | Thin helper bridge from raw tag strings to parser-owned tag/attribute parsing. | Already delegates to `doc_parse/html`. Keep only while raw scanners need tag-string helpers; delete or inline after scanner retirement. |
| `convert/html/html_noise_rules.mbt` | B, C, F | Product-specific noise subtree detection for nav/footer/search/sidebar/infobox/toc-like containers with prose preservation. | Keep in convert unless product policy moves elsewhere. Parser may expose structural class/id/role facts, but skip/preserve decisions are product policy and should not become parser behavior. |
| `convert/html/html_parser.mbt` | A, B, C, D, F | Entrypoint, parser validation/profile summary, event-backed scope selection, raw scope fallback, skip-range setup, asset/origin document assembly, and profile counters. | Parser validation and semantic summaries are now parser-backed. Keep event-backed body/scope selection, raw scope fallback for parser failure/large input, and product document/profile/origin policy. M9 can tighten event-backed scope parity and isolate raw fallback. |
| `convert/html/html_to_ir.mbt` | A, B, F | Converts scanner nodes plus semantic lowering attempts into core IR, Markdown-facing inline rendering, images/assets, origins, RichTable hints, list/quote/table fallback policy. | Safe semantic slices are consumed here. Keep product policy: Markdown escaping/rendering, RichTable emission, asset export/path naming, image fallback text, origin metadata, and guarded fallback behavior. Do not move this policy into parser. |
| `convert/html/html_semantic_lowering.mbt` | A, B, C, F | Parser-fact lowering attempts, guard comparison against existing output, candidate/lowered/existing-path counters, and M8 guard reason counters. | Covers safe blockquote/pre-code, simple paragraphs/inlines, headings/safe link paragraphs, safe lists, safe images/figures, and safe simple tables. Keep as convert policy and observability. M9 can add note or complex-table attempt counters before any migration; M10 should leave policy lowering here even after raw scanners are deleted. |

Responsibilities that must remain on existing scanners until more semantic
facts and parity tests exist:

* Complex tables: spans, captions, nested tables, ragged rows, complex cells,
  images/lists/blockquotes/pre/figures inside cells, malformed table boundaries,
  and RichTable compatibility.
* Notes and footnotes: same-document ref/body matching, footnote-like ID/class
  heuristics, note body exclusion from main flow, note definitions, and note
  placement policy.
* Malformed HTML: incomplete raw tags, missing close tags, tolerant fallback
  ranges, and large-input/parser-failure behavior.
* Body and scope selection: event-backed root selection is preferred, but raw
  body/content fallback remains necessary when parser analysis is skipped or
  fails.
* Noise filtering: nav/footer/sidebar/infobox/toc/search pruning and
  prose-preservation heuristics are product-specific.
* Complex inline spacing and escaping: Markdown-facing text cleanup, link
  rendering identity, note ref markers, and image fallback text.
* Complex image/link/asset behavior: local export, remote/data/unsafe fallback,
  asset path naming, image captions, origin metadata, and unresolved local
  assets.

Semantic path coverage now exists for these safe subsets:

* Blockquote and pre/code facts for top-level simple cases.
* Simple paragraph and inline text/break/emphasis/strong/code/span cases.
* Headings and safe link paragraphs.
* Safe flat list items.
* Safe local image paragraphs and single-image figures with simple captions.
* Safe simple tables with one header row and simple inline cell content.

M9/M10 recommendations:

* M9 should be a parity and isolation pass, not another broad runtime migration.
  Keep running focused unit tests plus HTML samples, quality, and bench. Add
  audit/profile probes for note facts and complex table facts before migrating
  either area.
* Notes/footnotes are a good M9 candidate only after `doc_parse/html` owns
  note ref/body facts, IDs, marker text, body ranges, and confidence. Convert
  should still own rendering, placement, and note definition policy.
* Complex table migration should wait for parser facts that represent spans,
  captions, ragged rows, nested table presence, direct child blocks, and cell
  inline completeness. Until then, keep the current scanner as guarded fallback.
* Scanner isolation is safer than deletion in M9: group raw scanners as
  fallback-only, keep profile counters proving semantic coverage, and make
  deletion a later M10 step after sample/quality/bench parity.
* Do not move product policy into parser. Markdown escaping, RichTable rendering
  policy, asset export/path naming, origin metadata, and product-specific noise
  filtering should remain in `convert/html`.

## M9.5 Parser Facts Equivalence Expansion

M9.5 is complete for facts/read-path coverage, not runtime scanner deletion.
`doc_parse/html` now emits parser-owned facts for the responsibilities that
blocked the first M10 deletion audit, and `convert/html` exposes them through
summary/profile read paths. No dispatcher wiring changed and no new lowering
slice was migrated.

New parser facts and counters cover:

* Notes/footnotes: `HtmlNoteRefFact`, `HtmlNoteBodyFact`, and `HtmlNoteFact`
  expose same-document href/target IDs, note body IDs, source order, ref/body
  previews, inline child keys, duplicate-body warnings, missing/broken targets,
  backrefs, and relation confidence. Convert still owns note placement,
  appendix/definition construction, and Markdown note policy.
* Complex tables: table facts now summarize span-cell count, ragged-row count,
  nested-table cells, complex cells, image cells, direct block-child cells, and
  malformed table warnings in addition to existing row/cell/section/caption and
  per-cell source facts. Parser still does not build a dense span grid; RichTable
  rendering and padding/span policy remain convert-owned.
* Body/scope and malformed roots: `HtmlDocumentScopeFact` exposes html/head/body
  keys where available, selected content root key, scope source, title/meta
  previews, missing/multiple body/html flags, malformed-root warning, selected
  scope reason, and related noise candidate keys. Convert still owns event-backed
  scope selection, raw fallback for skipped/parser-failed inputs, and output
  ordering policy.
* Complex inline/link/image facts: link facts now expose nested inline child
  keys, linked image source keys, image-in-link relation, note-ref/backref
  classification, title/rel/target attrs, and URL class. Image facts expose
  parent inline/link keys, `srcset`, alt/title completeness, and existing
  remote/data/local/unsafe classification. Entity-decoded text and whitespace
  boundary hints are available through inline facts; raw pre-decoded entity
  lexemes are intentionally not reconstructed from the DOM.
* Product noise hints: `HtmlNoiseCandidateFact` exposes tag/source/depth/text,
  attrs, nav/footer/sidebar/hidden/script-style-template/boilerplate reasons,
  confidence, and scope references. Product-specific skip/preserve decisions
  remain in `convert/html/html_noise_rules.mbt`.
* Convert observability: `HtmlSemanticBlockSummary` and profile details now
  include note, complex-table, scope/body, complex inline/image/link, and noise
  counters, with read-path helpers for note/scope/noise/complex-inline summaries.

M9.5 scanner audit update:

| File | M9.5 facts now available | Still blocking deletion |
| --- | --- | --- |
| `convert/html/html_dom.mbt` | Scope facts, noise candidate keys, note-body facts, and existing block/list/figure/table facts can describe the main scanner responsibilities. | Normal runtime still scans block nodes, applies note-body/noise skipping, handles malformed block boundaries, and feeds existing lowering. Delete only after scanner isolation or parser-DOM lowering replaces the runtime input. |
| `convert/html/html_inlines.mbt` | Link/image facts now include nested child keys, linked image relation, note-ref/backref classification, URL class, attrs, `srcset`, and whitespace/entity-decoded text hints. | Markdown escaping/render identity, complex spacing, image fallback text, note marker rendering, and scanner-backed inline lowering remain convert product behavior. |
| `convert/html/html_table.mbt` | Complex table counters and per-cell flags now expose spans, captions, sections, ragged rows, nested tables, image/list/blockquote/pre/figure/table cells, direct child blocks, and malformed warnings. | RichTable policy, row padding/span interpretation, cell Markdown rendering, malformed raw table recovery, and current runtime table input remain scanner-owned until a dedicated migration. |
| `convert/html/html_notes.mbt` | Parser facts now expose note refs, note bodies, relations, broken/missing/duplicate targets, backrefs, and order. | Note definition construction, body exclusion from main flow, placement, marker normalization, and product confidence policy remain convert-owned. |
| `convert/html/html_bytes.mbt` | Parser facts reduce future need for tag-block and raw matching helpers in migrated slices. | Shared raw scanner helpers still have normal-runtime callers across DOM/inline/table/notes/noise/scope fallback. Quarantine before deletion. |
| `convert/html/html_tag_attrs.mbt` | Parser facts expose structured attrs for new fact consumers. | Raw scanner callers still need tag-string attr bridges until scanner modules disappear. |
| `convert/html/html_noise_rules.mbt` | Parser now emits structural noise candidates with reason hints. | This is product policy and should remain in convert; only low-level raw scanning can be removed after callers consume parser facts. |
| `convert/html/html_parser.mbt` | Parser semantic summaries now expose M9.5 facts and profile counters. | Entrypoint, event-backed scope, raw fallback, profile, asset/origin document assembly, and product output remain convert-owned. |
| `convert/html/html_to_ir.mbt` | Future migrations can consume richer facts for notes, complex tables, scope, and complex inline/image/link cases. | Markdown escaping, RichTable rendering, asset export/path naming, image/figure metadata, origin construction, and guarded fallback are product policy. |
| `convert/html/html_semantic_lowering.mbt` | Read-path counters can now observe M9.5 facts without migrating lowering. | Lowering policy remains convert-owned; new complex slices should be added only after parity probes prove output identity. |

M9.5 leaves Option 2 intact: the existing parser package grows typed facts, the
existing converter package owns product lowering, and raw scanners are retained
until runtime callers can be safely isolated or removed without expected-output
updates.

## M9 Parity Closeout

M9 parity hardening is complete for the current Option 2 semantic slices. The
formal validation snapshot is recorded below. No samples expected output or
quality-lab fixture changed, and the current convert HTML bench median remains
within the M0/M7/M8 range.

Semantic lowering coverage is exercised by profile counters and output-stability
tests for:

* Blockquote and pre/code: candidate/lowered/existing-path counters are covered;
  guarded blockquotes and incomplete pre/code keep existing output, with
  unsupported and incomplete/empty guard reason counters where applicable.
* Paragraph/simple inline: candidate/lowered/existing-path counters and empty,
  render-mismatch, and unsupported guard counters are covered.
* Heading and safe link paragraph: candidate/lowered/existing-path counters and
  heading guard reason counters are covered, including max-heading clamping.
* Safe list: candidate/lowered/existing-path counters plus nested, empty,
  render-mismatch, and unsupported guard counters are covered.
* Safe image and figure: candidate/lowered/existing-path counters plus empty,
  render-mismatch, identity, unsupported, and aggregate guard counters are
  covered.
* Safe simple table: candidate/lowered/existing-path counters plus span,
  caption, nested, complex-cell, ragged, and mismatch guard counters are covered.

Guarded existing-path coverage remains required for linked or unsafe images,
remote/data images, complex link/image paragraphs, nested or mixed lists,
complex blockquotes, table spans/captions/ragged rows/nested tables/complex
cells, notes/footnotes, malformed HTML, body/scope fallback, and
product-specific noise filtering.

Metadata and origin sanity remains on the convert product path: block origins,
asset origins, image and figure metadata, RichTable hints, object references,
and asset path naming are still constructed in `convert/html`.

## M10 Deletion And Quarantine Pass

M10 deletion/quarantine was audited after M9.5 parser facts landed. No helper
was deleted in this pass: every raw scanner helper with deletion potential still
has a normal-runtime caller or owns product policy. The safe semantic subsets
are covered by parser-backed guarded lowering, but the existing raw scanners are
still the runtime source for guarded complex paths.

Precise caller map summary:

| File | Important functions or groups | Caller classification | M10 result |
| --- | --- | --- | --- |
| `convert/html/html_dom.mbt` | `scan_html_nodes_with_skip_ranges`, `scan_html_notes`, `scan_html_nodes_with_notes` | B, F. `parse_html` still calls these directly to produce runtime `HtmlNode`s and note definitions. | Retained and labeled guarded complex path. |
| `convert/html/html_dom.mbt` | `scan_list_nodes`, `scan_li_children`, `scan_html_nodes_in_container_with_notes`, `html_skip_range_end_at` | B, F. Internal runtime callers handle nested lists, containers, skip ranges, note-body exclusion, noise skips, malformed block boundaries, blockquote/pre/table recursion. | Retained. |
| `convert/html/html_inlines.mbt` | `html_inlines_from_bytes_with_notes`, `render_inlines`, `append_inlines` | B, C, F. DOM/table/notes/IR lowering and semantic guard comparisons still call them for complex inline rendering identity. | Retained and labeled guarded complex path. |
| `convert/html/html_inlines.mbt` | `find_figure_image_inline`, `find_figure_caption_inlines` | B, C. Runtime figure scanning still uses these for image/caption extraction. | Retained. |
| `convert/html/html_inlines.mbt` | `sanitize_html_href`, redirect helpers, text merge helpers | B, C, E. Runtime inline/note scanning uses them; whitebox tests cover link behavior. | Retained. |
| `convert/html/html_table.mbt` | `html_table_from_bytes_with_notes`, `html_table_row_from_bytes`, `normalize_table_rows`, `html_table_header_rows`, `parse_html_positive_int_attr` | B, C, F. DOM scanning still calls table parsing; `html_to_ir` still consumes `HtmlTable` rows/hints. | Retained and labeled guarded complex path. |
| `convert/html/html_notes.mbt` | `build_html_note_plan`, `collect_html_note_targets`, `html_note_body_range_end`, note ref/body constructors and render helper | B, C, F. `parse_html`, DOM, inline, table, and document note-definition emission still consume this plan. Parser note facts now exist, but convert does not yet lower notes from them. | Retained and labeled guarded complex path. |
| `convert/html/html_bytes.mbt` | `pat`, `find_bytes`, `find_bytes_case_insensitive`, tag/list/li matching, tag stripping, entity bridge | B, E, F. DOM/inline/table/notes/noise/scope helpers all still call these. | Retained and labeled low-level helper path. |
| `convert/html/html_tag_attrs.mbt` | `html_open_tag_name`, `read_html_attr_value` | B, E, F. Raw scanner callers still bridge tag strings to parser attr/tag helpers; tests also cover attrs. | Retained and labeled low-level helper path. |
| `convert/html/html_noise_rules.mbt` | `find_skippable_html_noise_subtree_end` and noise token/prose helpers | C, F. Product skip/preserve policy remains convert-owned and is called from DOM scanning. | Retained and labeled product policy path. |
| `convert/html/html_parser.mbt` | `parse_html`, parser analysis summaries, event-backed scope helpers, raw scope helpers, profile detail renderers | B, C, F. Public entrypoint and product assembly remain normal runtime; scope fallback remains required for skipped/parser-failed inputs. | Retained. |
| `convert/html/html_to_ir.mbt` | `nodes_to_blocks`, inline/list/quote/table/image/asset/origin helpers | C. Product lowering, Markdown/RichTable rendering, assets, origins, and guarded semantic comparisons remain convert-owned. | Retained. |
| `convert/html/html_semantic_lowering.mbt` | `build_html_semantic_lowering_state_from_bytes`, `lower_next_html_semantic_*`, guard/render/profile helpers | A, B, C. Safe semantic slices are active here; guarded complex cases still compare against existing output. | Retained. |

Deleted helpers/functions: none.

Quarantined or labeled pieces:

* `convert/html/html_dom.mbt`: labeled as the guarded complex runtime block
  input path.
* `convert/html/html_inlines.mbt`: labeled as guarded complex inline/image/link
  rendering path.
* `convert/html/html_table.mbt`: labeled as guarded complex table/RichTable path.
* `convert/html/html_notes.mbt`: labeled as guarded note planning and placement
  path.
* `convert/html/html_bytes.mbt`: labeled as low-level helper path for existing
  guarded scanners.
* `convert/html/html_tag_attrs.mbt`: labeled as low-level raw tag-string helper
  path.
* `convert/html/html_noise_rules.mbt`: labeled as convert-owned product noise
  policy.

Retained raw scanner reasons:

* Parser facts describe the source facts, but `parse_html` still feeds
  `nodes_to_blocks` from raw-scanned `HtmlNode`s.
* Complex table runtime output still depends on raw table rows, normalized
  ragged rows, span hints, and cell inline rendering.
* Note definitions and note-body exclusion from main flow still depend on the
  convert note plan.
* Complex inline/image/link rendering still depends on raw inline rendering
  identity, Markdown escaping behavior, image fallback text, and note refs.
* Scope selection and raw content extraction still need event-backed and raw
  behavior for skipped/parser-failed inputs.
* Noise skipping is product policy and should remain in convert even though
  parser now emits noise candidate facts.

Future M10 deletion criteria:

* Parser facts must fully replace the runtime input for a scanner slice.
* Guarded complex samples, quality rows, and focused unit tests must still pass
  without expected-output updates.
* Remaining byte/tag helpers should first be isolated behind explicit guarded
  complex-path modules or comments, then deleted as callers vanish.

## M11 Single-Scan Parser-Owned Runtime Switch

M11 switches the normal `parse_html` runtime from raw scanner input to parser
facts without creating `html_v2` and without switching dispatcher wiring.

Current normal runtime pipeline:

```text
read raw bytes for IO/provenance/profile length
 -> normalize CR/BOM bytes
 -> UTF-8 text
 -> @dphtml.parse_html_document(text) exactly once in parse_html
 -> @dphtml.collect_html_semantic_document(parser_doc)
 -> convert/html/html_fact_runtime.mbt lowers parser facts
 -> core Document / Markdown / metadata / origins
```

Raw bytes are retained only as the input payload for file read, CR/BOM
normalization, UTF-8 decoding, profile byte counts, input directory context,
and origin/asset policy. They are not passed to block, inline, table, note,
image/link, body/scope, or noise source-discovery scanners in the normal
runtime.

`convert/html/html_fact_runtime.mbt` is the M11 runtime lowering boundary. It
builds a `HtmlConvertContext` from `@dphtml.HtmlSemanticDocument` and lowers:

* Scope/body selection from parser scope facts and parser block attrs.
* Noise skip/preserve decisions from parser noise candidates, with
  product-specific policy still in convert.
* Notes/footnotes from parser note relation, ref, and body facts; convert still
  owns note definitions and placement.
* Paragraphs, headings, links, images, figures, lists, blockquotes, pre/code,
  and tables from parser block/inline/link/image/table facts.
* Complex tables conservatively from parser table facts, including span hints,
  ragged rows, nested table markers, and nested table child block emission.
* Complex inline/image/link behavior from parser inline, link, image, and note
  facts; unsafe URLs become text or conservative placeholders according to
  convert product policy.

Raw scanner retirement result for normal runtime:

| File | M11 normal-runtime status | Remaining role |
| --- | --- | --- |
| `convert/html/html_parser.mbt` | No longer calls raw block/inline/table/note/scope scanners. Calls the parser once, then fact runtime lowering. | Entrypoint, validation/profile detail, document assembly, origins, asset map, and note attachment. |
| `convert/html/html_fact_runtime.mbt` | New normal runtime. | Convert-owned fact lowering and product policy over parser facts. |
| `convert/html/html_dom.mbt` | Not called by normal runtime. | Quarantined obsolete raw block scanner; retained for deletion audit. |
| `convert/html/html_inlines.mbt` | Raw scanner functions are not called by normal runtime. | `HtmlInline`, rendering, merge, URL sanitizing, and redirect helpers remain product helpers; byte scanners are quarantined. |
| `convert/html/html_table.mbt` | Not called by normal runtime. | Quarantined obsolete raw table scanner; RichTable policy is now applied from parser facts in fact runtime. |
| `convert/html/html_notes.mbt` | Not called by normal runtime. | Quarantined obsolete raw note planner; note rendering helpers remain candidates for reuse or deletion. |
| `convert/html/html_bytes.mbt` | Not called by normal runtime for source discovery. | Helper surface for quarantined scanners; deletion candidate once scanner files are removed. |
| `convert/html/html_tag_attrs.mbt` | Not called by normal runtime source discovery. | Raw tag-string helper bridge for quarantined scanners; parser facts now provide attrs for runtime. |
| `convert/html/html_noise_rules.mbt` | Raw subtree scanner is not called by normal runtime. | Product noise token/prose policy remains convert-owned; fact runtime consumes parser noise candidates. |
| `convert/html/html_to_ir.mbt` | `nodes_to_blocks` is no longer normal runtime. | Product helpers for Markdown/IR, image export/path naming, origins, captions, RichTable metadata, and an obsolete scanner-node projection pending deletion. |
| `convert/html/html_semantic_lowering.mbt` | Runtime state is now built from the already parsed semantic document. | Guard/counter/profile taxonomy and product observability remain convert-owned. |

Convert-owned product policies that should not migrate to the parser:

* Markdown and IR escaping/rendering choices.
* RichTable rendering and table metadata/hints.
* Local asset export, asset path naming, image fallback output, and unresolved
  asset policy.
* Origin metadata and object/key-path construction.
* Note definition construction and placement.
* Product-specific noise skip/preserve decisions.
* Profile and product observability counters.

Remaining gaps after M11:

* Quarantined raw scanner files are still present and produce unused-code
  warnings when focused `moon check` runs. They are outside normal runtime but
  should be deleted or moved to test/quarantine modules in a dedicated scanner
  deletion slice.
* `html_to_ir.mbt` still contains the obsolete `nodes_to_blocks` projection for
  `HtmlNode`; normal runtime no longer calls it.
* M11 intentionally does not update samples expected output or quality-lab
  fixtures. Any parity drift should be treated as a product decision, not hidden
  by reintroducing raw scanner fallback.

Recommended next slices:

* Scanner deletion slice: delete or quarantine `html_dom`, raw byte scanner
  entrypoints in `html_inlines`, raw table scanner entrypoints in `html_table`,
  raw note planner entrypoints in `html_notes`, and the obsolete
  `nodes_to_blocks` projection once no tests require them.
* Notes hardening slice: expand parser note confidence and convert note
  placement tests if samples reveal ambiguous refs or duplicate bodies.
* Complex table hardening slice: refine parser dense-span/table-child facts and
  RichTable hint policy without raw table scanning.
* Closeout report slice: generate `docs/report/HTML-Option2-closeout.md` after
  scanner deletion or explicit quarantine acceptance.

## Acceptance Criteria

HTML Option 2 cleanup is complete when:

* `convert/html` normal runtime no longer reparses raw HTML for migrated
  structures.
* Semantic facts originate in `doc_parse/html`.
* `convert/html` owns only output and product policy.
* Unsupported structures are represented as typed warnings or facts.
* Samples, quality, and bench checks remain green.
* No `html_v2` package exists.
* No dispatcher switch is required.
* Raw scanner helpers are deleted or isolated to test-only or temporary paths.

## Non-goals

* Full browser HTML5 tree builder behavior.
* CSS layout or rendering.
* JavaScript execution.
* Remote image fetching.
* Pixel-perfect rendering.
* Complete accessibility tree.
* Full DOM API.

## Validation Baseline

Latest M10 deletion/quarantine validation baseline:

* `moon info && moon fmt`: passed with one non-HTML EPUB unused-function
  warning from `convert/epub`.
* `moon check doc_parse/html convert/html`: passed.
* `moon test doc_parse/html/tests`: 47/47 passed.
* `moon test convert/html/test`: 61/61 passed.
* `bash samples/check.sh --format html`: passed, 111 checked.
* `bash samples/check_quality.sh --format html`: passed, 2 checked.
* `bash samples/bench.sh --layer convert --format html --iterations 1 --warmup 0`:
  passed, convert HTML median about 2563 ms.
* `moon check`: passed with two non-HTML warnings in EPUB/Markdown test code.
* Full `moon test` was not rerun for this closeout. The last known full-run
  failures were unrelated to HTML: PPTX/ZIP origin metadata and a missing
  external PDF sample.

## Commit Readiness

This document is a contract only. It does not modify runtime behavior. Future
implementation should proceed slice by slice inside the existing packages.
