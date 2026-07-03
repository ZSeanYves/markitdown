# 格式能力档位与执行策略架构书

> 建议路径：`docs/architecture/format-mode-and-execution-profile-architecture.md`
>
> 本文是 [`docs/architecture/mb-markitdown-architecture.md`](./mb-markitdown-architecture.md) 的补充设计书，不替代主架构书。
>
> 本文不重定义 `Balanced / Accurate / Stream` 的用户语义，只补充两件事：
>
> 1. 各格式在不同 mode 下应该覆盖到什么能力
> 2. 同一 mode 内，面对中大文件时如何自动切换执行策略与渲染策略以提升性能

---

## 0. 不冲突约束

本文与主架构书、`docs/capabilities-and-limitations.md` 的关系必须满足以下约束：

1. `Balanced / Accurate / Stream` 仍然是用户可见 mode，不允许因为文件大小自动互相切换。
2. 自动切换只发生在同一 mode 内部，切的是 execution profile，而不是 mode。
3. `pdf` 不因为“文件大”自动升级到 OCR 或 layout-heavy 路线；`Accurate` 和显式 OCR 仍然是单独决策。
4. 当前 capabilities 文档里尚未正式承诺的能力，在本文中只能写成“目标覆盖”或“扩展路线”，不能表述成“当前已正式支持”。
5. 主架构书定义的统一主链 `input -> parser -> pipeline -> render` 不变，本文只细化 RoutePlanner、Lowering、Renderer 的策略选择层。

---

## 1. 设计目标

本项目的目标不是做一个“全格式全保真编辑器”，而是做一条轻量、成熟、可扩展的转换链。

这里的“轻量成熟化”具体指：

1. 默认 `Balanced` 要覆盖大多数用户真正需要消费的结构语义。
2. `Accurate` 只承接那些明显更重、明显更贵、但价值足够高的语义恢复。
3. `Stream` 只在天然适合流式的格式上暴露为正式能力，不为了“形式统一”强行给每个格式都加 `--stream`。
4. 中大文件优化优先通过“同 mode 内的执行策略切换”解决，而不是把用户悄悄切到另一个 mode。
5. 性能优化必须 fail-closed、可诊断、可解释，不能靠隐藏 fallback 掩盖能力边界。

---

## 2. 市场成熟实现给出的启发

业界成熟实现对我们的启发大致一致：

1. Pandoc 代表的是“markup / structured text 走 AST，再由 writer 输出”的路线，适合 Markdown、HTML、LaTeX、docx 这类文本与半结构化文档。
2. Apache Tika 代表的是“统一检测入口 + 专用 parser + 提取优先”的路线，说明广格式支持并不等于所有格式都追求同样深度的结构恢复。
3. Unstructured 把 PDF / image 的 `fast / hi_res / ocr_only / auto` 明确区分，说明“能力档位”和“底层策略”本来就应该是两个层次。
4. openpyxl 为超大 XLSX 提供 read-only / optimized modes，说明电子表格类格式天生需要“同格式内的轻重执行档位”。

对 mb-markitdown 来说，合理借鉴是：

1. 文本/markup 格式优先 AST 或 block/event lowering。
2. Office / container / paged document 维持专用 parser，不强行塞进一个万能 DOM。
3. 大文件优化优先做 route / lowering / render profile 的切换。
4. 真正 layout-heavy 的恢复只进入 `Accurate`，不污染默认 `Balanced`。

---

## 3. 当前实现里的 Mode、Route 与 Render 关系

这份补充架构必须先贴当前实现，而不是只写理想模型。

### 3.1 当前代码里的 mode 不是单一轴

当前实现里用户可见的 `ConvertMode` 是：

```moonbit
pub enum ConvertMode {
  Fast
  Balanced
  Accurate
  Stream
  Rag
  Debug
}
```

但在真正执行时，核心决策不是只看 `ConvertMode`，而是看三个字段：

```moonbit
pub struct ConvertOptions {
  mode : ConvertMode
  fidelity_mode : FidelityMode
  output_mode : OutputMode
  stream_requested : Bool
  ...
}
```

也就是说，当前产品语义其实已经被拆成了三层：

1. `fidelity_mode`：`Balanced` 或 `Accurate`
2. `output_mode`：`Markdown`、`Debug`、`Rag`
3. `stream_requested`：是否显式请求流式 route

### 3.2 当前 `ConvertMode` 到执行语义的映射

当前默认映射关系是：

