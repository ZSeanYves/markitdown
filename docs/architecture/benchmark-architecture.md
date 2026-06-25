# mb-markitdown Benchmark 体系架构书

> 建议路径：`docs/architecture/benchmark-architecture.md`
> 适用项目：MoonBit 版 `markitdown` / `mb-markitdown`
> 版本定位：Benchmark architecture contract
> 目标状态：以 MoonBit 为主体的完整 benchmark corpus、native harness、external baseline、process measurement 与 report toolchain。
> 重要原则：Python / shell runner 只作为历史过渡实现，不属于最终目标架构。

---

## 0. 架构目标

本 benchmark 体系的目标不是“写几个脚本跑耗时”，而是建立一套可长期维护、可复现、可审计、可扩展的性能验证基础设施。

它必须回答四类问题：

```text
1. 单个底层 reader / parser / renderer 是否变慢？
2. Parser -> ParseResult -> Core IR -> Pipeline -> Renderer 的分层开销是多少？
3. 用户真实 CLI 转换文件时的启动成本、总耗时、输出大小、内存占用如何？
4. 与 Microsoft MarkItDown 等外部工具相比，MoonBit 实现的速度、吞吐、RSS、成功率如何？
```

Benchmark 体系服务项目三条主线：

```text
H1 稳定基线：
  每个格式具备基础 benchmark，保证转换路径持续可运行。

H2 质量对标：
  对照主流工具保留结构能力，但质量判定不混进性能脚本。

H3 速度领先：
  建立 small / medium / large / huge / batch 性能矩阵，定位 parser、reader、IR、renderer、assets、IO、CLI 启动成本等瓶颈。
```

核心口号：

```text
samples/bench 存样例；
bench/ 测 MoonBit in-process 性能；
bench/runner 用 MoonBit 调 CLI 和外部工具；
C FFI 只用于 benchmark native measurement；
Python / shell runner 退役；
samples/check.sh 只做 correctness，不做 benchmark。
```

---

## 1. Benchmark 总体分层

最终 benchmark 体系分为四层：

```text
samples/bench/
  tracked benchmark corpus

bench/
  MoonBit native in-process benchmark harness

bench/runner/
  MoonBit-native CLI / external baseline / report toolchain

bench/runner/native/
  bench-only C FFI resource measurement stubs
```

完整数据流：

```text
samples/bench/MANIFEST.tsv
  ↓
Benchmark selector
  ↓
┌─────────────────────────────┬──────────────────────────────┐
│ bench/                       │ bench/runner/                 │
│ moon bench in-process         │ MoonBit process runner         │
│ micro / pipeline / product    │ CLI / external tool baseline   │
└─────────────────────────────┴──────────────────────────────┘
  ↓
BenchmarkResult JSONL
  ↓
Summary / Markdown report / optional baseline comparison
```

Benchmark 体系与主产品架构的关系：

```text
input / format_readers / formats / runtime / pipeline / render / convert / cli
  ↑
  只被 benchmark 调用

bench / bench/runner
  ↓
  不能被主产品 runtime 依赖
```

---

## 2. 核心边界

必须遵守：

```text
1. Benchmark 不改变产品输出行为。
2. Benchmark 不修改 runtime / convert / formats / parser / pipeline / render / cli 的语义。
3. Benchmark 不恢复 samples/bench.sh。
4. Benchmark 不恢复 samples/helpers/bench/。
5. Benchmark 不依赖 quality-lab 运行。
6. external_bench 只可作为历史来源池，不作为正式运行依赖。
7. samples/bench 是正式 tracked corpus，不允许 local-only / ignored payload。
8. bench/ 只做 MoonBit in-process benchmark，不 fork CLI。
9. bench/runner/ 负责 process-level benchmark、外部工具对比、RSS、report。
10. process / RSS / C FFI 只能存在于 bench/runner 或 bench-only native package。
11. C FFI 不进入主链 runtime。
12. OCR / layout model / PDF rasterization 不进入默认 benchmark tier。
13. PDF 默认 benchmark 只测 native-text 路径。
14. 性能数据默认 soft report，不作为 CI hard gate。
```

禁止恢复：

