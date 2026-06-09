# PDF v2 Lowering

Status: experimental RESET-9 scaffold.

This package owns the conservative convert lowering boundary for PDF v2. It
consumes only:

- `@normalized_model.PdfV2DocumentModel`
- `@feature_export.PdfV2BlockFeatureRecord`
- `@classifier_gate.PdfV2BlockDecision`

It does not read raw PDF bytes, does not call the old `doc_parse/pdf` parser,
does not call the old `convert/pdf` runtime, does not load TSV/model files, and
does not mutate parser-owned model, feature, or classifier decision records.

The default policy is fail-closed:

- abstain, uncertain, missing decision, or low confidence stays `text`
- parser risks suppress semantic lowering by default
- headings require an accepted decision and `min_heading_confidence`
- list items require an accepted decision, `min_list_confidence`, and marker
  evidence
- captions lower only to `caption_text`; they are not bound to images here
- tables stay plain text unless table-region evidence is strong
- noise is suppressed only with high confidence and explicit evidence

Images, forms, annotations, and unsupported vectors are represented as
conservative placeholders from parser facts. This layer does not export real
image assets, reparse annotations, traverse AcroForm data, switch the
dispatcher, or emit the final Markdown/core IR product. Later milestones can
connect this lowering result to core IR, Markdown policy, assets, samples, and
runtime adoption gates after the contract is proven.