| ConvertMode | fidelity_mode | output_mode | stream_requested |
| --- | --- | --- | --- |
| `Fast` | `Balanced` | `Markdown` | `false` |
| `Balanced` | `Balanced` | `Markdown` | `false` |
| `Accurate` | `Accurate` | `Markdown` | `false` |
| `Stream` | `Balanced` | `Markdown` | `true` |
| `Rag` | `Balanced` | `Rag` | `false` |
| `Debug` | `Balanced` | `Debug` | `false` |

这里有两个必须说清的事实：

1. 当前 `Stream` 不是“第三种 fidelity”，它默认仍然是 `Balanced fidelity + Markdown output + stream_requested=true`。
2. 当前 `Rag` 和 `Debug` 也不是 parser route，它们主要改变的是输出模式与 renderer。

因此本文后续提到的“mode”，应优先理解成：

1. `Balanced fidelity`
2. `Accurate fidelity`
3. `显式 stream 请求`

而不是把 `Stream` 当成与 `Balanced`、`Accurate` 完全同型的一条独立 fidelity 轴。

### 3.3 当前 route 决策的真实边界

当前 route 决策来自三类信号：

1. `stream_requested`
2. `fidelity_mode`
3. `preflight probe` 的 over-limit 探针

现状可以概括为：

1. `stream_requested=true` 时，优先尝试切到该格式的 `explicit_stream_route`。
2. 如果格式不支持显式 stream，则保留 canonical route，并写入 `explicit_stream_unsupported_fell_back`。
3. `fidelity_mode=Accurate` 当前只会正式改变少数格式行为，最明确的是 `pdf -> layout_two_stage OCR route`，以及 `docx/xlsx/pptx` 内部的更高保真 lowering。
4. over-limit 自动切换只在少数已接入 preflight probe 的格式上存在，不是全格式统一能力。

### 3.4 当前自动切换已经落地的格式

当前 `convert/preflight_probe.mbt` 已正式接入 over-limit 探针的格式有：

1. `markdown`
2. `json`
3. `ipynb`
4. `yaml`
5. `toml`
6. `xml`
7. `html`
8. `xlsx`
9. `pdf`

其中真正会因为 over-limit 自动改 route 的是：

| 格式 | canonical | over-limit 自动切换 |
| --- | --- | --- |
| `markdown` | `dom_ast_model` | `block_streaming` |
| `json` | `dom_ast_model` | `streaming_event` |
| `ipynb` | `dom_ast_model` | `block_streaming` |
| `yaml` | `dom_ast_model` | `streaming_event` |
| `xml` | `dom_ast_model` | `streaming_event` |
| `html` | `dom_ast_model` | `block_streaming` |
| `xlsx` | `package_single_pass` | `block_streaming` |

当前接了 preflight 但不会因为 over-limit 改 route 的有：

1. `toml`
2. `pdf`

其中：

1. `toml` 当前 probe 主要用于记录与暴露预算，不做大文件 route 切换。
2. `pdf` 当前 route 仍由 `fidelity_mode` 与显式 OCR 决定，不由“文件大”决定。

### 3.5 Stream 当前不只是 route，也会进入流式 render path

当前实现里，`RenderInput` 有三种：

```moonbit
RenderInput::Document
RenderInput::BlockStream
RenderInput::EventStream
```

当 parser / pipeline 最终产物是 `BlockStream` 或 `EventStream` 时：

1. `finalize_pipeline_convert_execution` 不会强行 materialize 成 `Document`
2. renderer 会走 `render_input(...)`
3. diagnostics 会记录 `stream_render_path=true`
4. provenance 会记录 `render_input_kind=block_stream` 或 `event_stream`

这意味着当前的“流式”至少有三层含义：

1. 显式请求流式 route
2. parser / pipeline 保持 `BlockStream` 或 `EventStream`
3. renderer 直接消费 stream-like input，而不是先转完整 document

因此本文后面谈 `Stream` 时，必须同时区分：

1. `stream_requested`
2. `selected_route`
3. `render_input_kind`

---

## 4. 现状约束下的 Mode 契约

### 4.1 Balanced fidelity

当前 `Balanced` 的真实语义是：

1. `fidelity_mode=Balanced`
2. 默认 `output_mode=Markdown`
3. 默认 `stream_requested=false`

它代表的是主产品默认路径，而不是“绝不允许 block/event route”。

因为当前实现里：

