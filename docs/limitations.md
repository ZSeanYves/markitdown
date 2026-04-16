# Known Limitations

## General

* The project focuses on structured Markdown output rather than full visual reproduction
* Complex layout recovery remains strongly format-dependent
* Some advanced semantics are still conservatively downgraded into readable paragraph order
* Current origin metadata is lightweight provenance only, not precise anchoring (no bbox / char range / source object id)

## PDF

* OCR remains a dedicated plugin-style path rather than the default `normal` flow
* The normal PDF path on `main` has already been fully replaced by native recovery, but it is not yet a full layout-semantic reconstruction system
* More complex multi-column, mixed graphic-text, and extreme layout cases remain active areas of improvement
* Some extreme pseudo two-column or extractor-level anomaly cases may still lose information before later recovery stages

## PPTX

* table-like regions are currently stabilized mainly at the reading-order / grouping level
* not all high-confidence grid-like regions are upgraded into richer table semantics
* negative layouts are often conservatively preserved as readable ordered paragraphs
* image-to-caption matching remains conservative; ambiguous multi-image/multi-caption scenes are intentionally left unmatched

## HTML

* the parser is intentionally lightweight
* there is no browser-grade rendering model
* complex deeply nested semantic containers are still handled conservatively
* remote images are not force-exported as local assets

## PDF image context

* image context remains lightweight and conservative
* nearby caption attachment is currently only attempted for single-image + single high-confidence caption-like cases
* no precise bbox graph matching between images and text blocks yet

## XLSX

* no formula evaluation
* merged cells are not yet reconstructed as richer semantic structures

## DOCX

* quote-like / code-like detection still depends partly on conservative heuristics
* non-standard or multilingual style naming may reduce structural precision
