# Community package experiments

The registry snapshot and production decisions in this directory are frozen
inputs to the 0.8 migration. A package is not promoted because it builds: the
experiment must preserve the product's semantic output, source/provenance
fields, resource limits, and failure classification with a thin adapter.

## Reproduce the adopted codec probes

Run each target separately because MoonBit's build lock serializes the working
tree:

```bash
moon run tools/experiments/community/run_codec.mbtx "$PWD" native
moon run tools/experiments/community/run_codec.mbtx "$PWD" wasm
moon run tools/experiments/community/run_encoding.mbtx "$PWD" native
moon run tools/experiments/community/run_encoding.mbtx "$PWD" wasm
```

The probe compares the old `bikallem/compress` implementation with
`moonbit-community/flate@0.8.5` for raw DEFLATE and zlib, then checks
incremental input, bounded output, trailing data, truncation and CRC. It is a
codec experiment; it does not replace the local ZIP path, collision checks,
CRC policy, or decompression budgets.

The product adapter uses `horideicom/encoding_sjis@0.1.1` only for the
portable Shift_JIS/JIS X 0208 subset. Replacement output is rejected. CP932
Microsoft extension rows (for example `FA 40`) remain a Native-only iconv
extension until a complete portable corpus and two Native/Wasm dual runs prove
parity. `run_encoding.mbtx` covers the same representative corpus and the
package's split-character streaming API on each backend. The product source
I/O tests additionally cover malformed and truncated sequences and the
explicit extension boundary.

## Candidate decisions

`production-decisions-2026-10-07.json` records the current adopted subset and
the candidates that remain deferred. XML, HTML, TOML, Markdown, Office and PDF
packages were not forced into the product because their current APIs lose
source locations, assets, notes, cached values, error policy, or portable
resource control. A deferred candidate may be reconsidered only with a new
isolated probe and the same dual-run evidence; it is not a hidden runtime
fallback.

The records intentionally distinguish local macOS evidence from the Linux RC
gate. Registry exact-version consumer validation remains a post-publication
step and cannot be satisfied by a local cache or `.mbtx` run.