```text
samples/bench.sh
samples/helpers/bench/
Python primary runner
shell primary runner
quality-lab runtime dependency
external_bench runtime dependency
benchmark-generated payload ignored by git
local-only benchmark corpus
```

允许保留的历史过渡文件：

```text
P13-C Python / shell runner 可作为迁移参考；
目标架构完成后应删除或标记 retired；
最终 benchmark 主路径必须由 MoonBit toolchain 承担。
```

---

## 3. Corpus 层：samples/bench

### 3.1 定位

`samples/bench/` 是主仓正式 benchmark corpus。

它不是缓存，不是临时下载目录，不是 local-only 数据目录。

所有 payload 必须：

```text
tracked
可审计
有 manifest row
有 bytes
有 sha256
有 source_ref
有 size_class
有 enabled_tier
```

### 3.2 目录结构

```text
samples/bench/
  README.md
  MANIFEST.tsv
  FORMAT_MATRIX.md

  txt/
    tiny/
    small/
    medium/
    large/
    huge/
  csv/
    tiny/
    small/
    medium/
    large/
    huge/
  tsv/
    tiny/
    small/
    medium/
    large/
    huge/
  json/
    tiny/
    small/
    medium/
    large/
    huge/
  yaml/
    tiny/
    small/
    medium/
    large/
    huge/
  xml/
    tiny/
    small/
    medium/
    large/
    huge/
  markdown/
    tiny/
    small/
    medium/
    large/
    huge/
  html/
    tiny/
    small/
    medium/
    large/
    huge/
  zip/
    tiny/
    small/
    medium/
    large/
    huge/
  epub/
    tiny/
    small/
    medium/
    large/
    huge/
  pdf/
    tiny/
    small/
    medium/
    large/
    huge/
  docx/
    tiny/
    small/
    medium/
    large/
    huge/
  pptx/
    tiny/
    small/
    medium/
    large/
    huge/
  xlsx/
    tiny/
    small/
    medium/
    large/
    huge/
```

### 3.3 MANIFEST.tsv

Manifest 表头：

```tsv
bench_id	format	size_class	rel_path	source_kind	source_ref	bytes	sha256	enabled_tier	bench_layers	tags	review_status	notes
```

字段含义：

```text
bench_id:
  稳定唯一 ID。
  推荐格式：<format>_<size_class>_<short_name>_v1

format:
  txt / csv / tsv / json / yaml / xml / markdown / html / zip / epub / pdf / docx / pptx / xlsx

size_class:
  tiny / small / medium / large / huge

rel_path:
  相对 samples/bench 的 payload 路径。

source_kind:
  copied_from_external_bench
  copied_from_samples
  generated_tracked
  hand_made
  missing_candidate

source_ref:
  来源追踪。
  来自 external_bench 时记录 external bench_id / 原 rel_path。
  来自 samples 时记录原路径。
  生成时记录 deterministic generation 摘要。

bytes:
  payload 实际字节数。
  missing_candidate 为 0。

sha256:
  payload sha256。
  missing_candidate 为空。

enabled_tier:
  smoke / regular / release / stress / disabled

bench_layers:
  micro / pipeline / product / external，可逗号组合。

tags:
  native-text, ooxml, table, images, links, cjk, many-rows, many-pages 等。

review_status:
  accepted / reviewed_candidate / missing_candidate / disabled

notes:
  人类可读说明。
```

### 3.4 size_class

```text
tiny:
  极小样例，测试固定开销和启动成本。

small:
  常规小文件，默认 smoke 可跑。

medium:
  中等真实文件，本地常规 benchmark。

large:
  大文件性能样例，release 前 benchmark。

huge:
  极大压力样例，stress benchmark。
```

所有 size class 的 payload 都是 tracked。`huge` 只代表默认不跑，不代表 local-only。

### 3.5 enabled_tier

```text
smoke:
  默认最快 benchmark。
  用于验证 harness、runner、外部工具调用是否正常。

regular:
  本地常规性能观察。
  包含 smoke + regular。

release:
  发布前性能报告。
  包含 smoke + regular + release。

stress:
  完整压力 benchmark。
  包含 smoke + regular + release + stress。

disabled:
  已登记但默认永不选择。
```

Tier 选择规则：

