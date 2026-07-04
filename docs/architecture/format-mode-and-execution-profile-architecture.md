# 格式能力档位与执行策略架构书

> 路径：`docs/architecture/format-mode-and-execution-profile-architecture.md`
>
> 本文是 [`docs/architecture/mb-markitdown-architecture.md`](./mb-markitdown-architecture.md) 的补充设计书。
>
> 主架构书定义统一主链 `input -> parser -> pipeline -> render`。
> 本文定义 mode、route、probe、planner、profile、render path 的稳定抽象与演进约束。

建议阅读顺序：

1. 先读主架构书，理解统一主链和通用边界。
2. 再读本文，理解 mode、route、planner、profile 的稳定契约。
3. 最后读 `docs/capabilities-and-limitations.md`，理解当前正式承诺的能力范围。

---

## 0. 文档定位

本文是规范性架构文档，不是实现说明、阶段总结或回归记录。

它回答的是下面几类问题：

1. 用户侧 mode 到底表达什么。
2. route、profile、render path 应当如何被统一建模。
3. planner 在什么边界内有权做自动切换。
4. 各格式应如何进入统一策略表，而不是继续长出入口旁路。
5. renderer、diagnostics、provenance 该依赖什么稳定契约。

因此本文的使用原则是：

1. 抽象先于实现。
2. 契约先于阶段性便利。
3. 实现若与本文偏移，应视为待收敛技术债，而不是反向修改本文去迁就实现。
4. `docs/capabilities-and-limitations.md` 负责回答“当前正式支持什么”；本文负责回答“这些能力必须如何被组织和约束”。

### 0.1 产品定位

本文服务的产品定位是：

- 一个面向多格式文档转换的、轻量成熟化的转换链

这里的“轻量成熟化”有三层含义：

1. 优先做高置信、可解释、可回归验证的结构恢复。
2. 不以沉重模型、隐式执行或不可控旁路作为默认产品前提。
3. 用统一 planner、统一 profile、统一 renderer 契约支撑长期迭代，而不是靠单格式特例堆能力。

这意味着本项目既不是：

1. 追求极限版面智能的重型文档 AI 平台
2. 追求完整编辑器语义的全功能 AST 工具链
3. 只输出字符串、缺乏 provenance 的一次性脚本

### 0.2 术语约定

为避免文档与实现长期漂移，本文固定使用以下术语：

1. `mode`：
   用户可见的核心策略模式。
2. `route`：
   parser / runtime 的主执行路线。
3. `profile`：
   在既定 route 上调节资源、lowering 或 render 行为的运行时策略。
4. `planner`：
   唯一负责冻结执行计划的决策层。
5. `canonical`：
   某格式在某 mode 下的默认正式路线，不等于“唯一实现”。
6. `same-mode adaptive switch`：
   不切 mode，只切 route/profile/render path 的自适应切换。

---

## 1. 不冲突约束

本文与主架构书共同满足以下不变约束：

1. 用户可见核心策略模式只有 `Balanced / Accurate / Stream`。
2. `Rag / Debug` 是输出形态，不是核心策略模式。
3. 自动切换只允许发生在同一策略模式内部，切换对象是 route、profile、render path，而不是 mode。
4. `pdf` 不因文件大自动升级到 OCR 或重布局路线；进入 `layout_two_stage` 只能由 `Accurate` 或显式 OCR 语义触发。
5. parser 不直接生成 Markdown；renderer 不自行越权修改 route、profile 或 mode。
6. 所有正式入口都应复用统一主链：`detect -> probe -> planner -> parser -> pipeline -> renderer`。
7. 任何格式若进入正式支持矩阵，必须进入统一策略表与统一执行计划模型。
8. diagnostics 与 provenance 必须能解释每次 route/profile 决策，而不是只暴露最终输出。

---

## 2. 设计目标

本文约束下的执行策略体系，必须同时满足以下目标：

1. 冻结外部契约：
   `ConvertMode`、CLI 语义、输出形态和主要诊断面应保持稳定。
