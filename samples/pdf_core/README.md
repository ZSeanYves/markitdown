# PDF Core Fixtures

该目录用于维护 **pdf-native 相关回归样例**，已按职责拆分为三个子目录，避免 native 能力验证与 gate 策略验证混用。

## 目录结构

- `expected/`
  - 存放 native 验证用的黄金输出（`*.expected.md`）。
  - 与 `native/` 下同名 PDF 一一对应。
- `native/`
  - 存放用于验证 PDF 原生解析能力的样例 PDF（`pdf_native_real_*.pdf`）。
  - 由 `samples/pdf_native_check.sh` 使用，并与 `expected/` 做 diff。
- `gate/`
  - 存放用于验证 native-gated 策略决策的样例 PDF（`gated_should_use_*.pdf`）。
  - 由 `samples/pdf_native_gate_check.sh` 使用，仅校验 `selected/reason`，不做内容 diff。

## 生成/刷新样例

```bash
python3 samples/pdf_core/generate_phase7_native_fixtures.py
```

该脚本会：

1. 刷新 `native/` 下 phase-7 的程序化 PDF；
2. 同步 `gate/` 下来自 native 基线的 gate 样例（按 `gated_should_use_*` 命名）；
3. 一并生成 gate marker（如 encrypted marker），仓库不再提交 PDF 原件。

## 常用校验命令

```bash
# 校验 native 提取能力（有 expected diff）
bash samples/pdf_native_check.sh

# 校验 native-gated 决策（无 expected diff）
bash samples/pdf_native_gate_check.sh
```

## 命名约定

- native 样例：`pdf_native_real_<topic>.pdf`
- expected：`pdf_native_real_<topic>.expected.md`
- gate 样例：`gated_should_use_<topic>.pdf`

这样命名可以清晰区分：
- 「能不能解析对」归 native + expected，
- 「该不该走 native」归 gate。


> 说明：`native/` 与 `gate/` 下的 PDF 由脚本按需生成，不再存储 PDF 二进制原件。
