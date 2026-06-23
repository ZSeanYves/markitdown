# MoonBit Benchmark Toolchain

`bench/runner` 是 MoonBit-native 的 benchmark process runner。
它是当前唯一的正式 benchmark process runner 路径。

- `samples/bench/`：tracked benchmark corpus
- `bench/`：MoonBit in-process benchmark harness
- `bench/runner/`：CLI baseline、in-process engine baseline、外部 `markitdown` baseline、结果汇总

它负责：

- MoonBit CLI baseline
- MoonBit in-process engine baseline
- MarkItDown external baseline
- process-level wall time
- user / sys time
- peak RSS via native C FFI
- runner/CLI fixed-overhead diagnostics
- JSONL result
- summary JSON
- Markdown report

默认行为：

- 默认 tier 是 `smoke`
- 默认 repeat 是 `1`
- 默认 timeout 是 `60000ms`
- 不做 hard performance gate
- `markitdown` baseline 缺失时记录 `unavailable`，不会让整个 compare 失败
- `markitdown` 是 optional external dependency
- results / reports 默认 ignored
- `--timeout-sec` 保留为 human-friendly alias

## Runner Modes

从 P14-I 开始，`bench/runner` 明确区分两种使用方式：

- `release`：canonical performance mode，用于正式 benchmark、speedup、fixed overhead、report 结论
- `dev_moon_run`：dev smoke / help / quick validation / local debugging

正式 benchmark 口径必须来自 prebuilt release runner。`moon run bench/runner -- ...` 不再作为正式性能结论来源，因为它会引入开发态包解析 / 构建 / 启动路径，尤其会扭曲 in-process engine timing 与 fixed-overhead 计算。

如果 runner mode 无法自动识别，可通过环境变量覆盖：

```bash
MARKITDOWN_BENCH_RUNNER_MODE=release
MARKITDOWN_BENCH_RUNNER_MODE=dev_moon_run
MARKITDOWN_BENCH_RUNNER_MODE=unknown
```

## Canonical Benchmark Recipe

先构建 release runner 与 release CLI：

```bash
moon build bench/runner --target native --release
moon build cli --target native --release
```

推荐用固定路径：

```bash
RUNNER="_build/native/release/build/bench/runner/runner.exe"
test -n "$RUNNER"
"$RUNNER" help
```

如果实际产物路径不同，使用 fallback 发现命令：

```bash
RUNNER="$(find _build/native/release -type f \( -name 'runner.exe' -o -name 'runner' \) | grep '/bench/runner/' | head -1)"
test -n "$RUNNER"
"$RUNNER" help
```

正式性能命令统一使用：

```bash
"$RUNNER" select --tier smoke --limit 3

"$RUNNER" run \
  --tool moonbit-cli \
  --tier smoke \
  --limit 3 \
  --repeat 3 \
  --cli-output-mode file \
  --timeout-ms 60000

"$RUNNER" run \
  --tool moonbit-engine \
  --tier smoke \
  --limit 3 \
  --repeat 3 \
  --engine-output-mode file \
  --timeout-ms 60000

"$RUNNER" run \
  --tool moonbit-engine \
  --tier smoke \
  --format html \
  --repeat 7 \
  --engine-output-mode memory \
  --timeout-ms 60000

"$RUNNER" run \
  --tool moonbit-engine \
  --tier smoke \
  --format html \
  --repeat 7 \
  --engine-output-mode none \
  --timeout-ms 60000

"$RUNNER" run \
  --tool markitdown \
  --tier smoke \
  --limit 3 \
  --repeat 3 \
  --timeout-ms 60000 \
  --markitdown-path /Users/winter/miniconda3/bin/markitdown

"$RUNNER" compare \
  --tier smoke \
  --repeat 3 \
  --timeout-ms 60000 \
  --markitdown-path /Users/winter/miniconda3/bin/markitdown

"$RUNNER" compare \
  --tier smoke \
  --format html \
  --repeat 7 \
  --timeout-ms 60000 \
  --markitdown-path /Users/winter/miniconda3/bin/markitdown

"$RUNNER" diagnose-overhead --repeat 20

"$RUNNER" report --input bench/runner/results/<run>.jsonl
```

## Dev Smoke Only

`moon run bench/runner -- ...` 仍然保留，但仅用于：

- `help` smoke
- command parser smoke
- quick local validation
- local debugging

示例：

```bash
moon run bench/runner -- help
moon run bench/runner -- diagnose-overhead --repeat 3
moon run bench/runner -- compare --tier smoke --format html --repeat 1 --timeout-ms 60000
```

不要把 dev-mode 结果用于：

- formal speedup report
- CLI vs engine speedup source
- fixed overhead calculation source
- release comparison source

## 运行说明

MoonBit CLI baseline 优先测 built binary：

```bash
moon build cli --target native --release
```

若 `_build/native/release/build/cli/cli.exe` 存在，会直接测 built binary。否则当前实现会把 `moonbit-cli` 标记为不可用，提醒先构建。

