# OCR 与 PDF OCR / Layout 架构书

> 路径：`docs/architecture/ocr-and-pdf-ocr-architecture.md`
>
> 本文是 [`docs/architecture/mb-markitdown-architecture.md`](./mb-markitdown-architecture.md)
> 与
> [`docs/architecture/format-mode-and-execution-profile-architecture.md`](./format-mode-and-execution-profile-architecture.md)
> 在 OCR、PDF OCR、layout provider、route 触发规则上的专项补充与收敛文档。

建议阅读顺序：

1. 先读主架构书，理解统一主链 `detect -> probe -> planner -> parser -> pipeline -> renderer`。
2. 再读 mode / profile 架构书，理解 `Balanced / Accurate / Stream` 的稳定语义。
3. 最后读本文，理解 OCR、PDF OCR、layout 支持、provider 选择与触发规则。

---

## 0. 文档定位

本文只回答以下问题：

1. OCR 在本项目中到底是什么能力层，而不是什么。
2. OCR 与 `Balanced / Accurate / Stream` 的关系应如何建模。
3. PDF 何时允许进入 OCR / layout 路线。
4. PDF 中“整页 OCR”和“内嵌图片 OCR”应如何区分。
5. Tesseract、PaddleOCR / PP-StructureV3 等 provider 应如何进入统一主链。
6. zip / container / batch 处理时，如何批量触发扫描件 OCR，同时避免误伤正常 PDF。

本文是规范性架构文档，不是当前实现说明。

如果当前实现与本文冲突，应优先视为待收敛技术债，而不是修改本文去迁就阶段性实现。

---

## 1. 设计目标

OCR 相关设计必须同时满足以下目标：

1. 保持默认产品路径轻量：
   默认行为不得依赖沉重 OCR/layout 运行时。
2. 保持模式语义稳定：
   `Balanced / Accurate / Stream` 不能退化成“某个具体 provider 的别名”。
3. 允许显式与批量触发：
   用户既能单文件显式确认 OCR，也能在 zip / batch 下对扫描件批量触发 OCR。
4. 避免误 OCR：
   正常 born-digital PDF 中的内嵌图片，不应因为启用了 PDF OCR 就被误当成“纯图片输入”。
5. 支持 provider 演进：
   provider 可以替换、降级、回退，但产品契约不能绑死在某个具体模型名上。
6. 保持可解释性：
   每次是否 OCR、为何 OCR、选了哪个 provider、对哪些页 OCR，都必须在 diagnostics / provenance 中可解释。

---

## 2. 核心结论

如果只记住本文五条规则，应当是：

1. `mode` 与 `OCR policy` 必须解耦。
2. PDF OCR 的触发条件不能由“文件大”或“批处理模式”隐式决定。
3. PDF OCR 的自动触发必须建立在 `scanned-like probe` 证据上。
4. PDF OCR 默认是“整页 / 按页 OCR”，不是“自动 OCR PDF 里的 asset 图片”。
5. provider 选择是执行计划的一部分，不是模式语义本身。

---

## 3. OCR 的能力边界

在本项目中，`OCR` 是一个受约束的能力层，不等于“任何图像理解能力”。

它的正式职责包括：

1. 从图片或栅格化页面恢复文本。
2. 产生带 bbox / confidence 的 OCR 结构。
3. 在需要时补充 layout region、reading order、table structure 等 typed facts。

它不直接承诺：

1. 无证据的复杂阅读顺序猜测。
2. 无证据的 figure 理解或语义补全。
3. 把整页 OCR 结果直接当作最终 Markdown 结构。
4. 用 OCR 取代 native-text PDF 主链。

因此 OCR 在统一主链中的位置应当是：

```text
OCR provider
  -> OcrPageModel / LayoutRegion / TableSignal / confidence
  -> parser-owned facts
  -> IR passes
  -> renderer
```

而不是：

```text
OCR provider -> final Markdown
```