```text
smoke:
  enabled_tier == smoke

regular:
  enabled_tier in smoke,regular

release:
  enabled_tier in smoke,regular,release

stress:
  enabled_tier in smoke,regular,release,stress
```

默认 tier 必须是 `smoke`。

---

## 4. Native in-process 层：bench/

### 4.1 定位

`bench/` 是 `moon bench` 的原生 benchmark harness。

它负责测量 MoonBit 内部函数级和 in-process 转换路径：

```text
micro:
  detector / reader / renderer / pass 小粒度 benchmark

pipeline:
  parse -> ParseResult -> IRInput -> pipeline -> render 分层 benchmark

product:
  使用 samples/bench smoke corpus 走 in-process convert benchmark
```

它不负责：

```text
fork CLI
调用 markitdown
采集 peak RSS
采集 cold start
生成发布报告
对比外部工具
```

### 4.2 目录结构

```text
bench/
  README.md

  shared/
    moon.pkg
    bench_manifest.mbt
    bench_selector.mbt
    bench_fixture.mbt
    bench_blackhole.mbt

  micro/
    moon.pkg
    detector_bench_test.mbt
    reader_textlike_bench_test.mbt
    render_bench_test.mbt

  pipeline/
    moon.pkg
    convert_pipeline_bench_test.mbt

  product/
    moon.pkg
    corpus_smoke_bench_test.mbt
```

### 4.3 bench/shared

职责：

```text
读取 samples/bench/MANIFEST.tsv
解析 manifest row
选择 tier / format / size_class / bench_layers
跳过 missing_candidate / disabled / bytes=0 / missing payload
提供 payload path / bytes loader
提供 stable keep helper
```

Selector 默认：

```text
tier = smoke
exclude missing_candidate
exclude disabled
exclude bytes=0
exclude missing payload
```

### 4.4 bench/micro

Micro benchmark 测小粒度成本：

```text
micro.detector.smoke_formats
  对 smoke corpus 做 format detection。

micro.reader.textlike.smoke
  对 textlike / structured / markup smoke payload 做 reader 或 parser 前置路径。

micro.render.synthetic_blocks
  构造 synthetic DocumentIR / CoreBlock，测 Markdown renderer。
```

后续可扩展：

```text
micro.reader.ooxml.package_open_docx
micro.reader.xlsx.shared_strings
micro.reader.pdf.native_text_decode
micro.pipeline.normalize_text
micro.pipeline.resolve_table
micro.render.large_table
```

### 4.5 bench/pipeline

Pipeline benchmark 关注分层成本：

```text
pipeline.detect
pipeline.parse_only
pipeline.parse_to_ir
pipeline.build_document
pipeline.render_from_ir
pipeline.convert_total
```

首批可以合并成：

```text
pipeline.convert_total.smoke_textlike
pipeline.convert_total.smoke_office_pdf_container
```

成熟后应逐步拆细，便于定位瓶颈。

当前主仓已经补充多条 stage benchmark，用于把热点收敛到具体层段：

```text
pipeline.txt.*
pipeline.delimited.*
pipeline.html.*
pipeline.docx.*
pipeline.pptx.*
pipeline.xlsx.*
```

这些 stage benchmark 仍然走现有产品链路或格式内部只读 helper，
只用于定位 parse / normalize / lowering / render 的相对成本，不改变产品语义。

### 4.6 bench/product

Product benchmark 走 in-process API：

```text
samples/bench payload
  -> InputSource
  -> convert.convert_input
  -> ConvertResult
```

要求：

```text
不 fork CLI
不写外部报告
不生成长期 result file
只通过 b.keep 保留结果长度 / diagnostics count / block count 等
```

---

## 5. Process / External 层：bench/runner

### 5.1 目标状态

`bench/runner` 是 MoonBit-native benchmark process runner。

它负责：

```text
读取 samples/bench/MANIFEST.tsv
选择 tier / format / limit
调用当前 MoonBit CLI binary
调用 Microsoft MarkItDown CLI
计时 wall time
采集 exit code
采集 stdout/stderr bytes
采集 output bytes
采集 user/sys time
采集 peak RSS
输出 JSONL
生成 Markdown report
生成 summary JSON
```

