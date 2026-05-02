# Format Hardening Roadmap

This document defines the repository's format-by-format hardening path.

It is not the detailed support contract. For current per-format behavior and
limits, use [docs/support-and-limits.md](./support-and-limits.md).

It is also not a "more formats first" plan. The goal is to turn
`markitdown-mb` into a finished product by raising each already-supported
format from conservative baseline toward mainstream-tool quality and clear
native-performance leadership.

`H1 complete` does not mean `final done`. It only means the format has crossed
the first hardening gate and can now advance toward parity and performance.

## Format Hardening Ladder

### H1: Hardened baseline

An H1 format should have:

* regression samples
* metadata / origin / assets behavior fixed enough to treat as repository
  contract
* support-and-limits coverage
* smoke benchmark corpus
* MarkItDown overlap comparison when a meaningful overlap exists
* conservative fail-closed / fallback behavior for unsupported inputs

H1 is the point where the format stops being "newly wired" and starts being
stable enough for controlled iteration.

### H2: Market-parity quality pass

An H2 format should:

* compare output quality against mainstream tools
* add real-world samples instead of only synthetic regression cases
* cover complex edge cases and degradation boundaries
* preserve structures that mainstream tools preserve when feasible
* improve the bottom parser / core first when current converter quality is
  capped by missing source signal
* document intentional non-goals instead of silently underperforming

H2 is about quality parity, not only feature checkboxes.

### H3: Performance leadership pass

An H3 format should:

* benchmark the prebuilt native CLI
* cover small / medium / large / batch cases
* compare against Microsoft MarkItDown or other mainstream tools where useful
* classify results as win / close / loss
* profile and explain losses
* optimize parser / emitter / metadata / asset paths as needed
* eventually add lightweight performance-regression warning surfaces

H3 is the point where "native MoonBit is faster by default" becomes measured
project behavior rather than aspiration.

## Bottom-layer Delivery Principle

The repository should treat parsing foundations as first-class deliverables, not
throwaway converter internals.

That means:

* OOXML / ZIP / PDF / HTML / CSV / JSON / YAML / XML low-level parsing
  capability is part of the project output
* these packages should become reusable MoonBit ecosystem infrastructure
* format converters are consumers of those lower layers, not the only reason
  they exist
* if a converter cannot reach target quality because the lower layer does not
  expose enough signal, the preferred fix is to improve the lower layer first
* avoid piling format-specific regex patches into converters when the real
  missing capability belongs in the parser / package / substrate layer

This principle matters most for OOXML, ZIP, `pdf_core`, and other sources where
future consumers may need the same structural model even when they are not
emitting Markdown.

## Current Status

| Format | Current status |
| --- | --- |
| TXT | H1 complete |
| Markdown / MD / MARKDOWN | H1 complete |
| CSV / TSV | H1 complete |
| JSON | H1 complete |
| YAML / YML | H1 complete |
| XML | supported conservative baseline, pending H1 hardening |
| HTML / HTM | supported, pending H1 / H2 review |
| XLSX | supported, pending H1 / H2 review |
| ZIP | supported, pending H1 / H2 container hardening review |
| EPUB | supported, pending H1 / H2 ebook hardening review |
| DOCX | supported, pending H2 market-parity pass |
| PPTX | supported, pending H2 layout quality pass |
| PDF | supported, pending deeper `pdf_core` / convert H2 pass |

Notes:

* H1 complete is not final parity completion
* H2 and H3 remain open even for the formats that already have H1 baselines

## Recommended Order

Recommended next sequence:

1. Finish XML H1.
2. Review TXT / Markdown / CSV / TSV / JSON / YAML at H2 quality level.
3. Push HTML through H1 / H2.
4. Push XLSX through H1 / H2.
5. Push ZIP through H1 / H2.
6. Push EPUB through H1 / H2.
7. Run DOCX H2 market-parity pass.
8. Run PPTX H2 layout-quality pass.
9. Run PDF H2 with `pdf_core` upgrades first where needed.

This order keeps the project moving from simpler text / structured data toward
heavier document-layout formats, while also forcing the team to harden reusable
parser layers before relying on converter-local patching.

## Working Rule

For any format entering a new phase:

* do not declare the phase complete from support alone
* require regression, documented limits, and benchmark evidence
* treat converter quality gaps caused by weak parser signal as bottom-layer work
* keep intentional non-goals explicit
