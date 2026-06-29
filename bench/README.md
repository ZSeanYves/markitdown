# Benchmark Harness v2

`bench v2` 是仓库里唯一正式 benchmark 入口。

它只做一件事：用 release binary 测真实产品路径，并把结果和可信度一起落盘。

## 约束

- 不使用 `moon bench`
- 不使用 `moon run`
- runner 必须是 release:
  `_build/native/release/build/bench/runner/runner.exe`
- CLI 必须是 release:
  `_build/native/release/build/cli/cli.exe`
- `official-*` 只测产品默认路径

## 准备

先构建 release binary：

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
```

先做契约检查：

```bash
_build/native/release/build/bench/runner/runner.exe doctor
```

## 常用命令

| 用途 | 命令 |
| --- | --- |
| 查看场景 | `_build/native/release/build/bench/runner/runner.exe catalog scenarios` |
| 查看正式语料 | `_build/native/release/build/bench/runner/runner.exe catalog rows --tiers regular,release,stress` |
| 跑内部正式口径 | `_build/native/release/build/bench/runner/runner.exe run --preset official-internal` |
| 跑外部对标 | `_build/native/release/build/bench/runner/runner.exe run --preset official-compare --markitdown-path /path/to/markitdown` |
| 按场景定向跑 | `_build/native/release/build/bench/runner/runner.exe run --scenario diagnostic.html --bench-id html_huge_synthetic_articles_v1` |
| 重生成报告 | `_build/native/release/build/bench/runner/runner.exe report --run <run_id> [--baseline <run_id>]` |

常用参数：

- `--preset <name>`
- `--scenario <scenario_id>`
- `--tiers regular,release,stress`
- `--bench-id <id[,more]>`
- `--format <fmt[,more]>`
- `--limit <N>`
- `--repeat <N>`
- `--warmup <N>`
- `--timeout-ms <N>`
- `--markitdown-path <path>`
- `--baseline <run_id>`

说明：

- `--preset` 和 `--scenario` 二选一
- `run --preset ...` 会展开 preset 下全部 `scenario_ids`
- 一个 run 可以包含多个 scenario

## Preset

| preset | scenarios | tools | 用途 |
| --- | --- | --- | --- |
| `official-internal` | `product.official_internal` + `diagnostic.markdown/html/xml/xlsx/epub/zip` | `moonbit-cli`, `moonbit-engine` | 内部性能、路径证明、重点格式诊断 |
| `official-compare` | `compare.official_compare` | `moonbit-cli`, `moonbit-engine`, `markitdown` | 外部性能对标 |
| `doctor` | `doctor.binary_contract` | `moonbit-cli`, `moonbit-engine`, `markitdown` | 二进制契约检查 |

当前场景：

- `product.official_internal`
- `compare.official_compare`
- `doctor.binary_contract`
- `diagnostic.markdown`
- `diagnostic.html`
- `diagnostic.xml`
- `diagnostic.xlsx`
- `diagnostic.epub`
- `diagnostic.zip`

默认参数：

- official presets:
  `tiers=regular,release,stress`
- `repeat=3`
- `warmup=1`
- `timeout_ms=60000`
- order:
  `row_major_interleaved`

## 覆盖范围

当前正式覆盖这些格式：

- `txt`
- `csv`
- `tsv`
- `json`
- `yaml`
- `xml`
- `markdown`
- `html`
- `zip`
- `epub`
- `pdf`
- `docx`
- `pptx`
- `xlsx`

口径分工：

- `official-internal`
  产品口径 + CLI/engine 对照 + 路径证明
- `official-compare`
  用同一批正式语料做三方性能对比
- `diagnostic.*`
  重点格式诊断

`catalog rows` 返回的语料字段包括：

- `bench_id`
- `format`
- `size_class`
- `enabled_tier`
- `input_bytes`
- `sha256`
- `bench_layers`
- `tags`
- `source_kind`
- `source_ref`

## 输出

每次 run 固定写到：

```text
.tmp/bench/v2/runs/<run_id>/
```

主要文件：

- `results/samples.jsonl`
  原始 sample 数据
- `results/cases.jsonl`
  聚合后的 case 数据
- `results/summary.json`
  最重要的机器可读结果
- `reports/report.md`
  最重要的人读结果

## 结果怎么看

先看 `summary.json`：

- `trust_status`
  这轮 run 是否可信
- `gate_summary`
  这轮 run 是否形成可比集
- `route_coverage_summary`
  预期 route 是否覆盖到
- `truth_summary`
  为什么可信，或为什么失败
- `tools`
  每个工具的行数、成功数、中位数
- `by_format`
  每个格式的可比覆盖和 speedup

对 `official-compare`，重点看：

- `cli_geomean_speedup`
- `engine_geomean_speedup`

含义都是 `markitdown 时间 / MoonBit 时间`，数值越大说明 MoonBit 越快。

## 可信度规则

以下任一条件不满足，MoonBit case 直接判为 `trust_status=failed`：

- runner 不是 release `runner.exe`
- CLI 不是 release `cli.exe`
- 调度链使用 `moon` 转调
- MoonBit 行缺失完整 provenance
- `route_fidelity_status != matched`
- `expected_route != actual_route`
- 结构化大样本命中 low-density guard

MoonBit provenance 至少要求：

- `route_plan.selected_route`
- `route_plan.route_reason`
- `route_plan.route_probe_summary`
- `effective_parser_mode`
- `parse_result_kind`
- `pipeline_output_kind`
- `render_input_kind`
- `route_fidelity_status`

说明：

- `route_coverage_status` 只回答是否覆盖到预期 route
- `trust_status` 还会综合 provenance completeness、fidelity 和 semantic density
- `markitdown` 不参与 MoonBit 的 provenance trust 判定

## 官方口径

`official-internal` 用来看 MoonBit 内部性能、CLI / engine 一致性，以及 route coverage / fidelity 是否成立。

`official-compare` 用来看 MoonBit 对 `markitdown` 的速度对标。它可能因为外部工具失败而出现 `gate_status=partial`。

也就是说，`trust_status=trusted` 只代表 MoonBit 路径证明成立；compare 是否完整，还要看 `gate_summary` 和 `by_format[].status`。

## 示例

完整 `official-internal`：

- run id: `run-1782735690781-26`
- `selected_rows=52`
- `comparable_rows=52`
- `trust_status=trusted`

完整 `official-compare`：

- run id: `run-1782730945277-57`
- `trust_status=trusted`
- `selected_rows=36`
- `comparable_rows=27`
- `gate_status=partial`
- overall CLI speedup vs markitdown: `11.10x`
- overall engine speedup vs markitdown: `13.95x`

## 不再支持

当前 v2 不再支持：

- policy 驱动的 convert options 实验
- `inner_loop.*` benchmark
- 旧 compare/profile/overhead/inprocess 链
- legacy result protocol 兼容