它不应该长期依赖：

```text
Python runner
shell runner
external_bench
quality-lab
```

### 5.2 目标目录结构

```text
bench/runner/
  README.md
  moon.pkg
  main.mbt

  manifest/
    row.mbt
    parser.mbt
    selector.mbt

  command/
    command.mbt
    argv.mbt
    environment.mbt
    output_path.mbt

  process/
    process_runner.mbt
    process_result.mbt
    process_timeout.mbt

  measure/
    monotonic_time.mbt
    resource_usage.mbt
    resource_usage_native.mbt
    resource_usage_native_stub.c

  tools/
    moonbit_cli_tool.mbt
    markitdown_tool.mbt
    tool_registry.mbt

  result/
    cli_result.mbt
    result_jsonl.mbt
    summary.mbt
    markdown_report.mbt

  schemas/
    cli_result.schema.json
    summary.schema.json

  results/
    .gitkeep

  reports/
    .gitkeep
```

`bench/runner` 是 native-only package。

### 5.3 moon.pkg 原则

`bench/runner/moon.pkg` 应声明：

```text
supported-targets: native
```

如果使用 C stub，应声明 native stub：

```text
native-stub:
  measure/resource_usage_native_stub.c
```

它可以依赖：

```text
moonbitlang/async
moonbitlang/async/process
```

但这些依赖只能存在于 bench/runner，不允许进入主产品 runtime。

### 5.4 CLI 命令模型

统一命令结构：

```moonbit
pub struct CommandSpec {
  program : String
  args : Array[String]
  cwd : Option[String]
  env : Array[(String, String)]
  timeout_ms : Int64
}
```

统一结果结构：

```moonbit
pub struct CommandResult {
  exit_code : Int
  timed_out : Bool

  wall_ms : Int64
  user_time_us : Option[Int64]
  sys_time_us : Option[Int64]
  peak_rss_kb : Option[Int64]

  stdout_bytes : Int64
  stderr_bytes : Int64
  output_bytes : Int64

  stdout_excerpt : String
  stderr_excerpt : String
}
```

### 5.5 Tool 抽象

工具接口：

```moonbit
pub trait BenchTool {
  fn name(Self) -> String
  fn version(Self) -> Option[String]
  fn is_available(Self) -> Bool
  fn build_command(Self, row : BenchRow, output_path : String) -> CommandSpec
}
```

内置工具：

```text
MoonBitCliTool:
  调用当前构建出的 MoonBit CLI binary。
  目标是测 built binary，不测 moon run wrapper。

MarkItDownTool:
  调用系统 markitdown CLI。
  如果不存在，记录 unavailable，不 fail。
```

未来可扩展：

```text
PandocTool
PyMuPDFTool
CustomBaselineTool
```

外部工具失败时：

```text
记录 exit_code / stderr excerpt / status=failed
不影响整个 benchmark runner 的退出，除非 runner 自身崩溃
```

---

## 6. Process 执行策略

### 6.1 两种实现方式

Process runner 有两层能力：

```text
A. async/process runner
  负责 spawn 外部进程、等待、stdout/stderr、exit code。

B. native C measurement runner
  负责 fork/exec/wait4，采集 rusage / peak RSS / user/sys time。
```

目标架构以 B 为主，因为 benchmark 需要精确资源数据。

### 6.2 为什么需要 C FFI

`async/process` 能满足启动和等待外部命令，但 benchmark 还需要：

```text
peak RSS
user CPU time
system CPU time
exit status
timeout
stdout/stderr byte count
output file byte count
output mode attribution: file / stdout_capture / memory / none
```

其中 peak RSS / rusage 最适合由 native C stub 使用平台 API 获取。

### 6.3 C FFI 测量模型

C stub 负责：

```text
fork
execvp
redirect stdout/stderr to temp files or pipes
wait4 child
collect struct rusage
normalize ru_maxrss
return status fields
```

MoonBit 侧负责：

```text
构造 CommandSpec
调用 C measurement function
读取 stdout/stderr excerpt
统计 output file bytes
区分 canonical CLI output 与 diagnostic engine output modes
写 JSONL
生成 report
```

### 6.4 RSS 单位归一化

