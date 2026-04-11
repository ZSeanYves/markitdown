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
- `--pdf-backend <...>`：指定 PDF 后端
- `--pdf-backend-policy native-gated`：启用 gated 策略
- `--debug <extract|dump-raw|pipeline|all>`：调试输出

---

## 4. PDF：hybrid 现状

PDF 目前采用 hybrid 方案：

- 外部后端仍是主生产路径；
- native 能力持续扩展中，并已接入主流程的一部分分支；
- native-gated 决策用于逐步把可控样例切向 native。

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
# native 能力回归（PDF -> Markdown，与 expected 对比）
bash samples/pdf_native_check.sh

# gate 决策回归（检查 selected/reason，不做 expected diff）
bash samples/pdf_native_gate_check.sh
```

### 5.3 `samples/pdf_core/` 分层约定

- `samples/pdf_core/expected/`：native 黄金输出（`*.expected.md`）
- `samples/pdf_core/native/`：native 能力验证 PDF（`pdf_native_real_*.pdf`）
- `samples/pdf_core/gate/`：gate 决策样例 PDF（`gated_should_use_*.pdf`）

该分层用于避免：

- native 内容正确性验证 与
- gate 策略正确性验证

在样例与脚本上的职责混杂。

另外，`samples/pdf_core/native/` 与 `samples/pdf_core/gate/` 的 PDF 由 `generate_phase7_native_fixtures.py` 按需生成，仓库不再提交 PDF 原件。

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

## 7. 外部依赖说明（PDF）

PDF 外部路径通常依赖以下工具之一：

- `pdftotext`（Poppler）
- `mutool`（MuPDF）

安装示例：

- macOS: `brew install poppler mupdf`
- Ubuntu/Debian: `sudo apt-get install poppler-utils mupdf-tools`
- Arch: `sudo pacman -S poppler mupdf-tools`

---

## 8. 维护建议

- 目录重构后，所有脚本与文档避免再引用 `src/cli`；统一使用 `cli` package 路径。
- 新增 PDF native 样例时，优先明确其归属：
  - 若验证提取质量：放 `native/` + `expected/`
  - 若验证 gated 决策：放 `gate/`
- 如果新增可程序化生成的 fixture，优先收敛到：
  - `samples/pdf_core/generate_phase7_native_fixtures.py`

