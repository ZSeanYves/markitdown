# mb-markitdown 完整架构书

> 建议路径：`docs/architecture/mb-markitdown-architecture.md`  
> 适用项目：`mb-markitdown` / MoonBit 实现的 MarkItDown-like 文档转换工具  
> 版本定位：架构设计文档，不绑定某个具体 parser 库；MoonBit 类型示例为接近实现的设计草案。

---

## 0. 架构目标

mb-markitdown 的核心目标是：

1. 将多种输入格式转换为 Markdown / Debug JSON / RAG chunks / Debug IR。
2. 在速度、内存、结构保真、版面恢复之间提供明确模式选择。
3. 不让所有格式强行使用同一种解析策略，而是根据格式天然结构选择最合适的 parser 形态。
4. 所有 parser 最终进入统一的 `ParseResult / IRInput` 产品契约，renderer 统一消费 `RenderInput`。
5. 支持 source map、diagnostics、assets、metadata，方便调试、溯源、RAG 引用和后续质量评估。

本项目不是单纯的“文件转 Markdown 字符串工具”，而应该是：

```text
Source Format
  -> Parser Native Signals
  -> ParseResult / IRInput
  -> IR Passes
  -> RenderInput
  -> Renderer
  -> Markdown / Debug JSON / Chunks / Debug Output
```

核心原则：

```text
Parser 可以多态
IRInput / RenderInput 契约必须统一
Renderer 必须统一
SourceMap 必须统一
Diagnostics 必须统一
Markdown 是输出，不是中间表示
```

---

## 1. 总体分层

### 1.1 总体 pipeline

```text
InputSource
  ↓
FormatDetector
  ↓
ParserRegistry
  ↓
Parser
  ↓
ParseResult
  ↓
CoreIRBuilder
  ↓
IR Pass Pipeline
  ↓
DocumentAssembler
  ↓
Renderer
  ↓
ConvertResult
```

### 1.2 每层职责

| 层级 | 核心职责 | 不应该做什么 |
|---|---|---|
| InputSource | 抽象文件、bytes、stream、URL、本地路径、容器 entry | 不识别复杂格式语义 |
| FormatDetector | 识别扩展名、MIME、magic bytes、container 内部类型 | 不解析完整文档 |
| ParserRegistry | 根据格式、模式、能力选择 parser | 不参与具体解析 |
| Parser | 读取源格式，产出事实、block、signal、asset、metadata、source map | 不直接生成 Markdown，不做最终标题/阅读顺序决策 |
| ParseResult | 统一包装 parser 输出 | 不承载渲染策略 |
| CoreIRBuilder | 将 parser-native 输出统一成 Core IR | 不读取源文件 |
| IR Pass Pipeline | 跨格式结构归一：标题、列表、表格、段落、阅读顺序、页眉页脚等 | 不依赖具体文件库 |
| DocumentAssembler | 组装 section tree、reading order、caption binding、table continuation | 不处理源格式 I/O |
| Renderer | 将 Core IR 表达为 Markdown / Debug JSON / chunks | 不解析源文件，不重新猜测结构 |
| ConvertResult | 返回最终内容、metadata、diagnostics、assets、source map | 不再修改结构 |

---

## 2. 关键架构边界

### 2.1 Parser 不生成 Markdown

错误设计：

```text
DOCX Parser -> Markdown
PDF Parser  -> Markdown
HTML Parser -> Markdown
```

正确设计：

```text
Parser -> ParseResult -> IRInput -> Pipeline -> RenderInput -> Renderer -> Markdown
```

原因：

1. Markdown 表达能力有限，不能承载 layout、bbox、source map、confidence、asset relation。
2. PDF、PPTX、XLSX 等格式需要先收集结构证据，再统一判断。
3. RAG、debug JSON 输出不应该反向从 Markdown 解析。
4. 直接拼 Markdown 会让后续优化不可控。

### 2.2 Parser 产出事实和候选信号，不做最终结论

Parser 应产出：

```text
事实：text、style、bbox、page、row、cell、relationship、xpath
候选：heading_candidate、list_candidate、table_candidate、caption_candidate
资源：image、attachment、chart、media
溯源：SourceRef
诊断：Diagnostics
```

Parser 不应过早决定：

```text
这个一定是二级标题
这个一定是正文段落
这个一定不是页眉
这个表格一定要渲染为 Markdown table
```

这些决策应交给 IR Pass 和 Renderer。

### 2.3 source single-pass 不等于全流程 single-pass

推荐定义：

```text
源格式主结构尽量只扫描一次。
Core IR 可以多轮 pass。
Renderer 最后统一输出。
```

也就是：

```text
No repeated source traversal.
Multiple IR passes are allowed.
```

对 PDF / DOCX / PPTX / XLSX / HTML 这类格式，parser 层可以只做一次主扫描；但进入 Core IR 后，可以执行多轮轻量 pass，例如：

```text
NormalizeWhitespacePass
MergeTextLinePass
ResolveReadingOrderPass
ResolveHeadingPass
ResolveListPass
ResolveTablePass
RemoveHeaderFooterPass
AssembleSectionTreePass
```

---

## 3. Convert Mode

用户侧建议暴露少量清晰模式。

```moonbit
// MoonBit 风格草案，具体语法按项目当前 MoonBit 版本调整
pub enum ConvertMode {
  Fast
  Balanced
  Accurate
  Stream
  Rag
  Debug
}
```

### 3.1 Fast

目标：速度优先。

行为：

```text
不开 OCR
不开重型 layout model
不做复杂跨页表格合并
尽量保留标题、段落、列表、小表格
图片默认转 asset placeholder
适合作为默认 CLI/API 模式
```

适合：

```text
txt、csv、jsonl、markdown、toml、普通 html、普通 docx、简单 pdf
```

### 3.2 Balanced

目标：结构质量和速度平衡。

行为：

```text
启用轻量 reading order
启用标题推断
启用页眉页脚过滤
启用段落合并
启用列表修正
启用表格清理
不默认 OCR，不默认深度模型
```

适合：

```text
PDF 文本层、Office 文档、HTML、EPUB、常规 ipynb notebook
```

### 3.3 Accurate

目标：质量优先。

行为：

```text
可启用 OCR
可启用 layout detection
可启用 table structure recognition
可启用公式/图注/图片区域识别
可启用跨页表格合并
输出更丰富 diagnostics 和 source map
```

架构边界：

```text
当前 Accurate 的主要正式覆盖面仍然是复杂 PDF / OCR / layout-two-stage。
但 Accurate 也可以覆盖“已结构化文本格式中的高保真语义恢复”。
这类增强不一定意味着切换 parser route，也可以是在同一 canonical route 内增加更强语义 pass。
Markdown 是当前最明确的非 PDF 扩展对象：目标是在既有 route 内提升 heading/list/code/table/link/image/frontmatter/source line/raw HTML boundary/footnote 等语义保真。
在 convert/route_policy.mbt 与具体 parser 未产品化前，这仍然是扩展路线，不是当前 mode 承诺。
```

适合：

```text
复杂 PDF、扫描件、财报、论文、表单、多栏排版、表格密集文档
```

### 3.4 Stream

目标：低内存和可持续输出。

行为：

```text
优先 EventStream / BlockStream
避免构建完整 DocumentIR
适合超大线性文件
```

适合：

```text
txt、log、csv、tsv、jsonl、ndjson、srt、vtt、mbox、大型 xml/json、超限 ipynb
```

### 3.5 Rag

目标：服务 RAG 和检索增强。

输出：

```text
markdown
chunks
source map
heading path
page / slide / sheet / cell location
notebook cell / output location
metadata
table chunks
asset references
confidence / warnings
```

关注点：

```text
chunk 边界
标题路径
页码引用
表格独立块
图片/图注绑定
source citation
可追溯性
```

### 3.6 Debug

目标：开发 parser、评估转换质量。

输出：

```text
diagnostics
parser mode
block count
table count
image count
warnings
IR dump
source map dump
pass trace
route decision
```

---

## 4. Parser Mode

mb-markitdown 不要求所有 parser 使用同一种扫描策略。每个 parser 声明自己的 `ParserMode`。

