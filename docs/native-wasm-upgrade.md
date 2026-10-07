# Native/Wasm text runtime upgrade

Accepted scope: [ADR 0006](./adr/0006-shared-text-runtime.md).
Candidate research: [RFC 0001](./rfcs/0001-text-extraction-scope-and-community-packages.md).

## Frozen starting point

- Source commit: `6e7a7a2988407d4757d5247049cff4463ec61bf8`.
- Module: unpublished `ZSeanYves/markitdown@0.8.0`.
- Implementation branch: `codex/shared-native-wasm`.
- Local source archive: `.audit/2026-10-07-upgrade/baseline/source.tar`.
- Archive SHA-256: `feeb29e9e96a1c98ee4910fd556642b0109d71805e9d74d980d7c791a6799388`.
- The pre-existing work consists of the community assessment and its documentation links.
- Official stable endpoint `https://cli.moonbitlang.com/version.json`, checked
  2026-10-07: moon/moonrun `0.1.20260920 (914d7da)`, moonc
  `v0.10.14+7d59c7ec9`. Installed tools match. The repository pin has been
  upgraded from `0.1.20260803` / `v0.10.6+80dc50f24` with the compatibility
  changes and validation below.

The first baseline test attempt failed before compilation because downloading
`bikallem/compress@0.3.4` timed out. The published archive and `x@0.4.40` were
downloaded with curl, verified against registry SHA-256, and installed in the
source archive cache. This transport recovery changes no dependency version.
The retry and its compiler diagnostics are recorded separately.

The retry reached compilation and failed on the removed `typealias` syntax in
`tonyfettes/encoding@0.3.9`, also its latest registry version. This is not a
passing historical baseline. Attempts to retrieve the old pinned toolchain
from the official archive returned HTTP 403; no global installation was changed.

## Foundation implementation evidence

- Replaced the actual UTF-16-only uses of `tonyfettes/encoding` with core UTF-16,
  preserving explicit endian order, BOM ownership and strict malformed-input
  rejection. RAG byte representation is unchanged.
- Replaced raw DEFLATE, zlib and CRC with `moonbit-community/flate@0.8.5`.
  The project's ZIP container/parser, path validation, lazy reads, integrity
  checks and budgets remain in charge. ZIP inflation uses bounded output
  buffers, detects trailing compressed chunks and enforces the convenience
  decoder's output budget during inflation.
- Removed both direct and transitive `bikallem/blit` and `bikallem/compress`;
  `moon tree` resolves exactly flate 0.8.5, async 0.22.4 and x 0.5.5, with no
  further Mooncakes dependencies.
- Upgraded x and async separately from codec integration. The x migration
  handles its filesystem error's removal of implicit Show and its directory
  result changing to ArrayView. Product API types do not expose those errors.
- Isolated codec experiments: 6/6 on Native and 6/6 on linear Wasm; includes
  old/new cross-decoding, malformed UTF-16, the BMP corpus, incremental chunks,
  output ceilings, trailing/truncated DEFLATE and known CRC.
- Isolated official I/O experiments: 6/6 on each backend; random reads and EOF,
  readonly write failure, sync/rename, cancellation cleanup, suspending short
  readers and pull/sink backpressure. These do not claim the product's async
  migration has already happened.
- Product Native suites: 914/914 after UTF-16; 914/914 after flate; 917/917
  after x/async upgrades and three new ZIP boundary tests. No snapshots were
  updated to obtain these results. Logs: `.audit/2026-10-07-upgrade/`.
- This is correctness evidence on macOS arm64, not performance or Linux RC
  acceptance. Full governance and release gates are still pending.

Tracked probe sources and the exact latest registry records/checksums are in
`tools/experiments/community/`. Run `run_codec.mbtx` or `run_runtime.mbtx` with
the repository's absolute path and `native`/`wasm`; expected counts are six
tests per probe and target. Zero tests is a failure.

## Delivery state

| Stage | State | Required exit evidence |
| --- | --- | --- |
| P0 baseline | In progress | Source, dependency, text contract and runtime fingerprints; baseline failures classified |
| P1 experiments | In progress | Official I/O, compression, encoding and candidate decisions with exact versions |
| P2 text scope | Not started | OCR/audio removed and remaining Native text contracts pass |
| P3 one runtime | Not started | One async registry/reader/pull/sink, common I/O and root entrypoint |
| P4 all text formats | Not started | Wasm common corpus and Native superset pass |
| P5 adoption | Not started | Each selected adapter has two validation rounds and a rollback |
| P6 release candidate | Not started | Platform, performance, artifacts and precise-version consumer evidence |

No stage is completed by a help-only smoke test or by changing expected output
to match an unexplained result. Historical evidence and intentional retired
multimodal cases remain distinguishable from new passing text evidence.