2. 统一内部决策：
   不能让 route、profile、accurate、render path 分散在入口、parser、finalize 三处各判一套。
3. 允许同模式自适应：
   在不切 mode 的前提下，允许中大文件切换 route、profile、windowing 或 flushing 策略。
4. 支持格式扩展：
   新格式接入应主要新增策略表、probe signals、lowering hints 和 tests，而不是复制一条新主链。
5. 保持可解释性：
   任何自动切换都必须能由 probe signals、route reason、profile reason 和 strategy switches 解释。
6. 保持诚实边界：
   不支持的 stream、accurate 或 adaptive 能力，必须 fail closed 或显式 fallback，不得伪造支持。

### 2.1 读者最先应该记住的四条规则

如果只记住本文四件事，应当是：

1. 用户只选 `Balanced / Accurate / Stream`，不会直接选择 parser mode。
2. planner 是唯一选路者，probe 只提供证据。
3. 自动切换只允许发生在同 mode 内部。
4. renderer 只能消费计划和 hints，不能反向决定策略。

---

## 3. 稳定抽象

### 3.1 User Mode

`User Mode` 是用户可见的策略选择，负责表达“转换哲学”，而不是直接绑定 parser 实现。

它只回答一件事：

- 系统应该优先追求什么样的转换行为。

它不直接回答：

- 必须使用哪一种 parser mode
- 是否一定构建完整 `DocumentIR`
- 是否一定走某个特定 renderer

### 3.2 Output View

`Output View` 是用户可见的输出视图。

它回答的是：

- 同一份内部结果如何被投影为 Markdown、RAG、Debug 或兼容 JSON

它不改变：

- 核心策略模式
- planner 对 route/profile 的选择原则
- parser / pipeline 的职责边界

### 3.3 ExecutionIntent

`ExecutionIntent` 是从公开输入规整得到的内部意图对象。

它的职责是：

1. 把 mode、output view、stream 请求位、OCR 需求、资源限制等外部输入做无副作用归一化。
2. 消除不同入口对同一含义的重复表达。
3. 为 planner 提供统一输入面。

`ExecutionIntent` 不做 route 决策，也不直接承载格式私有执行细节。

### 3.4 ProbeOutcome

`ProbeOutcome` 是探针层产物，职责是提供结构化证据，而不是提前做决策。

它必须能够承载至少四类信息：

1. `probe_signals`：
   例如 `char_count`、`row_count`、`sheet_count`、`page_count`、`token_count`。
2. `prepared_source`：
   供后续 parser 复用的预处理输入。
3. `probe_artifacts`：
   可复用的 cheap artifact，如 token inventory、轻量 notebook model、JSON stream document。
4. `probe_failures` 与摘要：
   表达探针过程中发生的受控失败与退路说明。

Probe 的边界是严格的：

1. probe 可以判断“有什么信号”。
2. probe 不可以冻结 `selected_route`。
3. probe 不可以自行决定 `route_reason`。
4. probe 不可以在入口层偷偷实现第二套 planner。

### 3.5 ResolvedExecutionPlan

`ResolvedExecutionPlan` 是唯一执行真相源。

一旦 planner 冻结该计划，后续 parser、pipeline、renderer、finalize、provenance 都只消费这份计划，而不再重复做高层策略判断。

一份完整计划至少应包含：

1. 检测结果：
   `detected_format`
2. 用户策略：
   `strategy_mode`、`output_view`、`stream_requested`
3. 执行决策：
   `selected_route`、`requested_parser_mode`、`render_path_kind`
4. profile 决策：
   `execution_profile`、`lowering_profile`、`render_profile`
5. fidelity / accurate 决策：
   `accurate_feature_profile` 或等价 typed feature set
6. 解释面：
   `route_reason`、`execution_profile_reason`、`same_mode_strategy_switches`
7. 证据面：
   `probe_signals`、`probe_failures`、`probe_artifacts`、`prepared_source`

