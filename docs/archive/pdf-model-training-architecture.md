# PDF 模型训练架构契约

Status: archived architecture contract

本文记录 PDF 升级中两个模型的职责边界、输入输出信号、数据流和外仓目录职能。目标是让后续训练、评估、蒸馏和 runtime 讨论从职责出发，而不是被历史工具名、临时路径或旧模型 JSON 带偏。

## 1. 目标与职责划分

PDF 模型训练分为两个职责清晰的模型：

| 模型 | 消费层级 | 主要职责 | 不应承担 |
| --- | --- | --- | --- |
| `layout_recovery` | PDF parser | 从 raw/text/geometry 恢复页面结构、区域结构、阅读顺序和跨页关系 | 最终 Markdown block 语义分类 |
| `text_block_classifier` | Convert 层 | 将 parser 产出的 text block 判断为 Markdown/IR 语义角色 | canonical parser layout reconstruction |

### 1.1 `layout_recovery` 模型（Parser 层消费）

- 消费层级：PDF Parser
- 训练目标：
  - 页面结构检测
  - 区域分类：`table`、`figure`、`caption`、`header-footer`、`text`、`title`、`section-header`
  - 阅读顺序 candidate
  - 跨页 merge / no-merge candidate
  - 多栏检测 / 风险评估
  - 低信号 / malformed layout risk
- 输入信号：
  - PDF raw text / glyph / char / span / line / block
  - page boxes、rotation、image/vector/annotation/form geometry
  - content order / page index / object refs
- 输出信号：
  - page/region labels
  - reading_order / column / multi-column hints
  - cross-page merge / no-merge hints
  - risk scores / low-confidence flags
- DocLayNet 支撑：
  - 强：page / region / table / figure / caption / header-footer / text / title / section-header region
  - 弱：multi-column、artifact/noise region、caption association
  - 不支撑：cross-page merge/no-merge、source-ref consistency、parser text block grouping、line-to-block grouping、真实 reading order
- 高置信可进入 runtime：
  - 明显 header/footer
  - 明显 page number
  - high-confidence region
- 训练/评估专用：
  - cross-page merge/no-merge
  - reading order generalization
  - low-signal regions
  - risk assessment

### 1.2 `text_block_classifier` 模型（Convert 层消费）

- 消费层级：Convert 层
- 训练目标：
  - block-level 语义判定：`heading`、`paragraph`、`caption`、`table-like`、`list item`、`footer/header noise`、`form row`、`link text`、`keep-as-text`、`uncertain`
- 输入信号：
  - Parser 产出的 block/line/span/page geometry
  - candidate flags、font/size、line gaps/indents、page index
  - neighboring context、near image/annotation/table signals
- 输出信号：
  - block semantic role labels
  - soft hints + confidence
  - abstain / low-confidence 标记
- DocLayNet 支撑：
  - 强：`heading`、`paragraph`、`list_item`、`caption`、`table_like`、`footer-header noise`
  - 弱：`keep-as-text`、footnote-like、page number noise、figure-related caption
  - 不支撑：`form row`、`link text`、code-like、separator/decoration line、真实 Markdown section title vs document title、PDF footnote/endnote body
- 高置信可进入 runtime：
  - heading hints
  - list hints
  - table-like hints
  - caption hints
  - footer/header hints
- 训练/评估专用：
  - code-like
  - footnote-like
  - form_row
  - link text
  - separator

## 2. 输入输出信号

### 2.1 Parser 侧信号

`layout_recovery` 应靠近 parser-owned model，消费 PDF lower-layer 已有或未来可补充的结构信号：

- raw text ops、glyph、char、span、line、block
- bbox、origin、quad、font、font size、color、rotation
- page boxes、crop box、media box、page rotation
- images、vectors、annotations、forms 的 geometry
- page index、content order、source stream index、source op index
- object refs、source refs、raw content stream refs
- line gap、indent、baseline、line height
- parser-owned candidate flags 和 risk flags

`layout_recovery` 的输出应写回 parser-owned abstraction，例如：

- page-level layout hints
- region-level labels
- reading-order candidates
- column / multi-column hints
- cross-page boundary hints
- low-signal / malformed layout risk

### 2.2 Convert 侧信号

`text_block_classifier` 应消费 parser 已经产出的结构，而不是重新解析 PDF：

- block text
- block/line/span bbox
- page position
- font / dominant font size / dominant font name
- line count、line gap、indent、alignment
- candidate flags：heading、caption、table-cell、header/footer、artifact、page number
- neighbor context：previous / next block
- near image / annotation / table features
- layout_recovery 产出的高置信 region / risk / boundary hints

`text_block_classifier` 的输出应供 convert 层作为 fail-closed hint 消费：

