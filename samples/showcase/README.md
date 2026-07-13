# Core Conversion Showcase

This directory contains one substantive example for every core balanced input
extension. Unlike `samples/fixtures/`, these are not unit-test probes: they are
complete standards, public datasets, project documentation, books, notebooks,
or multi-page Office documents selected to show the main conversion path.

The set contains 27 inputs and stays below the 15 MiB repository budget. The
largest input is below 1 MiB. Notable document breadth:

- DVLA DOCX: 4 pages
- NHS PPTX and derived ODP: 15 slides each
- ONS XLSX: 8 sheets; derived USGS ODS: 2 sheets
- Alice EPUB: 15 spine items
- NIST SP 800-207 PDF: 59 pages
- RFC 3986 TXT/ODT and WCAG HTML: complete standards text

`MANIFEST.tsv` is the authority for source URLs, SHA-256 values, licenses,
derivations, and review status. Every format keeps its own local legal evidence
under `<format>/licenses/`, beside the input and result. `build_derived.py`
reproducibly creates format-equivalent examples from the reviewed source files;
derived files are never represented as upstream bytes.

Each format directory contains its checked-in release balance conversion as
`result.md`, beside the source input. Exported assets and controlled diagnostics
are kept in that same directory. `RESULTS.tsv` records result hashes, sizes,
asset counts, and diagnostic counts. Regenerate them after building the release
CLI:

```bash
python3 samples/showcase/generate_results.py
```

Build and try the release CLI:

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
./_build/native/release/build/cli/cli.exe balance \
  samples/showcase/pdf/nist-zero-trust-architecture.pdf \
  .tmp/showcase/nist.md
```

Run the evidence and conversion audit:

```bash
python3 samples/showcase/audit.py
```

The audit verifies repository evidence; it is not legal advice. Dynamic USGS
and UniProt inputs are dated snapshots, not freshness claims. Project Gutenberg
notices embedded in the book files must remain intact.