不同平台 `ru_maxrss` 单位不同：

```text
Linux:
  ru_maxrss 通常是 KiB

macOS / BSD:
  ru_maxrss 常见为 bytes
```

统一输出：

```text
peak_rss_kb
```

归一化逻辑放在 C stub 或 MoonBit wrapper 中，但必须在 README 中声明平台 caveat。

### 6.5 Timeout 策略

Timeout 必须由 measurement runner 支持。

推荐：

```text
默认 timeout:
  60s for smoke

regular:
  120s

release:
  300s

stress:
  explicit user-provided timeout
```

Timeout 行为：

```text
超过 timeout:
  kill child process
  wait/reap child
  status=timeout
  timed_out=true
  exit_code=-1
  保留已产生 stdout/stderr bytes
```

---

## 7. Result Model

### 7.1 JSONL Result

每个 benchmark row + tool 生成一行 JSON。

字段：

```json
{
  "schema_version": 1,
  "run_id": "20260623T123456Z-abcdef0",
  "repo_commit": "abcdef0",
  "tool": "moonbit-cli",
  "tool_version": "unknown",

  "bench_id": "csv_small_xxx_v1",
  "format": "csv",
  "size_class": "small",
  "enabled_tier": "smoke",
  "bench_layers": "external",
  "tags": "table,many-rows",

  "rel_path": "csv/small/xxx.csv",
  "input_bytes": 12345,
  "input_sha256": "....",

  "command_kind": "cli",
  "command_display": "cli.exe normal <input> <output>",

  "exit_code": 0,
  "status": "ok",
  "timed_out": false,

  "wall_ms": 12,
  "wall_us": 11842,
  "user_time_us": 10000,
  "sys_time_us": 2000,
  "peak_rss_kb": 12345,

  "stdout_bytes": 100,
  "stderr_bytes": 0,
  "output_bytes": 4567,

  "stdout_excerpt": "",
  "stderr_excerpt": "",
  "error": null
}
```

说明：

```text
wall_ms:
  rounded compatibility/display field

wall_us:
  preferred wall-clock basis for repeat aggregation,
  speedup calculation,
  fixed-overhead calculation

runner_mode:
  release | dev_moon_run | unknown

canonical_performance:
  true only when the run is marked as release runner mode

runner_path:
  resolved runner executable path when known
```

### 7.2 status

允许状态：

```text
ok
failed
timeout
skipped
unavailable
measurement_error
```

### 7.3 stderr/stdout excerpt

限制：

```text
stdout_excerpt max 500 chars
stderr_excerpt max 500 chars
```

不要把大输出塞进 report。

partial external baseline 解释约定：

```text
1. comparable rows 只统计所需工具都成功的 rows。
2. external baseline non-ok rows 必须单独列出。
3. MoonBit CLI/engine 仍成功、但 external baseline 非 ok 的 rows，
   必须标记为 external-only gap，不得误写成 MoonBit failure 或回归。
4. format/status 可以是 partial，只表示 cross-tool comparability 不完整，
   不等价于 MoonBit 产品路径失败。
```

---

## 8. Report Model

### 8.1 Summary JSON

`summary.json` 包含：

```text
run metadata
environment
corpus selection
tool summaries
per-format summaries
pairwise comparisons
failures
notes
timing precision markers
```

`corpus.tier` 必须表示本次 run 的 requested tier。实现上应优先从 selector
metadata（例如 `selector-stats.json` 中的 `requested_tier`）读取，而不是从
首条结果行的 `enabled_tier` 反推，因为 regular / release 选择集中通常会包含
smoke rows。

summary/report timing 约定：

```text
median/min/max wall_us:
  preferred aggregation basis when available

median/min/max wall_ms:
  rounded display/compatibility values

timing_precision:
  wall_us      -> precise path available
  ms_fallback  -> old wall_ms-only input summarized
```

runner mode 约定：

```text
release:
  canonical performance mode
  required for formal speedup / fixed-overhead / release benchmark conclusions

dev_moon_run:
  dev smoke / help / quick validation only
  must not be used for formal performance conclusions

unknown:
  detection unavailable
  report should warn and treat as non-canonical unless explicitly overridden
```