1. `Balanced` 也会在 over-limit 时自动切到 `block_streaming` 或 `streaming_event`
2. `Balanced` 也可以通过 `stream_requested=true` 显式请求流式 route

所以 `Balanced` 更准确的定义应该是：

1. 默认不开 OCR-heavy / layout-heavy / high-cost semantic recovery
2. 允许同 fidelity 内的 route 自适应与流式 render path

### 4.2 Accurate fidelity

当前 `Accurate` 的真实语义是：

1. `fidelity_mode=Accurate`
2. 默认 `output_mode=Markdown`
3. 默认 `stream_requested=false`

当前正式生效最明确的地方有：

1. `pdf` 会切到 `layout_two_stage` OCR 路线
2. `docx` 会开启更高保真 textbox / alternate content 相关恢复
3. `xlsx` 会开启 hidden rows / hidden sheets / merged span 等更高保真恢复
4. `pptx` 会开启 reading order、grouped shapes、merged span table 等更高保真恢复

因此本文里凡是“Accurate 应覆盖”的条目，都要区分：

1. 当前已在实现里生效
2. 当前只是建议的目标覆盖

### 4.3 Stream mode

当前 `ConvertMode::Stream` 的真实语义不是“独立 fidelity”，而是：

1. `fidelity_mode=Balanced`
2. `output_mode=Markdown`
3. `stream_requested=true`

因此，当前 `Stream mode` 更准确的定义是：

1. 显式请求优先走 `explicit_stream_route`
2. 若 route 产出 `BlockStream` / `EventStream`，则 renderer 走流式 render path
3. 若格式不支持显式 stream，则诚实回退到 canonical route，并保留 `stream_requested` 的诊断痕迹

这也是为什么本文不应把 `Stream` 写成“任何格式都能变流式”的承诺。

---

## 5. Stream 的正式语义与当前边界

### 5.1 Stream 不是自动切 mode

当前和未来都应坚持：

1. `Stream` 不因为文件大小自动触发。
2. `Stream` 是用户显式请求的语义。
3. over-limit 自动切换与 `Stream mode` 不是一回事。

### 5.2 Stream 的三种结果

当前代码里，显式 `Stream` 请求可能出现三种结果：

1. 显式 stream route 成功：
   - 例如 `html -> block_streaming`
   - `xlsx -> block_streaming`
   - `epub -> container_recursive`
2. 格式天生就是 streaming/block-like canonical：
   - 例如 `txt/csv/srt/vtt/jsonl/ndjson/eml/zip`
   - 这时 `Stream` 不是换路，而是显式确认本来就适合流式
3. 显式 stream 不支持，诚实 fallback：
   - 例如当前 `toml`
   - route reason 应为 `explicit_stream_unsupported_fell_back`

### 5.3 Stream 与流式 render path 的关系

当前实现里，不是只有 `ConvertMode::Stream` 才会走流式 render path。

只要最终 `render_input_kind` 是：

1. `block_stream`
2. `event_stream`

renderer 就会直接消费该输入，并写入：

1. `stream_render_path=true`
2. `render_input_kind=block_stream/event_stream`

这意味着：

1. `Balanced + over-limit route switch` 也可能进入流式 render path
2. `Stream mode` 只是更积极地请求这种路径

### 5.4 当前建议正式支持 `Stream` 的格式

结合现有实现，当前适合把 `Stream` 视为正式产品能力的格式是：

| 格式 | 当前实现状态 | 说明 |
| --- | --- | --- |
| `txt` | 已稳定 | canonical 就是 `streaming_event` |
| `csv` / `tsv` | 已稳定 | canonical 就是 `streaming_event` |
| `srt` / `vtt` | 已稳定 | canonical 就是 `streaming_event` |
| `jsonl` / `ndjson` | 已稳定 | canonical 就是 `streaming_event` |
| `json` | 已稳定 | explicit stream / over-limit 都走 `streaming_event` |
| `xml` | 已稳定 | explicit stream / over-limit 都走 `streaming_event` |
| `yaml` | 已稳定 | explicit stream / over-limit 都走 `streaming_event` |
| `html` | 已稳定 | explicit stream / over-limit 都走 `block_streaming` |
| `markdown` | 已稳定 | explicit stream / over-limit 都走 `block_streaming` |
| `ipynb` | 已稳定 | explicit stream / over-limit 都走 `block_streaming` |
| `eml` | 已稳定 | canonical 就是 `block_streaming` |
| `zip` | 已稳定 | canonical 就是 `container_recursive` |
| `epub` | 已稳定 | explicit stream 走 `container_recursive` |
| `odt` / `ods` / `odp` | 已稳定 | explicit stream 走 `block_streaming` |
| `xlsx` | 已稳定 | explicit stream / over-limit 都走 `block_streaming` |

