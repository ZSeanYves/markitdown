# Known Limitations

## General

* The project focuses on structured Markdown output rather than full visual reproduction
* Complex layout recovery remains format-dependent
* Some advanced semantics are still conservatively downgraded to readable paragraph order

## PDF

* `main` currently uses an external text-first pipeline
* OCR is a dedicated path, not the default normal flow
* more complex layouts still depend mainly on heuristic post-processing
* the main path is not yet based on a full event -> line -> block native recovery chain

## PPTX

* table-like regions are currently stabilized mainly as reading-order / grouping problems
* not all high-confidence grid-like regions are upgraded into richer table semantics
* negative layouts are often conservatively preserved as readable ordered paragraphs

## HTML

* the parser is intentionally lightweight
* no browser-grade rendering model
* complex deeply nested semantic containers are handled conservatively

## XLSX

* no formula evaluation
* merged cells are not yet reconstructed as richer semantic structures

## DOCX

* quote-like / code-like detection still depends partly on conservative heuristics
* non-standard or multilingual style naming may reduce structural precision
