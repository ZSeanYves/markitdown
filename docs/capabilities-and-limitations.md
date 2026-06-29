# Capabilities And Limitations

`markitdown-mb` 当前已经全面迁移到统一的 `v2` 主架构：`input -> parser -> pipeline -> render`。

这意味着当前产品路径的核心特点是：

- 所有正式格式都走统一主链，而不是多套历史分支并存
- 输出不仅是 Markdown，还保留更丰富的语义、诊断、source ref 与 provenance 事实
- benchmark、主回归、质量回归围绕同一条产品路径工作
- 不支持的能力直接 fail closed，不用隐藏 fallback 掩盖边界

这份文档面向两个问题：

- 现在各格式到底支持到了什么地步
- 哪些能力已经正式可用，哪些仍然缺失或明确不承诺

## 1. 产品边界

项目最初灵感来自微软的 `MarkItDown`：把多种常见文档格式转换成稳定、可消费的 Markdown。

当前实现不是对原项目的逐项复刻，而是一个更偏工程化的 MoonBit-first 实现，重点在于：

- 单一正式产品路径
- 更丰富的中间语义
- 更严格的 provenance / route fidelity / benchmark trust gate
- 更清晰的支持矩阵与 fail-closed 边界

## 2. 主 CLI 正式支持格式

主 CLI 当前正式支持：

| 格式族 | 扩展名 / 入口 | 当前正式状态 |
| --- | --- | --- |
| Plain text | `txt` | 正式支持 |
| Delimited text | `csv`, `tsv` | 正式支持 |
| Structured text | `json`, `jsonl`, `ndjson`, `xml`, `yaml`, `yml` | 正式支持 |
| Web / markup | `html`, `htm`, `markdown`, `md` | 正式支持 |
| Containers | `zip`, `epub` | 正式支持 |
| Office | `docx`, `xlsx`, `pptx` | 正式支持 |
| PDF | `pdf` | 正式支持，当前仅 native-text PDF |

明确不属于当前正式支持矩阵的输入：

- 扫描版 / 图片型 PDF
- `pdf --ocr`
- 默认图片输入
- 其它未列出格式

## 3. 能力总览

| 格式 | 当前主路径 | 已正式支持 | 当前缺失 / 不承诺 |
| --- | --- | --- | --- |
| `txt` | `streaming_event` | 段落、基础文本输出、RAG、debug、bench | 富语义来源天然有限 |
| `csv` / `tsv` | `streaming_event` | 表格型输出、RAG、debug、bench | 不做 Excel 级公式 / 样式语义 |
| `json` / `jsonl` / `ndjson` | `dom_ast_model` 或 `streaming_event` | 小中样本结构化输出、大样本 streaming、RAG、debug | 不追求完整 JSON editor 语义 |
| `xml` | `streaming_event` | 结构化输出、streaming、RAG、debug | 不做完整 schema-aware 语义 |
| `yaml` | `document` | 映射 / 列表 / 表格型输出、RAG、debug | 不承诺覆盖全部 YAML 高阶方言 |
| `markdown` | `block_streaming` | Markdown 读取、frontmatter passthrough、debug、RAG | 不承诺成为 CommonMark 全功能编辑器 |
| `html` | `block_streaming` | 标题、段落、列表、表格、图片、链接、RAG、assets | 不做浏览器级视觉布局恢复 |
| `zip` | `package_single_pass` | 容器扫描、路径安全、子文档派发、assets | 不做任意二进制内容解释 |
| `epub` | `package_single_pass` | OPF/spine 顺序、章节派发、局部资源 materialization、RAG | 不做远程资源抓取，不做阅读器级完整语义 |
| `docx` | `package_single_pass` | Office 文档主块、链接、图片、debug source refs、RAG | 不承诺覆盖 Word 全部高级版式语义 |
| `xlsx` | `package_single_pass` | sheet 读取、表格型输出、hidden sheet policy、公式缓存保留、debug | 不执行公式，不做 Excel 计算引擎 |
| `pptx` | `package_single_pass` | slide 顺序、列表、图片、speaker notes、hidden slide policy、debug | 不做完整演示视觉布局重建 |
| `pdf` | `page_single_pass` | native-text 提取、基础清理、显式 opt-in cleanup/table signals、RAG、debug | 扫描 PDF、`pdf --ocr`、layout-two-stage 仍未开放 |

## 4. 逐格式能力

### 4.1 TXT

当前状态：

- 正式支持
- 默认走轻量文本主链
- 支持 Markdown 输出、RAG 输出、debug JSON

特点：

- 适合中大文本文件
- 在 benchmark 中对大文本样本有稳定表现
- 输出语义以段落和基础块结构为主

当前不承诺：

- 富版式恢复
- 外部文档元数据推断

### 4.2 CSV / TSV

当前状态：

- 正式支持
- 默认走 streaming 主链

已验证能力：

- 基础表格转 Markdown
- repo-local 主回归样本覆盖
- RAG 输出
- benchmark 正式纳入

当前不承诺：

