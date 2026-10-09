# Compatibility matrix

Compatibility is measured against the text-only public contract through the
same MoonX package consumer used by release acceptance. The source checkout is
checked independently by MoonBit tests; it is never used as a substitute for a
published package run.

| Surface | Wasm | Native | Evidence |
| --- | --- | --- | --- |
| Text, structured data, markup, mail, ZIP, EPUB | shared | shared | `run_moonx_regression.mbtx --suite main` |
| Office and ODF balance | shared | shared | main and quality manifests |
| Office and ODF accurate semantics | shared | shared plus declared extensions | `--suite accurate` |
| Text-layer PDF | shared | shared plus declared extensions | PDF rows in quality/accurate manifests |
| Debug, RAG, provenance, assets | shared | shared | manifest signals and output views |
| OCR, audio, scanned-page recognition | unsupported | unsupported | explicit capability/error contract |

Every shared row must agree on content, structure, assets, source references,
and diagnostics. Backend identity and timing may differ. Native extensions may
only add a declared capability; disabling them must leave all shared rows
passing. Missing registry assets, missing outputs, parser errors, and resource
limit violations fail closed.

Run the matrix after publication:

```text
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@<exact-version> --target wasm --suite all
moonx tools/regression/run_moonx_regression.mbtx ZSeanYves/markitdown@<exact-version> --target native --suite all
```

The quality-lab revision and the two target summaries are the compatibility
evidence. No Python oracle, shell wrapper, local prebuilt, or alternate parser
is part of the acceptance path.
