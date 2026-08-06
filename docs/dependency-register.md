# Dependency Register

This register is the Phase 0-1 source of truth for direct dependencies. A
registry download count is discovery information only; adoption requires the
tests, security, license and maintenance evidence described below.

## Direct MoonBit dependencies

| Package | Version | Observed local use | Decision | Required owner/evidence |
| --- | --- | --- | --- | --- |
| `bikallem/blit` | 0.2.2 | ZIP and compression; native byte/FFI support | retain, isolate | Runtime owner; bounds, ASan/UBSan, debug/release ABI |
| `bikallem/compress` | 0.3.4 | DEFLATE, gzip, zlib and ZIP readers | retain | Format owner; truncation, bomb, fuzz, large-stream and differential tests |
| `moonbitlang/x` | 0.4.40 | filesystem, base64, crypto and codec helpers | retain and upgrade deliberately | Core owner; API diff, target matrix and microbench; executable entrypoints must not use deprecated `x/sys` process shims |
| `moonbitlang/async` | 0.20.2 | native command/process/filesystem adapters | retain behind runtime boundary | Runtime owner; no stable façade async types; cancellation/timeout/leak tests |
| `tonyfettes/encoding` | 0.3.9 | source decoding, UTF/legacy encoding and PDF/text paths | retain | Encoding owner; all-target corpus and blocking new-native full-suite gate |

`moon tree` now resolves five direct declarations. `TheWaWaR/clap@0.2.6` and
`tonyfettes/unicode@0.3.0` were removed after confirming that no package imported
them and after the all-target and full native suites passed. Re-add either only
with an actual production import and the normal dependency review.

The `_moonbit_get_cli_args` new-native link failure was not an encoding codec
failure. Object-level inspection traced the symbol to the legacy
`moonbitlang/x/sys` argument shim linked into executable test runners. CLI and
benchmark entrypoints now use `moonbitlang/core/env`; explicit process exit is
isolated in native-only `runtime/process`. This retains `x@0.4.40` without the
wide `x@0.4.48` filesystem error-API migration and makes the full new-native
suite pass without Python or a compatibility C bridge.

## Optional Python/system dependencies

Python is a benchmark/optional-runtime concern, not a core installation
requirement. The formal comparison environment is `Python 3.11` and
`tools/env/config/python/bench.lock`; its MarkItDown entry is pinned to `0.1.7`.
OCR, audio and accurate-PDF profiles use the existing managed installer and
fingerprint files. The stable core must continue to work with no Python,
Tesseract, FFmpeg, Poppler or model files installed.

| Runtime | Profiles | Boundary |
| --- | --- | --- |
| Tesseract | balance OCR | explicit capability probe; bounded input/output |
| FFmpeg + Vosk wrapper | audio | direct argv, timeout, output cap and process-group cleanup |
| Poppler `pdftoppm` + PaddleOCR | accurate PDF | optional route; model fingerprint and deterministic failure |
| MarkItDown Python package | bench only | pinned external oracle; never imported by MoonBit product |

## Community candidates

| Candidate | Current assessment | Action |
| --- | --- | --- |
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
