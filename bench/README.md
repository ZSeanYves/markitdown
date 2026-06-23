# Benchmark Harness

这个目录提供 MoonBit 原生 benchmark harness，只依赖仓库中已跟踪的
`samples/bench/` corpus，不引入外部 runner、结果基线或额外 payload。

当前分层：

- `bench/shared`：读取 `samples/bench/MANIFEST.tsv`、筛选 tier、定位 payload。
- `bench/micro`：小粒度 benchmark，例如格式探测、text-like 读取、Markdown 渲染。
- `bench/pipeline`：走 in-process convert API 的分层链路 benchmark。
- `bench/product`：默认只跑 smoke corpus 的产品级 smoke benchmark。
- `bench/runner`：process-level CLI / external baseline / RSS / report runner。

当前 `bench/pipeline` 除了总链路 `convert_total`，还包含多条阶段化 benchmark：

- `pipeline.txt.*`
- `pipeline.delimited.*`
- `pipeline.html.*`
- `pipeline.docx.*`
- `pipeline.pptx.*`
- `pipeline.xlsx.*`

默认 selector 只包含 `enabled_tier=smoke`，并且会排除：

- `source_kind=missing_candidate`
- `review_status=missing_candidate`
- `enabled_tier=disabled`
- `bytes=0`
- 缺失 payload

常用命令：

```bash
moon bench --target native --release --package bench/micro
moon bench --target native --release --package bench/pipeline
moon bench --target native --release --package bench/product
moon build bench/runner --target native --release
moon build cli --target native --release
RUNNER="$(find _build/native/release -type f \( -name 'runner.exe' -o -name 'runner' \) | grep '/bench/runner/' | head -1)"
"$RUNNER" select --tier smoke --limit 3
"$RUNNER" compare --tier smoke --repeat 3 --timeout-ms 60000 --markitdown-path /Users/winter/miniconda3/bin/markitdown
"$RUNNER" run --tool moonbit-engine --tier smoke --format html --repeat 7 --engine-output-mode memory --timeout-ms 60000
```

说明：

- benchmark 名称会稳定包含 tier、format 或 `bench_id`，便于后续结果归档。
- 本目录不修改 `samples/bench` corpus，也不让生产包依赖 `bench/`。
- `moon run bench/runner -- ...` 只保留给 dev smoke / help / quick validation，不作为正式性能结论来源。
- release runner 的 canonical compare 默认保留真实 output 行为；engine `memory` / `none` 仅用于 output attribution 诊断。
