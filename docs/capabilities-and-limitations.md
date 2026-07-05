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
| Subtitles | `srt`, `vtt` | 正式支持 |
| Delimited text | `csv`, `tsv` | 正式支持 |
| Structured text | `json`, `jsonl`, `ndjson`, `ipynb`, `xml`, `yaml`, `yml`, `toml` | 正式支持 |
| Web / markup | `html`, `htm`, `markdown`, `md`, `rst`, `adoc`, `asciidoc`, `tex`, `latex` | 正式支持 |
| Mail | `eml` | 正式支持 |
| Containers | `zip`, `epub` | 正式支持 |
| Office | `odt`, `ods`, `odp`, `docx`, `xlsx`, `pptx` | 正式支持 |
| PDF | `pdf` | 正式支持；默认 native-text，`--pdf-ocr explicit|auto-scanned` 走 Balanced PDF OCR，`--accurate` 默认 `auto_scanned` 并在命中 scanned-like 时走 Accurate PDF OCR |
| Audio | `wav`, `mp3`, `m4a` | 正式支持；P0 为 root local audio file 的 transcript-only media pipeline |
| Image OCR | `png`, `jpg`, `jpeg`, `bmp`, `webp`, `tif`, `tiff` | 正式支持 |

明确不属于当前默认主路径矩阵的输入：

- 未启用 `--ocr` 或 `--pdf-ocr auto-scanned` 的扫描版 / 图片型 PDF
- `mp4` / video / 流式音频 / subtitle sidecar / 容器内递归音频派发
- 其它未列出格式

## 3. 能力总览