`moonbit-engine` baseline 不 fork CLI。

- 它在 `bench/runner` 进程内读取 input
- 直接调用 `convert_input`
- 默认 `--engine-output-mode file` 会把 Markdown 输出和本地 assets 写到 `.tmp/markitdown-bench-output/...`
- `--engine-output-mode memory` 只保留 Markdown 到内存，用于归因 output sink 成本
- `--engine-output-mode none` 仍保留 render，只跳过最终 sink write，用于诊断归因，不代表用户可见产品路径
- compare 的 canonical 默认仍然是 CLI `file` 和 engine `file`

MarkItDown baseline 支持四级发现顺序：

1. CLI 显式参数 `--markitdown-path <path>`
2. 环境变量 `MARKITDOWN_BIN=<path>`
3. `PATH` lookup
4. fallback 路径

fallback 路径当前为：

- `/usr/local/bin/markitdown`
- `/opt/homebrew/bin/markitdown`
- `/Users/winter/miniconda3/bin/markitdown`

显式参数和 `MARKITDOWN_BIN` 都是强指定：

- 路径不存在或不可执行时，会生成 `status = "unavailable"` 的结果行
- `error` 字段会记录明确原因
- 不会静默 fallback 到其他路径

自动发现（`PATH` / fallback）找不到时，也会生成 `status = "unavailable"` 的结果行，而不是中断整个 run 或 compare。

如果需要固定 MarkItDown baseline，推荐使用下面两种方式之一：

```bash
"$RUNNER" run \
  --tool markitdown \
  --tier smoke \
  --limit 3 \
  --timeout-ms 60000 \
  --markitdown-path /Users/winter/miniconda3/bin/markitdown

MARKITDOWN_BIN=/Users/winter/miniconda3/bin/markitdown \
"$RUNNER" compare --tier smoke --limit 3 --timeout-ms 60000
```

结果 JSONL 的 `tool_version` 会记录已解析的 tool path 和来源，例如 `path=/Users/winter/miniconda3/bin/markitdown;source=path`。
CLI 同时支持 `--timeout-ms` 和 `--timeout-sec`；若同时传入会报参数错误，避免结果歧义。
`--repeat N` 会让每个 `bench_id + tool` 运行 `N` 次。原始 JSONL 会保留每次观测，并记录：

- `repeat_index`
- `repeat_count`

summary / report 会按 `bench_id + tool` 聚合成功观测，输出：

- `median_wall_ms`
- `min_wall_ms`
- `max_wall_ms`
- `median_wall_us`
- `min_wall_us`
- `max_wall_us`
- `median_peak_rss_kb`

跨工具对比现在区分三种口径：

```text
CLI speedup = markitdown_median_wall_us / moonbit_cli_median_wall_us
Engine speedup = markitdown_median_wall_us / moonbit_engine_median_wall_us
Fixed overhead = moonbit_cli_median_wall_us - moonbit_engine_median_wall_us
Fixed share = fixed_overhead_us / moonbit_cli_median_wall_us
```

说明：

- 原始 JSONL 同时保留 `wall_ms` 和 `wall_us`
- `wall_ms` 是 rounded compatibility/display 字段
- `wall_us` 是 summary / speedup / fixed-overhead 的首选计算基准
- 原始 JSONL / summary JSON 会记录 `runner_mode`、`canonical_performance`、`runner_path`
- report 会在 `runner_mode != release` 时给出 warning
- 如果输入是旧的 `wall_ms`-only JSONL，summary/report 会 fallback 到 `wall_ms`，并标记 `timing_precision = ms_fallback`
- 只有当所需工具行的聚合状态都为 `ok`，并且分母 wall time 大于 `0` 时，才会计算 speedup / fixed share

原始 JSONL 会额外记录：

- `runner_mode`: `release` / `dev_moon_run` / `unknown`
- `canonical_performance`: `true` / `false`
- `runner_path`: resolved runner executable path when known
- `measurement_mode`: `process-cli` 或 `inprocess-engine`
- `output_write_mode`: `file` / `stdout_capture` / `memory` / `none`
- `wall_ms`: rounded wall clock milliseconds
- `wall_us`: precise wall clock microseconds

这让 summary/report 可以同时展示：

- `MoonBit CLI vs MarkItDown`
- `MoonBit engine vs MarkItDown`
- `MoonBit CLI vs MoonBit engine`

同时把“是否可作为正式性能结论”显式保留下来。

output mode 解释：

- CLI canonical speedup 必须包含真实输出行为；当前 compare 默认测 CLI `file`
- CLI `stdout_capture` 是诊断模式，用于估算 stdout/capture 成本，不应替代 canonical CLI 结论
- engine `memory` / `none` 也是诊断模式，只用于归因，不应冒充 CLI 用户路径速度

## Fixed Overhead Diagnostics

`diagnose-overhead` 用于估算固定成本，不改变产品行为。
正式固定成本口径必须来自 release runner：