```moonbit
pub enum ParserMode {
  StreamingEvent
  BlockStreaming
  PackageSinglePass
  PageSinglePass
  DomAstModel
  LayoutTwoStage
  MediaPipeline
  ContainerRecursive
}
```

### 4.1 streaming-event

适合天然线性、可能很大的格式。

```text
source stream
  -> event stream
  -> renderer / IR consumer
```

适用格式：

```text
txt
log
csv
tsv
jsonl
ndjson
srt
webvtt
mbox
超限 yaml
超限 json
超限 xml
```

特点：

```text
低内存
可边读边处理
不默认构建完整 DocumentIR
适合超大文件
```

### 4.2 block-streaming

适合可以按自然单元分块的格式。

```text
source
  -> block / page / slide / sheet / chapter / message
  -> BlockIR
  -> assembler
```

典型粒度：

```text
Markdown: block
HTML: section / article / DOM subtree
PDF: page
XLSX: sheet / row / table region
EPUB: chapter
EML: MIME part
IPYNB: notebook cell / output group
```

### 4.3 package-single-pass

适合 zip/package 型文档。

```text
package
  -> metadata / relationships / styles / manifest / assets
  -> main content scan
  -> Core IR
```

适用格式：

```text
docx
pptx
xlsx
odt
ods
odp
epub
```

原则：

```text
可以预读 styles、relationships、manifest、metadata。
正文主结构尽量只扫描一次。
后续多轮处理只发生在 Core IR 上，不重复遍历源格式。
```

### 4.4 page-single-pass

适合分页文档。

```text
document
  -> page iterator
  -> text/image/vector/layout primitives
  -> page IR
  -> document assembler
```

适用格式：

```text
pdf
tiff
multi-page image
```

特点：

```text
不追求 byte-level 真流式
按 page 处理
保留 bbox、font、page number、image region、layout signal
```

### 4.5 dom-ast-model

适合 markup/tree 型格式。

```text
source
  -> AST / DOM
  -> Core IR
```

适用格式：

```text
markdown
html
xml
json
yaml
toml
ipynb
rst
asciidoc
latex
```

原则：

```text
小中型文件可以建 AST/DOM。
Markdown / HTML / YAML / JSON / XML 的超限分流由 convert 的 RoutePlanner 决定。
TOML 的规划中实现优先保持单一 `dom-ast-model` route，不为了配置文件格式引入额外 parser mode。
IPYNB 的规划中实现默认走 `dom-ast-model`，仅在 notebook 过大时按 cell / output group 降到 `block-streaming`。
Markdown 当前走 dom-ast-model canonical route，并在超限或 Stream 请求下切到 block-streaming。
Markdown 当前实现是轻量 block inventory + lowering，目标逐步靠近更完整语义解析，而不是已经产品化的完整 Markdown AST parser。
```

### 4.6 layout-two-stage

适合复杂视觉文档和高保真模式。

```text
stage 1: extract primitives
stage 2: layout / OCR / reading order / table recognition
```

适用格式：

```text
complex pdf
scanned pdf
image document
financial report
form
academic paper
multi-column document
table-heavy pdf
```

特点：

```text
高质量
高成本
不默认启用
由 mode=Accurate 或显式参数开启
```

### 4.7 media-pipeline

适合音频、视频类文件。

```text
media
  -> metadata
  -> transcript optional
  -> segment IR
```

适用格式：

```text
mp3
wav
m4a
mp4
video
```

音频扩展设计另见：[audio-media-pipeline-architecture.md](./audio-media-pipeline-architecture.md)。

### 4.8 container-recursive

适合容器文件。

```text
container
  -> entries
  -> dispatch child parser
  -> merge result
```

适用格式：

```text
zip
tar
directory
archive
```

---

## 5. 默认格式策略

### 5.1 默认策略表

说明：

```text
下表同时描述当前主架构事实与已经确定的扩展设计。
未进入 capabilities 文档的格式，不等同于当前已经产品化的正式支持。
```

```text
linear / streaming:
  txt      -> streaming-event only
  log      -> streaming-event only
  csv      -> streaming-event only
  tsv      -> streaming-event only
  jsonl    -> streaming-event only
  ndjson   -> streaming-event only
  srt      -> streaming-event only
  vtt      -> streaming-event only
  mbox     -> streaming-event only

tree / ast:
  md        -> dom-ast-model, over-limit -> block-streaming
  markdown  -> dom-ast-model, over-limit -> block-streaming
  json      -> dom-ast-model, over-limit -> streaming-event
  yaml      -> dom-ast-model, over-limit -> streaming-event
  yml       -> dom-ast-model, over-limit -> streaming-event
  toml      -> dom-ast-model
  ipynb     -> dom-ast-model, over-limit -> block-streaming(cell/output-group)
  xml       -> dom-ast-model, over-limit -> streaming-event
  rst       -> dom-ast-model
  adoc      -> dom-ast-model
  tex       -> dom-ast-model

web / markup:
  html      -> dom-ast-model + readability/hybrid, over-limit -> block-streaming(section/subtree)
  htm       -> dom-ast-model + readability/hybrid, over-limit -> block-streaming(section/subtree)

package documents:
  docx      -> package-single-pass only
  pptx      -> package-single-pass only
  xlsx      -> package-single-pass, over-limit -> block-streaming(sheet/row/table-region)
  odt       -> package-single-pass
  odp       -> package-single-pass
  ods       -> package-single-pass
  epub      -> package-single-pass + chapter blocks

paged documents:
  pdf       -> page-single-pass; Accurate / explicit OCR -> layout-two-stage
  tiff      -> page-single-pass
  tif       -> page-single-pass

image / OCR:
  png      -> layout-two-stage when OCR enabled; otherwise metadata/image asset only
  jpg      -> layout-two-stage when OCR enabled; otherwise metadata/image asset only
  jpeg     -> layout-two-stage when OCR enabled; otherwise metadata/image asset only
  webp     -> layout-two-stage when OCR enabled; otherwise metadata/image asset only

email:
  eml      -> block-streaming / MIME tree
  msg      -> block-streaming / library model

media:
  mp3      -> media-pipeline
  wav      -> media-pipeline
  m4a      -> media-pipeline
  mp4      -> media-pipeline

containers:
  zip       -> container-recursive only
  tar       -> container-recursive
```

### 5.2 大文件策略升级/降级

```text
RoutePlanner 在 parser 前统一做 canonical route 选择。
markdown 默认 -> dom-ast-model
超限 markdown / Stream markdown -> block-streaming
超限 yaml     -> streaming-event
超限 html     -> block-streaming(section/subtree)
超限 json     -> streaming-event
超限 xml      -> streaming-event
超限 ipynb    -> block-streaming(cell/output-group)
超限 xlsx     -> block-streaming(sheet/row/table-region)
复杂 pdf      -> Accurate 模式下 layout-two-stage
扫描 pdf      -> 仅在显式 OCR / Accurate 语义下进入 layout-two-stage

Markdown Accurate 当前属于“同 route 增强”，不是“跨 route 切换”。
也就是说，当前 `--accurate` 不会让 Markdown 切换到独立 parser mode 或独立 canonical route。

route 一旦选定，不允许跨模式 fallback。
route 失败时只允许同模式内 degradation，例如 section 裁剪、row 窗口裁剪、table-region 裁剪。
```

---

## 6. Core IR 总体设计

Core IR 应同时支持三种输入形态：

```moonbit
pub enum IRInput {
  EventStream(EventStream)
  BlockStream(BlockStream)
  Document(DocumentIR)
}
```

### 6.1 EventStream

适合：

```text
txt
csv
jsonl
srt
vtt
mbox
log
```

特点：

```text
低内存
顺序消费
可直接进入 streaming renderer
不保证完整 document tree
```

### 6.2 BlockStream

适合：

```text
pdf page
xlsx sheet / row / table region
epub chapter
eml mime part
html section
markdown block
```

特点：

```text
分块构建
可以局部 buffering
可以逐块执行 pass
可以最终组装 DocumentIR
```

### 6.3 DocumentIR

适合：