### 3.6 FormatStrategyPolicy

`FormatStrategyPolicy` 是按格式组织的单一策略表。

它必须覆盖所有正式支持格式，并按核心策略模式显式建模：

1. `Balanced policy`
2. `Accurate policy`
3. `Stream policy`

每个策略项至少需要表达以下信息：

1. canonical route
2. explicit stream support 与 explicit stream route
3. soft-limit / hard-limit 阈值
4. route-level accurate upgrades
5. execution / lowering / render profile
6. profile 切换时允许的 same-mode strategy switches

统一策略表的意义不是“所有格式立刻拥有同样多的能力”，而是：

- 所有格式都进入同一套决策语言
- 所有差异都经由同一 planner 和同一 provenance 解释

---

## 4. 用户模式契约

### 4.1 Balanced

`Balanced` 是默认策略模式。

它的契约是：

1. 优先选择成熟、稳定、成本可控的 canonical 路线。
2. 允许高置信的语义恢复。
3. 不以隐式重型推断、隐式 OCR、隐式深布局分析换取“看起来更聪明”的输出。
4. 允许在同 mode 内根据 probe signals 切换到更适合的大文件 route/profile。

`Balanced` 不是“最低能力模式”，而是：

- 面向长期默认产品行为的主模式。

### 4.2 Accurate

`Accurate` 是质量优先模式。

它的契约是：

1. 可以触发 route-level upgrade，例如 OCR / layout 路线。
2. 也可以在不换 route 的前提下，启用更高保真的语义恢复。
3. 只允许启用“有底层结构信号支撑、可解释、可回归验证”的增强。
4. 不允许把猜测式布局、猜测式宏执行、不可验证的补全写成架构承诺。

`Accurate` 的能力应优先通过 typed hooks / semantic feature profile 表达，而不是散落的裸 `fidelity_mode == Accurate` 判断。

### 4.3 Stream

`Stream` 是显式低峰值策略模式。

它的契约是：

1. 优先选择流式友好的 route、lowering、render path 和 flushing 策略。
2. 若格式声明了显式 stream route，则应优先使用该 route。
3. 若格式没有独立 stream route，则应优先使用同 mode 下最流式友好的 profile。
4. 若格式不支持真正的 stream 能力，系统必须显式说明 fallback，而不是假装已经进入流式实现。

`Stream` 不意味着：

1. 所有格式都必须拥有独立 streaming parser。
2. 所有 route 都必须放弃 `DocumentIR`。
3. renderer 可以绕过 planner 自行决定批量输出。

### 4.4 模式共同边界

以下约束适用于全部模式：

1. mode 决定策略，不直接决定 parser mode。
2. mode 决定质量/峰值取向，不直接决定输出视图。
3. 自动切换只能发生在 mode 内部。
4. mode 切换必须由用户显式请求，而不是 probe 或 parser 自主升级。

---

## 5. 输出形态契约

输出形态是与 mode 正交的第二维度。

公开输出形态包括：

1. `Markdown`
2. `RagJson`
3. `DebugJson`

其约束为：

1. `Markdown` 是标准人类可读输出。
2. `RagJson` 是面向 chunk、source ref、diagnostics 的结构化投影。
3. `DebugJson` 是面向内部观察与契约验证的结构化投影。

因此：

1. `--rag`、`--debug` 切的是输出视图，不是 mode。
2. 同一输入在 `Balanced / Accurate / Stream` 下，即使都输出 `RagJson` 或 `DebugJson`，也允许得到不同结果。

---

## 6. Route 与 Planner 契约

### 6.1 Route 族

统一 route 词汇表应维持稳定，至少包括：

1. `StreamingEvent`
2. `BlockStreaming`
3. `PackageSinglePass`
4. `PageSinglePass`
5. `DomAstModel`
6. `LayoutTwoStage`
7. `ContainerRecursive`

Route 是 planner、parser、render path 的共享语言。

新增 route 必须满足：

