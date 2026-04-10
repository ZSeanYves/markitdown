# PDF Native Acceptance (MVP)

本文件定义 `samples/pdf_native_check.sh` 的最小验收边界，目标是验证 **native backend 可接入主线**，而不是继续补 parser 细节。

## 目录组织

- 固定样例来源：`src/pdf_core/tests/test_file/*.pdf`
- Native 期望：`src/pdf_core/tests/test_file/*.expected.md`
- 运行产物：`.tmp_pdf_native_out/`
  - `run/*.md`：本次 native 输出
  - `log/*.log`：每个样例的执行日志（包含 backend 选择痕迹）
  - `log/*.diff`：失败样例的 diff

## 样例集合（第一批）

脚本默认覆盖以下 5 个 phase-5 真实简单样例：

1. `pdf_native_real_en_single_page.pdf`
2. `pdf_native_real_zh_single_page.pdf`
3. `pdf_native_real_text_multipage.pdf`
4. `pdf_native_real_tounicode_basic.pdf`
5. `pdf_native_real_header_footer_simple.pdf`

## 验收标准

### A. 强制只走 native

每个样例都必须以：

- `--pdf-backend pdf-native`
- `--pdf-extract-debug true`

执行，并在日志出现：

- `selected backend=pdf-native (forced)`

若缺少该标记，判为失败（说明无法确认实际 backend）。

### B. 输出正确性

- `diff expected vs actual` 全量一致 => `PASS`
- 若不一致 => `FAIL`，归类为 **silent wrong output**（程序成功返回但内容错误）

### C. unsupported 边界

- 默认这 5 个样例全部是 **required-pass**，不允许 unsupported。
- 如果后续新增复杂样例需要过渡，可加入脚本 `ALLOW_UNSUPPORTED`，并在 PR 中注明原因与退出条件。

## 扩大接入范围判定

可认为 native backend 已满足“扩大接入范围”的最小条件：

1. 第一批 required 样例连续稳定通过（建议在 CI 连续通过）。
2. required 集合中 `unsupported == 0`。
3. required 集合中无 silent wrong output（diff 全绿）。
4. 对外可观测到实际 backend（日志中有 forced native 标记）。