```text
docx
markdown
html
epub
pdf accurate mode
ipynb small/medium
json/yaml/toml small file
```

特点：

```text
完整结构
适合多轮 pass
适合 RAG chunking
适合 debug dump
```

---

## 7. 核心类型设计

下面是建议的核心类型。MoonBit 项目中可以按照当前语言版本调整具体语法和包路径。

### 7.1 SourceId / BlockId / AssetId

建议所有 id 使用轻量字符串封装，避免混用。

```moonbit
pub type SourceId String
pub type BlockId String
pub type AssetId String
pub type ParserName String
```

ID 推荐生成规则：

```text
file: hash/path/session id
block: b_000001 / page_1_b_0003 / slide_2_shape_5
asset: img_000001 / attach_000002
```

### 7.2 ParseResult

```moonbit
pub struct ParseResult {
  parser_name : String
  mode : ParserMode
  capabilities : ParserCapability
  event_stream : Array[CoreEvent]?
  block_stream : Array[CoreBlock]?
  document : DocumentIR?
  metadata : DocumentMetadata
  assets : Array[AssetRef]
  source_map : SourceMap?
  assembly : DocumentAssembly?
  diagnostics : Diagnostics
}
```

约束：

```text
event_stream / block_stream / document 公开结果必须且只应暴露一种主形态。
Parser 不直接返回 Markdown。
Parser 不负责最终标题层级、最终阅读顺序、最终 Markdown 表格策略。
```

### 7.3 DocumentIR

```moonbit
pub struct DocumentIR {
  id : String
  source : SourceRef
  metadata : DocumentMetadata

  blocks : Array[CoreBlock]
  assets : Array[AssetRef]
  diagnostics : Diagnostics

  sections : Array[SectionRef]
  source_map : SourceMap
}
```

说明：

```text
blocks 是文档主内容顺序。
sections 是可选的标题树/章节树索引。
assets 是全局资源表。
source_map 用于从 block 回源。
metadata 保存文件级信息。
```

### 7.4 CoreBlock

```moonbit
pub struct CoreBlock {
  id : String
  kind : BlockKind

  text : Option[String]
  children : Array[CoreBlock]

  source : Option[SourceRef]
  assets : Array[AssetId]
  signals : Array[CoreSignal]

  style : Option[StyleRef]
  layout : Option[LayoutBox]
  metadata : Map[String, JsonValue]
}
```

推荐 `BlockKind`：

```moonbit
pub enum BlockKind {
  Document
  Section
  Heading
  Paragraph
  List
  ListItem
  Table
  TableRow
  TableCell
  Image
  Code
  BlockQuote
  Formula
  Page
  Slide
  Sheet
  Chapter
  Email
  Attachment
  Metadata
  Raw
}
```

### 7.5 CoreSignal

```moonbit
pub struct CoreSignal {
  signal_type : SignalType
  confidence : Double
  value : JsonValue
  reason : Array[String]
  source : Option[SourceRef]
}
```

推荐 `SignalType`：

```moonbit
pub enum SignalType {
  HeadingCandidate
  ListCandidate
  TableCandidate
  CaptionCandidate
  HeaderFooterCandidate
  PageBreak
  SectionBreak
  ReadingOrderHint
  FontSignal
  LayoutSignal
  StyleSignal
  OcrSignal
  TableContinuationCandidate
  ArtifactCandidate
  LanguageHint
  CodeLanguageHint
}
```

使用原则：

```text
Parser 可以强信号，也可以弱信号。
信号不等于最终 block kind。
IR Pass 根据多个 signal 和上下文做最终判断。
```

示例：

```text
TextBlock("Abstract")
  signal: HeadingCandidate(level_hint=1, confidence=0.83)
  signal: FontSignal(size=16, bold=true)
  source: PDF page 1 bbox(...)
```

### 7.6 SourceRef

```moonbit
pub struct SourceRef {
  file_id : String
  format : String

  page : Option[Int]
  bbox : Option[BBox]

  line_start : Option[Int]
  line_end : Option[Int]
  byte_start : Option[Int]
  byte_end : Option[Int]

  xpath : Option[String]
  json_pointer : Option[String]
  yaml_path : Option[String]

  sheet : Option[String]
  cell_range : Option[String]

  slide : Option[Int]
  shape_id : Option[String]

  chapter_href : Option[String]
  email_part : Option[String]

  extra : Map[String, JsonValue]
}
```

格式映射：

| 格式 | SourceRef 字段 |
|---|---|
| PDF | page + bbox |
| DOCX | paragraph index / run index / relationship id |
| PPTX | slide + shape_id + bbox |
| XLSX | sheet + cell_range |
| HTML | xpath / css selector |
| EPUB | chapter_href + xpath |
| Markdown | line_start + line_end |
| TXT | line range / byte range |
| CSV | row / column range，放 extra 或 cell_range |
| JSON | json_pointer |
| YAML | yaml_path + line range |
| TOML | dotted path + line range，优先放 extra 或复用 yaml_path-like 表达 |
| IPYNB | json_pointer + `extra.cell_index/cell_kind/output_index` |
| EML | email_part |

对于 `toml` 与 `ipynb` 这类规划中的扩展格式，优先复用现有 `json_pointer / yaml_path / extra` 承载来源定位；只有当这些格式进入稳定公开契约后，才考虑是否把专属字段提升为 Core `SourceRef` 的显式一等字段。

### 7.7 LayoutBox

```moonbit
pub struct BBox {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

pub struct LayoutBox {
  page : Option[Int]
  bbox : Option[BBox]
  rotation : Double
  z_index : Option[Int]
  writing_mode : Option[String]
}
```

使用场景：

```text
PDF text span
PDF image region
PPTX shape
HTML visual layout optional
OCR region
```

### 7.8 StyleRef

```moonbit
pub struct StyleRef {
  style_id : Option[String]
  style_name : Option[String]
  font_name : Option[String]
  font_size : Option[Double]
  bold : Option[Bool]
  italic : Option[Bool]
  underline : Option[Bool]
  color : Option[String]
  extra : Map[String, JsonValue]
}
```

注意：

```text
StyleRef 记录源格式事实。
是否转为 heading/list/code 由 pass 决定。
```

### 7.9 AssetRef

```moonbit
pub struct AssetRef {
  id : String
  kind : AssetKind
  mime_type : Option[String]
  filename : Option[String]
  uri : Option[String]
  data_ref : Option[String]
  alt_text : Option[String]
  caption : Option[String]
  source : Option[SourceRef]
  metadata : Map[String, JsonValue]
}

pub enum AssetKind {
  Image
  Attachment
  Audio
  Video
  EmbeddedFile
  Thumbnail
  Chart
  Unknown
}
```

原则：

```text
Parser 提取 asset metadata 和关系。
是否导出到本地、base64、链接、占位符，由 renderer/options 决定。
```

### 7.10 Diagnostics

```moonbit
pub struct Diagnostics {
  warnings : Array[String]
  errors : Array[String]

  source_size : Option[Int64]
  parser_time_ms : Option[Int64]
  total_time_ms : Option[Int64]

  page_count : Option[Int]
  slide_count : Option[Int]
  sheet_count : Option[Int]

  block_count : Int
  table_count : Int
  image_count : Int
  asset_count : Int

  degraded_features : Array[String]
  selected_route : Option[String]
  route_reason : Option[String]
  route_probe_summary : Option[String]
  same_mode_degradation : Array[String]
  pass_trace : Array[String]

  extra : Map[String, JsonValue]
}
```

用途：

```text
debug
benchmark
质量评估
route 判断
RAG 溯源
用户提示
回归测试
```

---

## 8. Parser 接口设计

### 8.1 ParserCapability

每个 parser 必须声明能力，而不是让外层猜。

```moonbit
pub struct ParserCapability {
  parser_mode : ParserMode

  supports_streaming : Bool
  streaming_granularity : StreamingGranularity

  requires_random_access : Bool
  source_single_pass_preferred : Bool
  source_single_pass_strict : Bool

  produces_text : Bool
  produces_structure : Bool
  produces_layout : Bool
  produces_tables : Bool
  produces_images : Bool
  produces_metadata : Bool
  produces_source_map : Bool

  can_be_lossless : Bool
  can_preserve_order : Bool
  can_preserve_styles : Bool
}

pub enum StreamingGranularity {
  Byte
  Line
  Record
  Row
  Block
  Page
  Slide
  Sheet
  Chapter
  Message
  None
}
```