1. 能清楚定义输入粒度和资源画像。
2. 能映射到明确的 parser/runtime 边界。
3. 能被 diagnostics / provenance 解释。

### 6.2 Planner 决策顺序

planner 的规范顺序应固定为：

1. detect format
2. normalize intent
3. run probe
4. load `FormatStrategyPolicy`
5. resolve route-level fidelity / accurate upgrades
6. resolve explicit stream
7. evaluate hard thresholds
8. evaluate soft thresholds
9. freeze `ResolvedExecutionPlan`

这个顺序的意义是：

1. planner 是唯一决策者。
2. probe 只提供证据。
3. route、profile、render path 必须一起冻结，避免双轨生效。

### 6.3 入口统一约束

sync convert、async convert、plan_input、image OCR、pdf OCR 等入口必须共享同一 planner 语义。

允许不同入口有不同 runtime backend，但不允许：

1. 入口手工拼接第二套 route plan
2. finalize 侧重新猜 route
3. 某个格式只在某个入口下走特殊旁路

---

## 7. Profile 体系

### 7.1 ExecutionProfile

`ExecutionProfile` 表达的是同 route 内或同 mode 内的资源/规模执行画像。

它应至少包含：

1. `Standard`
2. `MediumAdaptive`
3. `LargeAdaptive`

其契约是：

1. `Standard`：
   采用默认 canonical 成本模型。
2. `MediumAdaptive`：
   命中 soft-limit 后生效；优先调节 buffering、windowing、flush granularity、sparse strategy，而不是优先换 mode。
3. `LargeAdaptive`：
   命中 hard-limit 后生效；允许切换到更适合的大文件 route，或者在原 route 内启用大文件 lowering/render 策略。

soft/hard 阈值必须按格式显式声明，而不是依赖全局固定比例。

### 7.2 LoweringProfile

`LoweringProfile` 决定 parser / lowering / pass pipeline 如何把源结构收口为可渲染 IR。

它应至少包括：

1. `Canonical`
2. `AccurateSemantic`
3. `StreamCanonical`
4. `LargeAdaptive`

其职责分工为：

1. `Canonical`：
   默认 canonical 语义恢复。
2. `AccurateSemantic`：
   高保真语义恢复，但前提是底层信号可解释。
3. `StreamCanonical`：
   偏向低峰值、边界稳定、批量 flush 友好的 lowering。
4. `LargeAdaptive`：
   面向大文件的窗口化、稀疏化、渐进化语义收口。

`LoweringProfile` 是结构性分发开关；
`accurate_feature_profile` 则是语义能力开关。
两者不应相互替代。

### 7.3 RenderProfile

`RenderProfile` 决定 renderer 如何组织顺序、分段、附录、窗口和批量输出。

公开变体应包括：

1. `DefaultMarkdown`
2. `SectionFlushMarkdown`
3. `SparseTableMarkdown`
4. `NotesAppendixFirst`
5. `AssetManifestFirst`
6. `PageWindowMarkdown`
7. `RecordBatchMarkdown`

其职责边界如下：

1. `DefaultMarkdown`：
   默认顺序与默认分段。
2. `SectionFlushMarkdown`：
   按 section / slide / sheet / chapter 边界组织输出。
3. `SparseTableMarkdown`：
   优先保留稀疏表语义，而不是强制稠密化。
4. `NotesAppendixFirst`：
   将 notes / comments / appendix 类块统一组织到附录区。
5. `AssetManifestFirst`：
   先输出资产清单，再输出正文内容。
6. `PageWindowMarkdown`：
   以 page / slide / window 为主要聚合边界。
7. `RecordBatchMarkdown`：
   按 record batch / event batch flush，避免一次性 materialize 超大流。

所有 renderer 必须共享同一 `RenderProfile` 语义：

1. Markdown renderer 体现文本顺序与组织差异。
2. RAG renderer 体现 chunk 边界与窗口差异。
3. Debug renderer 体现 profile、生效 hints 与重排结果。

---

## 8. Stream 支持策略

