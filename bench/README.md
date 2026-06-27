# Benchmark Harness v2

正式 benchmark 已切换到 `bench v2`，并且遵守两个硬约束：

- 不依赖 `moon bench`
- 不依赖 `moon run`

正式调度只能使用 release 产物：

- `_build/native/release/build/bench/runner/runner.exe`
- `_build/native/release/build/cli/cli.exe`

## 结构

- `samples/bench/MANIFEST.tsv`
  只负责 corpus 身份与 provenance。
- `bench/config/policy.json`
  是 benchmark 行为事实源。
- `bench/runner`
  是唯一正式 benchmark 入口。

正式结果根目录固定为：

```bash
.tmp/bench/v2/runs/<run_id>/
```

每次 run 产出：

- `results/samples.jsonl`
- `results/cases.jsonl`
- `results/summary.json`
- `reports/report.md`

## 正式命令

先构建 release binary：

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
```

常用命令：

```bash
_build/native/release/build/bench/runner/runner.exe catalog rows --tiers regular,release,stress --limit 3
_build/native/release/build/bench/runner/runner.exe catalog scenarios
_build/native/release/build/bench/runner/runner.exe doctor
_build/native/release/build/bench/runner/runner.exe run --preset official-internal --limit 3
_build/native/release/build/bench/runner/runner.exe run --preset official-compare --limit 3 --markitdown-path /path/to/markitdown
_build/native/release/build/bench/runner/runner.exe run --scenario diagnostic.markdown --bench-id markdown_huge_synthetic_book_v1
_build/native/release/build/bench/runner/runner.exe report --run <run_id> [--baseline <run_id>]
```

## 官方口径

- `official-internal`
  测 `moonbit-cli` 和 `moonbit-engine`
- `official-compare`
  测 `moonbit-cli`、`moonbit-engine`、`markitdown`

两者默认都使用：

- tiers: `regular,release,stress`
- order: `row_major_interleaved`
- `warmup=1`
- `repeat=3`

## 可信度约束

以下任一条件不满足，正式 run 直接不可信：

- runner 不是 release `runner.exe`
- CLI 不是 release `cli.exe`
- 调度链使用 `moon` 转调 benchmark
- MoonBit 行缺失 route provenance

MoonBit CLI 行会通过 `--provenance-out` 写 sidecar，runner 会把 route facts 写进
`samples.jsonl` 与 `cases.jsonl`。

## 当前状态

- `bench/micro`
- `bench/pipeline`
- `bench/product`

都已从正式 benchmark 体系移除。
