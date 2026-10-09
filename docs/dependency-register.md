# Dependency register

This register records the dependencies that remain after the text-only and
MoonX tooling migration. Exact package versions live in `moon.mod`; additions
must include a target matrix, license, resource-boundary, and removal review.

| Dependency | Decision | Boundary |
| --- | --- | --- |
| `moonbitlang/async` | retain | common async I/O, cancellation, and process boundary used by the façade and `.mbtx` tools |
| `moonbitlang/x` | retain only for imported core helpers | reevaluate each subpackage before adding another use |
| `moonbit-community/flate` | retain | DEFLATE codec adapter; ZIP path, CRC, traversal, and expansion budgets remain local |
| `horideicom/encoding_sjis` | retain | portable Shift_JIS/JIS X 0208 path; Native may extend the encoding boundary through FFI |
| `bikallem/compress` | removed | no production or transitive import remains |
| `bikallem/blit` | removed | no production or transitive import remains |
| `tonyfettes/encoding` | removed | core UTF contract and the reviewed portable codec cover current use |

Only the codec and encoding packages met the adoption gate: both compile for
Native and linear Wasm, have small adapters, preserve malformed-input and
resource checks, and remove real maintenance burden. XML, HTML, TOML, Markdown,
Office, and PDF candidates were retained as experiments because their AST
semantics, source positions, recovery policy, or resource behavior were not
equivalent enough for a safe thin adapter. Keeping a local implementation in
those areas is evidence-based scope control, not a package-count target.

The product has no Python, OCR/audio model, external converter, or installer
dependency. The only external data used by release validation is the pinned
`markitdown-quality-lab` checkout, consumed by the MoonX `.mbtx` manifests.
