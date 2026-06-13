# PDF v2 Reset 17K Header/Footer Evidence Audit

## Scope

Reset 17K was explicitly re-narrowed to header/footer repetition evidence.

Allowed scope in this reset:

- repeated header/footer typed evidence
- repeated-edge and numbered/page-variant evidence threading
- repeated-artifact attachment/suppression refinement
- false-positive guards for repeated body text and real section headings
- removal of the over-scoped edge-artifact heading/body split path

Out of scope in this reset:

- heading/title patches for `#` / `##` recovery
- broad heading classification rewrites
- normalizer string patches
- sample-name or phrase-specific suppression
- cross-page, image, or column behavior changes
- sample expected updates

## V1 Intent Reused / Rejected

Reused from the earlier v1 direction:

- repeated header/footer cleanup should be backed by typed repeated evidence
- numbered or page-variant header/footer forms should normalize to a stable typed key
- real body content should only be suppressed when repeated-edge evidence is strong and unblocked

Rejected from the earlier v1 direction:

- no phrase-specific suppression
- no normalizer patching
- no sample-specific logic
- no opportunistic heading/title repair to force parity on `pdf_header_footer_variants_phase15`

## Typed Evidence / Fact Changes

`PdfV2PageArtifactCandidate` now carries explicit repeated-edge evidence fields:

- `normalized_key`
- `raw_text_variants`
- `page_coverage_ratio`
- `first_page_index`
- `last_page_index`
- `page_number_like`
- `numbered_variant`
- `real_heading_risk`
- `table_header_body_risk`
- `blockers`

Repeated header/footer candidates now:

- normalize numbered/page variants through a typed variant key
- record repeated-edge evidence and page-number support separately
- gate product attachment on confidence plus zero blockers
- stay audit-only when `real_heading_risk` or other blockers remain

`PdfV2HeaderFooterVariantFact` now mirrors the typed repeated-edge evidence:

- `raw_text_variants`
- `first_page_index`
- `last_page_index`
- `page_number_like`
- `numbered_variant`
- `real_heading_risk`
- `blockers`

## False-Positive Guards

17K keeps repeated body content and real section headings out of suppressible noise when evidence is unsafe.

Guards now cover:

- repeated body titles/content in body position do not become repeated artifacts
- repeated top-edge section titles with real heading risk stay audit-only
- caption-like/table-like content does not become product-noise suppression
- numbered/page variants require typed repeated-edge support instead of raw string matching

## Product Output Status

Visible product behavior changed for header/footer artifact handling:

- repeated header/footer noise in `pdf_header_footer_variants_phase15` is suppressed
- numbered/page-variant edge evidence is typed and attached through repeated-edge facts
- body heading text and body paragraph text remain present

No sample expected files were changed in 17K.

## `pdf_header_footer_variants_phase15` Current Status

Current real output after 17K:

- repeated header/footer noise is suppressed
- body heading / real content is preserved
- `#` / `##` heading level still does not match expected
- page 3 still keeps heading text and body text in one line after artifact removal

This remaining mismatch is recorded as:

`non-17K residual: heading/title evidence or heading-level arbitration`

17K intentionally does not patch that residual because current heading recovery would require heading/title ownership, not header/footer repetition evidence.

## Failure Taxonomy

The repo-local 10-failure taxonomy did not change in 17K.

`pdf_header_footer_variants_phase15` remains in the header/footer bucket, but its remaining visible diff is now a heading/title residual rather than unsuppressed repeated header/footer noise.

The sample-check wrapper may still report `rows=0`; the run's `markdown-only.entrypoint.log` remains the authoritative source.