| 格式 | 当前主路径 | 已正式支持 | 当前缺失 / 不承诺 |
| --- | --- | --- | --- |
| `txt` | `streaming_event` | 段落、基础文本输出、RAG、debug、bench | 富语义来源天然有限 |
| `srt` / `vtt` | `streaming_event` | cue time range、multiline caption、first-class `SourceRef.time_start/time_end`、WebVTT note/style/region degrade、RAG、debug | 不做播放器级渲染、CSS 解释、字幕样式执行 |
| `csv` / `tsv` | `streaming_event` | 表格型输出、RAG、debug、bench | 不做 Excel 级公式 / 样式语义 |
| `json` | `dom_ast_model`，超限或显式 `--stream` 时 `streaming_event` | 小中样本结构化输出、大样本 structure-event streaming、RAG、debug | 不追求完整 JSON editor 语义 |
| `jsonl` / `ndjson` | `streaming_event` | line-delimited record 输出、RAG、debug | 不做完整 document tree 语义 |
| `ipynb` | `dom_ast_model`，超限或显式 `--stream` 时 `block_streaming` | markdown/code/raw cell、typed outputs、multi-MIME selection、RAG、debug、assets、source refs | 不执行 notebook，不恢复隐藏运行时状态，不运行 widget / JS runtime |
| `toml` | `dom_ast_model` | table / key-value / array-of-tables 输出、RAG、debug | 不承诺 editor 级 round-trip 或 comment-preserving |
| `xml` | `dom_ast_model`，超限时 `streaming_event` | 结构化输出、streaming、RAG、debug | 不做完整 schema-aware 语义 |
| `yaml` | `dom_ast_model`，超限时 `streaming_event` | 映射 / 列表 / 表格型输出、RAG、debug | 不承诺覆盖全部 YAML 高阶方言 |
| `markdown` | `dom_ast_model`，超限或显式 `--stream` 时 `block_streaming` | Markdown 读取、基础结构输出、frontmatter passthrough、debug、RAG | 不承诺成为 CommonMark 全功能编辑器 |
| `rst` / `asciidoc` / `tex` | `dom_ast_model` | typed semantic inventory、heading / paragraph / list / common table / common link/code / include-or-directive-or-environment boundary / RAG / debug | 不承诺完整方言编辑器、复杂 directive/macro/include 执行 |
| `html` | `dom_ast_model`，超限或显式 `--stream` 时 `block_streaming(HtmlTokenStructure)` | readability/hybrid content-root 选择、boilerplate suppression、标题/段落/列表/表格/图片/链接、RAG、assets | 不做浏览器级视觉布局恢复 |
| `eml` | `block_streaming(Message)` | headers summary、body selection、受控 `text/html`、nested message、typed attachment dispatch、inline image assets、RAG、debug | 不承诺无限递归附件展开，不做邮件客户端级完整行为恢复 |
| `zip` | `container_recursive` | 容器扫描、路径安全、子文档派发、assets | 不做任意二进制内容解释 |
| `epub` | 默认 `package_single_pass`，显式 `--stream` 时 `container_recursive` | OPF/spine 顺序、章节派发、局部资源 materialization、RAG | 不做远程资源抓取，不做阅读器级完整语义 |
| `odt` | 默认 `package_single_pass`，显式 `--stream` 时 `block_streaming` | ODT 主块、表格、图片、hyperlink、footnote/endnote、comment appendix、RAG、debug source refs、assets | 不承诺完整样式 round-trip、批注/修订/宏执行 |
| `ods` | 默认 `package_single_pass`，显式 `--stream` 时 `block_streaming` | sheet 读取、表格型输出、RAG、debug source refs、hidden sheet 可见性统计 | 不执行公式，不承诺完整样式/批注/嵌入对象恢复 |
| `odp` | 默认 `package_single_pass`，显式 `--stream` 时 `block_streaming` | slide 顺序、文本块、表格、图片、speaker-note-like notes、RAG、debug source refs、assets | 不承诺完整视觉布局重建、动画/脚本执行、样式 round-trip |
| `docx` | `package_single_pass` | Office 文档主块、链接、图片、debug source refs、RAG | 不承诺覆盖 Word 全部高级版式语义 |
| `xlsx` | 默认 `package_single_pass`，超限或显式 `--stream` 时 `block_streaming` | sheet 读取、表格型输出、hidden sheet policy、公式缓存保留、debug | 不执行公式，不做 Excel 计算引擎 |
| `pptx` | `package_single_pass` | slide 顺序、列表、图片、speaker notes、hidden slide policy、debug | 不做完整演示视觉布局重建 |
| `pdf` | `page_single_pass` 或 `layout_two_stage` | native-text 提取、Balanced/Accurate PDF OCR、基础清理、显式 opt-in cleanup/table signals、RAG、debug | OCR 路线当前不承诺复杂 layout intelligence；复杂表格/深度结构仍不属于 Balanced 契约 |

## 3.1 当前成熟度再审计

本轮再审计按 5 个维度判断格式成熟度：

- 主链稳定度
- 高频结构的 typed canonical 表达深度
- Stream / 大文件策略是否清晰
- diagnostics / provenance 是否完整可解释
- 主回归与质量回归的覆盖信心

档位定义固定为：

- `实验中`：主链或回归信心还不够，不能作为正式长期承诺
- `可用`：主链稳定可用，但语义深度、质量信心或可解释性仍偏薄
- `成熟`：canonical 主链稳定，高频结构已有 typed 表达，回归与诊断足以长期维护
- `强成熟`：在“成熟”之上，还具备更深的 accurate/profile/route 能力，或复杂格式下的长期回归信心明显更强

当前正式支持矩阵中，没有单列为 `实验中` 的输入；实验性只存在于尚未公开承诺的局部增强和后续规划中。

