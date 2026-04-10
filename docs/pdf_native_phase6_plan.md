# PDF Native phase-6 最小推进方案（受控扩大 native 接入范围）

> 目标：在不扩大战线（不立刻覆盖更多 PDF 规范细节）的前提下，
> 让 native backend 以“可解释、可回滚、可回归”的方式进入主流程。

## 0. 输入基线（承接 phase-5）

- 已通过 acceptance 的真实样例：
  - `pdf_native_real_en_single_page`
  - `pdf_native_real_zh_single_page`
  - `pdf_native_real_text_multipage`
  - `pdf_native_real_tounicode_basic`
  - `pdf_native_real_header_footer_simple`
- 当前已知原则：
  - native 已覆盖“真实简单文本 PDF”的最小可用闭环；
  - external backend 继续保留；
  - 复杂字体/复杂 CMap/多栏/xref stream/object stream/加密仍属 out-of-scope。

---

## 1. phase-6 范围与非目标

### 1.1 范围（In scope）

1. 定义**可判定的 native 适用条件**（白名单能力）。
2. 定义**必须走 external 的触发条件**（黑名单能力）。
3. 在主流程引入**受控接入模式**（显式策略 + 可观测日志），避免“隐式自动回退”。
4. 保持当前 phase-5 回归样例稳定，新增少量 phase-6 决策类样例。

### 1.2 非目标（Out of scope）

- 不新增复杂 PDF 规范支持面。
- 不引入“静默 auto fallback（先 native 失败再悄悄 external）”。
- 不改变现有 markdown 后处理语义（仅调整 backend 选择策略）。

---

## 2. 接入策略：从“后验失败”转为“前置分流”

## 2.1 新增 backend policy（建议）

在已有 `external | pdf-native` 基础上，新增**策略层参数**（可先挂在 CLI，再透传内部）：

- `external`：始终 external（保持默认稳态）。
- `native-strict`：始终 native；命中 unsupported 直接失败（延续当前可控性）。
- `native-gated`：先做“native 适配预检”，通过才走 native，否则直接走 external（**phase-6 主推**）。

> 关键点：`native-gated` 不是“失败后回退”，而是“执行前判定分流”。

## 2.2 预检分流器（gating）最小信号

预检只用**容器级与资源级廉价信号**，避免深入规范实现：

### A. 通过条件（优先 native）

- 文档未加密；
- xref/object 结构落在当前支持子集；
- 页面文本提取路径可建立（`/Contents` + 基础字体资源）；
- 无明显复杂版式信号（见下方拒绝条件）。

### B. 拒绝条件（转 external）

- 加密标志；
- 命中 xref stream/object stream 等未覆盖结构；
- 关键字体/编码元信息超出当前解码子集；
- 检测到高风险复杂布局信号（例如同页极端分散 text block、明显多栏特征）。

### C. 不确定条件

- 任一关键信号缺失或冲突时，按保守策略走 external，并记录原因码。

---

## 3. 主流程可控接入（避免盲目 fallback）

## 3.1 决策结果类型（建议）

新增统一决策对象（日志/调试可复用）：

- `selected_backend`: `pdf-native | external`
- `policy_mode`: `external | native-strict | native-gated`
- `decision_reason_code`: 如 `PASS_SIMPLE_TEXT`, `REJECT_ENCRYPTED`, `REJECT_COMPLEX_LAYOUT`, `REJECT_UNSUPPORTED_XREF`, `UNSURE_CONSERVATIVE_EXTERNAL`
- `precheck_confidence`: `high | medium | low`（可选）

## 3.2 行为约束

- `native-strict`：
  - 仅当用户明确要求“只走 native”时使用；
  - 报错时保留当前 `pdf-native unsupported/parser_error/...` 分类。
- `native-gated`：
  - 只做前置分流；
  - 不做运行中 silent fallback；
  - 输出明确 trace：
    - `[pdf-debug] policy=native-gated selected=external reason=REJECT_...`。

---

## 4. 最小交付拆分（建议 2 个小里程碑）

## M1（1~2 天）：策略壳 + 可观测性

1. 增加 policy 参数与解析（默认仍 `external`）。
2. 落地 precheck 决策骨架（先覆盖加密/xref/object-stream/基础布局信号）。
3. 打通统一 debug 日志与 reason code。
4. 不改变现有 extraction/enhance pipeline。

**完成标志**：
- phase-5 acceptance 全绿；
- 在同一输入下可稳定复现“为何选 native/为何选 external”。

## M2（1~2 天）：回归矩阵 + 受控放量

1. 新增 phase-6 决策样例（少量）：
   - `gated_should_use_native_*`（2 个）
   - `gated_should_use_external_*`（2~3 个，包含已知复杂/不确定信号）
2. 新增决策一致性检查脚本（可复用现有 acceptance 框架）。
3. 形成 rollout 建议：默认 external；灰度用户可启 `native-gated`。

**完成标志**：
- phase-5 功能样例 + phase-6 决策样例均稳定；
- 无 silent fallback，决策可审计。

---

## 5. 验收标准（phase-6 Done）

1. **可控性**：任意 PDF 的 backend 选择都有可读 reason code。
2. **稳定性**：phase-5 样例输出不回退。
3. **保守性**：不确定文档优先 external，避免 native 误用造成“静默错误文本”。
4. **可演进性**：后续 phase-7 可在不破坏接口的前提下扩充 precheck 信号和支持子集。

---

## 6. 风险与防护

- 风险 R1：预检过宽，误放 native。
  - 防护：默认保守拒绝；先小流量启用 `native-gated`。
- 风险 R2：预检过严，native 命中率低。
  - 防护：通过 reason code 统计 TOP 拒绝原因，再定向放宽单一规则。
- 风险 R3：策略分支增加维护成本。
  - 防护：统一决策对象 + 统一日志格式，避免散落 if/else。

---

## 7. 建议的最小实施清单（可直接开工）

1. CLI 增加 `--pdf-backend-policy`（`external|native-strict|native-gated`）。
2. `extract_pdf_text_result(...)` 前增加 precheck 分流入口。
3. 实现 `PdfPrecheckDecision` + reason code 枚举。
4. 在 debug 输出中打印 policy/selected/reason。
5. 扩展 `samples/pdf_native_check.sh` 或新增 `samples/pdf_native_gate_check.sh`，覆盖“应走 native / 应走 external”两类样例。

> 以上 5 项全部完成即可视为 phase-6 最小闭环。
