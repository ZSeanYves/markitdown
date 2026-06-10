# PDF v2 Convert Scaffold

`convert/pdf_v2` is an experimental convert package for the PDF v2 architecture
contract. It consumes `@pdfv2.PdfV2DocumentModel` from `doc_parse/pdf_v2`.

Boundaries for this scaffold:

- Convert does not read PDF paths, bytes, streams, or vendor objects.
- Convert does not rescan raw PDF input.
- Convert does not mutate the parser-owned model.
- Parser facts flow forward; Markdown and product policy stay in convert.
- `text_block_classifier` is represented as a convert-layer hint consumer.
- Deterministic rules, model hints, feature support, and risks cooperate
  through explicit gates.
- Low confidence behavior fails closed by abstaining or keeping text uncertain.
- No Python runtime, model file, DocLayNet data, `features.tsv`, `model.pkl`,
  quality-lab artifact, or old PDF fallback is used.

This phase intentionally provides contract-fast scaffolding only. Later phases
can lower to core IR once parser facts and policy gates stabilize.