- Excel 公式执行
- 单元格样式、批注、图表这类工作簿级语义

### 4.3 JSON / JSONL / NDJSON

当前状态：

- 正式支持
- 根据样本复杂度在 `dom_ast_model` 与 `streaming_event` 之间选择

已验证能力：

- 中小 JSON 可保留更丰富的结构化语义
- 大 JSON / huge JSON 可转入 streaming 路径
- `json_medium_spdx_licenses_v1` 这类样本上，MoonBit 路径可以稳定完成转换

当前已知事实：

- 在 `run-1782740391274-133` 中，`json_medium_spdx_licenses_v1` 上：
  - `moonbit-cli` 成功 `3/3`
  - `moonbit-engine` 成功 `3/3`
  - `markitdown` 成功 `0/3`
  - compare gate 因 baseline 无法形成可比集而失败

这说明在部分中高压结构化文本样本上，MoonBit 路径仍可稳定完成转换，而外部 baseline 可能无法形成完整可比结果。

当前不承诺：

- 通用 JSON 查询语言
- 所有 schema 的强语义解释

### 4.4 XML

当前状态：

- 正式支持
- 默认走 streaming/event 主链

已验证能力：

- 基础 XML 结构转 Markdown
- 大 XML benchmarking
- 主回归与 diagnostic 覆盖

当前不承诺：

- 全量 schema-aware 语义恢复
- 专用行业 XML 标准的深度业务解释

### 4.5 YAML / YML

当前状态：

- 正式支持
- 走 document 语义路径

已验证能力：

- mapping / nested mapping
- flow collections
- metadata-like 输出
- RAG 输出

当前不承诺：

- 覆盖 YAML 所有边缘语法与方言
- 复杂 anchor / alias 的产品级富语义展开承诺

### 4.6 Markdown

当前状态：

- 正式支持
- 走 block-streaming 主链

已验证能力：

- heading / paragraph / list 基础块结构
- frontmatter passthrough
- debug diagnostics
- RAG 输出

当前不承诺：

- 作为完整 Markdown 编辑器或 AST 工具链替代品
- 覆盖所有方言扩展

### 4.7 HTML

当前状态：

- 正式支持
- 走 block-streaming 主链

已验证能力：

- 标题、段落、列表
- 基础表格
- 图片与链接
- RAG 输出
- assets materialization

当前不承诺：

- 浏览器级 CSS 布局恢复
- 完整视觉阅读顺序重建
- JS 执行后的动态页面语义

### 4.8 ZIP

当前状态：

- 正式支持
- 走 `package_single_pass`

已验证能力：

- 容器 entry 枚举
- entry 路径归一与安全边界
- 已支持子格式继续回到统一主链
- 资源 materialization

稳定事实：

- `zip` 是正式产品格式
- `format_readers/zip` 是当前容器基线
- ZIP archive reading continues to rely on `bikallem/compress/flate` inside `format_readers/zip`

当前不承诺：

- 对任意二进制成员做智能识别
- 远程抓取或执行容器内外部引用

### 4.9 EPUB

当前状态：

- 正式支持
- 走 `package_single_pass`

已验证能力：

- OPF / spine 顺序
- chapter 级 HTML 派发
- 本地资源 materialization
- remote/data image no-fetch / no-persist
- debug JSON 暴露 spine / missing item 诊断

稳定事实：

- EPUB support is implemented through `format_readers/epub` on top of `format_readers/zip`

当前不承诺：

- 阅读器级完整 EPUB 交互语义
- 远程资源下载
- 任意脚本或外链内容执行

### 4.10 DOCX

当前状态：

- 正式支持
- 走 `package_single_pass`

已验证能力：

- Office 文档主块输出
- 链接
- 图片与 assets
- debug JSON 暴露 `relationship_id`、`part_name`、`paragraph_index`
- RAG / assets lane 回归覆盖

当前仓库内已验证的工程事实：

- renderer 仍是最终 Markdown 所有者
- 没有回退到 legacy docx 路线
- debug JSON 能暴露 Office source refs 与 pass trace

性能事实：

- `run-1782740057646-126`
- `docx` CLI speedup vs `markitdown`: `88.09x`

当前不承诺：

- Word 全部高级版式能力
- 复杂浮动布局、修订、宏、嵌入对象的完整产品语义恢复

### 4.11 XLSX

当前状态：

- 正式支持
- 走 `package_single_pass`

已验证能力：

- workbook / worksheet 主路径
- sheet 级输出
- hidden / very hidden sheet policy diagnostics
- 公式缺缓存时保留公式文本，不执行计算
- debug JSON 暴露 workbook/part metadata

性能事实：

- `run-1782740057650-138`
- `xlsx` CLI speedup vs `markitdown`: `30.75x`

当前不承诺：

- Excel 公式执行
- 完整工作簿计算引擎
- 图表、数据透视、宏等完整 Office 交互语义恢复

### 4.12 PPTX

当前状态：

- 正式支持
- 走 `package_single_pass`

已验证能力：