---

## 4. 模式与 OCR 的关系

### 4.1 模式不等于 provider

`Balanced / Accurate / Stream` 表达的是转换哲学，不是 provider 名称。

因此以下绑定都不应成为正式架构语义：

1. `Balanced = Tesseract`
2. `Accurate = PaddleOCR`
3. `Accurate = 一定 OCR`

更准确的关系应当是：

1. `Balanced`：
   优先轻量 canonical 路线；如果 OCR 被允许，也优先轻量 provider 默认值。
2. `Accurate`：
   允许 route-level OCR/layout upgrade；如果 OCR 被允许，也优先高保真 provider 默认值。
3. `Stream`：
   不改变 OCR 能力边界本身，只影响资源策略、flush/windowing 与输出路径。

### 4.2 模式与 OCR policy 解耦

用户模式之外，应单独存在 OCR policy。

至少要区分两类 policy：

1. 通用 OCR policy：
   面向直接图片输入与非 PDF OCR 输入。
2. PDF OCR policy：
   专门决定 PDF 何时允许进入 OCR / layout 路线。

这样做的原因是：

1. `Balanced` 仍然可以在显式确认或批量扫描件场景下做 OCR。
2. `Accurate` 也不必意味着对每个 PDF 无条件整本 OCR。
3. zip / batch / container 处理不需要靠切 mode 才能批量触发扫描件 OCR。

---

## 5. OCR policy 设计

### 5.1 通用 OCR policy

直接图片 OCR 的 policy 可以继续保持相对简单。

推荐至少支持：

1. `disabled`
2. `auto`
3. `explicit`

其中：

1. `disabled`：
   不启用 OCR。
2. `auto`：
   对天然图像输入按格式策略自动启用 OCR。
3. `explicit`：
   由用户显式确认 OCR。

对于直接图片输入，`auto` 仍可保持为正式默认。

### 5.2 PDF OCR policy

PDF 需要独立于通用 OCR policy 的专门策略。

推荐正式引入：

1. `disabled`
2. `explicit`
3. `auto_scanned`
4. `force`
5. `redo`

含义如下：

1. `disabled`：
   PDF 不进入 OCR / layout 路线。
2. `explicit`：
   只有显式确认时才进入 OCR / layout 路线。
3. `auto_scanned`：
   先做 scanned-like probe，只有命中扫描件/弱文本层证据时才进入 OCR。
4. `force`：
   无条件对 PDF 页做 OCR。
5. `redo`：
   在已有文本层的 PDF 中，仅对低质量或缺失文本页重做 OCR，并优先保留高置信 native text。

正式产品默认建议：

1. `Balanced PDF` 默认 `explicit`
2. `Accurate PDF` 默认 `auto_scanned`
3. batch / zip / container 可显式要求 `auto_scanned`

`force` 与 `redo` 可以作为后续能力，不要求第一阶段全部实现，但架构上应预留其语义。

---

## 6. PDF OCR 触发规则

### 6.1 不允许的触发方式

以下条件不得直接作为 PDF OCR 触发条件：

1. 文件大
2. 页数多
3. 进入 zip / container / batch
4. 命中普通资源限制
5. PDF 中存在图片 asset

原因是这些条件既不能稳定识别扫描件，也容易把默认产品路径拖进重型运行时。

### 6.2 允许的触发方式

PDF 进入 OCR / layout 路线只能由以下来源之一触发：

1. `pdf_ocr_policy = explicit`
2. `pdf_ocr_policy = force`
3. `pdf_ocr_policy = redo`
4. `pdf_ocr_policy = auto_scanned` 且 probe 证据命中 scanned-like 判定
5. `Accurate` 模式下的 PDF 策略表明确规定默认 `pdf_ocr_policy = auto_scanned`

### 6.3 Balanced 下的扫描件批量触发

`Balanced` 不得隐式升级为 OCR 路线，这条原则保留。

