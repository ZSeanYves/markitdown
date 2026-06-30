# Samples

`samples/` 是仓库内回归样本与验证入口。

这里主要有两类回归：

- 主回归：验证产品默认转换链路是否稳定。
- 质量回归：验证外部质量语料上的输出质量是否满足预期。

仓库内只保留轻量功能样例，用于主回归和单元级功能覆盖。
如果要验证真实转换质量或 benchmark 性能，请先把 `markitdown-quality-lab/` 下载到主仓目录下。性能使用方式见 [bench/README.md](/Users/winter/Documents/Moonbit/markitdown/bench/README.md)。

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

支持格式：

`txt, csv, tsv, json, jsonl, ndjson, xml, yaml, html, markdown, zip, epub, docx, xlsx, pptx, pdf, ocr`

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

- `samples/main_process/<format>/markdown/`：默认产品路径输入样本
- `samples/main_process/pdf/ocr/`：PDF Accurate / OCR 路线输入样本
- `samples/main_process/<format>/expected/`：Markdown 期望结果
- `samples/main_process/<format>/rag/`：RAG 期望结果
- `samples/main_process/<format>/assets/`：轻量资源输出期望

运行产物位于 `.tmp/check/runs/<run_id>/`，重点看：

- `summary.md`
- `summary.tsv`
- `reports/failures/`
- `diff/`
- `raw/`

说明：

- 这套回归只测产品默认路径。
- 不支持的格式在这里会直接 fail closed，不会偷偷切换到其它路线。
- `ocr` gate 覆盖正式支持的直接图片 OCR 输入：`png/jpg/jpeg/bmp/webp/tif/tiff`。
- `pdf/ocr` lane 覆盖 `pdf --accurate` 与显式 `pdf --ocr` 的 OCR-only 产品路径，不改变默认 `pdf` native-text gate。
- `workspace/` 只是临时工作目录，不作为主要排查入口。

## 质量回归

质量回归入口：

```bash
./samples/check_quality.sh
```

这套回归只使用外部质量语料 `markitdown-quality-lab`，不回退到仓库内样本。

准备语料：

```bash
git clone git@github.com:ZSeanYves/markitdown-quality-lab.git markitdown-quality-lab
```

请把 `markitdown-quality-lab` 下载到主仓目录下。

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
- benchmark 语料与质量语料是两回事；正式 `bench v2` 使用主仓目录下的 `markitdown-quality-lab/external_bench/`。
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