stream 能力应按格式类型分层设计，而不是一刀切。

### 8.1 天然 streaming canonical

以下格式族天然适合以 streaming 作为 canonical 路线：

1. 线性文本：
   `txt`
2. 线性表格：
   `csv`、`tsv`
3. 线性记录：
   `jsonl`、`ndjson`
4. 线性字幕：
   `srt`、`vtt`

对这类格式，`Balanced` 与 `Stream` 可能共享同一路线，但仍是两种不同的策略语义。

### 8.2 显式 stream 路线

以下格式族适合采用 “canonical document route + explicit stream route”：

1. 结构化文本：
   `json`、`xml`、`yaml`
2. 标记文本：
   `markdown`、`html`
3. notebook / sheet / package 的可分块格式：
   `ipynb`、`xlsx`、`odt`、`ods`、`odp`
4. package / chapter / container 可顺序派发格式：
   `epub`

对这类格式，stream 语义应由 planner 明确触发，不允许 parser 自行切换。

### 8.3 canonical only

以下格式族可以保持 canonical only，而不为“看起来完整”强行承诺 stream：

1. `toml`
2. `rst`
3. `asciidoc`
4. `tex`
5. `docx`
6. `pptx`

若用户显式请求 stream，而该格式无可靠 stream 实现，则系统必须：

1. 诚实给出 unsupported / fell-back 解释
2. 保留 canonical route
3. 不得伪造“已经进入真正流式路径”的诊断

### 8.4 paged / OCR 格式

以下格式不应被建模为 stream 优先：

1. `pdf`
2. 直接图片 OCR

它们的主要维度是：

- page/layout/OCR

而不是：

- event / record streaming

---

## 9. same-mode 自适应策略

自动切换的核心原则是：

1. 用户 mode 固定。
2. route/profile 可以在 mode 内部切换。
3. 所有切换都必须由 probe signals 与策略表解释。

### 9.1 soft-limit

命中 soft-limit 时，应优先：

1. 切换 `ExecutionProfile`
2. 切换 `LoweringProfile`
3. 切换 `RenderProfile`
4. 调整 windowing / buffering / sparse strategy

soft-limit 不应优先触发 mode 切换，也不应无解释地直接跳到重型路线。

### 9.2 hard-limit

命中 hard-limit 时，planner 可以：

1. 切换到策略表声明的 `hard_limit_route`
2. 保持原 route，但进入 `LargeAdaptive`

具体采用哪种方式，由格式策略声明，而不是入口处硬编码。

### 9.3 禁止切换

以下切换在架构上禁止：

1. 因文件大把 `Balanced pdf` 自动切到 OCR
2. 因文件大把 `Stream` 自动升级为 `Accurate`
3. 在 finalize 阶段重新决定 route
4. 通过 renderer 反向推断 planner 应该如何选路

---

## 10. 格式策略目录

本节给出按格式族组织的规范性策略目录。
它描述的是“应如何被设计”，而不是“代码今天恰好长什么样”。

