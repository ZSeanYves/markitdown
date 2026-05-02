# Benchmark Batch Design

This document captures the H3.2 design for batch benchmarking and future
product CLI batch mode.

Batch v1 status:

* CLI batch mode v1 is now implemented as
  `moon run cli -- batch [--with-metadata] <input_dir> <output_dir>`
* the implemented product scope is non-recursive, serial, directory-input
  batch with isolated per-document output roots and `batch-summary.tsv`
* benchmark-only batch harness work is still future work
* manifest mode, recursive traversal, parallelism, and benchmark corpus changes
  are still future work

The implementation keeps converter semantics, metadata schema, and existing
single-file `normal / ocr / debug` behavior unchanged.

Related planning context:

* [docs/benchmark-h3-plan.md](./benchmark-h3-plan.md)
* [docs/benchmark-baseline.md](./benchmark-baseline.md)
* [docs/benchmark-comparison.md](./benchmark-comparison.md)
* [docs/metadata-sidecar.md](./metadata-sidecar.md)

## 1. Definitions

### Batch benchmark

`batch benchmark` means a benchmark harness measures a set of multiple files as
one logical workload group.

The intended observations are:

* total elapsed time
* files processed
* total input bytes
* total output bytes
* average per file
* throughput
* startup overhead amortization or lack of amortization

Batch benchmark is a harness concept. It does not imply the product CLI already
supports multi-file conversion in one command.

### Batch mode

`batch mode` can mean two different things and should not be conflated.

`benchmark-only batch mode`:

* a benchmark harness loops over multiple files
* each file still uses the existing single-file `normal` command
* no product CLI change is required
* this is the low-risk H3-first path

`product CLI batch mode`:

* the user runs one CLI command for multiple files or a directory
* one process may handle many files
* startup cost can be amortized
* output layout, assets, metadata, and failure policy become product-surface
  concerns

### Process-per-file vs single-process

Single-file benchmarks today measure:

```text
startup + dispatch + parse + convert + emit + write
```

Future batch benchmarks must distinguish two runner models.

`process-per-file batch`:

* harness loops over files
* one process is started per file
* measures current real CLI batch user experience
* does not measure the upper bound of parser/converter throughput

`single-process batch`:

* one process handles many files
* startup cost is amortized across the group
* better approximates parser/converter throughput ceiling
* requires new product CLI behavior or new internal runner support

H3 speed conclusions should always label which model was measured.

## 2. Current CLI And Baseline Constraints

The current CLI is designed around one input path per invocation.

Relevant files:

* `cli/main.mbt`
* `cli/cli_app.mbt`
* `convert/convert/dispatcher.mbt`
* `core/tool.mbt`
* asset exporters under `convert/docx`, `convert/pptx`, `convert/html`,
  `convert/pdf`, `convert/zip`, and `convert/epub`

### Current CLI audit