```bash
"$RUNNER" diagnose-overhead --repeat 20 --cli-output-mode file --engine-output-mode file
```

dev smoke only：

```bash
moon run bench/runner -- diagnose-overhead --repeat 3
```

当前会测：

- `measurement_noop`
- `process_true`
- `process_echo_empty`
- `moonbit_cli_help`
- `moonbit_cli_tiny_txt`
- `moonbit_cli_small_html`
- `moonbit_engine_tiny_txt`
- `moonbit_engine_small_html`

它会输出：

- `bench/runner/results/<run-id>-overhead.jsonl`
- `bench/runner/reports/<run-id>-overhead.md`

当 runner mode 不是 `release` 时，overhead report 会明确警告：

- this run is not marked as release runner mode
- in-process engine timing under moon run/dev mode can be distorted

## 输出位置

结果文件：

- `bench/runner/results/<run-id>-moonbit-cli-<tier>.jsonl`
- `bench/runner/results/<run-id>-moonbit-engine-<tier>.jsonl`
- `bench/runner/results/<run-id>-markitdown-<tier>.jsonl`
- `bench/runner/results/<run-id>-summary.json`
- `bench/runner/results/<run-id>-selector-stats.json`
- `bench/runner/results/<run-id>-overhead.jsonl`

其中 `selector-stats.json` 会记录本次选择的 `requested_tier`。summary / report 的
顶层 corpus tier 会优先使用这个值，而不是从第一条结果行的 `enabled_tier`
反推。

报告文件：

- `bench/runner/reports/<run-id>.md`
- `bench/runner/reports/<run-id>-overhead.md`

转换输出和临时 stdout/stderr：

- `.tmp/markitdown-bench-output/<run-id>/<tool>/<bench_id>.md`
- `.tmp/markitdown-bench-output/<run-id>/<tool>/<bench_id>.md.stdout`
- `.tmp/markitdown-bench-output/<run-id>/<tool>/<bench_id>.md.stderr`

当 `repeat > 1` 时，输出文件会带 repeat suffix，例如：

- `.tmp/markitdown-bench-output/<run-id>/<tool>/<bench_id>-repeat-1.md`
- `.tmp/markitdown-bench-output/<run-id>/<tool>/<bench_id>-repeat-2.md.stdout`
- `.tmp/markitdown-bench-output/<run-id>/<tool>/<bench_id>-repeat-3.md.stderr`

## 报告结构

Markdown report 当前会输出：

- `Warnings`
- `Comparison Coverage`
- `Tool Summary`
- `Speedup Summary`
- `By Format`
- `Fixed Overhead Summary`
- `Lowest CLI Speedup Rows`
- `Lowest Engine Speedup Rows`
- `External Baseline Non-OK Rows`
- `MoonBit Non-OK Rows`
- `Slowest MoonBit Rows`
- `Highest RSS Rows`
- `First Optimization Candidates`

其中：

- `Environment` 会显示 `runner_mode`、`canonical_performance`、`runner_path`
- `Warnings` 会在 non-release runner 时说明该结果不应用于正式性能结论，也会提示 external baseline partial 情况只影响 comparable rows，不自动代表 MoonBit 回归
- `Comparison Coverage` 会同时展示 selected rows、comparable rows、各工具 ok rows，以及 external-only gap rows
- `By Format` 同时汇总 CLI / engine / MarkItDown 三方 median wall、两类 speedup、fixed overhead，以及每个 format 的 cli/engine/external ok row 计数
- `Fixed Overhead Summary` 展示每个 bench 的 CLI median、engine median、fixed overhead、fixed share
- `Lowest CLI Speedup Rows` 只展示 CLI vs MarkItDown 都成功的 rows
- `Lowest Engine Speedup Rows` 只展示 engine vs MarkItDown 都成功的 rows
- `External Baseline Non-OK Rows` 会列出 external baseline 非 `ok` 的 bench rows，便于区分 external failure 与 MoonBit failure
- `MoonBit Non-OK Rows` 会单独列出 MoonBit CLI 或 engine 非 `ok` 的 bench rows
- `Slowest MoonBit Rows` 用 MoonBit 聚合 median wall 排序
- `Highest RSS Rows` 跨工具按聚合 median RSS 排序
- wall 时间默认显示为 `x.xxx ms (N us)`；旧数据 fallback 时只显示 `ms`

## 平台说明

原生测量由 `measure/resource_usage_native_stub.c` 负责 `fork/exec/wait4` 和 `rusage` 采集。

- 输出统一使用 `peak_rss_kb`
- macOS 上 `ru_maxrss` 会先从 bytes 归一化到 KiB
- timeout 会杀掉子进程并回收，结果行记为 `status = "timeout"`
- RSS 口径存在平台 caveat
- in-process engine 行不使用 `wait4/getrusage`，而是使用 MoonBit monotonic clock
- Python / shell runner 已退役
