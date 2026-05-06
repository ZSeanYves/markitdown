# Quality Comparisons

This directory holds checked-in Markdown quality comparison records between
`markitdown-mb` and Microsoft MarkItDown.

These records are evidence for H2-quality discussions. They are not
performance benchmarks, and they are not blanket parity claims for every
format, feature, or document shape.

## Goal

Quality comparison in this repository is meant to answer:

* which tool preserves more LLM/RAG-useful structure on a concrete sample
* where current losses come from parser/core signal limits versus emitter shape
* which gaps are product-priority candidates for later H2.1 / P1 / P2 work

The focus is structure retention, not visual reconstruction.

## Not A Benchmark

Use these records for Markdown quality review.

Do not use them for:

* wall-time or throughput conclusions
* cold-start or memory conclusions
* OCR/cloud/plugin-path claims
* blanket product-ranking claims outside the recorded sample scope

For runner/corpus/performance governance, use
[docs/benchmark-governance.md](../benchmark-governance.md).

## Verdicts

Verdicts use these meanings:

* `win`: `markitdown-mb` keeps meaningfully more useful structure or avoids
  meaningfully more noise on the comparable scope
* `close`: both tools keep the important structures well enough; differences
  are mostly stylistic, policy-level, or too small to call a clear winner
* `loss`: Microsoft MarkItDown keeps meaningfully more useful structure or
  avoids meaningfully more noise on the comparable scope
* `not_comparable`: the compared outputs are not fair to score as win/loss

`not_comparable` is a valid result. It must not be counted as `win`.

## Not Comparable Rules

Mark a record `not_comparable` when:

* one side does not support the format
* one side requires an optional dependency the other path does not require
* one side requires OCR, cloud, LLM, or plugin paths outside the default local
  comparison scope
* input capability does not overlap enough for a fair structure comparison
* output structure is too different to score fairly on the chosen feature focus

## Quality Focus

Quality records should look at the structures most useful for LLM/RAG and
knowledge-base import:

* headings
* paragraphs
* lists
* tables
* links
* images and asset handling
* code and preformatted text
* metadata/origin behavior when the comparison scope includes it
* degradation explanations

## Explicit Non-Goals

These records do not compare:

* pixel-perfect visual fidelity
* complete Word/PPT/PDF visual layout restoration
* OCR/cloud/LLM-enhanced extraction quality

## Seed Records

The current checked-in seed set is intentionally small. It is enough to make
quality review concrete, but it is not the final parity conclusion.