- slide 顺序恢复
- 列表与段落结构
- hidden slide policy
- package-local 图片 assets
- speaker notes 输出
- debug JSON 暴露 slide part、placeholder、reading order strategy

当前不承诺：

- 完整视觉布局重建
- 演示动画、切换效果、复杂 SmartArt 的完整产品语义

### 4.13 PDF

当前状态：

- 正式支持，但仅限 native-text PDF
- 当前主路径仍是 `page_single_pass`

已验证能力：

- native-text 基线提取
- heading / paragraph 基础恢复
- cross-page 段落边界处理
- repeated header/footer 候选诊断
- table-like 候选诊断
- metadata-only link candidates
- 显式 opt-in `--pdf-cleanup conservative`
- 显式 opt-in `--pdf-tables simple`

当前明确缺失：

- 扫描版 / 图片型 PDF
- `pdf --ocr`
- layout-two-stage 正式产品路径
- 深度版面分析模型

当前边界行为：

- scanned-like PDF 当前 fail closed
- `pdf --ocr` 当前 fail closed，并且不会进入 OCR provider 成功路径

性能事实：

- `run-1782739994016-202`
- `pdf` CLI speedup vs `markitdown`: `30.60x`

## 5. OCR 现状

当前 OCR 只依托本地 `Tesseract` 命令行提供者。

产品事实：

- 图片 OCR 需要显式 `--ocr`
- 语言参数使用 `--ocr-lang <LANG>`
- `pdf --ocr` 当前不开放
- 扫描版 / 图片型 PDF 当前不进入正式产品路径
- 默认图片输入仍然 fail closed

macOS / Homebrew 安装：

```bash
brew install tesseract
brew install tesseract-lang
```

说明：

- `brew install tesseract` 默认只带 `eng`, `osd`, `snum`
- 需要更多语言时再安装 `tesseract-lang`
- 当前依赖的是本地可执行 `tesseract`，不是云端模型

## 6. v2 架构收益

当前仓库已经全面迁移到统一 `v2` 主架构。对外部使用者最直接的影响有三类：

- 语义更丰富：
  parser、pipeline、render 之间有稳定中间层，能保留更多主链事实、diagnostics、source refs、route provenance
- 大文件表现更稳：
  结构化文本与部分容器/Office 样本可以根据规模切换到更合适的 canonical route，而不是一条路径硬撑到底
- benchmark 更可信：
  `bench v2` 只测真实产品路径，并把 trust / route coverage / fidelity 一起纳入结果

## 7. 性能与高压样本口径

正式性能口径只认 `bench v2`。

它的约束是：

- 只跑 release binary
- 只测正式产品路径
- MoonBit case 必须带完整 provenance
- route mismatch / fidelity mismatch / missing provenance 都会直接打成 trust failure

当前仓库内已经有几组可直接复线的正式结果：

- `docx`: `run-1782740057646-126`
- `xlsx`: `run-1782740057650-138`
- `epub` / `pdf`: `run-1782739994016-202`
- `json` non-comparable 高压样本：`run-1782740391274-133`

目前可以安全表述的结论是：

- 在复杂文档主链上，`docx/xlsx/epub/pdf` 均有显著速度优势
- 在部分中高压样本上，外部 baseline 可能无法形成可比集，而 MoonBit 仍能稳定完成转换

目前最稳妥的例子是：

- `json_medium_spdx_licenses_v1`
- run id: `run-1782740391274-133`
- `moonbit-cli`: 成功 `3/3`
- `moonbit-engine`: 成功 `3/3`
- `markitdown`: 成功 `0/3`

因此，关于“高压环境”的对外说法，当前最准确的版本应是：

- 在部分中高压样本上，`markitdown` 可能无法形成完整可比结果，而 `markitdown-mb` 仍能稳定完成转换

而不是泛化成“所有超大文件场景都必然如此”。

## 8. 当前不承诺的能力

以下能力不在当前正式承诺范围内：

- 扫描 PDF OCR
- `pdf --ocr`
- 云 OCR / 大模型 OCR
- 自动 metadata sidecar 的正式产品承诺
- benchmark-only fast path
- 隐藏 alternate route
- 为了追求 benchmark 数字而牺牲主链语义

## 9. 推荐验证入口

快速功能验证：

```bash
moon build cli --target native
./_build/native/debug/build/cli/cli.exe normal samples/main_process/txt/markdown/txt_plain.txt .tmp/manual/out.md
```

主回归：

```bash
./samples/check.sh
./samples/check.sh --check-inventory
```

外部质量回归：

```bash
./samples/check_quality.sh
```

正式 benchmark：

```bash
moon build --target native --release --package ZSeanYves/markitdown/cli
moon build --target native --release --package ZSeanYves/markitdown/bench/runner
_build/native/release/build/bench/runner/runner.exe doctor
_build/native/release/build/bench/runner/runner.exe run --preset official-internal
_build/native/release/build/bench/runner/runner.exe run --preset official-compare --markitdown-path /path/to/markitdown
```
