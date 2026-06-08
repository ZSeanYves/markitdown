# HTML Option 2 Closeout Report

Date: 2026-06-08
Base commit: `6540ae8 html: switch runtime to parser-owned semantic facts`
Decision: `Option 2 existing-package refactor`
Status: `M12-M14 complete in worktree; validation passed`
Scope: `doc_parse/html + convert/html`

Explicit non-actions:

- no `html_v2`
- no dispatcher switch
- no samples expected change
- no quality-lab change
- no staging or commit in this slice

## Executive Summary

HTML remains Option 2: keep the existing `doc_parse/html` and `convert/html`
packages, keep dispatcher routing unchanged, and enforce the parser/convert
contract inside those packages.

M11 switched normal runtime to parser-owned semantic facts. M12-M14 complete the
follow-up closeout work that was intentionally left out of M11:

- M12 hardens notes/footnotes lowering from parser note facts.
- M13 hardens complex table lowering from parser table facts.
- M14 deletes obsolete raw scanner source-discovery surfaces.

Closeout conclusion after M12-M14: normal runtime source structure is owned by
`doc_parse/html`. `convert/html` consumes parser DOM/semantic facts and owns
Markdown/IR/RichTable/assets/origin/noise/note placement policy. The old raw
block/table/note/inline scanner path is no longer present as a normal-runtime
source-discovery fallback.

## Final Runtime Pipeline

```text
HTML bytes
 -> UTF-8 text / provenance
 -> doc_parse/html parse_html_document(text)
 -> tolerant DOM / source model
 -> parser-owned semantic facts / warnings / guards
 -> convert/html fact runtime lowering
 -> core Document / Markdown / RichTable / assets / metadata / origins
```

`parse_html` uses `@dphtml.parse_html_document(text)` as the structural parse
for normal conversion, then lowers through `html_semantic_document_to_blocks`.
Raw bytes remain only for IO, CR/BOM normalization, UTF-8 decoding, profile byte
counts, input directory context, and asset/origin policy.

## Parser / Convert Contract

`doc_parse/html` owns tokenizer, tolerant DOM/source model, entity/text/source
facts, body/scope facts, block/inline/link/image/table/list/figure/note facts,
malformed document facts, unsupported facts, warning facts, and guard facts.

`convert/html` owns Markdown/IR lowering, whitespace/product policy, RichTable
rendering and hints, asset export/path naming, origin metadata, note definition
placement, noise skip/preserve product policy, and profile/metadata policy.

Product policy that must stay in `convert/html`:

- Markdown escaping and inline rendering choices.
- RichTable rendering and span hint policy.
- Asset export, local path naming, unresolved image fallback, and image origins.
- Origin metadata and object/key-path construction.
- Note definition construction, placement, and display markers.
- Product-specific noise skip/preserve decisions.

## Milestones

- M0-M8b: architecture contract, parser facts, guarded semantic lowering, guard
  constants/counters, and raw scanner audit map.
- M9-M10: parity hardening, M9.5 fact expansion, and raw scanner caller map.
- M11: normal runtime switched to parser-owned semantic facts.
- M12: note/footnote fact lowering hardening.
- M13: complex table fact lowering hardening.
- M14: obsolete raw scanner deletion/quarantine cleanup.

## M12 Notes Hardening

Current product note policy:

- Parser provides `HtmlNoteRefFact`, `HtmlNoteBodyFact`, and `HtmlNoteFact`.
- Convert builds `@cor.NoteRef` and `@cor.NoteDefinition` from parser note
  relations.
- Convert controls document-end note placement, body block text, confidence
  mapping, note marker display, and origin metadata.
- Note body blocks are excluded from main flow by parser source keys.
- Missing targets stay conservative: the link remains visible instead of
  emitting a resolved note reference.
- Duplicate note bodies are skipped from main output and no longer produce
  duplicate note definitions.
- Multiple refs to the same body reuse one note definition.
- Note refs inside paragraphs and table cells lower through the same parser fact
  inline path.

M12 changed `html_fact_prepare_note_defs` so only ref+body parser relations
produce note definitions, definitions are deduped by body source key, and
orphan duplicate bodies do not leak into appendix output.

Runtime tests now cover simple note lowering, role/epub variants, `li` note body
exclusion, missing target behavior, multiple note ordering, duplicate body
dedupe, backref text in body content, and note refs inside table cells.

## M13 Complex Table Hardening

Current product table policy:

- Parser provides table sections, rows, cells, caption metadata, row/col span
  values, ragged-row flags, nested-table flags, complex-cell flags, malformed
  warnings, and inline child keys.
- Convert builds `RichTable` rows from parser table rows/cells.
- Convert pads colspan cells with empty cells to preserve current markdown table
  shape.
- Convert emits `TableSpanHint` records from parser rowspan/colspan values.
- Convert owns header-row inference via parser table section/cell facts.
- Convert renders cell text from parser inline/link/image/note facts.
- Nested table child blocks are emitted conservatively after the containing
  table path.
- Empty/malformed tables are guarded conservatively without raw table scanning.

M13 added runtime coverage for malformed/empty/nested table behavior and keeps
existing complex table coverage for captions, spans, ragged rows, nested tables,
image/list/blockquote/pre cells, links, code, breaks, entities, and span hints.

## M14 Scanner Deletion / Quarantine Cleanup

M14 deleted the obsolete raw scanner source-discovery files:

- `convert/html/html_dom.mbt`
- `convert/html/html_table.mbt`
- `convert/html/html_notes.mbt`
- `convert/html/html_block_helpers.mbt`
- `convert/html/html_tag_attrs.mbt`

M14 also removed raw byte/tag search helpers from `html_bytes.mbt`, removed raw
inline scanner entrypoints from `html_inlines.mbt`, removed raw subtree scanner
helpers from `html_noise_rules.mbt`, removed `HtmlByteRange` from
`html_parser.mbt`, removed `nodes_to_blocks` and `HtmlNode` projection helpers
from `html_to_ir.mbt`, and removed old `lower_next_html_semantic_*` scanner
bridge functions from `html_semantic_lowering.mbt`.

Focused scanner warnings are eliminated:

- `scan_html_nodes_with_skip_ranges`: deleted
- `scan_html_notes`: deleted
- `HtmlByteRange`: deleted
- `nodes_to_blocks`: deleted

Remaining convert helper surface and reason:

- `html_inlines.mbt`: `HtmlInline`, merging, Markdown-facing inline rendering,
  note ref rendering, URL sanitizing, and redirect unwrapping. Product policy.
- `html_bytes.mbt`: `html_unescape`. Product/helper bridge to parser entity
  decoding.
- `html_noise_rules.mbt`: token-based noise policy helpers. Product policy.
- `html_to_ir.mbt`: image export/path/origin helpers, paragraph splitting,
  caption/image block policy, heading clamp. Product policy.
- `html_semantic_lowering.mbt`: candidate counters, guard reason counters,
  semantic fact lookup helpers, and table header-row helper. Observability and
  product policy.
- `html_fact_runtime.mbt`: normal runtime fact lowering. Product policy over
  parser facts.

No remaining surface performs normal-runtime raw HTML source discovery.

## Boundary Status

- no `doc_parse/html_v2`
- no `convert/html_v2`
- no dispatcher diff
- no CLI/ZIP/bench/debug diff
- no samples expected diff
- no quality-lab diff
- no raw scanner source-discovery grep hits in `convert/html`
- no normal-runtime legacy/oracle/fallback glue
- no stage or commit in this slice

## Validation Snapshot

Validation for M12-M14:

```text
moon info && moon fmt: passed
moon check doc_parse/html convert/html: passed
moon test doc_parse/html/tests: 47/47 passed
moon test convert/html/test: 63/63 passed
bash samples/check.sh --format html: passed, 111/111 checked
bash samples/check_quality.sh --format html: passed, 2/2 checked
bash samples/bench.sh --layer convert --format html --iterations 1 --warmup 0: passed, median 2580.000ms
moon check: passed
```

`moon info && moon fmt` and global `moon check` reported only existing non-HTML
warnings:

- `convert/epub/epub_part_cache.mbt`: unused `read_epub_part_text_cached`.
- `convert/markdown/test/markdown_passthrough_test.mbt`: deprecated Debug/Show
  warning.

Full `moon test` was not run for this slice.

## Final Assessment

HTML Option 2 closeout is complete for this worktree.

The M12-M14 work satisfies the single-scan parser facts contract: parser owns
source structure; convert owns product lowering; obsolete raw scanner source
discovery is deleted rather than hidden behind fallback code.

Remaining follow-up slices should be independent hardening work, not contract
cleanup:

- notes edge-case hardening if additional EPUB/HTML samples reveal ambiguity
- complex table policy refinements if sample parity needs more browser-like
  behavior
- optional full `moon test` unrelated failure cleanup outside HTML