### 5.5 当前不应承诺显式 Stream 的格式

结合现有实现与产品语义，当前不应把显式 `Stream` 写成正式承诺能力的格式是：

| 格式 | 当前状态 | 原因 |
| --- | --- | --- |
| `toml` | 已显式 fallback | 代码已明确不支持 explicit stream |
| `rst` / `asciidoc` / `tex` | canonical only | 当前没有 explicit stream route |
| `docx` | canonical only | 当前没有 explicit stream route |
| `pptx` | canonical only | 当前没有 explicit stream route |
| `pdf` | canonical/accurate only | `Stream` 容易与 OCR/layout 语义混淆 |
| `image OCR` | layout route only | 流式价值和产品语义都不稳定 |

---

## 6. 中大文件自适应策略总则

### 6.1 总原则

中大文件自适应只允许做下面三种事：

1. 切同 mode 内的大文件 route。
2. 切同 mode 内的 lowering profile。
3. 切同 mode 内的 render profile。

不允许做的事：

1. 因为文件大而自动从 `Balanced` 切到 `Accurate`。
2. 因为文件大而自动打开 OCR。
3. 因为文件大而自动把 `Stream` 冒充成 `Balanced` 或 `Accurate`。

### 6.2 当前已存在的自动切换

当前仓库里已经正式存在的 over-limit 自动切换只有以下几组：

1. `markdown : dom_ast_model -> block_streaming`
2. `json : dom_ast_model -> streaming_event`
3. `ipynb : dom_ast_model -> block_streaming`
4. `yaml : dom_ast_model -> streaming_event`
5. `xml : dom_ast_model -> streaming_event`
6. `html : dom_ast_model -> block_streaming`
7. `xlsx : package_single_pass -> block_streaming`

当前没有 over-limit 自动切换、只保留 canonical route 的包括：

1. `toml`
2. `pdf`
3. `docx`
4. `pptx`
5. `rst`
6. `asciidoc`
7. `tex`
8. `eml`
9. `zip`
10. `epub`
11. `odt`
12. `ods`
13. `odp`

因此本文后续提到的“中大文件自适应”要分成两类：

1. 当前已经实现的 route-level auto switch
2. 未来建议新增的 same-mode render/lowering profile

### 6.3 两级阈值是建议，不是当前全量现实

`soft_limit / hard_limit` 目前更适合作为下一步统一化设计，而不是描述为当前全仓库已落地事实。

当前现实是：

1. 现有 preflight 主要偏向“是否 over-limit 从而切 route”
2. 还没有统一的 `MediumAdaptive` / `LargeAdaptive` 公共结构
3. 大部分格式还没有独立的 `soft_limit render profile`

因此本文建议保留两级阈值设计，但必须视为“推荐演进方向”。

建议定义：

1. `soft_limit`：优先切 render / lowering profile，不切 mode
2. `hard_limit`：必要时切到该格式已定义的大文件 route

### 6.4 推荐的两级阈值用途

`soft_limit` 适合未来切渲染策略：

1. Markdown table 改成 sparse table markdown。
2. notes / comments 从 inline 改成 appendix。
3. assets 从 eager materialize 改成 manifest-first。
4. section / slide / chapter 改成更快的 flush 策略。

`hard_limit` 适合未来切 route 或 lowering：

1. `dom_ast_model -> streaming_event`
2. `dom_ast_model -> block_streaming`
3. `package_single_pass -> block_streaming`
4. `package_single_pass -> container_recursive`

### 6.5 预探针信号

建议统一预探针信号：

| 信号 | 典型格式 |
| --- | --- |
| `char_count` | txt, markdown, html, yaml, toml |
| `block_count` | markdown, html, ipynb, odt, docx |
| `node_count` / `token_count` | json, xml, yaml, html |
| `row_count` / `col_count` / `estimated_cells` | csv, tsv, xlsx, ods |
| `page_count` | pdf, tiff |
| `slide_count` | pptx, odp |
| `sheet_count` | xlsx, ods |
| `entry_count` / `decoded_size` | zip, epub |
| `asset_count` / `attachment_count` | eml, epub, html, office |

### 6.6 决策顺序

建议顺序：

