# pdf_core

`pdf_core` 是 `markitdown-mb` 中面向 PDF 的底层结构恢复模块。

它的职责不是直接把 PDF 转成最终 Markdown，而是先把底层 PDF 内容解析、归一化并恢复成更稳定的中间结构，供后续 `convert/pdf` 消费。换句话说，`pdf_core` 解决的是“**如何把 PDF 这种天然不稳定、偏渲染导向的格式，恢复成更接近文档语义的结构化表示**”这个问题。

当前阶段，`pdf_core` 的核心定位是：

* 面向 **text-based PDF** 的底层结构恢复
* 优先完成 **text-first** 的可解释中间层建模
* 为更上层的 Markdown 转换、标题识别、段落恢复、页码清洗、阅读顺序优化提供基础

---

## 设计目标

PDF 与 docx / html 这类格式不同，它不是天然按“标题、段落、列表、表格”存储内容，而更接近“页面上的绘制指令”。因此，PDF 转换要想得到稳定结果，不能只依赖外部工具直接抽纯文本，而需要补上一层“结构恢复”。

`pdf_core` 的设计目标就是补上这层能力。

更具体地说，它希望做到：

1. **保留底层来源信息**

   * 文本来自哪一页
   * 来自哪个 content stream
   * 来自哪个 text object / op
   * 是否存在显式 break 信号
   * glyph 的原始解码信息是什么

2. **把底层碎片逐层恢复成更高层结构**

   * glyph → char
   * char → span
   * span → line
   * line → block

3. **尽可能用可解释规则，而不是黑盒猜测**

   * 当前 line / block 恢复主要依赖启发式规则
   * 但这些规则尽量保持可命名、可调试、可回归验证

4. **为 convert 层提供比“纯文本抽取”更强的输入**

   * convert 层不再直接面对碎裂的 glyph / op 流
   * 而是面对已经恢复过的 heading / paragraph 候选 block

---

## 当前整体链路

当前 `pdf_core` 主链路如下：

```text
MBTPDF adapter
-> raw
-> chars
-> spans
-> lines
-> blocks
-> PdfDocumentModel
```

每一层的职责如下。

### 1. MBTPDF adapter

当前底层接入的是 `Bobzhang/MBTPDF`。

adapter 的职责是：

* 遍历 PDF 页面及内容流
* 解析文本相关 operators
* 解码 glyph / text
* 提取最小字体与来源信息
* 生成 `raw` 层数据结构

这一层尽量只做“事实抽取”，不做复杂结构猜测。

### 2. raw 层

`raw` 层是 adapter 向上游提供的统一原始容器，当前主要包括：

* `RawPdfDocumentExtract`
* `RawPdfPageExtract`
* `RawTextOp`
* `RawDecodedGlyph`
* `RawSourceRef`
* 以及图片 / 注释等原始对象容器

这一层的特点是：

* 仍然保留了明显的 PDF 底层痕迹
* 但已经把底层对象整理成可以继续构建 chars / spans 的统一输入

当前 `RawTextOp` 中还会携带：

* `break_before`
* `break_reason`

用于把显式文本边界信号继续往上游透传。

### 3. chars 层

chars 层负责把 raw glyph 映射成 `PdfChar`。

这一层的主要内容包括：

* `decoded_text`
* `unicode`
* `bbox / origin`
* `font_name / font_size`
* `fill_color`
* `rotation`
* `is_ligature`
* `is_compat_glyph`
* `decode_confidence`
* `source`
* `break_before / break_reason`

也就是说，从 chars 层开始，`pdf_core` 已经进入“字符级结构化表示”。

### 4. spans 层

spans 层负责把连续 chars 聚合成 `PdfTextSpan`。

当前 Phase-1 规则下，span 聚合主要基于：

* source group 一致
* font name / font size 一致
* break 信号透传

这一层的目标不是恢复最终语义，而是先把离散字符聚成更可操作的文本片段。

### 5. lines 层

lines 层是当前 `pdf_core` 中最关键的一层之一。

它的职责是：

* 从 spans 恢复“更像人类阅读时看到的文本行”
* 修正 PDF 中常见的硬换行、碎片化、兼容字形问题
* 为 block 层提供更稳定的 line 输入

当前已实现的能力包括：

