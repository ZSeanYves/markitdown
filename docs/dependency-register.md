# Dependency register

The current product is Native-only. Direct runtime dependencies are pinned
in `moon.mod`; each evidence run must also save the resolved tree and hashes.
Toolchain changes are measured separately from dependency or parser changes.

| Dependency | Current decision | License declared by package | Boundary |
| --- | --- | --- | --- |
| `moonbitlang/async@0.22.4` | Retain | Apache-2.0 | Async I/O, cancellation, stdio and script/process orchestration |
| `moonbitlang/x@0.5.5` | Retain only imported helpers | Apache-2.0 | Filesystem, process exit and validation-tool hashing helpers |
| `moonbit-community/flate@0.8.5` | Retain for remaining consumers | Apache-2.0 | Checksums, zlib error taxonomy, immutable PDF table initialization and test encoder/oracle; user ZIP/PDF Flate uses the reviewed subset/adapter below |
| `internal/inflate` | Vendored streaming decoder subset | Apache-2.0 | Five upstream files/blocks at `3cbcb5c8bde0b34117fd7980b9f41719f2b8f3d7`; ZIP incremental decode and produced-byte accounting on codec failure |
| `horideicom/encoding_sjis@0.1.1` | Removed from product | Historical dependency | Wasm-only adapter removed; Native CP932 uses host iconv |
| `bikallem/compress`, `bikallem/blit` | Removed | Historical dependencies | Not current production imports |
| `tonyfettes/encoding` | Removed | Historical dependency | Current UTF handling uses core encoding APIs |

The three retained external package versions and licenses above are recorded in the
local dependency manifests. Verify the resolved tree rather than inferring
transitive absence from this table:

```text
moon tree
moon tree --target native --package
```

Official async/filesystem packages bring Native host bindings. The project
also retains small libc/POSIX and iconv stubs; necessity, ownership,
transitive host requirements and removal conditions are in the
[FFI inventory](ffi-inventory.md). There is no PDFium/Poppler, external
converter, Python, OCR or audio-model runtime dependency.

## Algorithm and experiment policy

XML, HTML, Markdown, structured-text, Office and PDF candidates remain
separate experiments unless a specific reviewed adoption is documented.
Experiment success is not production integration or format compatibility.
Record exact source/revision, license, imported fragments, semantics,
resource behavior and validation before copying an algorithm or adding a
runtime dependency. Do not maintain a second production conversion chain.

External libraries may provide algorithm references, corpus material or
offline differential oracles. Those roles do not imply a product runtime
dependency. Preserve the independent quality-lab checkout and existing user
changes; its manifest/hash audit is distinct from executing product cases.

The streaming decoder's exact revision, upstream hashes, selected line ranges,
license and modification are recorded in
[`internal/inflate/UPSTREAM.md`](../internal/inflate/UPSTREAM.md). `LICENSE` and
`NOTICE` ship with the package. The local change preserves consumed/produced
counters when a step raises after writing scratch output. ZIP charges those
produced bytes before returning the codec error; failed output is never
delivered. Normal output/status/count behavior is checked against the pinned
external implementation. This does not establish PDF decode budget coverage
or a performance gain.

The PDF reader now adapts pinned RFC1950 framing around that same streaming
engine. Exact fragments, blob/SHA, license and modifications are recorded in
[`internal/readers/pdf/UPSTREAM.md`](../internal/readers/pdf/UPSTREAM.md) and
its `NOTICE`. User content/CMap/font/object/image Flate streams share budget
accounting and hard integrity propagation. Other PDF filters and allocations
are not thereby covered. Static compiled-in table initialization keeps its
separate existing path.

P2 cumulative budget/lifetime work, P3 parser migrations, P4 PDF optimization,
P5 full RC and P6 post-publication checks remain incomplete under the
[Native plan](architecture/native-performance-plan.md). This dependency
inventory does not certify those gates or installation-size acceptance.