1. 先根据 `fidelity_mode / output_mode / stream_requested` 确认能力上界。
2. 再根据 format 查当前 `FormatRouteProfile`。
3. 再跑已有的 cheap probe。
4. 先应用当前已经存在的 explicit-stream / over-limit route 规则。
5. 后续若引入 `FormatStrategyPolicy`，再叠加 `soft_limit` render/lowering profile。
6. parser / lowering / renderer 只消费决策，不自行越权切 mode。

---

## 7. 每个格式族的目标覆盖

以下各表描述的是“轻量成熟化转换链”的目标覆盖。

阅读方式如下：

1. `Balanced 应覆盖` 与 `Accurate 应覆盖` 是产品目标边界。
2. `中大文件自动策略` 里会明确区分“当前已实现”与“建议演进”。
3. 如果某项与 `docs/capabilities-and-limitations.md` 尚未对齐到正式承诺，应视为规划，不应写进对外能力宣称。

### 7.1 Plain text / Delimited / Subtitle

| 格式 | Balanced 应覆盖 | Accurate 应覆盖 | 中大文件自动策略 |
| --- | --- | --- | --- |
| `txt` | 段落切分、空行边界、基础 source refs、长行受控截断 | 预格式化段落识别、缩进代码块保留、行号更细粒度保留；不需要独立重 route | 当前 canonical 已是 `streaming_event`，renderer 可直接走 stream render path；未来可补 line truncation / chunk flush profile |
| `csv` / `tsv` | header 推断、稳定 markdown table、列裁剪诊断、RAG 友好行块 | 更稳的 multiline cell / quoting 边界、source refs 到行列；通常不需要更重 parser | 当前 canonical 已是 `streaming_event`；未来建议补 `soft_limit -> sparse table renderer`，而不是切 mode |
| `srt` / `vtt` | cue 顺序、时间范围、multiline caption、NOTE/STYLE/REGION 受控 degrade | speaker / inline style boundary 更细 source refs；不需要独立 route | 当前 canonical 已是 `streaming_event`，无额外 over-limit route；未来只需 chunk flush |

设计结论：

1. 这组格式的 `Accurate` 多数是“更细来源保真”，不是“更重结构推理”。
2. 这组格式的性能优化主要靠局部截断、区域 flush、稀疏渲染，不需要复杂 route 切换。

### 7.2 Structured text

| 格式 | Balanced 应覆盖 | Accurate 应覆盖 | 中大文件自动策略 |
| --- | --- | --- | --- |
| `json` | key/value 结构、数组/对象层次、基础 path-like source refs、人类可读 markdown | 更稳的 raw boundary 保留、大对象折叠策略、schema hint appendix；不做 editor 级 round-trip | 当前已实现 `hard_limit -> streaming_event`；未来建议补 `soft_limit` summary/appendix renderer |
| `jsonl` / `ndjson` | 一行一记录、稳定 record 输出、RAG 友好 | shared schema 摘要、字段稀疏统计；通常不需要重 route | 当前 canonical 已是 `streaming_event`；未来只需 record batch / flush profile |
| `xml` | 元素/属性/文本边界、常见结构树、基础 xpath-like refs | 命名空间、mixed-content 边界更稳、raw fragment appendix；不做完整 schema engine | 当前已实现 `hard_limit -> streaming_event`；未来建议补轻量 summary renderer |
| `yaml` | mapping/list/标量结构、常见表格化输出、基础 path refs | anchors/aliases 的显式降级说明、frontmatter-like 保真；不承诺方言全覆盖 | 当前已实现 `hard_limit -> streaming_event`；未来建议补 summary renderer |
| `toml` | key/value、table、array-of-tables、dotted key | multiline string 边界更稳、raw toml fallback 更清晰；通常 Accurate 与 Balanced 差距很小 | 当前没有 over-limit route，explicit stream 也会诚实 fallback；后续如需优化，应优先补轻量 renderer 而不是公开 stream |
| `ipynb` | cell 顺序、markdown/code/raw、typed outputs、attachments、图片 assets | cell metadata appendix、隐藏输出/错误输出更细恢复、多 MIME 更稳择优 | 当前已实现 `hard_limit -> block_streaming(cell/output-group)`；未来建议补 `soft_limit` output-cap / attachment-cap renderer |

设计结论：

1. `json/xml/yaml` 的 Accurate 重点是“保真与边界更稳”，不是模型推理。
2. `ipynb` 是最值得做中大文件自适应的 structured text，因为 output 和 attachment 很容易放大体积。
3. `toml` 不值得为了形式统一硬做 `Stream`。