#### 文本归一化

* 常见 CJK compatibility glyph 归一化

  * 例如 `⽂ -> 文`、`⼀ -> 一`、`⽤ -> 用` 等
* 常见英文 ligature 归一化

  * 例如 `ﬁ -> fi`
* 英文断词换行修复

  * 例如 `inter- national -> international`

#### line 恢复

* 从 span 构建最小 line
* 对中文 hard wrap 做最小恢复
* 对英文 hard wrap 做最小恢复
* 对标题与正文关系做启发式区分
* 对页码样式短行做候选过滤

#### 当前规则风格

当前 lines 恢复使用的是“**保守的、可解释的启发式**”，而不是试图一次性完成复杂版面理解。其设计理念是：

* 宁可先得到稳定、可解释的 line
* 再逐步往 block / convert 层增加语义
* 不在这一层做过多高风险推断

### 6. blocks 层

blocks 层是当前阶段的第二个关键层。

在经过 line 恢复后，`pdf_core` 现在会进一步把 line 提升为 block。

当前 Phase-1 block 策略是：

* heading candidate line → 单独成 block
* page number candidate line → 单独成 block
* 普通正文 line → 单独 paragraph block

这一层当前不会激进地跨行合并 paragraph，而是优先输出稳定、清晰的 block 基线。

这样做的好处是：

* 结果更稳定
* 回归更容易
* 后续 convert 层更容易消费
* 不会在 block 层再次放大 line 层残余误差

### 7. PdfDocumentModel

当前 `pdf_core_api` 已经把对外输出切到了 `blocks` 层。

也就是说，当前 `extract_document_model(...)` 返回的 `PdfDocumentModel`，其 `page.text_blocks` 已经直接使用恢复后的 block 结果，而不是早期阶段那种临时占位结构。

这意味着 `pdf_core` 现在已经具备了“对上游提供结构化 PDF 文本模型”的能力，而不再只是一个实验性抽字层。

---

## 当前 Phase-1 已完成能力

下面总结一下截至当前阶段已经完成并通过样例验证的能力。

### 1. text-based PDF 的底层抽取链路已经跑通

已经具备：

* MBTPDF 接入
* raw 抽取
* chars / spans / lines / blocks 分层恢复
* PdfDocumentModel 对外输出

### 2. 文本归一化链路已经具备实用价值

已经覆盖：

* CJK compatibility glyph 的最小归一化
* ligature 归一化
* 英文断词换行修复

这对 PDF 中常见的：

* 中文兼容字形
* `ﬁ`
* `inter- national`

等问题已经有明显效果。

### 3. hard wrap 样例已经可以稳定恢复

对以下典型样例已经能够恢复出合理结构：

* `text_simple`
* `hardwrap_en`
* `hardwrap_zh`

当前结果能够稳定得到：

* heading block
* paragraph block
* 多段正文的分离
* 页码样式短行的清理

### 4. block 语义候选已经进入模型

当前 block 层已经能标注：

* `HeadingCandidate`
* `Text`
* `PageNumberCandidate`（候选）

虽然还不是完整语义模型，但已经足够支撑 convert 层的下一步接入。

---

## 当前 smoke / regression 状态

当前阶段的 smoke test 已经覆盖：

* raw 可读性
* chars / spans / lines / blocks 可构建性
* page model 最小可用性
* block 数量断言
* heading candidate 数量断言
* 最小内容断言

现阶段样例的目标状态大致如下：

### `hardwrap_en`

恢复为：

1. heading
2. 第一段正文
3. 第二段正文

### `hardwrap_zh`

恢复为：

1. `研究内容`
2. 正文
3. `技术路线`
4. 正文

### `text_simple`

恢复为：

1. 标题
2. 第一段
3. 第二段
4. 第三段

这说明 `pdf_core` 当前已经具备“**稳定恢复简单文本型 PDF 基本结构**”的能力。

---

## 当前的边界与限制

尽管当前阶段已经取得了可用结果，但 `pdf_core` 目前仍然明确属于 **Phase-1 text-first**。

下面这些问题当前还没有被完整解决，或者只做了非常有限的处理：

### 1. 复杂版面布局

当前还没有系统化处理：

* 双栏 / 多栏阅读顺序
* 浮动文本块
* 跨列内容误并
* 复杂页面层叠顺序