| 格式族 | Balanced 契约 | Accurate 契约 | Stream 契约 | 自适应说明 |
| --- | --- | --- | --- | --- |
| `txt/csv/tsv/srt/vtt/jsonl/ndjson` | 以天然 streaming canonical 为主 | 仅允许高置信同 route 增强，不引入重型第二路线 | 与 canonical 共享 route，但使用更强 flush / batch 语义 | 主要体现为 batching、windowing、render batching |
| `json/xml/yaml` | 默认保留 canonical 结构恢复 | 允许同 route 的高保真语义恢复 | 支持显式 stream 或超限切到 `streaming_event` | 中大文件可走 same-mode route switch |
| `markdown` | 默认 `dom_ast_model` canonical | Accurate 属于同 route 语义增强，不引入独立 route | 支持显式 stream 或超限切 `block_streaming` | 自适应重点是 section/block flush |
| `rst/asciidoc/tex` | 默认 `dom_ast_model` canonical，强调 typed semantic inventory | Accurate 只允许高置信 same-route semantic restoration | 默认不承诺独立 stream route | 不以 macro/directive execution 换取“高保真” |
| `toml` | 默认 `dom_ast_model` canonical | 允许 typed scalar / source / diagnostics 增强 | 默认不承诺 stream | 优先保持结构化配置文本语义 |
| `html` | 默认 canonical 内容抽取与结构恢复 | 可增强高置信内容根选择与结构语义 | 支持显式 stream 或超限 `block_streaming` | 自适应重点是 subtree/section 粒度 |
| `ipynb` | 默认 notebook-aware canonical | 可增强 outputs/source refs/attachments 等高置信语义 | 支持显式 stream 或超限 `block_streaming` | 自适应重点是 cell/output-group 粒度 |
| `eml` | 以 MIME-aware `block_streaming` 为主 | 允许更强 body/attachment 语义恢复 | `Stream` 与 canonical 共享 route，但使用流式友好 render/profile | 不承诺无限递归展开 |
| `zip` | 以 `container_recursive` 为主 | Accurate 不应发明二进制解释语义 | `Stream` 共享容器递归语义 | 自适应重点是容器条目粒度 |
| `epub` | 默认 `package_single_pass` | 可增强章节/notes/资源关系恢复 | 支持显式 stream 到 `container_recursive` | 自适应重点是 chapter/window 粒度 |
| `odt/ods/odp` | 默认 `package_single_pass` | 允许 notes/span/visibility/window 等高置信恢复 | 可声明显式 `block_streaming` 路线 | 自适应重点是块、行、slide 粒度 |
| `docx/xlsx/pptx` | 默认 `package_single_pass` | 允许 textbox/hidden/merged/notes/order 等高置信恢复 | 仅对明确声明的格式开放 stream 路线 | 自适应重点是 sheet/row/table-region/page-window |
| `pdf` | 默认 `page_single_pass` | 允许 route-level OCR/layout upgrade 和高置信页级恢复 | 不承诺显式 stream route | 禁止按文件大小自动升级 OCR |
| 直接图片 OCR | 以 `layout_two_stage` 为主 | Accurate 仍应以 typed OCR/layout features 表达 | 不承诺 stream | 主要维度是 OCR/layout，不是 streaming |

---

## 11. Normalize Hints 与 Renderer 边界

为了让 renderer 可长期维护，格式特有语义必须优先收口为规范化 hints，而不是长期暴露格式私有字段。

规范化 hints 至少包括：

1. `render_boundary`
2. `render_boundary_key`
3. `render_appendix_group`
4. `render_table_mode`
5. `render_window_group`

边界如下：

1. parser / lowering / pass pipeline 负责生成 hints。
2. renderer 只消费 plan、profile 和 hints。
3. renderer 不直接依赖 `docx`、`odt`、`tex` 等格式私有字段作为长期契约。
4. debug 输出必须能观察到这些 hints，便于后续扩展与契约测试。

---

## 12. diagnostics 与 provenance 契约

diagnostics / provenance 的职责不是“锦上添花”，而是：

- 解释 planner 与 renderer 决策。

稳定公开的解释面应至少包括：

1. `selected_route`
2. `route_reason`
3. `requested_mode`
4. `effective_mode`
5. `execution_profile`
6. `execution_profile_reason`
7. `lowering_profile`
8. `render_profile`
9. `render_input_kind`
10. `route_fidelity_status`
11. `same_mode_strategy_switches`
12. `probe_signals`
13. `probe_failures`

兼容字段可以存在，但不应取代主解释面。
例如：

- `same_mode_degradation` 可以作为兼容镜像保留，但长期主解释字段应是 `same_mode_strategy_switches`。

---

## 13. Accurate 能力边界

`Accurate` 不是“允许任何更重的代码路径”，而是受约束的高保真能力面。

其准入原则必须固定为：

1. 有底层结构信号支撑
2. 语义可解释
3. 回归可验证
4. 能进入统一 hooks / profiles / hints 主链