| Format | Sample | Feature focus | Verdict | Notes |
| ------ | ------ | ------------- | ------- | ----- |
| DOCX | [golden.docx](./docx-golden-structure.md) | headings, paragraphs, image, table | `close` | both retain the main structure; image/table policy differs |
| DOCX | [docx_table_multiline_cell.docx](./docx-table-multiline-cell.md) | table header and multiline cell | `win` | `markitdown-mb` keeps explicit header row and `<br>` cell split |
| DOCX | [docx_list_links_linebreaks.docx](./docx-list-link-style.md) | mixed list structure, hyperlink retention, line-break policy | `close` | both keep the useful list/link shape; `markitdown-mb` keeps the explicit `<br>` |
| DOCX | [docx_footnotes_endnotes_comments.docx](./docx-notes-comments.md) | notes/comments retention and ordering | `win` | `markitdown-mb` keeps explicit note/comment append sections and author signal |
| DOCX | [docx_image_alt_title.docx](./docx-image-assets.md) | local image asset behavior, alt/title preservation | `win` | `markitdown-mb` materializes local assets and keeps the title line |
| DOCX | [docx_textbox_body_and_table.docx](./docx-header-footer-textbox.md) | textbox extraction policy | `close` | both preserve useful text, but use different downgrade policies |
| PPTX | [pptx_title_bullets.pptx](./pptx-title-bullets.md) | slide order, heading, bullets | `win` | `markitdown-mb` keeps bullet structure; Microsoft MarkItDown flattens it |
| PPTX | [pptx_grouped_shapes_boundary.pptx](./pptx-reading-order.md) | grouped shapes, reading order, heading promotion | `win` | `markitdown-mb` keeps a clearer heading/body order for grouped text |
| PPTX | [pptx_image_alt_title.pptx](./pptx-links-images.md) | local image asset behavior, alt/title preservation | `win` | `markitdown-mb` materializes the image asset and keeps the title hint |
| PPTX | [pptx_hidden_slides_policy.pptx](./pptx-notes-hidden-slides.md) | hidden slide preservation | `win` | `markitdown-mb` keeps hidden slide state explicit |
| PPTX | [pptx_callout_blocks_basic.pptx](./pptx-table-grid-callouts.md) | callout/card grouping and reading order | `win` | `markitdown-mb` keeps clearer callout title/body pairing |
| PPTX | [pptx_image_caption_like_boundary.pptx](./pptx-caption-like-image.md) | caption-like image pairing | `win` | `markitdown-mb` keeps the local asset and nearby caption-like text together |
| XLSX | [xlsx_multi_sheet_mixed.xlsx](./xlsx-multisheet-table.md) | multi-sheet tables and typed cells | `win` | `markitdown-mb` keeps cleaner sheet sections and fewer placeholder cells |
| XLSX | [xlsx_formula_cached_values.xlsx](./xlsx-formula-cached-values.md) | cached formulas and missing-cache degradation | `win` | `markitdown-mb` avoids `NaN` for missing cache and keeps cached error text |
| XLSX | [xlsx_formula_eval_arithmetic.xlsx](./xlsx-formula-eval-arithmetic.md) | missing-cache arithmetic evaluation | `win` | `markitdown-mb` recovers arithmetic results while Microsoft MarkItDown emits `NaN` |
| XLSX | [xlsx_formula_eval_ranges.xlsx](./xlsx-formula-eval-ranges.md) | missing-cache range aggregates | `win` | `markitdown-mb` recovers aggregate results while Microsoft MarkItDown emits `NaN` |
| XLSX | [xlsx_formula_eval_unsupported.xlsx](./xlsx-formula-unsupported-boundary.md) | unsupported-formula fail-closed policy | `win` | `markitdown-mb` keeps blanks and records unsupported boundaries instead of placeholder values |
| XLSX | [xlsx_merged_cells_policy.xlsx](./xlsx-merged-cells-policy.md) | merged-cell top-left ownership | `win` | `markitdown-mb` keeps covered cells blank instead of injecting placeholder values |
| XLSX | [xlsx_typed_cells_matrix.xlsx](./xlsx-typed-cells.md) | typed-cell rendering | `win` | `markitdown-mb` keeps explicit error text and conservative boolean policy |
| HTML | [html_simple.html](./html-document-structure.md) | heading, paragraphs, list | `close` | outputs are structurally equivalent aside from bullet marker style |
| HTML | [html_table_ragged_links.html](./html-table-links.md) | table shape, ragged rows, inline links | `win` | `markitdown-mb` keeps the ragged trailing cell instead of shortening the row |
| HTML | [html_figure_figcaption_image.html](./html-figure-image-assets.md) | local image asset behavior, title, figcaption | `win` | `markitdown-mb` materializes local assets and keeps figure context explicit |
| HTML | [html_semantic_containers.html](./html-semantic-containers.md) | semantic wrapper passthrough | `close` | both preserve the useful body structure |
| HTML | [html_link_unsafe_javascript.html](./html-unsafe-link-boundary.md) | unsafe-link fail-closed boundary | `close` | both degrade dangerous hrefs to plain text on this overlap sample |
| ZIP | [zip_mixed_supported_entries.zip](./zip-mixed-supported.md) | nested dispatch, ordering, mixed supported entries | `win` | `markitdown-mb` keeps normalized entry ordering and structured JSON lowering |
| ZIP | [zip_duplicate_asset_names.zip](./zip-assets-remap.md) | nested HTML local-image remap and duplicate asset isolation | `win` | `markitdown-mb` materializes archive-namespaced assets instead of leaving raw entry-local refs |
| ZIP | [zip_path_traversal_boundary.zip](./zip-unsafe-path-boundary.md) | unsafe-path fail-closed policy | `not_comparable` | safety-boundary review only; do not count as a product-quality win |
| ZIP | [zip_unsupported_entries.zip](./zip-unsupported-entry-boundary.md) | unsupported-entry warning explainability | `win` | `markitdown-mb` explains degrade behavior instead of treating binary bytes as text |
| EPUB | [epub_spine_order.epub](./epub-spine-order.md) | spine-order aggregation and chapter boundaries | `win` | both preserve chapter order, but `markitdown-mb` keeps explicit archive-path boundaries |
| EPUB | [epub_nav_toc_basic.epub](./epub-nav-toc.md) | EPUB3 nav TOC extraction | `win` | `markitdown-mb` emits TOC structure while Microsoft MarkItDown keeps only the body |
| EPUB | [epub_cover_image.epub](./epub-assets-cover.md) | cover image asset export | `win` | `markitdown-mb` materializes the local cover asset and keeps body order explicit |
| EPUB | [epub_spine_unsupported_item_boundary.epub](./epub-unsupported-media-boundary.md) | unsupported spine media warning policy | `win` | `markitdown-mb` emits a clear warning block instead of leaking raw bytes as body text |
| EPUB | [epub_ncx_toc_basic.epub](./epub-ncx-toc.md) | NCX fallback TOC on the minimal-support subset | `win` | `markitdown-mb` emits the NCX TOC while Microsoft MarkItDown keeps only the body |
| CSV | [csv_ragged_rows.csv](./csv-ragged-rows.md) | ragged-row table retention | `win` | `markitdown-mb` preserves the extra column instead of truncating it |
| Markdown | [markdown_basic_heading_paragraph.md](./markdown-passthrough.md) | passthrough | `close` | identical structure on this sample |
| TXT | [txt_plain.txt](./txt-literal-safe.md) | literal-safe plain text | `close` | identical structure on this sample |
| TXT | [txt_markdown_like_literal.txt](./txt-markdown-like-literal.md) | literal-safe versus Markdown reinterpretation | `loss` | `markitdown-mb` preserves literal intent but collapses line structure |
| PDF | [heading_basic.pdf](./pdf-heading-structure.md) | heading retention and page-noise suppression | `win` | `markitdown-mb` restores heading structure and suppresses page residue |

Use [template.md](./template.md) for future additions.
