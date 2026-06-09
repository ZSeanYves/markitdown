# PDF v2 Convert Scaffold

Status: experimental scaffold.

This package lowers parser-owned `PdfV2DocumentModel` facts from
`doc_parse/pdf_v2`. It does not read raw PDFs, does not call the old PDF
runtime, does not load external model files, and does not mutate parser-owned
model records.

Current scope:

- block classifier gate placeholder
- fail-closed decision shape
- experimental dispatcher entrypoint for PDF v2
- conservative core IR adapter over v2 lowering output
- feature/report contract placeholders

The public `parse_pdf_v2` entry is wired for dispatcher adoption. It scans input
bytes once through the PDF v2 core scaffold, then routes through source events,
text reconstruction, normalized model, layout recovery, feature export,
classifier gate, and lowering. The current reader is still scaffold-only, so
empty extraction returns a diagnostic core document instead of falling back to
the old PDF runtime.