### 13.1 允许进入 Accurate 的能力

允许进入 Accurate 的典型能力包括：

1. paged / OCR 文档的 route-level OCR or layout upgrade
2. Office / ODF 文档的 hidden / notes / textbox / merged span / appendix / slide-window 等高置信恢复
3. markdown / rst / asciidoc / tex 等文本格式的 same-route semantic strengthening

### 13.2 不允许进入 Accurate 的能力

以下能力不应被写成 Accurate 承诺：

1. 无证据的阅读顺序猜测
2. 无证据的复杂布局智能
3. directive / macro / script / notebook execution
4. 需要执行外部依赖或外部运行时才能成立的语义补全

### 13.3 Accurate 的实现原则

Accurate 差异应优先通过：

1. `accurate_feature_profile`
2. `LoweringProfile::AccurateSemantic`
3. 规范化 render hints

而不是通过：

1. 入口层特判
2. finalize 侧补判
3. 散落的裸 `fidelity_mode == Accurate`

---

## 14. 格式成熟标准

架构层只定义成熟度标准，不在此文档中给出实现期的逐项评分。

### 14.1 可用

一个格式可以被称为 `可用`，当且仅当：

1. 它进入统一主链
2. 有稳定 canonical route
3. 有基本 diagnostics / provenance
4. 有最小回归样例

### 14.2 成熟

一个格式可以被称为 `成熟`，当且仅当：

1. 高频结构已有 typed canonical 表达
2. 大文件或 stream 边界清晰且诚实
3. diagnostics / provenance 足以解释策略切换
4. 有专门 contract tests 或稳定质量回归支撑长期维护

### 14.3 强成熟

一个格式可以被称为 `强成熟`，当且仅当：

1. 在 `成熟` 基础上
2. 还具备更深的 accurate/profile/runtime 能力
3. 并且这些能力已进入统一 plan-driven 主链，而不是依赖旁路

具体某个格式当前属于哪一档，由 `docs/capabilities-and-limitations.md` 给出公开判断。

---

## 15. 演进规则

新增格式或新增能力时，必须遵守以下规则：

1. 新格式必须先进入 `FormatStrategyPolicy`，再进入产品矩阵。
2. 新 route 必须先定义资源画像、render path 和 provenance 解释，再允许使用。
3. 新 profile 必须同时在 Markdown、RAG、Debug 至少一个输出面具备可验证行为。
4. 新 Accurate 能力必须先收口为 typed hooks / feature profile / normalized hints。
5. 若某项能力无法通过 `ResolvedExecutionPlan`、diagnostics、provenance 解释清楚，则不应进入正式主链。

### 15.1 需要架构评审的变更

以下变更不应作为普通实现细节直接落地，而应先过架构评审：

1. 新增或删除公开 `ConvertMode`
2. 新增 route 类型
3. 改变 planner 决策顺序
4. 让某个入口绕开统一 planner
5. 引入新的 renderer 长期契约字段
6. 让格式私有字段直接成为 renderer 的长期依赖
7. 把猜测式能力写入 Accurate 或 Balanced 默认行为

### 15.2 允许快速迭代的变更

以下变更通常可以在不改主抽象的前提下快速迭代：

1. 新增 probe signals
2. 调整单格式 soft/hard 阈值
3. 新增或细化 accurate feature
4. 新增 normalized render hints
5. 扩展 contract tests、sample fixtures、quality fixtures
6. 提升某格式在既有 route 内的 typed semantic inventory

---

## 16. 结论

本补充架构书的核心立场只有一句话：

- `mode / route / probe / planner / profile / render path` 必须先成为稳定抽象，再成为可扩展实现。

对一个长期维护的开源项目而言，真正要保护的不是“今天这段代码怎么写”，而是：

1. 用户模式语义是否稳定
2. planner 是否真正掌权
3. 自动切换是否诚实且可解释
4. 新格式能否以统一方式接入
5. renderer、diagnostics、provenance 是否围绕同一套长期契约演进