但这并不意味着 `Balanced` 不能批量处理扫描件。

正确做法是：

1. `Balanced` 保持其默认 mode 语义不变。
2. 用户或上层 batch / zip 入口显式设置 `pdf_ocr_policy = auto_scanned`。
3. planner 依据 probe 冻结是否对某个 PDF 或某些页进入 OCR。

因此：

```text
Balanced + pdf_ocr_policy=auto_scanned
```

是正式允许的设计。

它仍然属于 `Balanced`，不是偷偷切到 `Accurate`。

---

## 7. scanned-like probe

### 7.1 目标

`scanned-like probe` 是 PDF OCR 自动触发的唯一证据入口。

它的目标不是直接冻结 route，而是提供结构化信号。

### 7.2 典型 probe_signals

PDF probe 至少应尝试提供以下信号：

1. `pdf_page_count`
2. `pdf_native_text_span_count`
3. `pdf_native_text_coverage_ratio`
4. `pdf_empty_text_page_count`
5. `pdf_large_image_page_count`
6. `pdf_page_image_coverage_ratio`
7. `pdf_scanned_like_page_count`
8. `pdf_scanned_like_page_ratio`

如能力允许，还可补充：

1. `pdf_average_char_density`
2. `pdf_text_layer_quality_hint`
3. `pdf_vector_text_presence`
4. `pdf_background_image_dominant_page_count`

### 7.3 判定原则

scanned-like 判定应遵循保守原则：

1. 优先识别“文本层缺失或极弱”的页。
2. 同时参考大图覆盖率、页级文本密度、vector text 存在性。
3. 对边界页宁可不自动升级，也不要误判整本为扫描件。

### 7.4 planner 职责

probe 只提供信号。

planner 负责：

1. 判断文档是否 scanned-like。
2. 判断是否只对部分页 OCR。
3. 记录 `route_reason`、`route_probe_summary`、`same_mode_strategy_switches`。

---

## 8. PDF OCR 的页级混合策略

### 8.1 不推荐整本一刀切

对 mixed PDF，整本 OCR 往往是次优策略。

典型 mixed PDF 包括：

1. 前几页是扫描件，后几页是原生文本层。
2. 正文有文本层，但夹带图片型附录。
3. 部分页 text layer 损坏或为空。

因此 PDF OCR 正式策略应优先支持“按页混合”：

1. 有效 native-text 页：继续走 native-text page path
2. scanned-like 页：进入 OCR / layout page path
3. 最终在文档组装阶段合并为同一个 Document IR

### 8.2 Page-level Hybrid Assembly

推荐正式定义：

```text
pdf page route:
  native_text_page
  ocr_page
```

组装规则：

1. page 是 planner 和 provenance 的稳定单位。
2. 每页都要记录其来源：
   `native_text` 或 `ocr_provider:<name>`
3. 文档级 diagnostics 需要汇总：
   `ocr_used_pages`
   `native_text_pages`
   `scanned_page_ratio`
   `mixed_page_route`

### 8.3 redo 语义

`redo` 的正式方向应是：

1. 优先保留高置信 native-text page facts
2. 对缺字、乱码、极弱文本层的页补做 OCR
3. 避免让 OCR 粗暴覆盖正常文本层

这比“有文本层就完全不 OCR”与“整本强制 OCR”都更稳。

---

## 9. PDF OCR 与 PDF 内嵌图片 OCR 的边界

这是本文最重要的边界之一。

### 9.1 整页 OCR

`page OCR` 指：

1. 先把 PDF 页 rasterize
2. 再把整页送入 OCR / layout provider

它的正式用途是：

1. 扫描件
2. 图片型 PDF
3. 弱文本层 PDF
4. 需要页级 layout / table / reading order 恢复的 accurate 路线

### 9.2 内嵌图片 OCR

`asset image OCR` 指：