### 8.2 Parser trait

```moonbit
pub trait Parser {
  fn name(Self) -> String
  fn capability(Self) -> ParserCapability
  fn can_parse(Self, source : InputSource, detected : DetectedFormat) -> Bool
  fn parse(Self, ctx : ParseContext, source : InputSource) -> Result[ParseResult, ParseError]
}
```

对于可流式 parser，可单独实现：

```moonbit
pub trait StreamingParser {
  fn parse_events(Self, ctx : ParseContext, source : InputSource) -> Result[EventStream, ParseError]
}
```

对于分块 parser：

```moonbit
pub trait BlockParser {
  fn parse_blocks(Self, ctx : ParseContext, source : InputSource) -> Result[BlockStream, ParseError]
}
```

### 8.3 ParseContext

```moonbit
pub struct ParseContext {
  options : ConvertOptions
  detected_format : DetectedFormat
  source_id : String
  asset_store : AssetStore
  diagnostics : Diagnostics
  limits : ResourceLimits
}
```

### 8.4 ResourceLimits

```moonbit
pub struct ResourceLimits {
  max_file_size : Option[Int64]
  max_memory_mb : Option[Int]
  max_pages : Option[Int]
  max_rows : Option[Int]
  max_cols : Option[Int]
  max_cells : Option[Int]
  max_depth : Option[Int]
  max_assets : Option[Int]
  timeout_ms : Option[Int64]
}
```

---

## 9. CoreIRBuilder

CoreIRBuilder 负责把不同 parser 的输出统一到 Core IR。

### 9.1 输入

```text
ParseResult.event_stream
ParseResult.block_stream
ParseResult.document
```

### 9.2 输出

```text
IRInput.EventStream
IRInput.BlockStream
IRInput.Document(DocumentIR)
```

### 9.3 职责

```text
统一 block kind
统一 source ref
统一 asset ref
统一 metadata key
统一 diagnostics
将 parser-native signal 映射为 CoreSignal
将 parser-native style 映射为 StyleRef
将 parser-native layout 映射为 LayoutBox
```

### 9.4 不负责

```text
不读取源文件
不做最终 Markdown 渲染
不做高成本 OCR/layout 模型推理
不处理最终表格输出策略
```

---

## 10. IR Pass Pipeline

IR Pass 是 mb-markitdown 质量提升的核心。

### 10.1 Pass 接口

```moonbit
pub trait IRPass {
  fn name(Self) -> String
  fn run(Self, ctx : PassContext, input : IRInput) -> Result[IRInput, PassError]
}
```

### 10.2 PassContext

```moonbit
pub struct PassContext {
  mode : ConvertMode
  options : ProductOptions
  diagnostics : Ref[Diagnostics]
  assets : Ref[Array[AssetRef]]
  metadata : Ref[DocumentMetadata]
  source_map : Ref[SourceMap?]
  assembly : Ref[DocumentAssembly?]
}
```

### 10.3 推荐 Pass 顺序

```text
1. NormalizeTextPass
2. NormalizeWhitespacePass
3. MergeTextLinePass
4. ResolveReadingOrderPass
5. RemoveHeaderFooterPass
6. ResolveHeadingPass
7. ResolveListPass
8. ResolveTablePass
9. ResolveCaptionPass
10. ResolveAssetPass
11. AssembleSectionTreePass
12. DebugAnnotationPass
```

### 10.4 NormalizeTextPass

职责：

```text
统一换行
处理控制字符
处理 Unicode 空白
处理软连字符
可选繁简/全半角 normalization，但默认不要强改内容
```

### 10.5 NormalizeWhitespacePass

职责：

```text
合并多余空白
保留 code block 内空白
保留 table cell 内必要空白
避免破坏 Markdown 语义
```

### 10.6 MergeTextLinePass

主要用于 PDF/OCR。

职责：

```text
TextSpan -> TextLine
TextLine -> Paragraph candidate
处理断行
处理 hyphenation
处理多栏场景下的行合并限制
```

### 10.7 ResolveReadingOrderPass

主要用于 PDF/PPTX/OCR。

输入信号：

```text
bbox
page
z_index
font size
block distance
column detection
parser reading_order_hint
```

输出：

```text
blocks 按阅读顺序重排
添加 reading_order metadata
```

### 10.8 RemoveHeaderFooterPass

主要用于 PDF/OCR。

策略：

```text
跨页重复文本检测
页面顶部/底部位置检测
字号/位置稳定性检测
页码模式检测
```

输出：

```text
删除或标记 header/footer candidate
Debug 模式保留并注释
```

### 10.9 ResolveHeadingPass

输入信号：

```text
style_name
font_size
bold
vertical_gap
numbering pattern
HTML h1-h6
Markdown heading AST
DOCX paragraph style
PDF heading_candidate
```

输出：

```text
CoreBlock.kind = Heading
metadata.level = 1..6
```

原则：

```text
结构化格式优先信任源语义。
PDF/OCR 需要统计推断。
不要让单一 font size 决定标题。
```

### 10.10 ResolveListPass

职责：

```text
识别有序/无序列表
修正嵌套层级
合并连续 list item
处理 DOCX numbering
处理 Markdown/HTML 原生 list
处理 PDF 中的 bullet/number pattern
```

### 10.11 ResolveTablePass

职责：

```text
统一 table / row / cell
处理 merged cells
处理 header row
识别大表
识别跨页表格候选
选择 table logical model，不选择最终 Markdown 表达
```

注意：最终 table 输出由 renderer 根据 `table_strategy` 决定。

### 10.12 ResolveCaptionPass

职责：

```text
识别 figure/table caption
绑定 caption -> asset/table
处理 “Figure 1”, “Table 2”, “图 3”, “表 4” 等模式
结合位置关系和文本模式
```

### 10.13 ResolveAssetPass

职责：

```text
统一 asset id
处理图片 alt text
处理 embedded image relation
处理附件递归解析结果
处理 asset export policy
```

### 10.14 AssembleSectionTreePass

职责：

```text
根据 heading level 构建 section tree
为每个 block 添加 heading path
为 renderer / RAG chunking 提供 assembly 语义
```

### 10.15 RAG Chunking Projection

当前实现中，RAG chunking 不作为 IR pass 回写 Core IR；它是 renderer 前后的纯投影过程。

职责：

```text
按 heading path 切块
按 token/字符长度切块
表格独立切块
图片/图注绑定切块
保留 source map
避免跨语义边界硬切
```

说明：

```text
DocumentIR 路径由 RagJsonRenderer 直接消费 document + assembly 生成 chunks。
BlockStream / EventStream 路径由 RagJsonRenderer 的 direct-input 分支生成 chunks。
因此 RAG 是产品能力，但不是当前 pipeline 中的独立 IRPass。
```

---

## 11. Renderer 设计

Renderer 不读取源格式；它消费 convert + pipeline 产出的 RenderInput / Context。

### 11.1 Renderer trait

```moonbit
pub struct Renderer {
  name : String
  render : (DocumentIR, RenderContext) -> RenderResult
  render_input : (RenderInput, RenderContext) -> RenderResult
}
```

说明：

```text
当前实现保留双入口：
1. render(DocumentIR, ctx) 处理完整 document 路径
2. render_input(RenderInput, ctx) 处理 EventStream / BlockStream / direct Document 路径
convert 统一决定进入哪个入口；renderer 本身不负责 route 选择。
```

### 11.2 RenderContext

```moonbit
pub struct RenderContext {
  debug : Bool
  rag_options : RagOptions
  base_diagnostics : Diagnostics?
  metadata : DocumentMetadata?
  source_map : SourceMap?
  assets : Array[AssetRef]?
  assembly : DocumentAssembly?
}
```

说明：

```text
RenderContext 承载渲染时所需的稳定产品上下文。
它不是 parser/convert 的总配置镜像，而是 render 阶段真正消费的最小闭包。
```

