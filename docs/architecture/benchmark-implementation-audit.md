# Benchmark Implementation Audit

Note: this audit documents the v1-era implementation that has now been removed
from the formal benchmark path. The findings remain useful as migration input
for `bench v2` diagnostic providers, but `bench/pipeline`, `bench/product`, and
`bench/micro` are no longer official entrypoints.

## 0. Purpose

This document audits the current benchmark implementation against
`docs/architecture/benchmark-architecture.md`.

It is intentionally separate from the architecture document:

1. the architecture document defines the contract
2. this document records current compliance, gaps, and risks

The goal is to give later optimization work a trustworthy baseline: before
optimizing hot paths, we need to know whether benchmark numbers are measuring the
intended product route.

## 1. What Is Already Aligned

The current benchmark system already gets several important things right.

### 1.1 Official compare fairness

`bench/runner` already implements the fairness and provenance rules introduced in
the benchmark redesign:

- row-major compare scheduling
- warmup count serialization
- measurement-policy serialization
- runner and machine provenance
- per-format and overall geomean reporting

Evidence:

- `bench/runner/process/process_runner.mbt`
- `bench/runner/result/cli_result.mbt`
- `bench/runner/result/summary.mbt`

### 1.2 Full-path product measurement exists

`bench/pipeline/convert_pipeline_bench_test.mbt` measures `@convert.convert_input`
directly for smoke rows and official-gate rows. This remains the cleanest
in-process product-path benchmark.

### 1.3 Several route-sensitive stage suites were corrected

The following stage suites now use canonical route probing and preserve the
product-emitted `IRInput` shape through pipeline and render:

- `bench/pipeline/markdown_stage_bench_test.mbt`
- `bench/pipeline/html_stage_bench_test.mbt`
- `bench/pipeline/json_stage_bench_test.mbt`
- `bench/pipeline/yaml_stage_bench_test.mbt`
- `bench/pipeline/xml_stage_bench_test.mbt`
- `bench/pipeline/textlike_stage_bench_test.mbt`
- `bench/pipeline/delimited_stage_bench_test.mbt`
- `bench/pipeline/xlsx_stage_bench_test.mbt`

The shared bootstrap for this lives in
`bench/pipeline/lib/stage_helpers.mbt`.

### 1.4 Product architecture already exposes the required fast paths

The main product path already supports route-faithful execution:

- `convert/convert_finalize.mbt` keeps `IRInput -> RenderInput` shape
- `runtime/runtime.mbt` preserves the public three-shape `IRInput` contract
- `pipeline/pipeline.mbt` has event-stream and block-stream fast paths

This means the current benchmark gaps are mostly measurement gaps, not missing
product architecture.

## 2. Current Gaps And Risks

## 2.1 High: runner results still do not serialize route provenance

Current JSONL result rows carry measurement policy and runner provenance, but not
route provenance.

Missing fields include:

- selected route
- selected parser mode as a benchmark fact
- parse-result public IR shape
- pipeline output shape
- renderer input shape
- route-fidelity status
- route-affecting option provenance

Evidence:

- `bench/runner/result/cli_result.mbt`
- `bench/runner/result/summary.mbt`

Why this matters:

Without these fields, the report can say "MoonBit is 9.5x faster" but it cannot
prove whether the measured rows followed the intended main-architecture fast
paths. This is the biggest remaining trust gap.

## 2.2 High: benchmark option resolution is still row-agnostic

`bench/shared/bench_manifest.mbt` currently resolves benchmark convert options as
plain `@convert.default_convert_options()` and ignores the row:

- no per-row route-affecting policy
- no benchmark option fingerprint
- no explicit encoding of large-file / over-limit expectations
- no way to lock benchmark rows to future non-default product modes

Evidence:

- `bench/shared/bench_manifest.mbt:93-98`

Why this matters:

The benchmark architecture now depends on a deterministic option contract. As
long as the resolver ignores the row, route-sensitive rows can drift when product
defaults change.

## 2.3 High: in-process engine compare path also ignores row-level options

The in-process engine baseline inside `bench/runner` always calls
`@convert.default_convert_options()` for both warmup and measured runs.

Evidence:

- `bench/runner/process/inprocess_engine.mbt:10-16`
- `bench/runner/process/inprocess_engine.mbt:34-37`

Why this matters:

Even if stage benches become route-faithful, the compare engine baseline still
cannot follow a richer benchmark option contract. This will matter immediately if
we add row-specific limits, output policies, OCR policies, or explicit mode
selection.

## 2.4 High: `zip` and `epub` stage benches still force whole-document cost

The current product path advertises these formats as block-stream fast-path
families:

- `formats/zip/parser.mbt` sets `ir_input_kind=block_stream` and
  `event_semantics=archive_entry_block_stream`
- `formats/epub/parser.mbt` sets `ir_input_kind=block_stream` and
  `event_semantics=epub_spine_block_stream`
- `pipeline/pipeline.mbt` explicitly allows both semantics to skip the default
  pipeline

But the stage suites still do this:

- parse to `IRInput`
- force `stage_build_document(ir_input)`
- render the forced `DocumentIR`

Evidence:

- `bench/pipeline/zip_stage_bench_test.mbt:33-36`
- `bench/pipeline/zip_stage_bench_test.mbt:95-103`
- `bench/pipeline/epub_stage_bench_test.mbt:44-47`
- `bench/pipeline/epub_stage_bench_test.mbt:129-137`