1. 从 PDF 中提取内嵌图片 asset
2. 对图片 asset 单独做 OCR

它的用途不同：

1. figure / screenshot / scan-in-figure 中的局部文字恢复
2. image appendix / image notes / OCR caption enrich
3. 特定产品场景下的图片搜索或 RAG

### 9.3 正式规则

默认情况下：

1. `page OCR` 可以由 `pdf_ocr_policy` 驱动。
2. `asset image OCR` 不能因为启用了 `page OCR` 而自动启用。
3. `asset image OCR` 必须是单独的 feature / policy / provider 决策。

否则会出现：

1. 正常 PDF 中的插图被误 OCR
2. figure asset 被错误混入正文 reading order
3. 页面与图片 OCR 结果重复注入文档

因此 planner、parser、diagnostics 都必须区分：

1. `pdf_page_ocr_used`
2. `pdf_asset_image_ocr_used`

---

## 10. provider 架构

### 10.1 provider 是能力后端，不是产品契约

provider 是实现某一 OCR / layout 能力的运行时后端。

产品契约不应直接写成：

1. PDF Accurate 等于 PaddleOCR
2. 图片 OCR 等于 Tesseract

更稳定的建模应当是：

1. 定义 provider kind taxonomy
2. 在 plan 中记录 selected provider
3. 在策略表中定义 mode-aware default provider
4. provider 选择必须保持 plan-driven，且缺依赖时 fail closed

### 10.2 provider 类型

推荐将 OCR / layout provider 语义拆分为：

1. `TextOcrProvider`
2. `DocumentLayoutProvider`
3. `TableStructureProvider`
4. `PdfRasterProvider`

第一阶段若实现上仍由一个后端同时承担多项职责，也应在架构上保留这层语义拆分。

### 10.3 推荐 provider 角色

对当前产品定位，推荐角色如下：

1. `Tesseract`
   轻依赖、轻运行时、CLI 友好，适合轻量默认 OCR 底座。
2. `PaddleOCR / PP-StructureV3`
   更适合 Accurate 路线的 OCR + layout + table provider 默认值。
3. `pdftoppm` 或同类 raster backend
   是 PDF page OCR 的 raster provider，不等于 OCR provider。

### 10.4 默认 provider 策略

推荐默认值：

1. 直接图片 Balanced：
   默认 `Tesseract`
2. 直接图片 Accurate：
   默认 `PaddleOCR`
3. PDF Balanced + explicit / auto_scanned：
   默认 `Tesseract`
4. PDF Accurate + auto_scanned / force / redo：
   默认 `PaddleOCR`

这只是默认值，不是唯一实现。

### 10.5 fail-closed provider policy

当前正式产品策略是不做 provider fallback，而是在缺依赖或 provider 运行失败时 fail closed。

要求如下：

1. `selected_provider` 仍然必须进入 plan / provenance / diagnostics。
2. 缺依赖时必须返回稳定的 dependency diagnostics / install guidance。
3. 禁止静默切换到另一个 OCR provider。
4. 如未来重新开放 fallback，必须先更新正式架构契约，而不是作为实现细节偷偷恢复。

### 10.6 Paddle bridge runtime contract

当前实现已经把 `PaddleOCR` provider 落到一个可执行的 bridge 协议上，但它仍然是
`provider adapter`，不是完整的 PDF Accurate route。

运行时约定如下：

1. 通过环境变量 `MARKITDOWN_PADDLE_OCR_CMD` 提供 adapter 命令。
2. 运行时调用形式固定为：

```text
<adapter_cmd> <image_path> [--lang <LANG>]
```

3. adapter 必须把 OCR 结果写到 `stdout`，格式为单个 JSON object。
4. adapter 非零退出码进入 `CommandUnavailable` 或 `ExecutionFailed` taxonomy。
5. adapter 零退出但 JSON 不合法或字段缺失，进入 `OutputParseFailed` taxonomy。
6. adapter 零退出但 `pages` 为空，进入 `EmptyResult` taxonomy。

