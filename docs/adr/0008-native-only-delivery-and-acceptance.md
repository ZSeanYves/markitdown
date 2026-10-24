# ADR 0008: Native-only delivery and staged acceptance

- Status: accepted decision; implementation and acceptance remain incomplete
- Date: 2026-10-23
- Owners: @ZSeanYves
- Supersedes: ADR 0006's Wasm baseline and delivery targets; ADR 0007's sole
  published-MoonX acceptance path

## Context

The product needs reliable text-conversion quality with measurable Native
latency, memory and installation costs. Existing source checks, package smoke
results and historical cross-target timings do not establish the complete
quality, resource or performance contract. The user-approved plan fixes the
product scope and separates implementation from release acceptance.

## Decision

Support Linux x86_64 and macOS arm64 with Native as the default and only
product backend. Retire Wasm, Wasm-GC and JavaScript product distribution and
compatibility branches. Deliver the CLI with `moon install` and the library
through `ZSeanYves/markitdown/lib`; this cycle does not add separate prebuilt
download packages.

Keep the thin root `main.mbt`, public `lib` and private `internal` split.
Preserve the asynchronous façade, existing input constructors and façade-owned
types. The target is one async input/Registry/pull/Sink execution protocol
with explicit resource ownership, cancellation and cumulative budgets.
Existing synchronous adapters and buffering do not establish that target's
completion.

Keep text, Office/ODF semantics, PDF text/geometry, image assets, sources,
Markdown/Debug/RAG and existing mode meanings. OCR, scanned-page recognition,
audio transcription, rendering engines and formula recalculation remain out
of scope. Retain small FFI only with a recorded necessity, ownership,
transitive dependencies and removal condition. Do not introduce a second
PDF conversion chain or global user-document cache.

All automation remains `.mbtx`. Scripts may use the toolchain's script
runtime, but product acceptance runs actual Native artifacts. Local source,
fixed Git commit and exact published-version installation are distinct lanes;
one cannot substitute for another. Historical MoonX package runners and fake
runners do not establish Native product or publication acceptance.

## Acceptance and consequences

Quality is a prerequisite for performance. Execute all valid contracts,
including reference-tagged rows, with explicit expected-error behavior.
Separate output channels and validate RAG structure, sources and assets.
Freeze corpus/source/dependency/toolchain/executable/machine fingerprints and
preserve existing external-corpus work.

The plan's P0–P6 exit conditions remain independent. P1 manifests, local
installation, a public-consumer smoke or passing unit tests do not complete
P2 execution/budgets, P3 format migrations, P4 PDF optimization, P5 full RC or
P6 post-publication confirmation. Current implementation evidence must be
recorded as evidence for the specific work executed.

Formal performance requires two independent windows, each with 3 warmups and
30 interleaved measurements per group, complete quality equivalence and
per-case latency/RSS checks. The PDF targets are at least 50% lower latency
and 30% lower peak RSS; they are not measured achievements. Both platforms
also require the 60-minute reliability and 1/2/4-process deployment checks.
Unavailable tooling or incomplete measurements remain unaccepted.

These decisions supersede ADR 0006/0007 only for product targets, delivery and
acceptance policy. Their text-only scope, shared semantics, async direction
and format/mode contracts continue where consistent with this decision.
Historical records remain unchanged apart from supersession pointers.

## Verification and rollback

Use the Native source checks in [Contributing](../../CONTRIBUTING.md) and
the [installation/regression tools](../../tools/regression/README.md).
Save command/status/output fingerprints and review semantic differences.

Keep previous source and real Native binaries as frozen rollback artifacts;
do not keep parallel legacy production paths. Publication is a separate
action. Before P5 completion, do not claim candidate acceptance; before
exact-version P6 confirmation, do not claim formal delivery.