### 11.3 MarkdownRenderer

渲染规则：

| CoreBlock | Markdown 输出 |
|---|---|
| Heading | `#` 到 `######` |
| Paragraph | 普通段落 |
| List / ListItem | `-` 或 `1.` |
| Table small | Markdown table |
| Table large | fenced csv / html table / sample / summary |
| Image | `![alt](asset_uri)` |
| Code | fenced code |
| BlockQuote | `>` |
| Formula | `$...$` 或 fenced math |
| PageBreak | HTML comment / horizontal rule / page marker |
| Slide | section heading |
| Sheet | section heading + table |
| Chapter | section heading |
| Email | header block + body |

### 11.4 表格渲染策略

```moonbit
pub enum TableStrategy {
  Auto
  Markdown
  Html
  CsvFenced
  Sample
  Summary
}
```

保护参数：

```moonbit
pub struct TableRenderOptions {
  strategy : TableStrategy
  max_rows : Int
  max_cols : Int
  max_cells : Int
  include_formula : Bool
  include_hidden : Bool
}
```

默认建议：

```text
小表：Markdown table
中表：HTML table 或 fenced csv
大表：summary + sample
超大表：stream rows，不聚合为 Markdown table
```

### 11.5 DebugJsonRenderer

当前结构化调试输出固定由 `DebugJsonRenderer` 承担。

输出完整结构：

```text
document metadata
blocks
signals
source refs
assets
diagnostics
```

适合：

```text
debug
integration
RAG pipeline
测试快照
```

当前说明：

```text
CLI 不提供独立 --json。
当前正式公开的结构化输出是 DebugJson 与 RagJson。
OutputFormat::Json 如保留在内部枚举中，也不构成独立公开产品语义。
```

### 11.6 RagRenderer

输出：

```text
chunks
chunk text
heading path
source refs
page/slide/sheet/cell location
notebook cell/output location
asset refs
metadata
```

推荐 chunk 类型：

```text
text_chunk
table_chunk
image_caption_chunk
code_chunk
metadata_chunk
```

对于 `ipynb` 这类 notebook 格式，不额外发明新的公开 chunk 类型：

```text
markdown cell -> text_chunk
code cell -> code_chunk
tabular output -> table_chunk
image/display output -> image_caption_chunk 或 asset refs
notebook-level facts -> metadata_chunk
```

---

## 12. 各格式 Parser 详细设计

## 12.1 TXT / LOG Parser

ParserMode：`streaming-event`

### 输入特征

```text
天然线性
可能极大
结构弱
编码不确定
```

### 扫描策略

```text
按 byte/line 流式读取
编码检测
换行规范化
可选 paragraph grouping
```

### 输出

```text
LineEvent
ParagraphEvent
RawBlock
SourceRef(line_range / byte_range)
```

### 注意事项

```text
LOG 默认可渲染为 fenced code
普通 TXT 默认按段落渲染
超长行需要截断或 hard wrap 策略
不要默认完整读入内存
```

---

## 12.2 CSV / TSV Parser

ParserMode：`streaming-event`

### 输入特征

```text
天然二维表
可能极大
Markdown table 对大表不友好
```

### 扫描策略

```text
行级 streaming
delimiter sniffing
header detection
row count / col count guard
cell escaping
```

### 输出

```text
TableStartEvent
TableRowEvent
TableCellEvent
TableEndEvent
或 RowRecordEvent
```

### Renderer 策略

```text
小表 -> Markdown table
中表 -> fenced csv
大表 -> summary + sample
RAG -> row group chunks
```

### 必须支持的限制

```text
max_rows
max_cols
max_cells
max_cell_chars
```

---

## 12.3 JSON / JSONL Parser

### JSONL

ParserMode：`streaming-event`

```text
一行一个 record
适合超大数据
输出 RecordEvent
```

### JSON

ParserMode：默认 `dom-ast-model`，大文件切换 `streaming-event`

### 输出

```text
ObjectBlock
ArrayBlock
KeyValueBlock
RawJsonBlock
SourceRef(json_pointer)
```

### Markdown 策略

```text
配置类 JSON -> key-value sections
数据类 JSON -> fenced json / sample
复杂嵌套 -> summary + raw fenced json
```

---

## 12.4 YAML / TOML Parser

ParserMode：`dom-ast-model`

### 输入特征

```text
配置文件为主
需要保留 path 和行号
YAML 可能多文档
TOML 更强调单文档配置、dotted key 和 table / array-of-tables 语义
```

### 输出

```text
KeyValueBlock
ObjectBlock
ArrayBlock
SourceRef(yaml_path + line_range)
```

### 注意事项

```text
尽量保留 comments，若 parser 支持
多文档 YAML 可以按 document block 输出
不要把 YAML 全部强行转成普通段落
```

### TOML 融入主架构的扩展设计

TOML 不需要新 parser mode；建议直接复用现有 `dom-ast-model -> DocumentIR -> Renderer` 主链。

推荐策略：

```text
顶层 table -> section / key-value group
dotted key -> 路径化 key-value block
array-of-tables -> repeated section 或 table-like repeated object blocks
inline table -> 小型 object block
multiline basic/literal string -> paragraph 或 fenced text/code，保留换行
date/time/number/bool -> typed scalar，优先保留原值与最小必要规范化
```

边界说明：

```text
TOML 当前应按“结构化配置文本”设计，而不是按 Markdown 段落文本设计
不承诺编辑器级 comment round-trip
不引入独立 Accurate route
如后续需要更强保真，也优先在同一 dom-ast-model route 内增强 typed scalar / source refs / diagnostics
```

---

## 12.5 XML Parser

ParserMode：小文件 `dom-ast-model`，大文件 `streaming-event`

### 扫描策略

```text
小 XML -> DOM/AST
大 XML -> event/iter parser
```

### 输出

```text
ElementBlock
TextBlock
Attribute metadata
SourceRef(xpath)
```

### Markdown 策略

```text
文档型 XML -> heading/paragraph/list/table
数据型 XML -> fenced xml / summary / key-value
```

---

## 12.6 Markdown Parser

ParserMode：默认 `dom-ast-model`；`Stream` 或超限时切 `block-streaming`

### 输入特征

```text
已经是目标近似格式
但仍应进入统一 parser / IR / render 主链，便于 source map、RAG、debug、diagnostics
```

### 当前实现

```text
canonical route 仍是 dom-ast-model
Stream 或超限时走 block-streaming
当前 parser 本质上是轻量扫描器 + lowering
它会优先建立高频 block inventory，再补足 table/link/image/frontmatter/raw HTML/footnote 等语义
这还不是一个完整 Markdown AST parser，也不承诺覆盖全部方言
```

### Accurate 扩展路线

```text
当前不新增 Markdown 专属 canonical route
当前不让 Accurate 把 Markdown 切换到独立 parser mode
Accurate 可以在同一 route 内逐步增加更强语义 pass、归一化、source refs 和 diagnostics
优先增强范围：heading / list / code / table / link / image / frontmatter / source line / raw HTML boundary / footnote
只有当 convert/route_policy.mbt 与 formats/markdown/parser.mbt 的稳定行为真正升级后，才应把它写成已产品化 mode 行为
```

### 输出

```text
HeadingBlock
ParagraphBlock
ListBlock
CodeBlock
TableBlock
ImageBlock
SourceRef(line_range)
并保留逐步扩展到更强语义恢复的空间
```

---

## 12.7 HTML Parser

ParserMode：`dom-ast-model` + optional block streaming

### 输入特征

HTML 可能是：

```text
文章网页
文档站
Office 导出 HTML
邮件 HTML
爬虫噪声页面
SPA 导出的 fragment
```

### 策略选项

```moonbit
pub enum HtmlStrategy {
  Dom
  Readability
  Hybrid
}
```

### Dom 模式

```text
尊重 DOM 结构
保留 h1-h6、p、ul、ol、table、pre、code、blockquote、img、a
适合干净文档站和导出 HTML
```

### Readability 模式

```text
抽正文
过滤 nav、footer、aside、script、style、广告区
适合新闻、博客、普通网页
```

### Hybrid 默认