### 2. 表格、caption、footnote 等结构

当前 block 层还没有完整建模：

* table cell
* caption
* footnote
* header/footer
* marginal note

虽然模型里已经预留了候选字段，但尚未真正进入稳定恢复阶段。

### 3. 几何驱动能力仍然较弱

虽然 chars / spans / lines / blocks 模型中已经预留或携带了部分几何字段，但当前启发式仍然以 **text-first** 为主。

也就是说，当前系统还没有大规模利用：

* bbox 邻接关系
* baseline / line gap
* font size 层级
* 页面边缘位置
* alignment / indentation

来驱动更强的结构恢复。

### 4. 非文本对象链路还不完整

当前 `PdfDocumentModel` 中虽然预留了：

* images
  n- vectors
* annotations
* forms
* outlines

但当前主推进重点仍然是 text 主链，这些对象还未系统接入上层语义恢复链。

### 5. 启发式规则仍可能存在漏洞

当前 lines / blocks 的恢复依赖启发式规则，因此天然会存在：

* 规则冲突
* 误切 / 误并
* 样例外场景不稳
* 复杂真实 PDF 下的边界情况

不过当前阶段的策略是：

* 保持规则可解释
* 尽量保守
* 用 regression 样例集约束漂移
* 不在 Phase-1 过早追求复杂布局猜测

---

## 当前设计原则

当前 `pdf_core` 主要遵循以下设计原则。

### 1. 分层恢复

尽量把问题拆分到不同层解决：

* raw：事实抽取
* chars：字符结构化
* spans：局部聚合
* lines：文本连续性恢复
* blocks：初步语义恢复
* model：统一对外表示

### 2. 可解释启发式

当前大量逻辑确实是启发式，但尽量保持：

* 函数名语义清晰
* 规则触发原因可解释
* 可以通过样例和 debug 输出验证

### 3. 保守优先

在 PDF 恢复里，过度激进的规则很容易把不同结构错误粘连。当前更偏向：

* 先得到稳定可用的 baseline
* 再逐步扩展更复杂语义

### 4. 先 text-first，再逐步几何增强

当前阶段优先解决：

* 文本归一化
* hard wrap
* heading / paragraph 恢复

后续再引入：

* 更强的 bbox / baseline / font / alignment 信号

---

## 为什么当前选择 text-first Phase-1

这是一个刻意的设计取舍。

如果一开始就试图做：

* 完整阅读顺序
* 全页面版面恢复
* 双栏/表格/caption/页眉页脚统一判定

那么系统很容易在底层信号还不够稳定时就陷入过早复杂化。

因此当前先做的是：

* 把 raw 文本链路做通
* 让 line 恢复稳定
* 让 block 恢复可用
* 让 model 能正式承载这些结构

等这条链真正稳住后，再继续增强几何和复杂布局能力。

---

## 下一步路线

当前阶段完成后，下一步最自然的推进方向主要有两个。

### 方向 A：继续增强 `pdf_core`

可能包括：

* 引入更强几何信号参与 lines / blocks 恢复
* 提升标题识别、段落恢复、页眉页脚候选能力
* 开始建模 caption / table / artifact / header-footer
* 把 images / annotations / outlines 等对象逐步接入统一模型

### 方向 B：接入 `convert/pdf`

这也是当前最值得推进的方向之一。

即：

* 让 `convert/pdf` 直接消费 `PdfDocumentModel`
* 将 heading candidate / paragraph block 落地为 Markdown 结构
* 逐步减少旧路径中依赖“纯文本抽取 + 后处理”的部分

当前 `pdf_core` 的状态已经足以支撑这件事开始发生。

---

## 当前状态总结

一句话总结当前阶段：

> `pdf_core` 已经从“底层抽字实验链”进入“可稳定输出 heading / paragraph blocks 的 PDF text-first 结构恢复模块”阶段，并可作为后续 `convert/pdf` 接入的基础。

如果再展开一点说，就是：

* 它已经不只是“把 PDF 文字拿出来”
* 而是开始真正承担“结构恢复”的职责
* 虽然还远不是完整 PDF 引擎
* 但已经具备了一个清晰、稳定、可继续扩展的核心骨架

这也是当前阶段最重要的成果。