### 7.3 Markdown / Web / Markup

| 格式 | Balanced 应覆盖 | Accurate 应覆盖 | 中大文件自动策略 |
| --- | --- | --- | --- |
| `markdown` | 标题、列表、代码块、表格、引用、链接、图片、frontmatter、raw HTML boundary | footnote、reference link、task list、tight/loose list、definition-like block、source line refs；仍应同 route 增强 | 当前已实现 `hard_limit -> block_streaming(markdown-block)`；未来建议补 `soft_limit -> section flush renderer` |
| `html` | content root 选择、boilerplate suppression、标题/段落/列表/表格/图片/链接 | figure/caption 绑定、details/summary、表格结构保真、DOM path refs、受控 raw appendix | 当前已实现 `hard_limit -> block_streaming(html-token-structure)`；未来建议补 `soft_limit -> subtree flush` |
| `rst` | heading、paragraph、list、common table、code、link、directive boundary | footnote、definition list、admonition-like block、raw directive appendix；不执行 include | 当前 canonical only；如需优化，建议先做 canonical route 内 section flush，不急着公开 stream |
| `asciidoc` | 标题、段落、列表、代码块、常见表格、image/link、macro boundary | callout、admonition、xref boundary 更稳；不执行 include/macro | 当前 canonical only；建议先深化 typed lowering |
| `tex` | section、paragraph、list、common table、code-ish verbatim、label/ref boundary | 常见 equation / theorem / environment 边界 appendix、引用标签更稳；不做完整 TeX engine | 当前 canonical only；建议先深化 typed lowering |

设计结论：

1. 这组格式最接近 Pandoc 风格能力边界，核心是 typed lowering，不是视觉还原。
2. `markdown` 与 `html` 最值得做“同 mode 内的大文件 profile 切换”。
3. `rst/asciidoc/tex` 更适合先把 canonical route 做深，再决定是否需要大文件 profile。

### 7.4 Mail / Container

| 格式 | Balanced 应覆盖 | Accurate 应覆盖 | 中大文件自动策略 |
| --- | --- | --- | --- |
| `eml` | header summary、body selection、nested message boundary、attachment manifest、inline image asset | CID 绑定、quoted reply boundary、calendar / invite 附件显式分类、nested message appendix | 当前 canonical 已是 `block_streaming`；未来建议补 attachment-manifest-first 和 body windowing profile |
| `zip` | 安全遍历、子文档派发、路径保真、受控 assets | nested container provenance、重复路径冲突诊断、二进制 entry manifest | 当前 canonical 已是 `container_recursive`；未来建议补 manifest-first，限制 inline child materialization |
| `epub` | spine 顺序、章节文本、导航提示、图片 assets | footnote/backlink、figure/caption、章节级 source refs、TOC appendix | 当前 explicit stream 已走 `container_recursive`，默认仍是 `package_single_pass`；未来建议补 `soft_limit` chapter summary / asset-manifest |

设计结论：

1. 容器类的性能关键不是“能不能 parse”，而是“要不要全部展开”。
2. `manifest-first` 应成为容器类中大文件的标准渲染策略。

### 7.5 ODF / OOXML Office

| 格式 | Balanced 应覆盖 | Accurate 应覆盖 | 中大文件自动策略 |
| --- | --- | --- | --- |
| `odt` | heading/paragraph/list/table/link/image/footnote、基础 comment appendix | text box、annotation anchor、tracked-change appendix、页眉页脚噪声过滤增强 | 当前 explicit stream 已切 `block_streaming(block)`，但尚无 over-limit auto switch；未来建议补 `soft_limit` comments/notes appendix-first |
| `ods` | visible sheet、cached value、hyperlink、基础 table 输出、sheet 统计 | hidden row/sheet 恢复、merge span table、comment appendix、sheet metadata 更细保真 | 当前 explicit stream 已切 `block_streaming(row)`，但尚无 over-limit auto switch；未来建议补 sparse sheet renderer |
| `odp` | slide 顺序、title/body text、table、image、notes | grouped shape summary、reading order、merged table span、hidden slide appendix | 当前 explicit stream 已切 `block_streaming(slide)`，但尚无 over-limit auto switch；未来建议补 notes/asset appendix-first |
| `docx` | heading/paragraph/list/table/link/inline image/footnote/endnote、基础注释附录 | textbox、anchored/floating text、alternate content、merged table span、tracked-change appendix | 当前只有 canonical `package_single_pass`，无 explicit stream / over-limit route；未来如需优化，建议先做 same-mode appendix-first/profile 化 |
| `xlsx` | visible sheet、cached formulas、formal table、hyperlink、comments appendix、稀疏 sheet 友好输出 | hidden rows/sheets 恢复、merged span html table、grouped rows、sheet-level provenance 更细恢复 | 当前已实现 explicit stream 与 over-limit 都切 `block_streaming(row/table-region)`；未来建议再补 `soft_limit` sparse-table / appendix-first |
| `pptx` | slide 顺序、title/body bullets、image、speaker notes、链接、基础隐藏页策略 | reading-order grouping、textbox/shape text 恢复、merged span table、decorative group summary、标题提升 | 当前只有 canonical `package_single_pass`，无 explicit stream / over-limit route；未来如需优化，建议先做 slide-local flush/profile 化 |

