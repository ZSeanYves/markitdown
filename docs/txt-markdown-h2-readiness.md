# TXT / Markdown H2 Readiness

This document audits TXT and Markdown after the first H3 benchmark round and
decides whether they are ready to be marked H2 complete.

Scope of this review:

* TXT plain-text conversion
* Markdown passthrough conversion
* dispatcher/batch/metadata behavior
* support/limits wording

Non-goals:

* turning TXT into a Markdown parser
* turning Markdown into an AST rewrite pipeline
* adding complex encoding auto-detection
* changing benchmark baselines or metadata schema

## TXT Current Behavior

| Area | Current behavior | H2 expectation | Gap | Action |
| --- | --- | --- | --- | --- |
| UTF-8 BOM | Leading UTF-8 BOM is stripped before paragraph processing | Stable UTF-8 BOM handling | No gap | Keep current behavior |
| CRLF / CR normalization | `\r\n` and bare `\r` normalize to `\n` before paragraph splitting | Stable newline normalization | No gap | Keep current behavior |
| Empty file | True empty file emits empty document and empty markdown | Empty stays empty | No gap | Added direct regression coverage |
| Blank-line paragraph boundaries | Blank-only lines split paragraphs; repeated blank lines collapse | Paragraph-only TXT contract | No gap | Keep current behavior |
| Consecutive non-empty line merge | Non-empty lines inside one paragraph are trimmed and joined with single spaces | Conservative plain-text paragraph merge | No gap | Keep current behavior |
| Literal-safe Markdown output | Markdown-sensitive punctuation is escaped conservatively; heading/list/quote/thematic-break starters stay literal | TXT must not silently become semantic Markdown | Small gap was thematic-break-like markers | Fixed `---` / `***` / `___` paragraph-start escaping and added regression |
| Markdown-sensitive chars | `[]()<>#*_{}\`` and backslash are escaped conservatively where needed | Literal safety | No gap for current H2 boundary | Keep current behavior |
| Long lines | Long lines remain paragraph text; no wrapping or semantic inference | Stability over formatting cleverness | No gap | Existing samples already cover |
| Many paragraphs | Repeated paragraph groups remain stable and deterministic | Stable large-ish paragraph grouping | No gap | Existing sample/benchmark coverage is sufficient for H2 |
| CJK paragraphs | CJK lines join with spaces between physical lines inside a paragraph | Conservative, explicit joining policy | Acceptable policy | Document as intentional conservative behavior rather than language-aware wrapping |
| Metadata / source origin | Each paragraph carries `source_name`, `line_start`, `line_end`, block index; no assets | H2 should preserve lightweight provenance | No gap | Existing metadata/origin coverage is sufficient |
| Batch behavior | Batch mode reuses normal TXT conversion and isolates output roots | Same semantics in single and batch mode | No gap | Existing CLI batch tests already exercise `.txt` inputs |
| Unsupported encodings policy | TXT currently requires UTF-8-decodable input and fails closed on decode error | H2 does not require heavyweight auto-detect | No gap for current scope | Document UTF-8-only policy explicitly |

### TXT H2 Judgment

TXT should not infer headings, lists, links, tables, or code from plain text.
For this project, H2 means:

* stable paragraph conversion
* conservative literal-safe Markdown output
* BOM/newline normalization
* metadata/source-origin stability
* large/batch operational stability without semantic overreach

Against that bar, TXT is now ready to be treated as **H2 complete**.

Remaining future work belongs to post-H2 or optional policy upgrades:

* real-world corpus expansion
* encoding fallback policy if a lightweight approach appears worthwhile
* larger H3 profiling focus for huge plain-text files

## Markdown Current Behavior

| Area | Current behavior | H2 expectation | Gap | Action |
| --- | --- | --- | --- | --- |
| Passthrough behavior | Original normalized Markdown body is stored as passthrough markdown and emitted directly | Preserve author source rather than AST-rewrite it | No gap | Keep current behavior |
| UTF-8 BOM | Leading UTF-8 BOM is stripped | Stable BOM normalization | No gap | Keep current behavior |
| CRLF / CR normalization | CRLF and CR normalize to LF before passthrough storage | Stable newline normalization | No gap | Added direct CR-only regression |
| Trailing newline normalization | Non-empty output is normalized to exactly one trailing newline; empty output stays empty | Deterministic markdown tail normalization | No gap | Existing and new tests cover it |
| Raw HTML passthrough | Raw HTML is preserved literally | Preserve source fidelity | No gap | Keep current behavior |
| Fenced code passthrough | Fenced code blocks are preserved literally in output; conservative block slicing marks them as `CodeBlock` for metadata summary | Preserve code fences without AST rewrite | No gap | Keep current behavior |
| Links / images / table syntax passthrough | Markdown syntax is preserved verbatim in passthrough output | Passthrough fidelity | No gap | Keep current behavior |
| Frontmatter policy | Leading `---` / `+++` frontmatter block is preserved literally and summarized as one conservative paragraph-like block for metadata | Policy must be explicit, not heuristic | No gap after audit | Document current frontmatter passthrough policy explicitly |
| Metadata / source origin | Conservative blocks carry `source_name`, `line_start`, `line_end`, block index; no assets by default | H2 should preserve lightweight provenance without AST rewrite | No gap | Existing metadata/origin coverage is sufficient |
| Large passthrough | Large files follow source-preserving passthrough path with normalization only | Stability and fidelity, not beautification | No H2 gap | H3 profiling remains separate |
| Batch behavior | Batch mode reuses normal Markdown conversion and isolates output roots | Same semantics in single and batch mode | No gap | Existing CLI batch tests already exercise `.md` inputs |

### Markdown H2 Judgment

Markdown H2 should not mean “full Markdown semantic normalization.” For this
project it should mean:

* source-preserving passthrough fidelity
* stable BOM/newline normalization
* explicit frontmatter treatment
* lightweight metadata/origin slicing
* stable batch/large-file passthrough behavior

Against that bar, Markdown is now ready to be treated as **H2 complete**.

Remaining future work belongs outside this H2 decision:

* broader real-world Markdown corpus sampling
* larger H3 passthrough profiling
* any future richer provenance model, if ever needed, without AST rewrite

## Product-direction Judgment

Conservative product-direction conclusions for this repository:

### TXT

TXT H2 should include:

* semantic inference: **no**
* encoding auto-detect: **probably future, not H2-required**
* literal safety: **yes**
* large/batch stability: **yes**

### Markdown

Markdown H2 should include:

* AST parse/rewrite: **no**
* passthrough fidelity: **yes**
* normalization: **yes**
* frontmatter treatment: **yes, explicit policy required**

## Decision

* TXT: **H2 complete**
* Markdown / MD / MARKDOWN: **H2 complete**

Why this is reasonable:

* both formats are intentionally conservative
* both already have sample, metadata, and benchmark coverage
* both preserve their product boundary instead of drifting into “smart”
  inference that would increase risk disproportionately
* the only small TXT gap found in this audit was literal safety for thematic
  break markers, and that is now covered

## Non-goals

This audit does not change the following boundaries:

* TXT does not infer headings/lists/tables/code/links
* Markdown does not become an AST rewrite/beautification pipeline
* no complex encoding detection is added
* no H3 performance rewrite is attempted here
