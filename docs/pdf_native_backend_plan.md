# PDF Native Backend 接入计划（phase-4）

## 1) 模块拆分建议

目标：把 `pdf_core` 从“能 parse”推进到“能在主流程受控接入”。

- `src/pdf_core/`
  - `pdf_doc.mbt`：继续负责容器级打开、page tree、对象读取、`/Contents` 读取。
  - `pdf_object.mbt`：对象值解析（维持当前基础能力，不扩大战线）。
  - `pdf_stream.mbt`：stream 边界与长度读取，补齐 `/Length` 间接引用解析。
  - `pdf_content_stream.mbt`：content stream token + text operator 提取（已具备 phase-2.5/3 基础）。
  - **新增 `pdf_font.mbt`**：页面资源中 font lookup、`Tf` 当前字体追踪。
  - **新增 `pdf_cmap.mbt`**：ToUnicode 最小解析（bfchar + bfrange 基础）。
  - **新增 `pdf_text_decode.mbt`**：把 `Tj`/`TJ` 的 string/hex operand 按当前字体进行解码。
  - **新增 `pdf_extract_api.mbt`**：页级/文档级聚合 API（作为对外入口）。

- `src/pdf/`
  - `pdf_backend.mbt`：保留现有外部工具 backend，同时新增 native backend spec。
  - `pdf_parser.mbt`：新增显式开关，允许选择 `pdf-native` 或现有 external 路径。

---

## 2) 需要新增或修改的 API

### `pdf_core` 内部 API（新增）

- `resolve_page_fonts(doc, page_obj, page_gen) -> Map[String, PdfFontRef] raise`
  - 从 page `/Resources/Font` 建立 font name（如 `F1`）到 font object 引用的映射。
- `extract_text_ops_with_state(stream : Bytes) -> Array[PdfTextEvent] raise`
  - 在现有 op 提取之上保留 `Tf` 状态变化（font name + size）。
- `decode_text_operand(doc, font_ref, operand) -> String raise`
  - 对 `Tj`/`TJ` operand 执行最小解码，优先 ToUnicode；无映射时降级 latin1/byte passthrough。
- `extract_text_from_page(doc, page_obj, page_gen) -> String raise`
  - 聚合 page 的 `/Contents`（含数组）并执行字体+文本解码。
- `extract_text_from_document(doc) -> String raise`
  - 遍历 page tree，按页拼接文本，页间用 `\n` 分隔。

### 现有 API（调整）

- `extract_stream_length` / `parse_stream_bounds`
  - 支持 `/Length` 为 `Ref`，可解引用后再读取 stream。

---

## 3) 最小接入方案（并列接入主流程）

新增 backend 枚举（建议）：

- `external`（默认，当前行为）
- `native`（新）
- `auto`（后续再做）

接入步骤：

1. `parse_pdf(...)` 增加可选参数 `backend : String?`（或沿用现有选项统一到 CLI）。
2. 当 `backend == "native"`：
   - 走 `pdf_core.open_pdf` + `extract_text_from_document`。
   - 文本结果直接送入既有 cleanup/enhance pipeline（不改下游 IR 管线）。
3. 当 native 命中未支持能力（如复杂编码）：
   - 返回结构化错误 `PdfNativeUnsupported(feature)`；
   - 当前阶段先直接失败并提示“请切回 external”（保持行为可控）；
   - 下一阶段再做 `auto` fallback。

---

## 4) 优先实现顺序（建议按里程碑）

1. **M1: stream 稳定性**
   - `/Length` 间接引用
   - `/Contents` array 现状回归验证
2. **M2: font state**
   - page font resource lookup
   - `Tf` 解析与字体上下文跟踪
3. **M3: decode 最小闭环**
   - ToUnicode 最小支持（bfchar/bfrange）
   - `Tj`/`TJ` operand decode
4. **M4: 对外提取 API**
   - `extract_text_from_page`
   - `extract_text_from_document`
5. **M5: 主流程并列接入**
   - `pdf-native` 显式开关
   - 文案与错误提示

---

## 5) 最小测试清单

优先 hand-crafted + 少量真实样本：

1. **ToUnicode basic**
   - bfchar 单字符映射
   - bfrange 连续映射
2. **font lookup / Tf**
   - 同页多字体切换，验证 `Tf` 后 `Tj` decode 生效
3. **`TJ` with spacing numbers**
   - 数字间距项不产字符，字符串项按顺序拼接
4. **`/Contents` array**
   - 多 stream 页面提取顺序稳定
5. **`/Length` indirect ref**
   - stream 长度来自引用对象，解析正确
6. **真实简单文本 PDF 样例（2~3 个）**
   - 一页纯文本
   - 多页纯文本
   - 含 ToUnicode 的简单 CMap