| 格式 | 当前档位 | 再审计结论 |
| --- | --- | --- |
| `txt` | `成熟` | 轻量 `streaming_event` 主链稳定，RAG/debug/bench 完整，但语义天然简单 |
| `srt` / `vtt` | `成熟` | cue 时间与 source ref 语义稳定，streaming 路线长期可维护 |
| `csv` / `tsv` | `成熟` | 表格型 streaming 主链稳定，产品边界明确，不承诺工作簿级语义 |
| `json` | `强成熟` | `dom_ast_model` 与 `streaming_event` 双路径稳定，same-mode route 切换、provenance 与高压样本信心都较强 |
| `jsonl` / `ndjson` | `成熟` | line-delimited record 主链清晰，RAG/debug 契约稳定 |
| `ipynb` | `成熟` | cell/output/assets/source refs 都有 typed 支撑，block-streaming 回退明确，但不做 notebook execution |
| `toml` | `成熟` | canonical DOM 路线与 malformed degrade 语义稳定，边界清楚 |
| `xml` | `成熟` | DOM 与 streaming 两条 canonical 路线稳定，诊断与大文件策略明确 |
| `yaml` | `成熟` | mapping/list/table 类输出稳定，超限切换明确，但不宣称覆盖全部方言 |
| `markdown` | `成熟` | 读取、frontmatter、RAG/debug 与 stream fallback 已收敛，属于稳定 canonical 格式 |
| `rst` / `asciidoc` / `tex` | `成熟` | 共享 `text_markup` canonical 主链已具备 typed semantic inventory、专门 contract tests、专门主回归样例，当前正式结论已升级为“成熟 canonical 格式” |
| `html` | `强成熟` | content-root 选择、boilerplate suppression、block-streaming、assets 与质量回归都比较扎实 |
| `eml` | `成熟` | message/body/attachment 主链稳定，typed attachment dispatch 与受控 HTML lowering 边界清晰 |
| `zip` | `成熟` | 容器递归、路径安全、子文档派发与 assets 契约稳定 |
| `epub` | `成熟` | package/spine canonical 主链稳定，显式 stream 的 `container_recursive` 边界明确 |
| `odt` | `成熟` | package 主链、notes/comments appendix、source refs 与 Accurate 第一二批增强已形成长期可维护基础 |
| `ods` | `成熟` | hidden sheet/row、covered-cell/span-aware table hints 与大表策略已收敛到统一主链 |
| `odp` | `成熟` | slide-local organization、notes appendix、window hints 已稳定进入统一 planner/lowering/render 主链 |
| `docx` | `强成熟` | package canonical、textbox/alternate content Accurate 能力、source refs 与主回归/质量回归信心都较强 |
| `xlsx` | `强成熟` | hidden sheet/row、merged span、sparse/large route、Accurate 语义恢复都已形成强主链能力 |
| `pptx` | `强成熟` | slide/notes、reading-order-like 语义、group/decorative summary 与诊断解释能力较强 |
| `pdf` | `强成熟` | native-text 主路径、Balanced PDF OCR 与 Accurate PDF OCR 分工清晰，planner/provenance/回归口径都已收敛；边界是 OCR 路线仍不宣称复杂 layout intelligence |
| `wav` / `mp3` / `m4a` | `可用` | transcript-only media pipeline 已正式接入主链，Markdown/RAG/debug/provenance 可观察性完整；但当前仍是 P0 轻量实现，不承诺流式、多轨视图、视频容器或 diarization 能力 |
| 直接图片 OCR | `可用` | 产品路径正式可用，但质量强依赖外部 OCR 提供者与版面复杂度，当前承诺仍以文本恢复为主 |

本轮正式更新的重点结论是：

- `rst / asciidoc / tex` 不再应表述为“typed inventory 可用但仍偏薄”的格式
- 它们现在应被正式归类为 `成熟`，且类别是“成熟 canonical 格式”
- 这个结论建立在共享 semantic model、专门 contract suite、主回归样例和 markdown/rag/debug 三条输出面的可观察语义之上

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

### 4.2 SRT / VTT

当前状态：

- 正式支持
- 固定走 `streaming_event`
- 显式 `--stream` 不会切到新 route，因为它本身就是 canonical streaming 路径

