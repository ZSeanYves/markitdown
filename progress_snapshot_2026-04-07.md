# 仓库进度盘点（2026-04-07）

## 1) 仓库目录树（到 `src/<pkg>/<file>.mbt`）

```text
src/
  cli/
    cli_app.mbt
    cli_args.mbt
    main.mbt
  convert/
    dispatcher.mbt
  core/
    emitter_markdown.mbt
    errors.mbt
    ir.mbt
    tool.mbt
    zip_min.mbt
  docx/
    docx_document.mbt
    docx_numbering.mbt
    docx_package.mbt
    docx_parser.mbt
    docx_rels.mbt
    docx_styles.mbt
    docx_table.mbt
    docx_types.mbt
    docx_xml.mbt
  html/
    html_bytes.mbt
    html_dom.mbt
    html_parser.mbt
    html_to_ir.mbt
  pdf/
    pdf_block.mbt
    pdf_extract.mbt
    pdf_heading.mbt
    pdf_list.mbt
    pdf_noise.mbt
    pdf_page.mbt
    pdf_parser.mbt
    pdf_text.mbt
    pdf_to_ir.mbt
  pptx/
    pptx_bytes.mbt
    pptx_classify.mbt
    pptx_geom.mbt
    pptx_group_candidates.mbt
    pptx_grouping.mbt
    pptx_layout_base.mbt
    pptx_noise.mbt
    pptx_package.mbt
    pptx_paragraph_meta.mbt
    pptx_parser.mbt
    pptx_reading_order.mbt
    pptx_rels.mbt
    pptx_shape_collect.mbt
    pptx_slide.mbt
    pptx_table_like.mbt
    pptx_text.mbt
    pptx_types.mbt
  xlsx/
    xlsx_datetime.mbt
    xlsx_package.mbt
    xlsx_parser.mbt
    xlsx_shared_strings.mbt
    xlsx_sheet.mbt
    xlsx_styles.mbt
    xlsx_xml.mbt
```

## 2) 每个包的职责一句话说明

- `src/cli`：命令行入口，解析参数并触发转换流程。
- `src/convert`：按输入格式进行分发，统一调用各格式解析器并返回 IR。
- `src/core`：共享 IR、错误、文本工具和 Markdown 发射器，以及 Office ZIP 读取能力。
- `src/docx`：DOCX 解析流水线（文档结构、样式、编号、表格、关系）并映射到 IR。
- `src/html`：HTML 解析与 DOM/inline 结构恢复后映射到 IR。
- `src/pdf`：PDF 文本提取与结构恢复（分页、噪声清理、标题/列表识别）并映射到 IR。
- `src/pptx`：PPTX 形状级文本提取、阅读顺序/分组启发式恢复并映射到 IR。
- `src/xlsx`：XLSX 工作簿/工作表解析、样式驱动日期时间识别，并输出表格型 IR。

## 3) 当前 regression / sample 目录结构

- `regression/`：当前仓库中不存在该目录。
- `samples/`：
  - `samples/docx/`、`samples/html/`、`samples/pdf/`、`samples/pptx/`、`samples/xlsx/`（原始样本）
  - `samples/expected/docx|html|pdf|pptx|xlsx/`（对应 golden Markdown）
  - `samples/diff.sh`（样本回归 diff 脚本）

## 4) 最近改动最多的文件（按 `git log --name-only` 计数）

1. `README.mbt.md` (21)
2. `src/html/html_dom.mbt` (20)
3. `src/xlsx/xlsx_parser.mbt` (16)
4. `src/pptx/pptx_slide.mbt` (15)
5. `src/core/tool.mbt` (15)
6. `src/pptx/pptx_parser.mbt` (14)
7. `src/xlsx/xlsx_sheet.mbt` (12)
8. `src/pdf/pdf_normalize.mbt` (11, 历史路径，当前工作树无此文件)
9. `src/html/html_to_ir.mbt` (11)
10. `src/docx/docx_xml.mbt` (11)

## 5) 我打算本轮动的文件

- 仅新增该盘点文档：`progress_snapshot_2026-04-07.md`。
- 本轮不改动解析逻辑代码，先做现状梳理，便于下一轮选定具体改造点。

## 6) 相关类型定义所在文件

- 统一 IR 与公共错误/配置：
  - `src/core/ir.mbt`（`Block`, `Document`）
  - `src/core/errors.mbt`（`Utf8DecodeError`, `AppError`）
  - `src/core/zip_min.mbt`（`ZipEntry`, `ZipReader`, `ZipError`）
  - `src/convert/dispatcher.mbt`（`ConvertOptions`）
- 格式域内关键内部类型：
  - `src/docx/docx_types.mbt`（`ListKind`, `ParagraphListInfo`, `DocxNumbering`, `DocxStyles`）
  - `src/pptx/pptx_types.mbt`（`PptxBlock`, `SlideShape`, `LayoutShape`, `ShapeGroupKind`, `ShapeGroup`, `SlideParagraph`, `BulletKind`）
  - `src/xlsx/xlsx_styles.mbt`（`XlsxStyles`）

## 7) 相关核心函数签名

- 统一入口/分发：
  - `parse_to_ir(path : String, opts : ConvertOptions) -> Result[Document, AppError]`
- 各格式入口：
  - `parse_docx(path : String, out_dir : String, max_heading : Int) -> Document`
  - `parse_html(path : String, out_dir : String, max_heading : Int) -> Document`
  - `parse_pdf(path : String, out_dir : String, max_heading : Int) -> Document`
  - `parse_pptx(path : String, out_dir : String, max_heading : Int) -> Document`
  - `parse_xlsx(path : String, out_dir : String, max_heading : Int) -> Document`
- IR 与输出：
  - `new_document() -> Document`
  - `push(doc : Document, b : Block) -> Unit`
  - `emit_markdown(doc : Document) -> String`
- 公共工具/ZIP：
  - `open_zip(path : String) -> ZipReader`
  - `ZipReader::read_entry_bytes(name : String) -> Bytes`

---

## 建议的后续规划顺序（简）

1. 先锁定高活跃文件（`html_dom` / `xlsx_parser` / `pptx_slide` / `pptx_parser`）做“回归样本 → 函数热点”映射。
2. 补齐历史改名文件轨迹（如 `pdf_normalize.mbt`）对应到现存模块，避免误判技术债位置。
3. 将“类型定义 → 入口函数 → 样本用例”串成一页维护图，方便任务拆分与并行开发。
