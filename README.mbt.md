# markitdown-mb (MoonBit)

`markitdown-mb` 是一个基于 MoonBit 的多格式文档转 Markdown 工具。

支持输入格式：

- `.docx`
- `.pdf`
- `.xlsx`
- `.pptx`
- `.html`

---

## 1. 总览

主流程：

```text
document -> parser -> IR -> Markdown
```

项目已经历结构重构：目录从过去的 `src/*` 迁移为顶层 package（例如 `cli/`, `convert/`, `core/`, `doc_parse/*`）。

CLI 入口 package 当前路径为：

- `cli`

因此命令行调用应使用：

```bash
moon run cli -- <args>
```

---

## 2. 当前目录结构（重构后）

- `cli/`：命令行入口、参数解析、应用编排
- `convert/`：按格式分发转换流程
  - `convert/docx/`
  - `convert/pdf/`
  - `convert/xlsx/`
  - `convert/pptx/`
  - `convert/html/`
- `core/`：共享 IR 与 Markdown 生成
- `doc_parse/`：底层解析能力
  - `doc_parse/ooxml/`：OOXML 包与结构读取
  - `doc_parse/zip/`：ZIP 基础能力
  - `doc_parse/pdf_core/`：PDF 原生底层解析能力
- `samples/`：回归输入样例与黄金输出

---

## 3. 快速开始

### 3.1 转换命令

```bash
moon run cli -- convert <input-file> -o out/output.md --out-dir out
```

示例：

```bash
# DOCX
moon run cli -- convert samples/docx/golden.docx -o out/golden.md --out-dir out

# PDF
moon run cli -- convert samples/pdf/text_simple.pdf -o out/text_simple.md --out-dir out

# XLSX
moon run cli -- convert samples/xlsx/sheet_simple.xlsx -o out/sheet_simple.md --out-dir out

# PPTX
moon run cli -- convert samples/pptx/pptx_simple.pptx -o out/pptx_simple.md --out-dir out

# HTML
moon run cli -- convert samples/html/html_simple.html -o out/html_simple.md --out-dir out
```

### 3.2 常用选项

- `-o <path>`：输出 Markdown 文件（默认 stdout）
- `--out-dir <dir>`：资源输出目录
- `--max-heading <1..6>`：限制标题级别
- `--ocr [1|true|on|yes]`：PDF 启用 OCR 增强
- `--debug <extract|dump-raw|pipeline|all>`：调试输出

---

## 4. PDF：native-only 主流程

PDF 当前主流程为 native-only：

- PDF 文本提取仅走 `doc_parse/pdf_core`；
- external backend 选路与 gate 逻辑已移除；
- OCR 作为可选增强分支保留。

### 当前 native 已覆盖的基础能力（摘要）

- PDF 对象/容器访问
- 页面引用与页数
- 内容流读取
- 基础文本提取路径
- 部分 ToUnicode 相关能力
- 部分字体兜底场景

### 仍在持续完善的方向（摘要）

- 加密 PDF
- 更完整的 xref/object stream 变体
- 更完整字体系统
- 复杂阅读顺序（多栏、交错布局）

---

## 5. 回归测试体系

### 5.1 全格式样例回归

```bash
bash samples/check_samples.sh
bash samples/diff.sh
```

### 5.2 PDF native 专项

```bash
# PDF 主流程回归（PDF -> Markdown，与 expected 对比）
bash samples/pdf_regression_check.sh
```

### 5.3 `samples/pdf_core/` 分层约定

- `samples/pdf_core/expected/`：PDF 主流程黄金输出（`*.expected.md`）
- `samples/pdf_core/native/`：PDF 主流程验证样例（`pdf_native_real_*.pdf`）

`native/` 与 `expected/` 的样例可由 `generate_phase7_native_fixtures.py` 按需生成。

---

## 6. 开发与质量命令

建议在提交前执行：

```bash
moon info
moon fmt
moon check
moon test
```

当行为预期变化导致快照差异时：

```bash
moon test --update
```

---

## 7. OCR 依赖说明（PDF 可选增强）

若启用 OCR 增强（`--ocr`），通常依赖：

- `ocrmypdf`
- `tesseract`

安装示例：

- macOS: `brew install ocrmypdf tesseract`
- Ubuntu/Debian: `sudo apt-get install ocrmypdf tesseract-ocr`

---

## 8. 维护建议

- 目录重构后，所有脚本与文档避免再引用 `src/cli`；统一使用 `cli` package 路径。
- 新增 PDF 样例时，优先放入 `native/` + `expected/` 作为主流程回归。
- 如果新增可程序化生成的 fixture，优先收敛到：
  - `samples/pdf_core/generate_phase7_native_fixtures.py`