| Question | Audit result |
| --- | --- |
| 1. Does the current CLI support only one input? | Yes. `normal`, `ocr`, and `debug` all parse one positional input path per invocation. There is no list, manifest, or directory-input branch in `cli/main.mbt`. |
| 2. How is output treated when it is a file or directory? | If output is omitted, Markdown goes to stdout. If output ends with `/` or `\\`, or does not exist and is not `.md`/`.markdown`, it is treated as a directory and resolved to `<output>/<input_stem>.md`. If output looks like `.md` or `.markdown`, it is treated as a file path. Existing non-Markdown paths are currently treated as directory-like as well because `looks_like_output_dir` returns `true` for existing paths. |
| 3. How is the assets directory named? | Top-level single-file conversions generally emit into `assets/` under the resolved output root, using names like `assets/image01.png`. ZIP and EPUB additionally remap nested assets under `assets/archive/<entry_id>/...` inside one document conversion. |
| 4. How is the metadata directory named? | When `--with-metadata` is enabled and output is on disk, the sidecar path is `<markdown_dir>/metadata/<stem>.metadata.json`. Stdout mode intentionally has no metadata sidecar. |
| 5. Would repeated multi-file conversion hit `assets/image01` conflicts? | A shared flat output directory is not a safe batch namespace. DOCX, PPTX, HTML, and PDF exporters use `next_image_asset_rel_path_unique`, so sequential runs avoid overwriting by scanning existing files and renumbering. That avoids direct overwrite but produces order-dependent, cross-document asset numbering. ZIP and EPUB already namespace by archive entry, but not by top-level source file, so two different archives with the same entry ids can still collide in one shared output tree. |
| 6. Would metadata files conflict? | Yes if two inputs resolve to the same markdown filename in the same directory. For example, same-stem inputs from different directories, or same basename with different extensions, both collapse to the same `<stem>.md` and `metadata/<stem>.metadata.json` in a flat output layout. |
| 7. How does single-file failure currently affect exit code? | The current behavior is not normalized enough for product batch semantics. `cli_app.mbt` has `exit_error` as a print helper, not a dedicated nonzero process-exit helper. As a result, some usage/validation paths can print an error message and return without a nonzero code, while lower-layer parse/runtime failures can still surface as nonzero exits. |
| 8. What is the hardest future CLI-batch problem? | Output contract design is the hardest problem, not file enumeration. A future batch CLI must define deterministic per-document output layout, asset namespace isolation, metadata namespace isolation, partial-failure policy, unsupported-file policy, ordering, and exit-code semantics before single-process throughput can be interpreted safely. |

### Baseline implications

Current benchmark baselines should remain interpreted as single-file harness
measurements:

* smoke benchmark mainly tracks single-file trend behavior
* comparison benchmark is selected overlap only
* comparison prefers prebuilt native CLI, with `moon run` fallback
* `.tmp/bench/...` outputs remain manual-inspection artifacts
* no checked-in corpus or baseline currently describes batch throughput

## 3. Benchmark-only Batch Mode Design

### Recommendation

The recommended H3-first path is:

* implement benchmark-only batch mode before product CLI batch mode
* keep runner semantics as process-per-file at first
* keep using the existing `normal` single-file conversion contract
* add a dedicated checked-in batch corpus
* keep batch results explicitly labeled as `process-per-file`

This is the lowest-risk way to answer whether current speed wins depend too
heavily on single-file startup cost or very small samples.

### Why benchmark-only comes first

Benefits:

* no converter change
* no CLI change
* no metadata schema change
* no new product failure contract yet
* can ship useful throughput evidence immediately

Known limit:

* this does not measure single-process throughput ceiling yet

### Corpus design options

Two batch corpus styles are plausible.

| Option | Advantages | Drawbacks |
| --- | --- | --- |
| Explicit manifest rows | Fully reproducible, explicit checked-in membership, easy per-file status tracking, easy stable ordering, easy sample-level allowlists and notes | Corpus file is longer |
| Directory or glob group | Easy to maintain when adding files, less TSV verbosity | Runtime expansion can drift by platform or shell, ordering can vary, group membership is less explicit, harder to review benchmark-set changes in diff |

Recommended choice:

* use explicit manifest rows as the checked-in contract
* if convenience tooling is needed later, generate manifest rows from
  directories as a local helper, but keep the checked-in corpus explicit

### Recommended batch corpus schema

Recommended file:

```text
samples/benchmark/batch_corpus.tsv
```

Recommended header:

```text
group_id	format	sample	input_path	metadata_enabled
```

Why include `metadata_enabled`:

* it matches the shape already used by `samples/benchmark/corpus.tsv`
* phase 1 groups can still keep it as `false`
* future metadata-on batch groups do not require a second corpus format

Recommended invariants:

* `group_id` is the logical batch workload identity
* rows for the same `group_id` should keep one `format`
* rows for the same `group_id` should keep one `metadata_enabled` value
* `sample` stays explicit for per-file status reporting
* checked-in row order is the execution order contract

Example:

```text
group_id	format	sample	input_path	metadata_enabled
txt_small_set	txt	txt_001	samples/benchmark/batch/txt/txt_001.txt	false
txt_small_set	txt	txt_002	samples/benchmark/batch/txt/txt_002.txt	false
html_small_set	html	html_001	samples/benchmark/batch/html/html_001.html	false
```

### Recommended harness shape