设计结论：

1. Office 家族里最值得优先做大文件 profile 的是 `xlsx`，其次是 `ods/odt/odp`。
2. `docx/pptx` 的核心价值仍然是语义完整性，内部可以做 medium profile，但不宜把 profile 直接包装成用户可见 `Stream`。
3. `merged span table`、隐藏内容恢复、floating content 恢复应明确属于 `Accurate`。

### 7.6 PDF / OCR

| 格式 | Balanced 应覆盖 | Accurate 应覆盖 | 中大文件自动策略 |
| --- | --- | --- | --- |
| `pdf` | native-text 提取、基础阅读顺序、段落/列表/标题 heuristics、受控表格 signal、RAG/source refs | OCR、layout-two-stage、多栏重排、跨页表格、caption/figure 绑定、form-like key-value 恢复 | 当前 route 只由 fidelity/explicit OCR 决定，不因 over-limit 自动改 route；未来建议补 page-window assembler / merge-budget profile |
| `image OCR` | 文字段落恢复、基础行块顺序、bbox/source refs | 更稳的区域组合、多栏/表格弱恢复、diagnostics 更丰富；仍不默认视觉大模型 | 当前走 layout route，不做显式 stream；未来可考虑 page-window flush，但不应和 `Stream mode` 混同 |

设计结论：

1. `pdf` 的性能策略应该是 page-window 与 merge-budget 管控，而不是偷偷升级 OCR。
2. `Accurate` 在 `pdf / image OCR` 上依然是最值得投入的重能力模式。

---

## 8. 哪些能力应留在 Balanced，哪些应进入 Accurate

### 8.1 应稳定放在 Balanced 的能力

这些能力对“成熟默认转换”是刚需，而且通常不需要高成本：

1. heading / paragraph / list / code / link / image 的基础恢复。
2. 小中型常见表格输出。
3. source refs、diagnostics、degraded_features。
4. 容器/附件/图片的 manifest 或 placeholder。
5. notebook cell、mail part、slide、sheet、chapter 这类天然块边界的稳定输出。

### 8.2 应明确放进 Accurate 的能力

这些能力价值很高，但对成本、稳定性、全局上下文依赖都更大：

1. OCR 与 layout-heavy 路线。
2. 隐藏 sheet / hidden row / floating text / alternate content / grouped shape 恢复。
3. merged table span、复杂表格跨块或跨页组装。
4. 更激进的阅读顺序重排。
5. 需要大范围回看和跨 block 证据合并的推理。

### 8.3 对轻量目标不值得优先做成 Accurate 差异的格式

这些格式可以允许 `Accurate == Balanced + richer diagnostics/source refs`：

1. `txt`
2. `csv`
3. `tsv`
4. `srt`
5. `vtt`
6. `jsonl`
7. `ndjson`
8. `toml`

原因很简单：

1. 这些格式本身结构简单。
2. 用户通常不期待“模型级增强”。
3. 真正的产品价值在稳定、快、低内存，而不是做出巨大的 mode 差异。

---

## 9. 渲染策略切换目录

为了让“中大文件优化”真正落地，建议把 render profile 做成正式概念。

### 9.1 建议 render profile

```moonbit
pub enum RenderProfile {
  DefaultMarkdown
  SectionFlushMarkdown
  SparseTableMarkdown
  HtmlSpanTable
  NotesAppendixFirst
  AssetManifestFirst
  PageWindowMarkdown
  RecordBatchMarkdown
}
```

### 9.2 各 render profile 的典型用途

