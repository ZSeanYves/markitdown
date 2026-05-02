# ZIP H1/H2 Container Review

This document records the current ZIP H1/H2 container review status for
`markitdown-mb`.

It is an audit and planning document. The detailed support contract remains
[docs/support-and-limits.md](./support-and-limits.md).

## Current implementation map

### Converter and lower layer

* converter entry: `convert/zip/zip_to_ir.mbt`
* safe-path and asset-remap helpers live in the same package
* raw ZIP parsing: `doc_parse/zip/zip_reader.mbt`
* raw codec / decompression helpers: `doc_parse/zip/codec*.mbt`

### Dispatch and container wiring

* `.zip` is routed through the shared dispatcher
* supported ZIP entries are dispatched by extension through the same converter
  families used for standalone inputs
* ZIP does not recurse into nested archives; `.zip` / `.jar` / `.epub` entries
  are downgraded to warning blocks

### Metadata / provenance

* metadata format is `zip`
* container-level `source_name` is the archive filename
* every entry heading and sub-block is rewritten to carry archive-level
  `source_name` plus entry `key_path`
* remapped asset origins keep archive `source_name`, entry `source_path`, and
  entry `key_path`
* warning blocks also keep the offending entry `key_path`
* document-level metadata is currently `null` for ZIP containers

## Current H1 status

### Supported and stable in H1

* safe normalized entry traversal
* stable lexicographic entry ordering after normalization
* directory and common macOS metadata skip
* supported-entry dispatch for:
  * Markdown / CSV / TSV / TXT / XML / JSON / YAML / static HTML
  * self-contained DOCX / PPTX / XLSX / PDF
* unsupported entry downgrade to warning blocks
* nested archive downgrade to warning blocks
* archive-scoped asset namespace/remap
* same-archive HTML local-image support through a safe extracted tree
* entry-count and decoded-size guardrails

### Current policy fixed by regression

* unsafe archive paths fail closed at container level
* normalized path collisions fail closed
* duplicate raw central-directory names fail closed in the ZIP lower layer
* unsupported binary entries do not abort the whole archive
* hidden files are not skipped generically; only common macOS metadata is
  filtered in H1
* nested archives are not traversed or previewed
* HTML local images only resolve through a safe materialized sibling tree

### Known H1 limits

* no nested archive recursion
* no encrypted ZIP support
* no ZIP64 support
* no data-descriptor support
* only `store` and `deflate` compression methods are supported
* no binary preview beyond warning blocks
* no document-level container inventory/summary metadata
* no include/exclude policy for hidden files beyond macOS metadata filtering
* safe materialization is still tightly coupled to the HTML local-image path

## H2 gap table

| Area | Current behavior | Market expectation | Gap | Bottom-layer needed? | Suggested action |
| --- | --- | --- | --- | --- | --- |
| Nested archive policy | Nested archives always downgrade to warnings | Clear policy plus optional archive inventory or explicit opt-in recursion | Moderate | Partly | Keep default non-recursive, but design explicit nested-archive surfaces |
| Huge archive behavior | Entry count and decoded-size caps exist, but coverage is still light | Better large-archive ergonomics and clearer diagnostics | Moderate | Yes | Add larger corpora and inspect lower-layer memory behavior |
| Streaming vs materialization | Reads archive bytes eagerly; HTML local images can trigger full safe extraction | Lower memory overhead and more selective materialization | Large | Yes | Add entry streaming and narrower extracted-tree planning in ZIP core |
| ZIP64 | Fail closed | Broader compatibility on large real-world archives | Large | Yes | Add ZIP64 support in raw reader before converter changes |
| Data descriptor | Fail closed | Better compatibility with more producer variants | Large | Yes | Add data-descriptor support in raw reader with invariants |
| Encrypted ZIP | Fail closed | Clearer unsupported reporting and optional detection detail | Small | Yes | Keep fail-closed default, improve diagnostics if needed |
| Unsupported compression methods | Fail closed | Broader compatibility | Moderate | Yes | Extend codec support only when needed by real archives |
| Duplicate entries | Raw duplicate names fail closed; normalized collisions fail closed | Explicit duplicate policy and better diagnostics | Moderate | Yes | Preserve duplicate inventory in lower layer if policy evolves |
| Hidden/system file policy | Only macOS metadata is auto-skipped | Broader container noise filtering policy | Moderate | Partly | Decide whether generic dotfiles should be shown, skipped, or policy-driven |
| Per-entry failure isolation | Read/convert failures become warning blocks | Stronger isolation and better archive summaries | Moderate | Partly | Consider container summary blocks or structured warning inventory |
| Entry provenance | `key_path` rewriting is stable | Richer per-entry provenance and container inventory metadata | Moderate | Yes | Add container inventory/debug model in lower layer or converter boundary |
| Asset remap robustness | Archive namespace/remap works for current cases | More stress coverage across many asset-producing entries | Moderate | Partly | Add more asset-heavy corpora and collision stress tests |
| HTML sibling resolution | Safe extracted tree works | More targeted dependency materialization and clearer diagnostics | Moderate | Yes | Decouple extracted-tree planning from converter-local HTML heuristics |
| Container benchmarking | Smoke coverage now exists but no batch/memory tracking | Better archive-overhead visibility | Moderate | Partly | Add archive-heavy and asset-heavy benchmark follow-ups |

## ZIP lower-layer gaps

The current ZIP reader is already a meaningful reusable substrate, not just a
converter helper. H2 gaps now mostly come from compatibility breadth and
container-scale ergonomics rather than from basic safety.

### Stable enough today

* EOCD and central-directory parsing are in place
* central/local header consistency checks exist
* duplicate central-directory names fail closed
* encrypted, multi-disk, ZIP64, and data-descriptor cases are rejected early
* normalized path model and collision checks are already enforced in the
  container layer
* `store` and `deflate` entry reads are stable for current supported archives

### Lower-layer gaps that likely gate H2 quality

* no ZIP64 support
* no data-descriptor support
* no entry streaming interface
* no richer entry inventory/debug surface for archive triage
* no explicit size-ratio / bomb heuristics beyond decoded byte caps
* safe materialization planning is still coupled to converter-side HTML image
  needs rather than exposed as a more general archive service

### Recommendation

If ZIP H2 work stalls, strengthen the ZIP lower layer first:

* add ZIP64 support with tests
* add data-descriptor support with central/local consistency checks
* expose a better archive inventory/debug model
* design entry streaming or more selective materialization
* evaluate stronger bomb-protection heuristics beyond current byte caps

Do not try to close these gaps only by piling more path-string rules into the
converter.
