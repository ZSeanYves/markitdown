# HTML / HTM H1/H2 Review

This document records the current HTML / HTM H1/H2 review status for
`markitdown-mb`.

It is an audit and planning document. It is not the detailed support contract;
the support contract remains [docs/support-and-limits.md](./support-and-limits.md).

## Current implementation map

### Converter and lower layer

* converter entry: `convert/html/html_parser.mbt`
* lightweight scanner / DOM-like lowering helpers: `convert/html/html_dom.mbt`
* HTML node to unified IR lowering and image export: `convert/html/html_to_ir.mbt`
* byte helpers and partial entity unescape: `convert/html/html_bytes.mbt`

### Dispatch wiring

* `.html` / `.htm` are routed through the shared dispatcher
* ZIP entry conversion also routes `.html` / `.htm` through the same path

### Metadata / assets

* metadata format is `html`
* block origins carry `source_name` and `block_index`
* line-range origin is not available in the current HTML path
* local HTML image export is supported through the existing asset pipeline
* remote/data-URI HTML images are not fetched

## Current H1 status

### Supported and stable in H1

* headings, paragraphs, lists, block quotes, code blocks, tables
* inline links
* local image export
* figure / figcaption / alt / title handling for local images
* UTF-8 BOM removal
* CRLF / CR normalization
* conservative malformed-markup tolerance in common cases
* current remote image downgrade behavior fixed by regression

### Tolerated but conservative

* semantic wrappers such as `main` / `section` / `header` / `footer`
* `details` / `summary` as conservative text-preserving lowering
* comments / doctype ignored
* mixed inline/block list and quote content through current fallback rules

### Known H1 limits

* no CSS layout recovery
* no JavaScript execution
* no remote fetch
* no rowspan / colspan reconstruction
* no DOM-path metadata
* no specialized `details` / `summary` reconstruction
* current HTML named-entity decoding is partial beyond numeric entities and the
  small built-in set
* remote `figure` images currently degrade to no emitted block rather than a
  caption-preserving fallback

## H2 gap table

| Area | Current behavior | Market expectation | Gap | Bottom-layer needed? | Suggested action |
| --- | --- | --- | --- | --- | --- |
| Mixed inline/block content | Conservative scan plus fallback text reconstruction | Stable preservation of nested mixed content across real pages | Moderate | Yes | Separate node-model cleanup from converter heuristics before more rules |
| Entity decoding | Numeric plus a small named subset | Broader HTML named-entity coverage | Moderate | Yes | Add a fuller reusable named-entity surface in the lower layer |
| Link handling | Inline links are stable and relative href is preserved | Broader coverage across messy nested link content | Small | Mostly no | Add more real-world link samples and tighten inline extraction if needed |
| Image alt/title/figcaption | Local image handling is stable | More robust caption/image association and remote-image policy clarity | Moderate | Yes | Improve image-context lower layer and define explicit remote figure fallback |
| Table strategy | Basic tables and ragged rows work; pipes are escaped | Better handling for complex tables including spans | Large | Yes | Keep spans out of H1; design lower-layer table model before H2 converter work |
| Nested lists | Common nested cases are covered | More robust behavior on messy DOM and mixed blocks | Moderate | Partly | Add real-world nested-list cases and review scanner boundaries |
| Pre/code | Common `pre` path is stable | Better preservation around mixed wrappers and raw text edges | Small | Partly | Add tricky `pre`/`code` wrapper cases before any logic change |
| `details` / `summary` | Conservative text-preserving lowering | Cleaner semantic reconstruction | Moderate | Yes | Treat as H2 feature, not H1 bug |
| Semantic tags | Child content survives; wrappers are not modeled | Better section-aware lowering in some content shapes | Small | Yes | Strengthen node model if semantic grouping becomes valuable |
| Malformed HTML tolerance | Common unclosed-tag cases do not panic | Broader recovery on messy real pages | Moderate | Yes | Add corpus from real messy pages and harden scanner recovery |
| Local vs remote resources | Local accepted-path export works; remote/data URI are not fetched | Clearer degradation for unsupported resource shapes | Small | Partly | Document policy and add remote figure fallback review |

## HTML lower-layer gaps

The current HTML path is stronger than string-regex extraction, but it is still
below the kind of reusable lower layer needed for broad H2 work.

### Stable enough today

* lightweight tokenizer/scanner is usable for common static HTML
* raw text handling for `script` / `style` / `head` is safely suppressive
* attribute extraction is good enough for current image/link use
* local-image path policy is intentionally strict

### Lower-layer gaps that likely gate H2 quality

* node model is shallow and only partially separates parsing from lowering
* block/inline boundary logic is spread across scanner and converter rules
* named-entity decoding is incomplete
* malformed-tag recovery is only lightly hardened
* source positions are not preserved
* remote/non-local image behavior is handled at converter time rather than via a
  cleaner lower-layer resource policy model
* complex table structure does not have a lower-layer model for spans

### Recommendation

If HTML H2 quality stalls, prefer improving the lower layer first:

* stronger reusable HTML node model
* clearer inline/block boundary representation
* fuller entity decode support
* explicit resource-policy helpers
* optional source-position capture if provenance becomes important

Do not respond to those gaps by piling more ad hoc converter-local string
patches onto the current scanner.
