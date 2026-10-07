# Dependency Register

This register is the Phase 0-1 source of truth for direct dependencies. A
registry download count is discovery information only; adoption requires the
tests, security, license and maintenance evidence described below.

## Current migration selection (2026-10-07)

The implementation is tracked in [Native/Wasm upgrade](./native-wasm-upgrade.md).
Exact latest registry records, licenses, dependency trees and archive checksums
are frozen in `tools/experiments/community/registry-2026-10-07.json`.

| Dependency | Production decision | Evidence and remaining gate |
| --- | --- | --- |
| `moonbitlang/async@0.22.4` | Upgrade; official shared I/O boundary | Six I/O tests on Native and Wasm; full product Native/Wasm suites; product async chain now wired through the shared façade |
| `moonbitlang/x@0.5.5` | Upgrade; retain used filesystem/base64/crypto APIs | Error and directory API migration; reevaluate filesystem imports after async migration |
| `moonbit-community/flate@0.8.5` | Provisional adoption, codec layer only | Cross-codec experiments and full product tests; retain local ZIP policy and reader; two RC dual runs and performance gates pending |
| `horideicom/encoding_sjis@0.1.1` | Provisional adoption, portable Shift_JIS/JIS X 0208 subset | Wasm source I/O covers ASCII, half-width, JIS X 0208, malformed/truncated bytes, and rejects CP932 FA-FC extension rows; full CP932 dual corpus and Linux RC gate pending |
| `bikallem/compress@0.3.4` | Remove | No product imports or transitive dependency remains; available in isolated comparison module |
| `bikallem/blit@0.2.2` | Remove | All direct and indirect callers eliminated by codec migration |
| `tonyfettes/encoding@0.3.9` | Remove | Only UTF-16 used; core preserves tested contracts; latest upstream package does not compile on selected compiler |

All four selected registry dependencies are Apache-2.0 and have no additional
Mooncakes dependencies. Official async has its own platform/runtime stubs;
this is a transitive native-runtime dependency, not a claim of zero C in the
native executable. Conversion still has local FFI pending the runtime migration.

The adoption record is provisional until the complete release-candidate gates
pass; focused tests are not release approval.

## Historical direct dependencies before this migration

| Package | Version | License | Observed local use | Decision | Required owner/evidence |
| --- | --- | --- | --- | --- | --- |
| `bikallem/blit` | 0.2.2 | Apache-2.0 | ZIP and compression; native byte/FFI support | retain, isolate | Runtime owner; bounds, ASan/UBSan, debug/release ABI |
| `bikallem/compress` | 0.3.4 | Apache-2.0 | DEFLATE, gzip, zlib and ZIP readers | retain | Format owner; truncation, bomb, fuzz, large-stream and differential tests |
| `moonbitlang/x` | 0.4.40 | Apache-2.0 | filesystem, base64, crypto and codec helpers | retain and upgrade deliberately | Core owner; API diff, target matrix and microbench; executable entrypoints must not use deprecated `x/sys` process shims |
| `moonbitlang/async` | 0.20.2 | Apache-2.0 | native command/process/filesystem adapters | retain behind runtime boundary | Runtime owner; no stable façade async types; cancellation/timeout/leak tests |
| `tonyfettes/encoding` | 0.3.9 | Apache-2.0 | source decoding, UTF/legacy encoding and PDF/text paths | retain | Encoding owner; all-target corpus and blocking new-native full-suite gate |

The frozen source resolved five direct declarations. `TheWaWaR/clap@0.2.6` and
`tonyfettes/unicode@0.3.0` were removed after confirming that no package imported
them and after the all-target and full native suites passed. Re-add either only
with an actual production import and the normal dependency review.

The `_moonbit_get_cli_args` new-native link failure was not an encoding codec
failure. Object-level inspection traced the symbol to the legacy
`moonbitlang/x/sys` argument shim linked into executable test runners. CLI and
benchmark entrypoints now use `moonbitlang/core/env`; explicit process exit is
isolated in `runtime/process` and the selected x/async versions are checked
independently. No Python or compatibility C bridge is needed by conversion.

## Optional Python/system dependencies

Python is a benchmark/build-only concern, not a product runtime. The formal
comparison environment is `Python 3.11` and
`tools/env/config/python/bench.lock`; its MarkItDown entry is pinned to `0.1.7`.
The only managed profile is `bench`, installed by
`tools/env/installers/install_bench_baseline_deps.sh`. OCR, audio,
scanned-page recognition, model downloads and system-tool installers were
removed in 0.8. The stable core works with no Python, system tools or model
files installed.

| Runtime | Managed version/lock | Profiles | Boundary |
| --- | --- | --- | --- |
| MarkItDown Python package | `python/bench.lock` (`0.1.7`) | bench only | pinned external oracle; never imported by MoonBit product |

Python transitive versions are authoritative in the benchmark lock file. The
oracle is never imported by the MoonBit product or used at conversion runtime.
Because that lock reproduces the upstream oracle distribution, it can still
contain transitive packages for upstream multimodal providers. Those entries
are benchmark-environment inputs only; they are not product capabilities,
installers, model downloads, or MoonBit runtime dependencies.

## Community candidates

The entries below record the Phase 0-1 assessment. The itemized production
decisions are in `tools/experiments/community/production-decisions-2026-10-07.json`.
For the current registry
versions, downloaded-source review, native probes, and a proposed text-only
product boundary, see the [2026-10-07 assessment](./rfcs/0001-text-extraction-scope-and-community-packages.md).
The RFC is the historical assessment; current production status and remaining
gates are recorded in the JSON decision file and the table above.

| Candidate | Current assessment | Action |
| --- | --- | --- |
| `horideicom/encoding_sjis` | portable Shift_JIS/JIS X 0208 decoder with replacement flag; no CP932 extension rows | adopted in `internal/readers/source_io` with strict adapter; Native iconv remains the extension path |
| `moonbit-community/yaml` | promising but maturity and exact API contract not established | shadow adapter only |
| `moonbit-community/html` | WHATWG-oriented claim, but adoption evidence is small | HTML corpus POC; no blind swap |
| `mizchi/markdown` | useful cross-platform implementation, but not a complete CommonMark/GFM replacement | keep local; use conformance suite first |
| `bobzhang/toml` | candidate parser | toml-test/error-span/performance POC |
| `Milky2018/xml` | pull-parser candidate; security/resource policy unverified | do not replace yet |
| `ivgtr/moonzip` | not equivalent to the local secure ZIP policy | do not replace |

Each candidate requires two release-candidate dual runs, semantic parity,
resource limits, sanitizer/fuzz evidence, license/NOTICE/SBOM review, a
maintainer response plan and a reversible adapter switch. A candidate that
fails one criterion remains a documented experiment, not a production
dependency.

## Upgrade protocol

1. Open one dependency PR with current/target versions and a lock diff.
2. Record upstream release, license, transitive tree, target support and known
   security issues.
3. Run affected package tests, all-target checks, Tier 1 native tests, contract
   corpus and benchmark delta.
4. Obtain code-owner and security/runtime approval when FFI or parsing changes.
5. Keep the old version available for one rollback release unless the change is
   a security emergency.