### 8.2 Markdown Report

报告结构：

```markdown
# Benchmark Report

## Environment
- commit
- branch
- date
- platform
- MoonBit version
- CLI binary path
- MarkItDown path/version
- target tier
- timeout

## Corpus
- selected rows
- skipped rows
- by format
- by size_class

## MoonBit CLI
- success / failed / timeout
- total wall ms
- median wall ms
- max wall ms
- max peak RSS
- output bytes
- slowest top 10

## MarkItDown
- same metrics

## Comparison
- rows where both succeeded
- selected rows vs comparable rows
- MoonBit-ok rows vs external-ok rows
- external-only gap rows
- total wall ms ratio
- median wall ms ratio
- per-format table
- RSS comparison
- failures by tool

## Failures
- bench_id
- tool
- exit_code
- status
- stderr excerpt

## Notes
- no hard gate
- RSS platform caveat
- external tool caveat
- runner_mode != release implies non-canonical performance data
- external-only failures must not be reported as MoonBit regressions
```

### 8.3 Report 文件策略

生成文件默认不提交：

```text
.tmp/bench/**/*.jsonl
.tmp/bench/**/*.json
.tmp/bench/**/*.md
```

允许提交：

```text
schemas
README
baseline policy
.tmp/ ignored output roots
```

是否提交正式 release report 由单独 release 流程决定。

---

## 9. Baseline Policy

### 9.1 不做默认 hard gate

Benchmark 默认不作为 CI hard gate。

原因：

```text
本机负载会影响耗时
不同 CPU / OS / 文件系统差异大
MarkItDown 环境依赖不稳定
RSS 平台口径存在差异
```

### 9.2 Soft warning

建议规则：

```text
median wall_ms regression <= 15%:
  pass

15% < regression <= 30%:
  warning, requires explanation

regression > 30%:
  manual investigation
```

RSS 建议：

```text
peak_rss_kb regression <= 20%:
  pass

20% < regression <= 50%:
  warning

regression > 50%:
  manual investigation
```

这些规则只用于 report，不自动 fail。

### 9.3 Baseline 文件

长期可新增：

```text
bench/runner/baselines/
  README.md
  smoke.native.macos-arm64.json
  smoke.native.linux-x64.json
```

但 baseline 必须带环境信息：

```text
OS
arch
MoonBit version
compiler target
commit
CPU model if available
RAM if available
MarkItDown version
```

没有环境信息的 baseline 不可信。

---

## 10. 与 correctness / quality 的边界

### 10.1 samples/check.sh

`samples/check.sh` 只做 correctness regression。

它不负责：

```text
计时
RSS
MarkItDown 对比
benchmark report
```

### 10.2 samples/check_quality.sh

`quality` bridge 负责 external_quality 质量对齐，不负责 benchmark。

### 10.3 benchmark 不判定质量

Benchmark 只记录：

```text
是否成功
输出大小
耗时
RSS
stderr
exit code
```

它不比较 Markdown 内容质量。

质量差异应通过：

```text
samples/check.sh
samples/check_quality.sh
quality-lab
manual review
```

处理。

---

## 11. 与 external_bench 的关系

`markitdown-quality-lab/external_bench` 的最终定位：

```text
历史来源池
候选样例池
未来 refresh source
```

正式 benchmark 不运行 external_bench 路径。

正式 benchmark 只运行：

```text
samples/bench/MANIFEST.tsv
samples/bench/<format>/<size_class>/<payload>
```

如果要从 external_bench 引入新样例，流程是：

```text
external_bench candidate
  ↓
copy into samples/bench
  ↓
record source_ref
  ↓
record sha256 / bytes
  ↓
commit tracked payload
```

---

## 12. 分层 Benchmark Matrix

### 12.1 Micro

```text
Target:
  input / format_readers / render / pipeline pass

Tool:
  moon bench

Data:
  tiny / small mostly

Output:
  console benchmark stats
```

### 12.2 Pipeline

```text
Target:
  parser registry
  parse result
  runtime bridge
  pipeline build
  renderer

Tool:
  moon bench

Data:
  smoke corpus

Output:
  console benchmark stats
```

### 12.3 Product In-process