```text
优先 article/main
否则 body
过滤明显噪声
保留正文结构
```

### 输出

```text
HeadingBlock
ParagraphBlock
ListBlock
TableBlock
CodeBlock
ImageBlock
Link metadata
SourceRef(xpath)
```

---

## 12.8 EPUB Parser

ParserMode：`package-single-pass` + `chapter block-streaming`

### 输入特征

EPUB 本质：

```text
zip
  OPF package
  manifest
  spine reading order
  XHTML chapters
  assets
  metadata
```

### 扫描策略

```text
读取 container.xml
读取 OPF metadata / manifest / spine
按 spine 顺序解析 chapter XHTML
chapter 内复用 HTML parser
```

### 输出

```text
DocumentIR
ChapterBlock
HeadingBlock
ParagraphBlock
ImageBlock
AssetRef
SourceRef(chapter_href + xpath)
```

### 注意事项

```text
不要按 zip entry 顺序拼接
必须按 spine 顺序
必须保留 chapter href
```

---

## 12.9 DOCX Parser

ParserMode：`package-single-pass`

### 输入特征

DOCX 是结构文档，不是纯视觉文档。

### 需要读取的 parts

```text
[Content_Types].xml
_rels/.rels
word/document.xml
word/styles.xml
word/numbering.xml
word/_rels/document.xml.rels
word/footnotes.xml
word/endnotes.xml
word/comments.xml
word/header*.xml
word/footer*.xml
word/media/*
word/charts/* optional
```

### 扫描策略

```text
预读 relationships / styles / numbering
主扫描 document.xml
遇到 paragraph/table/image/hyperlink/footnote ref 生成 block 或 signal
```

### 输出 block

```text
ParagraphBlock
Run fragments
TableBlock
ImageBlock
FootnoteRefBlock
EndnoteRefBlock
CommentRef metadata
PageBreak signal
SectionBreak signal
```

### 必须保留信号

```text
paragraph style id/name
run style
bold/italic/underline
numbering id / level
hyperlink rel id
drawing/image rel id
table grid
merged cell
footnote/endnote ref
comment ref
section break
page break
```

### 判断原则

```text
Heading style 是强 heading signal
Numbering 是强 list signal
字体变大只是弱 heading signal
DOCX 不需要像 PDF 那样过度推断
```

---

## 12.10 PPTX Parser

ParserMode：`package-single-pass` + slide block

### 输入特征

PPTX 的自然单位是 slide，不是 paragraph。

### 需要读取的 parts

```text
ppt/presentation.xml
ppt/slides/slide*.xml
ppt/slides/_rels/slide*.xml.rels
ppt/slideLayouts/*
ppt/slideMasters/*
ppt/notesSlides/*
ppt/media/*
ppt/charts/* optional
```

### 扫描策略

```text
读取 presentation slide order
按 slide 顺序解析
解析 placeholders、shapes、text boxes、tables、images、notes
```

### 输出

```text
SlideBlock
ShapeBlock
TextBoxBlock
TableBlock
ImageBlock
SpeakerNotesBlock
```

### 必须保留

```text
slide_no
shape_id
placeholder_type
z_order
bbox
alt_text
speaker notes
image relationships
table cells
```

### Markdown 渲染建议

```markdown
# Slide 3: Title

- bullet
- bullet

![alt](asset_uri)

> Speaker notes: ...
```

---

## 12.11 XLSX Parser

ParserMode：`package-single-pass` + sheet/row streaming

### 输入特征

XLSX 容易内存爆炸，大表不适合 Markdown table。

### 需要读取的 parts

```text
xl/workbook.xml
xl/worksheets/sheet*.xml
xl/sharedStrings.xml
xl/styles.xml
xl/_rels/workbook.xml.rels
xl/tables/table*.xml optional
xl/charts/* optional
```

### 扫描策略

```text
预读 workbook / sheets / shared strings / styles
按 sheet 读取
按 row/cell streaming
识别 used range
识别 table region
```

### 输出

```text
Workbook metadata
SheetBlock
TableRegionBlock
RowBlock
CellBlock
Formula metadata
MergedCell metadata
```

### 表格输出策略

```text
小表 -> Markdown table
中表 -> HTML table / fenced csv
大表 -> summary + sample
超大表 -> streaming rows，避免完整聚合
```

### 必须支持参数

```text
max_rows
max_cols
max_cells
include_formulas
include_hidden_sheets
include_hidden_rows
include_hidden_cols
```

---

## 12.12 PDF Parser

ParserMode：默认 `page-single-pass`，复杂/扫描件 `layout-two-stage`

### 输入特征

PDF 是显示格式，不是语义格式。它经常缺少：

```text
真实段落
真实标题
真实表格结构
真实阅读顺序
真实列表语义
```

### Fast PDF

```text
文本层抽取
按 page 处理
简单坐标排序
简单段落合并
不 OCR
不表格结构识别
```

### Balanced PDF

```text
TextSpan -> Line -> Block
reading order
页眉页脚检测
标题候选
caption 候选
简单表格候选
```

### Accurate PDF

```text
OCR
layout detection
table structure recognition
formula/code/image region
multi-column reading order
cross-page table merge
```

### Parser 输出事实

```text
PageBlock
TextSpan
TextLine candidate
TextBlock candidate
ImageRegion
VectorRegion optional
TableCandidate optional
FontSignal
LayoutSignal
SourceRef(page + bbox)
```

### 不应直接输出

```text
最终 Heading
最终 Paragraph
最终 Markdown Table
最终阅读顺序结论
```

这些交给 IR Pass。

---

## 12.13 图片 / 扫描件 Parser

ParserMode：`layout-two-stage` when OCR enabled

### 模式

```text
metadata_only
ocr
ocr_layout
vlm_caption optional
```

### 输出

```text
ImageDocumentIR
Image metadata
OcrTextBlock
LayoutRegion
SourceRef(bbox)
AssetRef
```

### 注意事项

```text
OCR 默认不应强制启用
准确模式开启 OCR/layout
OCR 结果必须带 confidence
```

---

## 12.14 Email Parser：EML / MSG / MBOX

### EML

ParserMode：`block-streaming` / MIME tree

```text
headers
text/plain part
text/html part
attachments
inline images
```

策略：

```text
优先 text/plain
否则 text/html -> HTML parser
附件可递归 parser
```

### MBOX

ParserMode：`streaming-event`

```text
一封邮件一个 MessageBlock
适合大 mailbox
```

### MSG

ParserMode：`block-streaming` / library model

```text
复合二进制格式
通常依赖专门库
不追求真流式
```

---

## 12.15 Archive Parser：ZIP / TAR / Directory

ParserMode：`container-recursive`

### 扫描策略

```text
列出 entries
过滤目录和危险路径
对每个 entry 调 FormatDetector
分发子 parser
合并结果
```

### 安全要求

```text
防 zip slip
限制最大 entry 数
限制递归深度
限制总解压大小
限制单文件大小
```

### 输出

```text
ContainerBlock
EntryBlock
Child ConvertResult / Child DocumentIR
```

---

## 12.16 Audio / Video / Subtitle Parser

### SRT / VTT

ParserMode：`streaming-event`

```text
cue -> TranscriptEvent
SourceRef(time range / line range)
```

### Audio / Video

ParserMode：`media-pipeline`

```text
metadata
duration
chapters
transcript optional
segments
```

输出：

```text
MediaBlock
TranscriptSegmentBlock
SourceRef(time range)
```

---

## 12.17 IPYNB / Notebook Parser（扩展设计）

ParserMode：默认 `dom-ast-model`；超限 notebook 规划中切到 `block-streaming`

### 设计定位

`ipynb` 不是普通 JSON 文本，也不是 package 文档。它更接近“有顺序的结构化 notebook 容器”：

```text
top-level notebook metadata
ordered cells
markdown / code / raw cell kinds
rich outputs
attachments / display_data
language and kernel hints
```

因此建议：

```text
默认复用现有 dom-ast-model canonical route
大 notebook 再按 cell / output group 降级到 block-streaming
不新增专属 parser mode
不改写现有 RoutePlanner 的基本分流原则
```