已验证能力：

- SubRip / WebVTT cue 时间范围输出
- cue source refs 现在正式保留 `time_start` / `time_end`
- multiline caption 文本保留
- WebVTT `NOTE` / `STYLE` / `REGION` 受控 degrade 为 raw subtitle blocks
- RAG 输出、debug diagnostics、基础 line-range source refs
- malformed 输入会在同一 `streaming_event` route 内 fail closed，不跨模式降到 document parser

当前不承诺：

- 播放器级 CSS / region / positioning 解释
- 完整字幕样式系统恢复
- 富媒体轨道、音视频同步执行语义

### 4.3 CSV / TSV

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

### 4.4 JSON / JSONL / NDJSON

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

### 4.5 IPYNB

当前状态：

- 正式支持
- 默认走 `dom_ast_model`
- 显式 `--stream` 或超限时走 `block_streaming`

已验证能力：

- notebook summary table
- markdown / code / raw cell 显式边界输出
- stream / display_data / execute_result / error 等 typed outputs 的可见降落
- `application/javascript` / `text/javascript` 走显式 degrade 的 raw fenced javascript 路径
- `application/json` 与 `application/*+json` 优先走结构化 JSON lowering
- image output 与 markdown attachment 的 assets 落盘
- RAG / debug / source refs / diagnostics

当前 mode 事实：

- 当前 `--accurate` 不会让 `ipynb` 切换到新的 parser route
- `ipynb` 不会退化成普通 `json` 的无序键值文档策略

当前不承诺：

- notebook 执行、output 重算、kernel 状态恢复
- widget / JavaScript runtime 富交互恢复

### 4.6 XML

当前状态：

- 正式支持
- 默认走 `dom_ast_model`
- 超限时切到 `streaming_event`

已验证能力：

- 基础 XML 结构转 Markdown
- 大 XML benchmarking
- 主回归与 diagnostic 覆盖

当前不承诺：

- 全量 schema-aware 语义恢复
- 专用行业 XML 标准的深度业务解释

### 4.7 YAML / YML

当前状态：

- 正式支持
- 默认走 `dom_ast_model`
- 超限时切到 `streaming_event`

已验证能力：

- mapping / nested mapping
- flow collections
- metadata-like 输出
- RAG 输出

当前不承诺：

- 覆盖 YAML 所有边缘语法与方言
- 复杂 anchor / alias 的产品级富语义展开承诺

### 4.8 TOML

当前状态：

- 正式支持
- 走 `dom_ast_model` 主路径

已验证能力：

- 顶层 key-value / named table / dotted key
- array、array-of-tables、inline table
- multiline string、RAG 输出、debug diagnostics
- malformed 输入会降级为 raw fenced toml block，并显式打 warning / fallback 标记

当前不承诺：

- editor 级 comment-preserving / round-trip
- 超出当前主回归范围的 TOML 方言级扩展

### 4.9 Markdown

当前状态：

- 正式支持
- 默认走 `dom_ast_model`
- 显式 `--stream` 或超限时走 `block_streaming`

已验证能力：

- heading / paragraph / list 基础块结构
- frontmatter passthrough
- debug diagnostics
- RAG 输出

当前 mode 事实：

- 当前 `--accurate` 不会让 Markdown 切换到新的 parser route
- Markdown Accurate 增强属于规划中的同 route 语义扩展，不是当前正式承诺能力

当前不承诺：

- 作为完整 Markdown 编辑器或 AST 工具链替代品
- 覆盖所有方言扩展

### 4.10 RST / AsciiDoc / TEX

当前状态：

- 正式支持
- 当前正式档位是 `成熟 canonical 格式`
- 默认走 `dom_ast_model`
- 显式 `--stream` 当前只会诚实 warning 后回退到 canonical route，不切独立 streaming parser

已验证能力：