当前 bridge payload 正式契约为：

```json
{
  "provider_name": "paddle_ocr",
  "provider_version": "3.0.0",
  "diagnostics": ["adapter=sample"],
  "pages": [
    {
      "page_index": 0,
      "width": 1000,
      "height": 2000,
      "language": "eng",
      "diagnostics": ["page=0"],
      "blocks": [
        {
          "block_index": 0,
          "bbox": { "x0": 10, "y0": 20, "x1": 300, "y1": 120 },
          "confidence": 0.97,
          "lines": [
            {
              "line_index": 0,
              "text": "MoonBit OCR",
              "bbox": { "x0": 10, "y0": 20, "x1": 280, "y1": 60 },
              "confidence": 0.98,
              "words": [
                { "word_index": 0, "text": "MoonBit" },
                { "word_index": 1, "text": "OCR" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

其中：

1. `provider_name` 与 `pages` 是必填字段。
2. `page.blocks`、`block.lines`、`line.words` 都是正式结构字段，不接受直接吐纯文本。
3. `bbox`、`confidence`、`provider_version`、`diagnostics`、`language` 是可选增强字段。
4. bridge 输出只负责统一 OCR / layout facts，不直接输出 Markdown。
5. 不允许 bridge 静默降级到别的 provider；当前缺依赖时必须直接 fail closed。

仓库内的 `samples/helpers/paddle_ocr_bridge.py` 是当前 bridge 协议的参考实现。

---

## 11. route 设计

### 11.1 PDF canonical route

PDF 仍保持：

1. canonical route：`page_single_pass`
2. OCR / layout upgrade route：`layout_two_stage`

但 `layout_two_stage` 不再被理解为“默认整本 rasterize + OCR-only”。

更准确的定义应为：

```text
layout_two_stage
  stage 1: page probe / native text inventory / raster readiness
  stage 2: page-level OCR/layout/table provider path when policy allows