### 输入特征

```text
本质上是 JSON 文档
但核心语义不在任意键值，而在有序 cells 与 output boundary
markdown cell 可复用 Markdown lowering
code cell output 需要做类型化降落，而不是单纯 fenced json
```

### 扫描策略

```text
解析顶层 notebook JSON
保留 nbformat / language_info / kernelspec 等 notebook-level facts
按 cells 顺序逐个 lowering
markdown cell 进入 Markdown-like block lowering
code cell 进入 CodeBlock，并按 output 类型派发 text/table/image/raw
raw cell 保守降为 RawBlock 或 fenced raw text
attachment / display_data 优先转 AssetRef + source refs
```

### 输出

```text
小中 notebook -> DocumentIR
大 notebook -> BlockStream(cell/output-group)
Markdown-derived HeadingBlock / ParagraphBlock / ListBlock / TableBlock
CodeBlock
OutputBlock（在当前 CoreBlock 体系内优先映射为 Table / Raw / Image / Paragraph，而不是先新增专属 block kind）
AssetRef
SourceRef(json_pointer + extra cell markers)
```

### Markdown / RAG 策略

```text
markdown cell：复用现有 Markdown route 的 lowering 语义
code cell：以 fenced code 为主，并保留 language hint
stdout / stderr：优先 fenced text 或 RawBlock
tabular output：优先 TableBlock，小样本输出 Markdown table，大样本可降级
text/html output：只在安全边界内做受控 HTML lowering；否则保留 raw snippet
image/png / image/jpeg：转 AssetRef，并由 renderer 决定输出占位或引用
RAG chunking：默认不跨 cell 粗暴合并；优先保留 cell 级 chunk boundary
```

### 边界说明

```text
不执行 notebook
不重算 code output
不依赖 cell 之间隐藏运行时状态恢复
不因为 ipynb 引入新的 public OutputFormat
Accurate 当前也不应让 ipynb 切换到新的 parser route；后续若做高保真增强，优先仍在同 route 内增加 output normalization / diagnostics / source refs
```

---

## 13. FormatDetector 设计

### 13.1 检测顺序

```text
1. 用户显式指定 format
2. magic bytes / signature
3. MIME type
4. 文件扩展名
5. container internal inspection
6. text/binary heuristic
```

### 13.2 DetectedFormat

```moonbit
pub struct DetectedFormat {
  extension : Option[String]
  mime : Option[String]
  format : String
  confidence : Double
  is_container : Bool
  is_binary : Bool
  reason : Array[String]
}
```

### 13.3 常见 magic bytes

```text
PDF: %PDF-
ZIP/OOXML/EPUB: PK\x03\x04
PNG: \x89PNG
JPEG: FF D8 FF
GIF: GIF87a / GIF89a
TIFF: II*\x00 / MM\x00*
```

### 13.4 OOXML/EPUB 区分

ZIP 内部判断：

```text
[Content_Types].xml + word/document.xml -> docx
[Content_Types].xml + ppt/presentation.xml -> pptx
[Content_Types].xml + xl/workbook.xml -> xlsx
mimetype=application/epub+zip + META-INF/container.xml -> epub
```

### 13.5 TOML / IPYNB 扩展检测

```text
toml:
  优先使用 .toml 扩展名或 application/toml
  在扩展名缺失但用户显式指定时，允许用基础 grammar probe 辅助确认
  不建议把普通 ini/conf 轻易误判成 toml

ipynb:
  优先使用 .ipynb 扩展名或 notebook 相关 MIME
  若扩展名丢失但内容是 JSON，可在顶层存在 nbformat + cells 数组时升级识别为 ipynb
  一旦识别为 ipynb，就不应再按普通 json 的“无序键值文档”策略处理
```

---

## 14. ParserRegistry 与 RoutePlanner

### 14.1 ParserRegistry

```moonbit
pub struct ParserRegistry {
  parsers : Array[Parser]
}
```

选择逻辑：

```text
format match
capability match
convert mode match
resource limits match
priority score
RoutePlanner selected_route
```

### 14.2 canonical route 策略

示例：

```text
txt/csv/tsv/jsonl/ndjson -> streaming-event
markdown -> dom-ast-model, over-limit -> block-streaming
yaml/json/xml -> dom-ast-model, over-limit -> streaming-event
toml -> dom-ast-model
ipynb -> dom-ast-model, over-limit -> block-streaming(cell/output-group)
html -> dom-ast-model + readability/hybrid, over-limit -> block-streaming(section/subtree)
docx/pptx -> package-single-pass
xlsx -> package-single-pass, over-limit -> block-streaming(sheet/row/table-region)
pdf -> page-single-pass, Accurate / explicit OCR -> layout-two-stage
zip -> container-recursive
```

Diagnostics 中必须记录：

```text
selected_route
route_reason
route_probe_summary
same_mode_degradation
warnings
degraded_features
```

---

## 15. ConvertOptions

```moonbit
pub struct ConvertOptions {
  mode : ConvertMode
  output_format : OutputFormat
  explicit_format : DetectedFormat?
  ocr_options : OcrOptions
  limits : ResourceLimits
  pdf_cleanup_mode : PdfCleanupMode
  pdf_table_mode : PdfTableMode
  rag_options : RagOptions
}
```

当前职责边界：

```text
ConvertOptions 是 convert 层的执行编排配置。
它负责选择转换模式、输出投影、输入解析入口、资源上限，以及当前已产品化的 PDF/RAG 选项。
它不是覆盖全部 renderer 策略的总配置对象。
未进入该结构的更宽 renderer 策略，不构成当前公开契约。
```

### 15.1 OutputFormat

```moonbit
pub enum OutputFormat {
  Markdown
  Json
  RagJson
  DebugJson
}
```

当前产品语义：

```text
Markdown：默认公开输出
DebugJson：当前唯一正式公开的结构化调试输出
RagJson：当前正式公开的 RAG 输出
Json：内部/兼容保留位，不单独作为公开产品语义；当前不提供独立 CLI surface
```

### 15.2 PdfCleanupMode

```moonbit
pub enum PdfCleanupMode {
  Disabled
  Conservative
}
```

说明：

```text
当前只把 PDF 页眉页脚清理收口为这一个显式产品选项。
更宽的 PDF 能力矩阵仍属于后续实现，不在现行 ConvertOptions 契约中展开。
```

### 15.3 PdfTableMode

```moonbit
pub enum PdfTableMode {
  Disabled
  Simple
}
```

说明：

```text
当前只把 PDF 的简单表格重建收口为这一个显式产品选项。
更复杂的表格识别与结构恢复仍属于后续实现，不在现行 ConvertOptions 契约中展开。
```

### 15.4 RagOptions

```moonbit
pub struct RagOptions {
  chunk_size : Int
  chunk_overlap : Int
  preserve_heading_path : Bool
  preserve_source_ref : Bool
  split_tables : Bool
  split_code_blocks : Bool
}
```

---

## 16. ConvertResult

```moonbit
pub struct ConvertResult {
  content : String
  output_format : OutputFormat

  metadata : Map[String, JsonValue]
  assets : Array[AssetRef]
  diagnostics : Diagnostics
  source_map : Option[SourceMap]

  chunks : Option[Array[RagChunk]]
  debug_ir : Option[DocumentIR]
}
```

### 16.1 RagChunk

```moonbit
pub struct RagChunk {
  id : String
  kind : ChunkKind
  text : String
  heading_path : Array[String]
  source_refs : Array[SourceRef]
  asset_refs : Array[AssetId]
  metadata : Map[String, JsonValue]
}

pub enum ChunkKind {
  Text
  Table
  Code
  ImageCaption
  Metadata
  Raw
}
```

---

## 17. 错误处理策略

### 17.1 错误类型

```moonbit
pub enum ConvertError {
  UnsupportedFormat(String)
  DetectionFailed(String)
  ParseFailed(String)
  ResourceLimitExceeded(String)
  RendererFailed(String)
  IoError(String)
  SecurityError(String)
}
```

### 17.2 可恢复错误

可恢复错误不应直接中断整个转换：

