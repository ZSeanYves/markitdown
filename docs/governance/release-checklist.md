# Native release checklist

Use this checklist for the unreleased 0.8 candidate. The
[Native plan](../architecture/native-performance-plan.md) is the acceptance
authority. Items stay open until their saved evidence is reviewed; local
correctness results alone do not close P2–P6.

## P0 and source identity

- [ ] Freeze source revision/dirty state, rollback source/binary, dependencies,
  toolchain, machine and corpus hashes; preserve existing quality-lab changes.
- [ ] Validate all requested manifests before filtering: missing files,
  duplicate IDs, unknown signals, malformed rows and zero cases fail.
- [ ] Run every valid main/quality/accurate contract, including `reference`
  rows and explicit expected-error contracts.
- [ ] Version, migration guide, capabilities, interfaces and documentation agree.
- [ ] Dependency/FFI changes have necessity, ownership, license and removal evidence.

## P1 Native delivery

- [ ] Pin MoonBit `0.1.20261021` / `moonc v0.10.17+093cb8f9c`.
- [ ] Linux x86_64 and macOS arm64 Native check, interfaces, formatting,
  debug/release tests and builds pass.
- [ ] Local and fixed full-Git-revision installations pass from fresh
  directories; their evidence is kept distinct.
- [ ] Independent Native consumers import only the public `lib` façade and
  resolve the intended candidate source.
- [ ] Product Wasm/JavaScript branches and unused dependencies are removed.

## P2–P4 implementation and quality

- [ ] One async input/Registry/pull/Sink execution protocol and public Sink API
  satisfy their interface and backpressure contracts.
- [ ] Normal completion, cancellation and I/O/write failures release owned
  files, caches and temporary data deterministically.
- [ ] Encoding/scalar, ZIP/CRC/cache, decompression, cumulative parsing,
  output, source/asset/RAG metadata and temporary-storage budgets are verified.
- [ ] XML and format migrations preserve all promised semantics and sources.
- [ ] PDF has lightweight reusable probing, on-demand objects, bounded decode,
  single interpretation/text decode, document caches and page lifetimes.
- [ ] PDF geometry, CJK/vertical text, ActualText, links, tables and assets pass
  per-file contracts and mandatory hard cases.
- [ ] Golden changes are explained and reviewed; no content or integrity check
  is removed for speed.

## P5 full RC

- [ ] Full daily/showcase and corpus regressions pass with zero new quality failures.
- [ ] Two independent performance windows each contain 3 warmups and
  30 interleaved baseline/candidate measurements per group.
- [ ] Per-case latency/RSS stay within 10% for comparable fingerprints;
  PDF targets and any unmet targets are reported honestly.
- [ ] Startup, single-file, batch, library, first-output, CPU, RSS, throughput,
  installation size and machine/compiler fingerprints are recorded.
- [ ] Both platforms complete 60-minute mixed loads and 1/2/4 independent
  conversion processes without growing RSS/FD/temp-file retention.
- [ ] Applicable interface, coverage, mutation, sanitizer and fuzz checks pass;
  unavailable gates are explicitly unaccepted.
- [ ] Complete success/failure summaries, logs and rollback instructions are attached.

## P6 post-publication confirmation

- [ ] Publication was separately authorized and executed.
- [ ] Exact-version `moon install` succeeds from a fresh destination.
- [ ] A fresh independent registry consumer resolves that exact version
  without local overrides.
- [ ] Published package contents/hashes agree with the accepted candidate.
- [ ] The Native consumer workflow confirms both supported platforms.

Do not replace a failed publication lane with a local binary. Before P5
completion, do not claim candidate acceptance. Before P6 completion, do not
claim formal delivery.
