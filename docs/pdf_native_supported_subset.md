# PDF Native Supported Subset（phase-5）

本文档描述 `markitdown-mb` 当前 **native PDF backend** 的可用子集（以当前实现为准，不代表完整 PDF 规范支持）。

## Supported

- 容器级基础读取：基础 xref/table + 间接对象读取（项目所需子集）。
- `/Contents` 单 stream 与数组 stream 聚合读取。
- `/Length` 直接值与间接引用解析。
- 页面字体资源解析（包含 inherited page resources 的常见路径）。
- 文本操作符子集：
  - `BT` / `ET`
  - `Tf`（当前字体状态跟踪）
  - `Tj`
  - `TJ`（数组中的数字间距项忽略，字符串项拼接）
- 基础 ToUnicode CMap：
  - `bfchar`
  - `bfrange`
- 缺失 ToUnicode 时的保底解码路径（byte/string fallback）。

## Unsupported

- 加密 PDF。
- 完整 xref-stream / object-stream 生态覆盖。
- 完整字体系统与复杂编码体系（复合字体细分场景、复杂字形映射等）。
- 完整 ToUnicode/CMap 生态（超出当前最小子集的高级特性）。
- 完整多栏/复杂阅读顺序重建。
- “native 自动回退到 external”的 `auto fallback` 模式（当前不启用）。

## Degraded / Partial

- 在简单文本 PDF 上可用性较好，但复杂排版文档可能出现：
  - 语义段落边界不理想；
  - 阅读顺序与视觉顺序不一致；
  - 字体映射不足导致的字符退化。
- `TJ` 的间距数字仅用于跳过，不参与排版还原。
- 当文档超出支持子集时，建议切换 external backend。

## Recommended Current Use Cases

- 单页或多页的简单文本 PDF（英文/中文均可尝试）。
- 结构相对规整、阅读顺序近似线性的文档。
- 需要在项目内使用纯 native 路径进行可控回归验证时：
  - 使用 `--pdf-backend pdf-native` 显式启用；
  - 结合样例回归（`samples/pdf` + `samples/expected/pdf`）持续稳固行为。

## Notes

- 当前策略是“增量推进、可控接入”：优先扩大真实简单样例覆盖，不主动扩展规范战线。
- 若你的 PDF 依赖复杂字体/编码/版式，请优先使用 external backend。