Preferred next implementation path:

* add a dedicated future script such as `samples/scripts/bench_batch.sh`
* keep existing `samples/scripts/bench_smoke.sh` and
  `samples/scripts/bench_compare_markitdown.sh` behavior unchanged

Why a dedicated script is safer than overloading smoke first:

* batch result schema is group-oriented, not single-sample-oriented
* artifact layout is easier to isolate under its own root
* existing smoke summary semantics stay stable
* H3.2 is explicitly trying to avoid accidental benchmark-contract drift

If the repository later prefers less script surface area, an additive
`bench_smoke.sh --kind batch` mode is still viable, but only after the batch
summary schema is fixed.

### Recommended artifact layout

Recommended root:

```text
.tmp/bench/batch
```

Recommended artifacts:

* `results.jsonl`
* `summary.tsv`
* `file_results.jsonl`
* `groups/<group_id>/<sample>/...` for kept conversion outputs

Recommended per-file output isolation:

```text
.tmp/bench/batch/groups/<group_id>/<sample>/<sample>.md
.tmp/bench/batch/groups/<group_id>/<sample>/assets/...
.tmp/bench/batch/groups/<group_id>/<sample>/metadata/<sample>.metadata.json
```

This keeps current single-file asset conventions untouched while preventing
cross-sample asset and metadata collisions inside the benchmark harness.

### Measurement model

For process-per-file batch, record both:

* group wall-clock elapsed time
* per-file elapsed time for each invocation

Interpretation:

* group wall clock answers current user-facing batch experience for repeated CLI
  invocations
* per-file timings preserve median and outlier visibility
* the result must still be labeled `process-per-file`, because startup is paid
  once per file

### Result schema proposal

Recommended group-level required fields:

* `group_id`
* `format`
* `process_model`
* `runner_command`
* `file_count`
* `success_count`
* `failure_count`
* `total_input_bytes`
* `total_output_bytes`
* `total_elapsed_ms`
* `avg_ms_per_file`
* `median_ms_per_file`
* `throughput_input_bytes_per_sec`
* `metadata_enabled`
* `timestamp_utc`

Recommended group-level optional fields:

* `runner_kind`
* `total_asset_bytes`
* `total_metadata_bytes`
* `stderr_bytes_total`
* `git_rev`
* `timer_precision`

Recommended per-file detail fields:

* `group_id`
* `format`
* `sample`
* `input_path`
* `input_bytes`
* `output_bytes`
* `elapsed_ms`
* `exit_code`
* `success`
* `metadata_enabled`

Definitions:

* `total_output_bytes` should mean Markdown bytes, not all artifact bytes, so
  the field stays comparable with existing benchmark output emphasis
* `total_asset_bytes` can be tracked separately when image-heavy groups matter
* `throughput_input_bytes_per_sec` should be defined as
  `total_input_bytes / total_elapsed_seconds`
* `median_ms_per_file` is only meaningful when per-file timings are actually
  captured

Example group record:

```json
{
  "group_id": "txt_small_set",
  "format": "txt",
  "process_model": "process-per-file",
  "runner_command": "moon run cli -- normal",
  "file_count": 8,
  "success_count": 8,
  "failure_count": 0,
  "total_input_bytes": 16384,
  "total_output_bytes": 15872,
  "total_elapsed_ms": 842,
  "avg_ms_per_file": 105.25,
  "median_ms_per_file": 104,
  "throughput_input_bytes_per_sec": 19458.4,
  "metadata_enabled": false,
  "timestamp_utc": "2026-05-03T00:00:00Z"
}
```

### Failure policy for benchmark-only batch

Recommended behavior:

* one file failure should not abort the whole group immediately
* record per-file failure and continue to the next file
* summary should surface `success_count` and `failure_count`
* group exit should be nonzero if any measured file failed

Why this policy fits the benchmark harness:

* one broken sample should not hide the rest of the timing signal
* the harness still needs a failing overall status for discipline
* kept outputs under `.tmp/bench/batch/...` make postmortem inspection easier

### Non-goals for benchmark-only batch

This first batch benchmark design does not attempt to:

* claim single-process throughput
* redefine current smoke or comparison baselines
* imply the product CLI already supports batch conversion
* solve all future output-layout issues for one-command product batch

## 4. Product CLI Batch Mode Options

Product CLI batch mode is no longer only hypothetical: Batch v1 now implements
the simplest form of Option A. The comparison below remains useful for future
expansion decisions.

### Option comparison

| Option | UX | Implementation risk | Output clarity | Assets and metadata safety | Recommended? |
| --- | --- | --- | --- | --- | --- |
| A. `markitdown-mb batch <input_dir> <output_dir>` | Clear intent, discoverable, easy to document | Moderate | Strong | Strong if per-document output roots are required | Yes, best first product surface |
| B. `markitdown-mb normal <input_dir> <output_dir>` | Superficially simple, but command meaning becomes overloaded | High | Weak to medium | Weak unless many hidden rules are added | No |
| C. `markitdown-mb batch --manifest files.tsv --out out/` | Best for reproducible automation | Moderate to high | Strong | Strong if manifest rows resolve to isolated doc roots | Later, as advanced mode |

### Option A: dedicated batch subcommand

Strengths:

* makes multi-file semantics explicit
* avoids overloading current `normal` meaning
* gives a clean place for recursive, filter, and summary flags later
* easier to assign a distinct exit-code contract

Weaknesses:

* new product surface area
* still needs careful output layout and failure semantics

### Option B: let `normal` accept directories

Why this is not recommended first:

* current `normal` is mentally and structurally a single-file path
* current output-path heuristics are already file-vs-directory sensitive
* mixing file and directory input into one command makes failure behavior and
  output inference much less obvious
* documentation and debugging become harder

### Option C: manifest mode

Strengths:

* most reproducible
* automation-friendly
* naturally aligns with benchmark and regression workflows

Weaknesses:

* heavier UX for everyday use
* requires a manifest contract before ad hoc usage is easy

Recommended product direction:

* first product batch surface should be Option A
* manifest mode can be added later as an advanced extension of batch behavior

## 5. Recommended Product Output Contract

If product CLI batch mode is implemented later, the main design goal should be
namespace isolation per top-level input document.

### Recommended output layout

Do not write all batch outputs into one shared flat directory.

Implemented Batch v1 layout:

```text
<output_root>/<stable_index>-<input_stem>/<input_stem>.md
<output_root>/<stable_index>-<input_stem>/assets/...
<output_root>/<stable_index>-<input_stem>/metadata/<input_stem>.metadata.json
```

The earlier `<relative_input_path_with_extension>/...` design is still a viable
future option when recursive or manifest mode is added, but Batch v1 uses the
stable-index document-root strategy to keep collisions impossible without
changing converter behavior.

General per-document layout principle:

```text
<output_root>/<relative_input_path_with_extension>/<input_stem>.md
<output_root>/<relative_input_path_with_extension>/assets/...
<output_root>/<relative_input_path_with_extension>/metadata/<input_stem>.metadata.json
```

Example:

```text
out/reports/q1.docx/q1.md
out/reports/q1.docx/assets/image01.png
out/reports/q1.docx/metadata/q1.metadata.json

out/reports/q1.pdf/q1.md
out/reports/q1.pdf/assets/image01.jpg
out/reports/q1.pdf/metadata/q1.metadata.json
```

Why this layout is recommended:

* current converters already assume per-document `assets/` under one output
  root
* same-stem but different-extension inputs stay isolated
* same basename from different source directories stays isolated
* ZIP and EPUB top-level archives gain a source-document namespace, not only an
  internal entry namespace
* single-file and batch mental models remain compatible

### Assets namespace policy

Recommended policy:

* keep existing per-document `assets/imageNN.ext` behavior inside one document
  root
* never make multiple top-level inputs share the same `assets/` directory
* keep ZIP and EPUB `assets/archive/...` remaps inside the document root

This avoids converter changes while still making future batch behavior safe.

### Metadata namespace policy

Recommended policy:

* keep current sidecar location rule relative to each document root
* do not introduce one shared global metadata directory for all batch outputs

That means:

```text
<doc_root>/<stem>.md
<doc_root>/metadata/<stem>.metadata.json
```

### Summary report

Recommended batch summary outputs:

* one machine-readable summary under `<output_root>/batch-summary.json`
* one easy-to-scan tabular summary under `<output_root>/batch-summary.tsv`

Recommended summary fields:

* input count
* success count
* failure count
* skipped unsupported count
* total elapsed ms
* output root
* process model
* ordering mode

## 6. Recommended Product Failure Policy

### Supported-file failure

Recommended behavior:

* continue processing remaining files
* record the failed file in the summary
* return nonzero overall exit if any supported file failed

### Unsupported files

Implemented Batch v1 behavior for directory input:

* unsupported top-level files are recorded in `batch-summary.tsv`
* batch continues to later files
* overall batch exit is nonzero if any unsupported or failed file appears

This is slightly stricter than the softer recommendation in the earlier design,
but matches the current v1 implementation and keeps failures visible.

Recommended initial behavior for manifest mode:

* treat unsupported listed files as failures
* manifest is explicit intent, so silent skipping is less appropriate

### Recursive traversal

Implemented Batch v1 default:

* non-recursive by default
* add explicit `--recursive` later if needed

Why:

* safer for large trees
* easier to reason about output cardinality
* easier to keep benchmarks and acceptance tests intentional

### Extension filter

Recommended later flag:

```text
--ext docx,pdf,html
```

This is useful but not required for the first benchmark-only phase.

### Deterministic ordering

Recommended rule:

* discover candidate files
* normalize to relative paths
* sort lexicographically by normalized relative path before processing

This is important for repeatable batch summaries and stable asset numbering
inside any one-process implementation.

### Exit-code semantics

Recommended future product contract:

* exit `0`: all selected supported files succeeded
* exit `1`: one or more selected supported files failed
* exit `2`: CLI usage error, manifest parse error, or invalid batch
  configuration

Batch v1 currently implements this contract for the `batch` subcommand:

* exit `0`: all processed files succeeded
* exit `1`: one or more files were `failed` or `unsupported`
* exit `2`: batch CLI usage or batch setup error

## 7. Format Rollout Plan

Recommended batch benchmark rollout order:

### Phase 1: cheap text and structured formats

* TXT
* Markdown
* CSV
* JSON
* HTML

Why phase 1 comes first:

* cheapest way to expose startup-overhead distortion
* easiest files to collect into explicit groups
* fastest iteration loop while the harness contract is still settling

### Phase 2: OOXML and PDF

* DOCX
* PPTX
* XLSX
* PDF

Why phase 2 comes next:

* closer to real office-document batch workloads
* more representative for product-facing performance claims
* surfaces asset export and metadata sidecar costs more realistically

### Phase 3: containers and ebooks

* ZIP
* EPUB

Why phase 3 is last:

* stresses archive materialization and remap safety
* more sensitive to output layout and namespace policy
* more likely to need per-document isolation before product batch is safe

## 8. Recommended Next Implementation Path

Recommended order after this Batch v1 round:

1. Keep Batch v1 stable and covered by lightweight tests.
2. Add a checked-in explicit manifest corpus for benchmark batch groups.
3. Implement benchmark-only process-per-file batch harness first.
4. Keep benchmark batch results clearly labeled as `process-per-file`.
5. Decide later whether Batch v2 should add recursive or manifest mode.
6. Only then decide whether single-process throughput work needs deeper product
   expansion.

This keeps H3 evidence gathering ahead of product-surface expansion.

## 9. Open Questions And Non-goals

Open questions:

* should batch benchmark `total_output_bytes` remain Markdown-only forever, or
  should a separate artifact-byte metric become standard?
* should future batch harness reuse `bench_smoke.sh` internals or stay as a
  separate script long-term?
* does product batch eventually need both directory mode and manifest mode, or
  is one sufficient for the first release surface?

Non-goals for H3.2:

* no converter semantic change
* no `normal / ocr / debug` semantic change
* no recursive directory traversal in Batch v1
* no manifest mode in Batch v1
* no benchmark corpus change in this round
* no benchmark baseline rewrite in this round
* no metadata schema change