- 共享 `text_markup` 主链已经形成稳定 canonical 语义层
- heading / paragraph / list / code / common table / common link 进入统一 typed lowering
- `rst` 的 field-list、definition-list、common directive、include boundary 已进入稳定 canonical inventory
- `asciidoc` 的 admonition、quote、listing/source、attribute-like metadata、include boundary 已进入稳定 canonical inventory
- `tex` 的 sectioning、itemize/enumerate、verbatim/listing、tabular、theorem-or-quote-like environment、include boundary 已进入稳定 canonical inventory
- markdown / RAG / debug 三条输出都能稳定观察到 semantic attrs、boundary、source refs 与 diagnostics
- repo 内已有专门 contract tests 与专门主回归样例覆盖 canonical semantic inventory

当前不承诺：

- 完整方言编辑器能力
- 复杂 directive / include / macro / environment 执行
- Accurate/layout-intelligence 风格的高保真恢复
- 所有表格方言与交叉引用系统的完整语义恢复

### 4.11 HTML

当前状态：

- 正式支持
- 默认走 `dom_ast_model`
- 显式 `--stream` 或超限时走 `block_streaming`

已验证能力：

- `main/article/body/fragment` content-root 选择
- `nav/footer/hidden/script/style/template/repeated boilerplate` 抑制
- 标题、段落、列表、基础表格
- 图片与链接
- RAG 输出
- assets materialization

当前不承诺：

- 浏览器级 CSS 布局恢复
- 完整视觉阅读顺序重建
- JS 执行后的动态页面语义

### 4.12 ODT

当前状态：

- 正式支持
- 默认走 `package_single_pass`
- 显式 `--stream` 时走 `block_streaming`

已验证能力：

- `content.xml` 主块扫描
- heading / paragraph / list / table / image 基础语义恢复
- hyperlink、footnote / endnote、comment appendix
- notebook 以外的常规图片 assets materialization
- RAG 输出、debug diagnostics、source refs

当前不承诺：

- 完整 ODF 样式系统、批注、修订、脚注等高级语义全覆盖
- 宏执行、嵌入对象执行
- 与 `docx` 全高级能力逐项等价

### 4.13 ODS

当前状态：

- 正式支持
- 默认走 `package_single_pass`
- 显式 `--stream` 时走 `block_streaming`

已验证能力：

- `content.xml` 工作表扫描
- visible sheet heading + 表格型输出
- 行级 block-streaming
- RAG 输出、debug diagnostics、sheet source refs

当前不承诺：

- 公式执行或重算
- 完整 ODF 样式系统、批注、嵌入对象语义恢复
- 与 `xlsx` 全高级能力逐项等价

### 4.14 ODP

当前状态：

- 正式支持
- 默认走 `package_single_pass`
- 显式 `--stream` 时走 `block_streaming`

已验证能力：

- `content.xml` slide 顺序扫描
- heading / paragraph / list / table / image / notes 基础语义恢复
- 本地图片 assets materialization
- RAG 输出、debug diagnostics、slide source refs

当前不承诺：

- 完整视觉布局、动画与过渡恢复
- 宏执行、脚本执行、嵌入对象执行
- 与 `pptx` 全高级能力逐项等价

### 4.15 ZIP

当前状态：

- 正式支持
- 走 `container_recursive`

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

### 4.16 EPUB

当前状态：

- 正式支持
- 默认走 `package_single_pass`
- 显式 `--stream` 时走 `container_recursive`

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

### 4.17 DOCX

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

### 4.18 XLSX

当前状态：

- 正式支持
- 默认走 `package_single_pass`
- 超限或显式 `--stream` 时走 `block_streaming`

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

### 4.19 PPTX

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

### 4.20 PDF

当前状态：

- 正式支持
- 默认主路径是 `page_single_pass`
- `pdf --pdf-ocr explicit|auto-scanned` 会进入 Balanced PDF OCR 的 `layout_two_stage`
- `pdf --accurate` 默认先做 scanned-like probe，命中时进入 Paddle-backed Accurate PDF OCR 的 `layout_two_stage`

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