| Render Profile | 适用格式 | 价值 |
| --- | --- | --- |
| `DefaultMarkdown` | 全格式 | 默认输出 |
| `SectionFlushMarkdown` | markdown, html, rst-like, odt | 降低全局组装峰值 |
| `SparseTableMarkdown` | csv, tsv, xlsx, ods | 降低大表 materialize 成本 |
| `HtmlSpanTable` | xlsx accurate, pptx accurate, ods accurate | 保 merged span 语义 |
| `NotesAppendixFirst` | docx, pptx, odt, odp, eml, ipynb | 避免把辅助内容挤进正文主路径 |
| `AssetManifestFirst` | zip, epub, html, eml | 避免中大文件资产爆炸 |
| `PageWindowMarkdown` | pdf, tiff OCR | 降低跨页全局缓存压力 |
| `RecordBatchMarkdown` | jsonl, ndjson, txt | 低峰值持续输出 |

### 9.3 切换原则

1. `soft_limit` 优先切 render profile。
2. 只有 render profile 仍不够时，才切 `LargeAdaptive` route。
3. 渲染策略切换必须在 diagnostics 中可见，例如：
   - `render_profile=sparse_table_markdown`
   - `same_mode_strategy_switch=xlsx_soft_limit_sparse_renderer`
   - `same_mode_strategy_switch=pdf_page_window_flush`

---

## 10. 建议的数据结构落点

当前仓库已经有：

1. `formats/profile.mbt` 负责 route profile。
2. `convert/preflight_probe.mbt` 负责 over-limit 探针。
3. `convert/route_policy.mbt` 负责 route 选择。

建议新增一层而不是推翻现有结构：

### 10.1 StrategyPolicy

```moonbit
pub struct FormatStrategyPolicy {
  format : @input.DetectedFormat
  mode : ConvertMode
  supports_explicit_stream : Bool
  soft_limit_strategy : String?
  hard_limit_route : FormatRoute?
  hard_limit_lowering_profile : String?
  soft_limit_render_profile : String?
  hard_limit_render_profile : String?
}
```

### 10.2 策略输出

在 `PreflightProbe` 或 `RouteDecision` 上新增：

1. `execution_profile`
2. `lowering_profile`
3. `render_profile`
4. `same_mode_strategy_switches`

### 10.3 renderer 边界

renderer 不应自行决定切 profile。

正确顺序是：

1. preflight 决定 profile
2. parser / lowering 接收 profile
3. renderer 仅执行 profile

这样可以保证：

1. 同一输入的策略可复现。
2. benchmark 能比较 profile 差异。
3. diagnostics 能解释为什么变快、代价是什么。

---

## 11. 推荐优先级

### 11.1 第一优先级

这些最符合“轻量成熟化转换链”的短中期目标：

1. `markdown` 的 `soft_limit -> section flush`，`hard_limit -> block_streaming`
2. `html` 的 `soft_limit -> subtree flush`，`hard_limit -> block_streaming`
3. `ipynb` 的 output/attachment cap profile
4. `xlsx` 的 `soft_limit sparse renderer` 与 `hard_limit row/table-region route`
5. `ods/odt/odp` 对齐 `xlsx` 的 package-to-block 大文件 profile
6. `epub/zip/eml` 的 manifest-first profile
7. `pdf` 的 page-window assembler profile

### 11.2 第二优先级

这些值得做，但应晚于上面一批：

1. `docx` medium profile
2. `pptx` medium profile
3. `rst/asciidoc/tex` 的 section flush
4. `json/xml/yaml` 的 appendix-first summary renderer

### 11.3 暂不优先

1. 给 `toml` 做显式 `Stream`
2. 给 `pdf` 做自动 OCR 升级
3. 给所有格式统一一套“大文件模式”名字但没有真实差异

---

## 12. 一句话结论

对 mb-markitdown 来说，正确的策略不是“让 `Balanced / Accurate / Stream` 自动互切”，而是：

1. 把 mode 稳定为用户语义契约。
2. 把中大文件优化下沉为同 mode 内的 execution profile。
3. 优先切 render profile，再切 large route。
4. 让 `Balanced` 覆盖成熟默认语义，让 `Accurate` 承接高成本高价值恢复。
5. 让 `xlsx/html/markdown/ipynb/epub/ods/odt/odp/pdf` 成为大文件自适应的主战场。

这样既不破坏主架构书中 mode 的边界，也能把“像 xlsx 一样按文件规模切执行/渲染策略”的思路推广成统一产品能力。