```text
Target:
  convert API

Tool:
  moon bench

Data:
  smoke corpus

Output:
  console benchmark stats
```

### 12.4 CLI / External

```text
Target:
  built MoonBit CLI
  MarkItDown CLI

Tool:
  bench/runner MoonBit process runner

Data:
  smoke / regular / release / stress

Output:
  JSONL
  summary JSON
  Markdown report
```

---

## 13. Package Boundaries

### 13.1 Allowed Dependencies

`bench/*` may depend on:

```text
input
core
parser
formats
runtime
pipeline
render
convert
```

`bench/runner` may depend on:

```text
standard library
moonbitlang/async
moonbitlang/async/process
bench manifest parsing utilities if factored
native C stub
```

### 13.2 Forbidden Dependencies

主链禁止依赖：

```text
bench
bench/runner
C measurement stubs
MarkItDown tool wrapper
process runner
resource usage measurement
quality-lab
external_bench
```

`bench` 禁止依赖：

```text
bench/runner process runner
MarkItDown wrapper
C RSS stub
```

`bench/runner` 禁止修改：

```text
runtime behavior
product output
samples/bench payload
```

---

## 14. Native-only Policy

`bench/runner` 是 native-only。

理由：

```text
需要进程执行
需要文件系统
需要 C FFI
需要 wait4/getrusage 类平台 API
```

不支持：

```text
wasm
wasm-gc
js
browser
```

如果 MoonBit package 需要声明：

```text
supported-targets: native
```

---

## 15. Migration Plan

当前已有 P13-C Python / shell runner。目标架构要求完全删除该写法。迁移分三步：

### Phase D1：MoonBit process runner prototype

新增：

```text
bench/runner/moon.pkg
bench/runner/main.mbt
bench/runner/manifest/*
bench/runner/process/*
bench/runner/result/*
```

实现：

```text
读取 samples/bench/MANIFEST.tsv
选择 --tier smoke --limit 3
调用 built MoonBit CLI
调用 markitdown if available
输出 JSONL
```

此阶段可以暂不做 RSS，或者 RSS 返回 null。

### Phase D2：C FFI resource measurement

新增：

```text
bench/runner/measure/resource_usage_native.mbt
bench/runner/measure/resource_usage_native_stub.c
```

实现：

```text
fork/exec/wait4
wall time
user time
sys time
peak RSS
timeout
stdout/stderr bytes
output bytes
```

输出字段与 P13-C JSONL 兼容。

### Phase D3：Retire Python / shell runner

删除：

```text
bench/runner/*.py
bench/runner/*.sh
```

保留：

```text
bench/runner/README.md
bench/runner/moon.pkg
bench/runner/**/*.mbt
bench/runner/**/*_stub.c
bench/runner/schemas/*.json
```

README 更新：

```text
Python / shell runner retired.
Use release runner for formal benchmark commands.
Keep moon run bench/runner -- ... as dev smoke only.
```

目标命令：

```bash
moon build bench/runner --target native --release
moon build cli --target native --release
RUNNER="$(find _build/native/release -type f \( -name 'runner.exe' -o -name 'runner' \) | grep '/bench/runner/' | head -1)"
"$RUNNER" run --tool moonbit-cli --tier smoke --limit 3 --timeout-ms 60000
"$RUNNER" run --tool markitdown --tier smoke --limit 3 --timeout-ms 60000 --markitdown-path /Users/winter/miniconda3/bin/markitdown
"$RUNNER" compare --tier smoke --repeat 3 --timeout-ms 60000 --markitdown-path /Users/winter/miniconda3/bin/markitdown
"$RUNNER" report --input .tmp/bench/runs/<run_id>/results/<run>.jsonl
```

---

## 16. CLI UX

目标命令：

```bash
moon build bench/runner --target native --release
moon build cli --target native --release
RUNNER="_build/native/release/build/bench/runner/runner.exe"
"$RUNNER" select --tier smoke
"$RUNNER" run --tool moonbit-cli --tier smoke
"$RUNNER" run --tool markitdown --tier smoke --markitdown-path /Users/winter/miniconda3/bin/markitdown
"$RUNNER" compare --tier smoke --markitdown-path /Users/winter/miniconda3/bin/markitdown
"$RUNNER" report --input <result.jsonl>
```

