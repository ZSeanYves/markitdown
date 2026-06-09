# PDF v2 Classifier Gate Scaffold

Status: experimental RESET-8 scaffold.

This package consumes parser-produced
`doc_parse/pdf_v2/feature_export.PdfV2BlockFeatureRecord` values and builds
convert-local block decision candidates with confidence, trace, warnings, risks,
and reason tags.

Scope:

- features-only input from parser-owned feature export
- deterministic constraints, optional model hints, weak heuristics, and abstain
- fail-closed defaults
- diagnostics-only consumption of parser warnings/risks
- one-pass/no-fallback policy carried as a convert contract

Non-goals:

- no PDF raw reads
- no old `doc_parse/pdf` or `convert/pdf` calls
- no vendored parser calls
- no external repository, TSV, pickle, model, or local corpus reads
- no model training or feature-data generation
- no Markdown/IR lowering
- no mutation of parser facts

Candidate facts remain evidence-only. This scaffold emits convert-local
candidate decisions and traces; it does not write final semantic labels back to
the parser model.
