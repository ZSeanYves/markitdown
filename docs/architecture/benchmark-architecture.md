# mb-markitdown Benchmark Architecture v2

## 0. Purpose

`bench v2` exists to measure the real product routes defined by
`docs/architecture/mb-markitdown-architecture.md`.

正式 benchmark 的第一原则不是“能跑”，而是：

- 测量路径必须忠实于产品 route selection
- 正式调度必须是 release binary-only
- 结果必须带完整 route provenance

## 1. Hard Constraints

正式 benchmark 体系完全禁止：

- `moon bench`
- `moon run`

唯一正式 orchestrator：

- `_build/native/release/build/bench/runner/runner.exe`

唯一正式 MoonBit CLI 被测对象：

- `_build/native/release/build/cli/cli.exe`

若 runner 不是 release binary、CLI 不是 release binary、或 benchmark 调度链使用
`moon` 转调，则该 run 直接 `trust_status=failed`。

## 2. Top-Level Model

`bench v2` 只有三层事实源：

1. `samples/bench/MANIFEST.tsv`
   只负责 corpus identity。
2. `bench/config/policy.json`
   负责 scenario、preset、tool matrix、row policy。
3. `bench/runner`
   负责 catalog、planning、execution、result、report。

旧的：

- `bench/micro`
- `bench/pipeline`
- `bench/product`

都不再属于正式 benchmark 主路径。

## 3. Scenario-First Execution

runner 先展开：

```text
scenario x row x tool
```

再生成 measurement case。

当前正式 preset：

- `official-internal`
- `official-compare`
- `doctor`

当前内建诊断 / 参考 scenario：

- `diagnostic.markdown`
- `diagnostic.html`
- `diagnostic.xml`
- `diagnostic.xlsx`
- `diagnostic.epub`
- `diagnostic.zip`

## 4. Route Fidelity Contract

产品侧必须提供：

- `plan_input(source, options) -> RoutePlan`
- `convert_input_with_provenance(source, options) -> ConvertExecution`

`RoutePlan` 至少记录：

- `detected_format`
- `selected_route`
- `route_reason`
- `route_probe_summary`
- `requested_parser_mode`

`ConvertProvenance` 至少记录：

- `route_plan`
- `effective_parser_mode`
- `parse_result_kind`
- `pipeline_output_kind`
- `render_input_kind`
- `route_fidelity_status`

MoonBit 正式 benchmark 行若缺少这些字段，不是 warning，而是 trust failure。
同样，若 `route_fidelity_status != matched`，或 `expected_route != actual_route`，
也必须直接视为 trust failure。

## 5. Measurement Rules

正式 preset 默认：

- order: `row_major_interleaved`
- `warmup=1`
- `repeat=3`

`doctor` 默认：

- `warmup=5`
- `repeat=20`

`moonbit-engine` 允许 in-process，但只能在 release runner 内部执行，并明确标记为
`measurement_mode=inprocess-engine`。

## 6. Result Protocol

正式结果根目录固定为：

```text
.tmp/bench/v2/runs/<run_id>/
```

结果协议固定三层：

1. `samples.jsonl`
2. `cases.jsonl`
3. `summary.json` + `report.md`

`summary.json` 必须显式记录：

- `binary_only_contract`
- `trust_status`
- gate summary
- route coverage summary
- truth summary
- per-scenario summary
- baseline diff（如提供）

## 7. Official Views

`official-internal` 只服务 MoonBit 内部优化判断：

- MoonBit CLI / engine median
- route coverage
- non-ok rows
- baseline diff

`official-compare` 只服务外部对标口径：

- CLI / engine speedup
- by-format speedup
- comparable coverage
- excluded or non-ok rows

官方 KPI 与诊断视图必须分离，不能再把 block-stream / stream family 强行量成
whole-document 路径。

## 8. Current Cutover

本次切换已确定：

- 正式 benchmark 主路径移除 `moon bench`
- 正式 benchmark 主路径移除 `moon run`
- `bench/micro` / `bench/pipeline` / `bench/product` 删除
- runner help / README / 结果路径切到 v2

剩余工作只允许继续在 v2 主路径上收敛，不再维护 v1 兼容层。