- suggested label
- confidence
- reason tags
- abstain / uncertain
- blocked reason when hard constraints reject a suggestion

## 3. DocLayNet 支撑情况

### 3.1 DocLayNet 对 `layout_recovery`

| 支撑等级 | 目标 |
| --- | --- |
| 强支撑 | page/region detection、table region、figure region、caption region、header/footer region、text/title/section-header region |
| 弱支撑 | multi-column hints、artifact/noise region、caption association |
| 不支撑 | cross-page merge/no-merge、source-ref consistency、parser text block grouping、line-to-block grouping、真实 reading order |

DocLayNet 可作为 `layout_recovery` 的第一条 public gold region lane，但不能单独证明 parser reading order、跨页关系或 source-ref consistency。

### 3.2 DocLayNet 对 `text_block_classifier`

| 支撑等级 | 目标 |
| --- | --- |
| 强支撑 | heading vs paragraph、list item、caption、table-like、footer/header noise |
| 弱支撑 | keep-as-text、footnote-like、page number noise、figure-related caption |
| 不支撑 | form row、link text、code-like block、separator/decoration line、真实 Markdown document title vs section title、PDF footnote/endnote body |

DocLayNet 可以支撑 `text_block_classifier` 的主干 block semantics，但对表单、链接、代码块、装饰线、Markdown heading role 等输出策略仍需补充数据。

## 4. 数据流

推荐数据流如下：

```text
raw PDF / pdf_core signals
  -> layout_recovery model (parser layer)
  -> parser-owned PdfDocumentModel
  -> text_block_classifier model (convert layer)
  -> convert-owned IR/Markdown
```

禁止的反向依赖：

- parser 不依赖 convert 结果。
- `text_block_classifier` 的结果不反向改写 parser canonical model。
- convert 不重新构建 parser-owned canonical layout。
- runtime 不直接依赖外仓训练数据、训练缓存或模型参数。

允许的正向依赖：

- `layout_recovery` 输出的高置信 region / reading-order / boundary / risk hints 可以成为 `text_block_classifier` 的输入特征。
- `text_block_classifier` 可以作为 convert 层的 soft hint / confidence / abstain 来源。
- 高置信、可解释、fail-closed 的 distilled rules 可以进入 runtime。

## 5. 外仓目录职能

建议将 PDF 模型训练资产保留在外仓 `markitdown-quality-lab/pdf_model_training/`，并按公共数据、模型专属派生资产、共享契约三类分层。

```text
pdf_model_training/
  datasets/
    doclaynet/
      README.md
      dataset_card.md
      source_catalog.tsv
      local_only/
        cache/
        extracted/
        raw_index/
      derived/
        pilot500_v1/
        pilot1000_v1/
        pilot3000_v1/

  text_block_classifier/
    dataset/
    labels/
    manifests/
    adapters/
    scripts/
    training/
    models/
    reports/

  layout_recovery/
    dataset/
    labels/
    manifests/
    adapters/
    scripts/
    training/
    models/
    reports/

  shared/
    schemas/
    feature_contracts/
    label_provenance/
    report_templates/
    review_guidelines/
```

目录职责：

| 目录 | 职责 |
| --- | --- |
| `datasets/doclaynet/` | DocLayNet 来源、授权、dataset card、公共索引和本地 raw cache 边界 |
| `datasets/doclaynet/local_only/` | 本地下载、解压、raw index、缓存；不得提交进主仓 |
| `datasets/doclaynet/derived/` | 可复现 pilot subset 和派生索引 |
| `text_block_classifier/` | convert-layer block semantic training/eval/report/model artifacts |
| `layout_recovery/` | parser-layer layout/region/reading-order/boundary training/eval/report/model artifacts |
| `shared/` | 两模型共享 schema、feature contract、label provenance、报告模板、review 指南 |

## 6. 核心原则

1. 职责清晰：`layout_recovery -> parser`，`text_block_classifier -> convert`。
2. 上下游关系：`layout_recovery` 输出可作为 `text_block_classifier` 输入特征。
3. DocLayNet 使用：
   - 公共 raw dataset 层支持两模型。
   - 派生资产放模型目录内，便于版本控制和审计。
4. 高置信 vs 训练专用：
   - 高置信、可解释、fail-closed 的结果可进入 runtime。
   - 低置信/复杂结构用于训练、评估、审计和规则蒸馏。
5. 禁止操作：
   - parser 不依赖 convert 结果。
   - convert 不重构 parser canonical layout。
   - normal runtime 不直接依赖外仓。
   - 不把大数据集、模型参数、训练缓存提交进主仓。
   - 公共原始数据集必须被 gitignore；模型派生文件是否版本管理必须按外仓策略单独审查。