```

### 11.2 图片 canonical route

直接图片输入仍可使用 `layout_two_stage` 作为 OCR 主路由。

但 route 内部应允许：

1. OCR-only provider path
2. OCR + layout provider path
3. OCR + layout + table provider path

### 11.3 route 不是 provider

同一个 `layout_two_stage` route 内，可以根据 plan 选择不同 provider 组合。

因此 route 语义不应绑死为：

1. `layout_two_stage = tesseract`
2. `layout_two_stage = PaddleOCR`

---

## 12. ExecutionIntent / ProbeOutcome / Plan 扩展

### 12.1 ExecutionIntent

内部意图对象至少应新增或显式收口以下概念：

1. `ocr_policy`
2. `pdf_ocr_policy`
3. `preferred_ocr_provider`
4. `preferred_layout_provider`

### 12.2 ProbeOutcome

PDF probe 需要支持：

1. `pdf_scanned_like_page_ratio`
2. `pdf_native_text_coverage_ratio`
3. `pdf_empty_text_page_count`
4. `pdf_page_image_coverage_ratio`

### 12.3 ResolvedExecutionPlan

正式执行计划至少应能解释：

1. `selected_route`
2. `selected_pdf_page_strategy`
3. `pdf_ocr_policy`
4. `selected_ocr_provider`
5. `selected_layout_provider`
6. `provider_reason`
7. `ocr_page_selection_reason`
8. `scanned_like_probe_summary`

---

## 13. diagnostics 与 provenance

OCR 相关 diagnostics 至少要区分四个层面：

1. 用户是否请求 OCR
2. planner 是否允许 OCR
3. 哪些页实际走了 OCR
4. 使用了哪个 provider，以及是否 fail closed

建议统一暴露以下 metrics / metadata：

1. `ocr_intent`
2. `pdf_ocr_policy`
3. `pdf_ocr_trigger`
4. `pdf_page_ocr_used`
5. `pdf_asset_image_ocr_used`
6. `ocr_provider_name`
7. `layout_provider_name`
8. `ocr_provider_status`
9. `ocr_used_pages`
10. `native_text_pages`
11. `scanned_page_ratio`
12. `mixed_page_route`

如发生自动触发，还应记录：

1. `route_reason = pdf_scanned_like_auto_upgrade`
2. `route_probe_summary = ...`

---

## 14. 批处理、zip 与容器递归

### 14.1 批处理原则

zip / container / batch 的正确设计不是：

1. 进入批处理就自动对全部 PDF OCR

而是：

1. 容器递归仍先 detect / probe
2. 对每个 PDF 单独应用 `pdf_ocr_policy`
3. `auto_scanned` 只对命中 scanned-like 的 PDF 或页面生效

### 14.2 推荐批量语义

推荐对 batch / zip 提供正式策略：

1. `inherit`
2. `pdf_auto_scanned`
3. `pdf_force`

其中：

1. `inherit`：
   复用普通单文档产品策略。
2. `pdf_auto_scanned`：
   对批量中的 PDF 显式启用 `pdf_ocr_policy = auto_scanned`。
3. `pdf_force`：
   对批量中的 PDF 显式启用 `pdf_ocr_policy = force`。

这样既能批量触发扫描件 OCR，也不会因为普通 born-digital PDF 带图片就误 OCR。

---

## 15. 对当前设计的收敛建议

基于本文，建议将现有方向收敛为：

1. 保留 PDF native-text `page_single_pass` 作为正式 canonical route。
2. 保留 `layout_two_stage` 作为 OCR / layout upgrade route。
3. 不再把 PDF OCR 的产品语义写成“`--accurate` 自动等于 OCR-only 路线”。
4. 引入 `pdf_ocr_policy`，用于显式、自动扫描件、强制与重做策略。
5. 将 `Balanced` 下批量扫描件 OCR 的正式触发方式定义为 `Balanced + pdf_ocr_policy=auto_scanned`。
6. 将“整页 OCR”和“PDF 内嵌图片 OCR”明确拆成不同能力面。
7. 将 provider 选择从硬编码切为 plan-driven default + fallback。
8. 让 `Tesseract` 作为轻量默认 OCR / fallback。
9. 让 `PaddleOCR / PP-StructureV3` 作为 Accurate 路线的高保真默认 provider。
10. `PaddleOCR` 通过 `MARKITDOWN_PADDLE_OCR_CMD`
    bridge 接入统一 provider 主链后，`pdf --accurate` 默认采用 `auto_scanned`；命中 scanned-like 时进入该 OCR route，如运行时缺少 Paddle，则明确提示安装方式并 fail closed。

---

## 16. 不应做的事

以下做法应视为架构反模式：

1. 因文件大或进入批处理而自动 OCR PDF。
2. 让 `Balanced` 因内部超限偷偷升级为 OCR / layout 路线。
3. 让 `Accurate` 默认无条件整本 OCR 全部 PDF。
4. 让 `page OCR` 自动带出 `asset image OCR`。
5. 在 parser、finalize、renderer 三处分别私自决定是否 OCR。
6. 把 provider 名直接写成 mode 语义。
7. 让 provider 静默切换且无 diagnostics。

---

## 17. 演进顺序

推荐的实施顺序是：

1. 先把 `mode`、`ocr_policy`、`pdf_ocr_policy` 文档语义收口。
2. 再给 planner / probe 增加 scanned-like signals 与 `route_reason`。
3. 然后让 PDF OCR 支持 page-level hybrid assembly。
4. 再引入 `PaddleOCR / PP-StructureV3` 作为 Accurate 默认 provider。
5. 最后再考虑 `redo`、asset image OCR 与更复杂 table/layout provider 组合。

这可以最大化保持当前主链稳定，同时逐步提升 PDF OCR 与 layout 能力。
