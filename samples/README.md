# Samples

`samples/` 是仓库内回归样本与验证入口。

这里主要有两类回归：

- 主回归：验证产品默认转换链路是否稳定。
- 质量回归：验证外部质量语料上的输出质量是否满足预期。

仓库内只保留轻量功能样例，用于主回归和单元级功能覆盖。
正式主回归、质量回归与 benchmark 都明确依赖主仓根目录下的 `./markitdown-quality-lab/`。性能使用方式见 [bench/README.md](/Users/winter/Documents/Moonbit/markitdown/bench/README.md)。

当前 `rst / asciidoc / tex` 主回归除了基础 heading / paragraph / code / table 之外，还覆盖一组更偏 canonical semantic inventory 的轻量样例，用于验证 field-or-attribute metadata、definition-like inventory、quote/admonition/include、以及 tex metadata/environment 的稳定输出。

## 主回归

主回归入口：

```bash
./samples/check.sh
```

默认会对主产品格式同时执行：

- Markdown 结果回归
- RAG 结果回归
- Assets 结果回归
- 显式 OCR lane 回归

这套回归不是纯 repo-local 检查；正式语料来自外仓 `markitdown-quality-lab/external_main_process/`。

支持格式：

`txt, csv, tsv, json, jsonl, ndjson, xml, yaml, html, markdown, zip, epub, docx, xlsx, pptx, pdf, wav, mp3, m4a, ocr`

常用命令：

```bash
./samples/check.sh
./samples/check.sh --format pdf
./samples/check.sh --markdown --format docx
./samples/check.sh --rag --format html
./samples/check.sh --assets --format epub
./samples/check.sh --check-inventory
./samples/check.sh --list-inventory
```

目录约定：

- `samples/fixtures/contracts/<format>/`：主仓离线 test 与保留 shell contract 需要的最小夹具
- `samples/fixtures/boundaries/<format>/`：高价值 malformed / fail-closed / safety 边界夹具
- `markitdown-quality-lab/external_main_process/<format>/<lane>/`：外仓主回归输入语料
- `markitdown-quality-lab/external_main_process/<format>/expected/<lane>/`：外仓主回归期望结果
- `markitdown-quality-lab/external_main_process/MANIFEST.tsv`：主回归唯一 enrollment 清单

运行产物位于 `.tmp/check/runs/<run_id>/`，重点看：

- `summary.md`
- `summary.tsv`
- `reports/failures/`
- `diff/`
- `raw/`

说明：

- 这套回归只测外仓主语料上的产品默认路径。
- `./samples/check.sh` 启动时会先确认外仓 manifest、enrollment 与运行目录，因此在真正开始逐行执行前出现一段准备时间是预期行为。
- 不支持的格式在这里会直接 fail closed，不会偷偷切换到其它路线。
- `ocr` gate 覆盖正式支持的直接图片 OCR 输入：`png/jpg/jpeg/bmp/webp/tif/tiff`。
- `pdf/ocr` lane 覆盖 `pdf --accurate` 与显式 `pdf --ocr` 的 OCR-only 产品路径，不改变默认 `pdf` native-text gate。
- `wav/mp3/m4a` gate 覆盖当前 native `whisper.cpp` audio transcript 接入面；`m4a` lane 额外依赖本地 `ffmpeg`。
- `workspace/` 只是临时工作目录，不作为主要排查入口。

## 质量回归

质量回归入口：

```bash
./samples/check_quality.sh
```

这套回归只使用主仓根目录下的外部质量语料 `./markitdown-quality-lab`，不回退到仓库内样本。

准备语料：

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

正式放置位置是主仓根目录下的 `./markitdown-quality-lab`。

常用命令：

```bash
./samples/check_quality.sh
./samples/check_quality.sh --format pdf
```

运行产物位于 `.tmp/quality/runs/<run_id>/`，重点看：

- `summary.md`
- `summary.tsv`
- `reports/`
- `diff/`
- `raw/`

说明：

- 这套回归面向外部质量语料，不替代主回归。
- `workspace/` 同样只作为临时目录。
- benchmark 语料与质量语料是两回事；正式 `bench v2` 默认使用主仓目录下的 `./markitdown-quality-lab/external_bench/`。
- ZIP 相关样例与主链实现建立在 `format_readers/zip` 之上，底层解压继续依赖 `bikallem/compress/flate`。

## 覆盖范围

主回归覆盖：

- 主产品支持格式的默认转换链路
- Markdown 输出稳定性
- RAG 输出结构与内容契约
- 轻量 assets 输出契约
- 样本清单完整性与 enrollment 完整性

质量回归覆盖：

- 外部质量语料上的实际输出质量
- 不同格式质量信号的通过、失败与跳过情况
- 外部语料与当前 CLI 能力边界的匹配情况

简化理解：

- 要看“产品主链路有没有回归”，跑 `./samples/check.sh`
- 要看“真实质量语料表现怎么样”，跑 `./samples/check_quality.sh`
