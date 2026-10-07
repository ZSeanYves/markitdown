# ADR 0006: One asynchronous text runtime for Wasm and Native

- Status: accepted for implementation, 2026-10-07
- Supersedes: ADR 0002's synchronous/native-only API and the multimodal scope
- Implementation status: tracked in `../native-wasm-upgrade.md`; acceptance is
  not a claim that implementation or release validation has completed

## Decision

The unreleased 0.8 API will use one asynchronous conversion pipeline and one
parser registry for linear-memory Wasm and Native. Pure parsing, semantic
lowering, IR, Markdown/debug/RAG output, assets, and source mapping remain
shared. Reader, pull-stream advancement, and sink operations can suspend.
There will be no second synchronous conversion engine or backend-specific
copy of format semantics. Caller-owned readers remain caller-owned.

Wasm must cover the existing text-format common contract before this upgrade
is complete, including Office, ODF, EPUB, MIME, ZIP, and PDF text layers.
Native is a capability superset and may add small private FFI extensions.
Both backends use the portable implementation for their common capabilities.
Parse, integrity, encoding-validation and resource-limit failures never trigger
a more permissive provider. Common I/O uses official runtime libraries where
the existing contract can be retained; whole-file buffering is not an
acceptable replacement for bounded random access or pull streaming.

Remove OCR, audio transcription, scan recognition, their public options and
runtime/model installers. Keep document images as assets, subtitle timing,
PDF geometry, and Office/ODF accurate semantics. Removed flags fail explicitly.

The module root will be the moonx executable entrypoint and delegate to the
single CLI implementation. One capability registry drives dispatch, the public
API, CLI reporting and documentation. Independent Native binaries and default
moonx/Wasm are the primary delivery paths; deprecated moonx/Native is tested
separately while available.

## Dependency policy

Inventory actual direct and transitive uses before deciding to remove,
upgrade, replace or retain a dependency. Refresh the stable toolchain and
registry at the start, freeze exact versions and checksums, and isolate
toolchain changes from dependency and parser changes.

Test candidates outside the product dependency graph before adoption.
Adapters may map data, errors, locations, budgets and product semantics;
they must not reimplement a missing parser or maintain a private upstream fork.
Reject candidates without demonstrated contract preservation and maintenance,
correctness or performance value. Python-only build steps are acceptable when
reproducible and useful; Python is not a conversion runtime dependency.
Adoption must not depend on upstream accepting changes for this project.

## Verification and rollback

Keep existing text regression, source/asset, resource, coverage, fuzz,
sanitizer and performance gates. Compare old/new implementations and both
backends using frozen fixtures; zero tests or missing mandatory cases cannot
pass. Preserve the 10% time/RSS self-baseline limit for comparable fingerprints.
Establish separate Wasm evidence and record compiler changes independently.

Each adopted dependency needs two candidate validation rounds, explicit
semantic differences, license/transitive/build evidence and a recoverable
version. Frozen old source and binaries are comparison/rollback artifacts;
production does not retain parallel old/new execution paths. Required platform
coverage remains Linux x86_64 and macOS arm64. Publishing is a separate step.