Why this matters:

These two stage suites are still measuring a slower synthetic path than the
product path for the same route family. Their attribution conclusions are not
trustworthy until they are converted to the same route-preserving shape used by
the corrected markdown/html/json/xml/yaml/textlike/xlsx suites.

## 2.5 Medium: many `build_document` stage names no longer describe the actual measurement

In the corrected route-sensitive suites, the benchmark named `build_document`
often no longer builds a document. It now measures `run_default_pipeline` and may
return `EventStream` or `BlockStream`.

Examples:

- `bench/pipeline/markdown_stage_bench_test.mbt:105-116`
- `bench/pipeline/html_stage_bench_test.mbt:143-154`
- `bench/pipeline/json_stage_bench_test.mbt:98-109`

Why this matters:

The implementation got more correct, but the stage label stayed old. That can
still mislead optimization work by making people think a whole-document build is
hot when the benchmark is actually timing "pipeline on the emitted IR shape".

This should be renamed to something like:

- `run_pipeline`
- `pipeline_output_shape`
- `force_document_materialization` only when that is truly what is being timed

## 2.6 Medium: canonical route probing currently depends on full `convert_input`

`bench/pipeline/lib/stage_helpers.mbt` currently bootstraps canonical route
selection by calling full `@convert.convert_input(...)` once outside measurement
and then rebuilding parse context from the returned `detected_format` and
`parser_mode`.

Evidence:

- `bench/pipeline/lib/stage_helpers.mbt:283-304`

Why this matters:

This is route-faithful, so it is much better than handwritten benchmark route
logic. But it is still a temporary bootstrap, not a clean architecture endpoint.

Limitations:

- it duplicates work conceptually
- it couples stage benchmarking to full convert success
- it hides the need for a first-class benchmark-safe RoutePlanner API

Recommended direction:

Expose a dedicated route-planner or preflight API that returns:

- selected route
- selected parser mode
- route reason
- route probe summary
- route-affecting option fingerprint

Then let stage benches consume that API directly.

## 2.7 Medium: official summaries still cannot report route coverage

`bench/runner/result/summary.mbt` produces strong environment and performance
summaries, but it has no route-coverage section because the raw rows do not carry
route facts.

Why this matters:

The current report can tell us:

- how many rows were comparable
- where failures and timeouts happened
- geomean speedups by format

But it still cannot answer:

- did all `markdown huge` rows actually use block-streaming?
- did `xlsx huge` use block-streaming or package-single-pass?
- did any official-gate row silently fall back to a whole-document path?

That missing layer is exactly what would have made the previous markdown mismatch
obvious much earlier.

## 2.8 Medium: `docx`, `pptx`, and `pdf` stage suites still use the older stage pattern

These suites still use `stage_build_document(...)` and
`stage_render_markdown(...)`:

- `bench/pipeline/docx_stage_bench_test.mbt`
- `bench/pipeline/pptx_stage_bench_test.mbt`
- `bench/pipeline/pdf_stage_bench_test.mbt`

Current risk is not identical across them:

- `docx` and `pptx` parsers already emit `DocumentIR`, so the current stage shape
  is not obviously wrong
- `pdf` currently also materializes document output in the parser path, so it is
  not the same failure mode as markdown/html/json/xml

But these suites still lack explicit route and shape assertions. If their product
routes evolve later, the benchmark will not automatically tell us that the stage
measurement became synthetic.

Recommended direction:

Move them onto the same shared route-fidelity scaffold even if the emitted shape
currently remains `Document`.

## 2.9 Low: tool command metadata does not yet preserve route-relevant semantics

The tool metadata in compare mode is still light:

- the MoonBit CLI tool only preserves command shape
- the in-process engine tool uses a generic `convert_input <input> ...` display

Evidence:

- `bench/runner/tools/moonbit_cli_tool.mbt`
- `bench/runner/tools/moonbit_engine_tool.mbt`

Why this matters:

Once benchmark option resolution becomes richer, command/result metadata should
surface that richness so report readers can see which mode and route policy were
actually exercised.

## 3. Priority Order For Follow-up Work

The next benchmark fixes should happen in this order:

1. Add route provenance fields to MoonBit raw rows and summaries.
2. Replace row-agnostic benchmark option resolution with a centralized,
   auditable row-to-`ConvertOptions` contract.
3. Make `bench/runner` in-process engine reuse that same option contract.
4. Fix `zip` and `epub` stage suites to preserve block-stream fast-path
   measurement.
5. Rename misleading stage labels such as `build_document`.
6. Expose a first-class route-planner/preflight API for benchmarks instead of
   using full `convert_input` as bootstrap.
7. Move `docx`, `pptx`, and `pdf` onto the same route-fidelity scaffold for
   future-proofing.

## 4. What This Means For Future Optimization Work

The benchmark architecture is now strong enough to support the user’s core
concern:

if a product fast path exists, benchmark architecture must prove that it was the
path being measured.

That changes the optimization workflow:

1. first verify route fidelity
2. then trust the hotspot attribution
3. then optimize parser-core / tokenizer / large-case main chains

Without Step 1, further optimization work risks chasing synthetic bottlenecks.