- OCR 路线下的复杂 layout/model 恢复
- 深度版面分析模型

当前边界行为：

- scanned-like PDF 在未启用 `--ocr` 或 `--pdf-ocr auto-scanned` 时当前 fail closed
- Balanced PDF OCR 依赖本地 `pdftoppm` + `tesseract`
- Accurate PDF OCR 依赖本地 `pdftoppm` + Paddle bridge
- 缺失依赖时返回 fail-closed 的诊断卡片，不做静默 provider fallback

性能事实：

- `run-1782739994016-202`
- `pdf` CLI speedup vs `markitdown`: `30.60x`

## 5. OCR 现状

当前 OCR 已拆成两条正式 provider 路线：

- Balanced OCR / Balanced PDF OCR：本地 `Tesseract`
- Accurate OCR / Accurate PDF OCR：外部 `PaddleOCR` bridge

产品事实：

- 直接图片输入正式支持，并默认启用 OCR
- `--no-ocr` 可显式关闭直接图片 OCR
- 语言参数使用 `--ocr-lang <LANG>`
- 直接图片 `Balanced` 默认走 `Tesseract`，直接图片 `Accurate` 走 Paddle bridge
- `pdf --ocr` 继续作为 `pdf --pdf-ocr explicit` 的兼容别名
- `pdf --pdf-ocr explicit|auto-scanned` 走 Balanced PDF OCR
- `pdf --accurate` 默认走 `auto_scanned`，仅对命中 scanned-like 的 PDF 进入 Accurate PDF OCR
- 扫描版 / 图片型 PDF 当前需要 `--ocr`、`--pdf-ocr auto-scanned`，或直接使用 `--accurate`
- 当前 Balanced OCR 输出以文本段落、reading order、基础块级布局恢复为主，不承诺复杂表格/深度版面重建
- 当前 Accurate OCR / Accurate PDF OCR 已接入 Paddle bridge，但仍通过同一套共享 OCR lowering 收敛，不做静默 fallback

macOS / Homebrew 安装：

```bash
brew install poppler
brew install tesseract
brew install tesseract-lang
python3 -m pip install paddlepaddle paddleocr
chmod +x samples/helpers/paddle_ocr_bridge.py
export MARKITDOWN_PADDLE_OCR_CMD="$PWD/samples/helpers/paddle_ocr_bridge.py"
```

Ubuntu：

```bash
sudo apt install poppler-utils tesseract-ocr
sudo apt install tesseract-ocr-eng
python3 -m pip install paddlepaddle paddleocr
chmod +x samples/helpers/paddle_ocr_bridge.py
export MARKITDOWN_PADDLE_OCR_CMD="$PWD/samples/helpers/paddle_ocr_bridge.py"
```

说明：

- `brew install tesseract` 默认只带 `eng`, `osd`, `snum`
- 需要更多语言时再安装 `tesseract-lang`
- Ubuntu 可按需安装额外语言包，例如 `tesseract-ocr-chi-sim` 或 `tesseract-ocr-jpn`
- 当前依赖的是本地可执行 `pdftoppm`、`tesseract` 与外部 Paddle bridge，不是云端模型
- 本项目不内置、不打包、不分发这些第三方二进制或 Python 运行时

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

- 云 OCR / 大模型 OCR
- OCR 路线下的复杂 layout/model 恢复
- provider 自动下载或静默 fallback
- benchmark-only fast path
- 隐藏 alternate route
- 为了追求 benchmark 数字而牺牲主链语义

## 9. 推荐验证入口

快速功能验证：

```bash
moon build cli --target native
./_build/native/debug/build/cli/cli.exe normal samples/fixtures/contracts/txt/txt_plain.txt .tmp/manual/out.md
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