```text
单张图片读取失败
单个附件解析失败
单页 PDF 解析失败
某个表格结构恢复失败
OCR 某页失败
```

处理方式：

```text
记录 warning
标记 degraded_features
继续转换其余内容
```

### 17.3 不可恢复错误

```text
文件不存在
权限失败
格式完全不支持
容器安全检查失败
超出硬性资源限制
```

处理方式：

```text
返回 ConvertError
保留 diagnostics
```

---

## 18. 资源与安全策略

### 18.1 资源限制

必须支持：

```text
max_file_size
max_memory_mb
max_pages
max_rows
max_cols
max_cells
max_assets
max_recursion_depth
timeout_ms
```

### 18.2 容器安全

对 ZIP/TAR：

```text
禁止绝对路径
禁止 ../ 路径穿越
限制 entry 数
限制总解压大小
限制递归层级
检测压缩炸弹风险
```

### 18.3 HTML 安全

```text
不执行 script
不加载远程资源，除非显式允许
过滤危险 URI scheme
```

### 18.4 图片/OCR 安全

```text
限制像素数
限制页数
限制 OCR 时间
限制临时文件大小
```

---

## 19. 模块目录建议

```text
src/
  markitdown/
    mod.mbt

    input/
      source.mbt
      detector.mbt
      mime.mbt
      magic.mbt

    core/
      ir/
        block.mbt
        document.mbt
        event.mbt
        signal.mbt
        source_ref.mbt
        asset.mbt
        diagnostics.mbt
        metadata.mbt
      pass/
        pass.mbt
        normalize_text.mbt
        whitespace.mbt
        merge_lines.mbt
        reading_order.mbt
        header_footer.mbt
        heading.mbt
        list.mbt
        table.mbt
        caption.mbt
        section_tree.mbt
        chunking.mbt
      render/
        renderer.mbt
        markdown.mbt
        json.mbt
        rag.mbt
        debug.mbt

    parser/
      parser.mbt
      registry.mbt
      capability.mbt
      result.mbt

      text/
        text_parser.mbt
        log_parser.mbt
      csv/
        csv_parser.mbt
      json/
        json_parser.mbt
        jsonl_parser.mbt
      yaml/
        yaml_parser.mbt
      toml/
        toml_parser.mbt
      markdown/
        markdown_parser.mbt
      html/
        html_parser.mbt
        readability.mbt
      ipynb/
        notebook_parser.mbt
        cell_lowering.mbt
        output_lowering.mbt
      epub/
        epub_parser.mbt
      office/
        ooxml_package.mbt
        docx_parser.mbt
        pptx_parser.mbt
        xlsx_parser.mbt
      pdf/
        pdf_parser.mbt
        pdf_page.mbt
        pdf_layout.mbt
      image/
        image_parser.mbt
        ocr.mbt
      email/
        eml_parser.mbt
        mbox_parser.mbt
        msg_parser.mbt
      archive/
        archive_parser.mbt
      media/
        subtitle_parser.mbt
        media_parser.mbt

    convert/
      options.mbt
      converter.mbt
      result.mbt
      pipeline.mbt

    util/
      id.mbt
      limits.mbt
      json_value.mbt
      error.mbt
```

---

## 20. 测试策略

### 20.1 单元测试

```text
FormatDetector test
ParserCapability test
CoreIRBuilder test
每个 IR Pass test
Renderer test
```

### 20.2 fixture 测试

每种格式至少准备：

```text
empty file
small normal file
large file
unicode file
malformed file
file with images
file with tables
file with nested structure
```

### 20.3 golden snapshot

对每个 fixture 保存：

```text
expected markdown
expected json ir optional
expected diagnostics subset
```

### 20.4 parser regression

尤其需要覆盖：

```text
DOCX numbering
DOCX merged table cells
PPTX speaker notes
XLSX large sheet
HTML noisy page
PDF two columns
PDF repeated header/footer
PDF table-heavy page
EPUB spine order
CSV huge file
JSONL huge file
TOML dotted keys / array-of-tables / multiline strings
IPYNB markdown+code cells / display_data / attachments / oversized notebook degradation
```

### 20.5 性能测试

指标：

```text
parser time
render time
total time
peak memory
output size
block count
table count
asset count
```

---

## 21. 推荐落地路线

### Phase 1：核心骨架

```text
InputSource
FormatDetector
Parser trait
ParseResult
CoreBlock / SourceRef / AssetRef / Diagnostics
MarkdownRenderer
ConvertOptions / ConvertResult
```

目标：让现有 parser 都能接入统一 pipeline。

### Phase 2：主格式接入

```text
text
csv
json/jsonl
markdown
html
docx
pptx
xlsx
pdf text-layer
```

目标：完成主格式的 parser -> Core IR -> Markdown。

补充说明：

```text
在当前主格式已经稳定的前提下，TOML 与 IPYNB 是最适合接入的下一批扩展格式：
它们都可以复用既有 structured-text / notebook lowering 主链，而不需要推翻现有 parser mode 体系。
```

### Phase 3：IR Pass 完善

```text
NormalizeWhitespacePass
ResolveHeadingPass
ResolveListPass
ResolveTablePass
ResolveReadingOrderPass
RemoveHeaderFooterPass
AssembleSectionTreePass
```

目标：提升 Markdown 结构质量。

### Phase 4：RAG / Debug 输出

```text
RagRenderer
ChunkingPass
DebugJsonRenderer
IR dump
source map export
```

目标：支持知识库和 parser 开发。

### Phase 5：高保真能力

```text
PDF layout
OCR
table structure recognition
image OCR
cross-page table merge
caption binding
```

目标：覆盖复杂 PDF、扫描件和财报论文类文档。

---

## 22. 最终架构约束清单

必须遵守：

```text
1. Parser 不直接生成 Markdown。
2. Markdown 不是中间表示。
3. Parser 可以多态，Core IR 必须统一。
4. 所有复杂格式必须带 SourceRef。
5. 所有 parser 必须返回 Diagnostics。
6. 大文件格式优先 streaming 或 block-streaming。
7. PDF 不追求 byte-level 真流式，默认 page-level。
8. XLSX 不默认全量 workbook model，大表必须受 limits 保护。
9. HTML 默认 hybrid，不应机械 DOM 全量转 Markdown。
10. EPUB 必须按 spine 顺序，而不是 zip entry 顺序。
11. DOCX 应信任源结构，不要像 PDF 一样过度推断。
12. PPTX 应按 slide 建模，不要强行当长文档。
13. OCR/layout/table recognition 属于 Accurate 模式，不默认开启。
14. Renderer 不读取源格式。
15. IR Pass 不依赖具体 parser 库。
16. RoutePlanner 必须记录 diagnostics，并写明 selected_route / route_reason / route_probe_summary。
17. 仅允许同模式内 degradation；degradation 必须记录 diagnostics，且禁止跨模式 fallback。
18. 容器解析必须做安全限制。
19. RAG chunk 必须保留 heading path 和 source refs。
20. TOML / IPYNB 等新增格式应优先复用现有 dom-ast-model / block-streaming，而不是为了单一格式发明新 parser mode。
21. IPYNB 不执行 cell，不重算 output；只消费文件中已有 notebook 事实。
```

---

## 23. 一句话总结

mb-markitdown 的合理架构不是“所有格式统一扫描方式”，而是：

```text
线性大文件走 streaming-event；
压缩包文档走 package-single-pass；
分页文档走 page-single-pass；
markup/tree 文档走 dom-ast-model；
复杂视觉文档走 layout-two-stage；
markdown / html / xlsx 等分块友好格式在超限时走 block-streaming；
所有分流都由 convert 的 RoutePlanner 决定，且不允许跨模式 fallback；
容器文件走 container-recursive；
媒体文件走 media-pipeline。

所有 parser 输出 ParseResult；
所有 ParseResult 先收敛到公开三态 IRInput，并经 pipeline 进入 RenderInput；
所有 Markdown/Debug JSON/RAG 输出由 Renderer 统一生成。
```

这套设计可以同时保留 MarkItDown 类工具的轻量速度优势，也给复杂 PDF、Office、HTML、EPUB、RAG 和 Debug 留出足够的结构空间。