dev-only：

```bash
moon run bench/runner -- help
moon run bench/runner -- diagnose-overhead --repeat 3
```

支持参数：

```text
--tier smoke|regular|release|stress
--format <format>
--limit <n>
--timeout-ms <ms>
--repeat <n>
--timeout-sec <sec>
--timeout-ms <ms>
--markitdown-path <path>
--tool moonbit-cli|moonbit-engine|markitdown
```

默认：

```text
tier = smoke
tool = moonbit-cli
timeout = 60000ms
result output = .tmp/bench/runs/<run_id>/results/<run_id>.jsonl
report output = .tmp/bench/runs/<run_id>/reports/<run_id>.md
```

---

## 17. Validation Commands

每次修改 benchmark 架构后，至少执行：

```bash
moon fmt
moon info
moon check

moon bench --target native --release --package bench/micro
moon bench --target native --release --package bench/pipeline
moon bench --target native --release --package bench/product

moon build bench/runner --target native --release
moon build cli --target native --release
RUNNER="$(find _build/native/release -type f \( -name 'runner.exe' -o -name 'runner' \) | grep '/bench/runner/' | head -1)"
test -n "$RUNNER"
"$RUNNER" help
"$RUNNER" diagnose-overhead --repeat 20
"$RUNNER" compare --tier smoke --format html --repeat 7 --timeout-ms 60000 --markitdown-path /Users/winter/miniconda3/bin/markitdown
"$RUNNER" compare --tier smoke --repeat 3 --timeout-ms 60000 --markitdown-path /Users/winter/miniconda3/bin/markitdown

moon run bench/runner -- help
moon run bench/runner -- diagnose-overhead --repeat 3

moon test tests
bash samples/check.sh --check-inventory
git diff --check -- . ':(exclude).tmp'
```

如果 MarkItDown 不可用：

```text
MarkItDown runner must report unavailable, not fail the whole validation.
```

---

## 18. Security / Safety

Process runner 必须：

```text
quote argv safely
never invoke through shell unless explicitly necessary
write outputs to /tmp or configured output dir
never overwrite input corpus
cap stdout/stderr excerpt
support timeout
kill child on timeout
reap child process
avoid leaking temp files
avoid recording sensitive absolute paths in committed reports
```

Benchmark report 默认不提交。

If report is committed for release, it must not include:

```text
private user path
full environment dump
unbounded stderr
temporary directory secrets
```

---

## 19. Future Extensions

可扩展方向：

```text
1. Batch benchmark:
   batch of 10 / 100 / mixed files

2. Assets benchmark:
   measure asset export overhead

3. Metadata / debug benchmark:
   compare normal vs debug JSON output

4. RAG benchmark:
   chunking throughput and source_ref overhead

5. PDF signal benchmark:
   native text / link / table candidate / header-footer candidate

6. Parallel benchmark:
   batch concurrency if product supports it

7. Cross-platform baseline:
   macOS arm64
   Linux x64
   Linux arm64

8. Release reports:
   tag-based benchmark report snapshots
```

---

## 20. Final Architecture Contract

最终 benchmark 体系必须满足：

```text
1. Corpus lives in samples/bench and is fully tracked.
2. Function-level benchmark lives in bench/ and uses moon bench.
3. CLI/external/process benchmark lives in bench/runner and is MoonBit-native.
4. Python and shell runners are retired from the primary architecture.
5. Resource measurement uses bench-only native C FFI when process API does not expose RSS.
6. C FFI never enters product runtime.
7. MarkItDown is optional external baseline, never a runtime dependency.
8. Benchmark results are soft reports, not default hard CI gates.
9. Correctness remains in samples/check.sh and quality bridge.
10. Benchmark never changes conversion semantics.
```

一句话总结：

```text
mb-markitdown 的 benchmark 体系不是脚本集合，而是 MoonBit-native 的性能观测层：
tracked corpus 提供稳定输入；
moon bench 测内部函数与分层成本；
MoonBit process runner 测真实 CLI 与外部工具；
C FFI 补齐 RSS / rusage；
报告层只提供证据，不替代 correctness gate。
```
