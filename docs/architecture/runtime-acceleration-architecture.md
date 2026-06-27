# mb-markitdown Runtime Acceleration 架构书

> 适用范围：`mb-markitdown` 主链 `parser -> pipeline -> render` 的 native / FFI acceleration  
> 角色定位：正式产品架构，不是实验记录  
> 当前结论：native acceleration 允许存在，但只允许以 **scanner primitive surface** 的形式进入产品主链

## 0. 文档定位

这份文档回答的问题固定为：

```text
在不破坏 mb-markitdown 现有产品契约的前提下，
如何把 FFI/native acceleration 接入主链，
并为未来更底层的 FFI 下沉预留稳定边界。
```

本书是规范性文档，因此它定义的是：

```text
允许什么 surface
禁止什么边界穿透
MoonBit 与 native 之间怎样通信
失败时怎样退回 reference path
benchmark 和回归如何证明 native path 是真的
```

它不记录一次性优化过程，也不替代性能审计文档。

## 1. 目标与非目标

### 1.1 目标

本书的目标固定为：

```text
1. 把 native acceleration 收口到少数稳定 surface。
2. 让 parser / pipeline / render 的产品契约保持不变。
3. 为未来更底层 FFI 预留空间，但不把低层细节暴露给产品层。
4. 保证 fallback、diagnostics、benchmark 都是可验证的。
```

### 1.2 非目标

本书明确不是：

```text
不重新设计 convert / parser / pipeline / render 主链
不引入 benchmark-only fast path
不让 native 层直接输出 Markdown / RAG / Debug JSON
不把 package/container/document semantics 下沉到 native
不允许以“更快”为理由绕开现有 quality / source_map / asset 契约
```

## 2. 核心设计原则

### 2.1 Surface First，不按格式堆 native

native acceleration 的设计单位固定为 **surface**，不是单个格式。

正确方向：

```text
xml_native
html_native
json_native
yaml_native
pdf_native
```

错误方向：

```text
docx_native_package
pptx_native_package
epub_native_archive
zip_native_inventory
xlsx_native_workbook_package
```

原因很简单：

```text
产品真正稳定的加速边界，是 tokenizer / event / structural primitive。
而 package/container 级逻辑天然带有格式策略、验证语义和产品决策。
```

### 2.2 Primitive Only，不让 native 承担产品语义

native 层只允许提供事实级 primitive，例如：

```text
XML events
HTML tokens / scope primitives
JSON structural facts
YAML token / event facts
worksheet row / cell primitives
PDF page text / geometry primitives
```

native 层明确禁止提供：

```text
Markdown document
RAG chunks
Debug JSON
最终 heading / list / caption / section tree 结论
package/container inventory 的产品级语义结论
```

### 2.3 Same-Path Reference，不跨模式 fallback

native path 失败时，只允许两种结果：

```text
1. fail-closed
2. 回到同一 canonical path 下的 reference implementation
```

明确禁止：

```text
跨 parser mode fallback
静默切到另一条产品路径
关闭 source_map / metadata / assets 后继续宣称成功
benchmark 时走 native，正式 CLI 时走另一条隐藏路径
```

### 2.4 Lower FFI Allowed，但只在 surface 内部发生

本项目允许未来接入更底层 FFI，但它们只能作为 **surface 内部实现细节** 存在。

也就是说，允许：

```text
xml_native
  -> Expat
  -> 或更低层 XML tokenizer / SIMD primitive

html_native
  -> Lexbor
  -> 或更低层 tokenizer / DOM-lite primitive

pdf_native
  -> PDFium
  -> 或更低层 page text / layout primitive
```

但 MoonBit 产品层看到的始终只能是：

```text
surface facade
```

而不是：

```text
backend-specific ABI
sub-primitive private API
第三方库内部对象
```

这条原则是为了给后续更底层 FFI 留空间，同时避免产品架构被底层实现绑死。

## 3. 正式 surface 矩阵

### 3.1 当前正式方向

| Surface | 当前状态 | 允许承载的 primitive | 主要服务格式 |
|---|---|---|---|
| `xml_native` | 已存在、可继续演进 | XML event / workbook / sharedStrings / worksheet scan | `xlsx`，未来 `xml/docx/pptx/epub package xml` |
| `html_native` | 预留 | tokenizer / scope / subtree primitive | `html`，未来 `epub` chapter HTML |
| `json_native` | 预留 | structural scan / path-value primitive | `json` |
| `yaml_native` | 预留 | token / event / path-value primitive | `yaml` |
| `pdf_native` | 预留 | page text / geometry primitive | `pdf` |

### 3.2 明确禁止的 surface

以下方向被正式禁止：

```text
archive_native
zip inventory native
OOXML package native
EPUB package native
entry read / inflate 作为产品 surface
任何 package/container semantics native path
```

原因不是“永远不能用底层库”，而是：

```text
package/container 层一旦 native 化，就会把验证规则、路径归一、entry 可见性、
source boundary、diagnostics 语义一起拖进 native 层，风险远高于收益。
```

### 3.3 `zip` 的位置

`zip` 继续定位为：

```text
MoonBit reference implementation
```

它是：

```text
OOXML / EPUB / ZIP parser 的容器语义基线
```

它不是：

```text
native surface
```

如果未来确实需要更低层的 inflate / decode FFI，也只能：

```text
作为 MoonBit zip reader 内部的私有实现细节
```

而不能：

```text
替换 central-directory / inventory / validation / package semantics 的产品契约
```

## 4. 主链集成位置

native acceleration 只允许出现在 parser 侧的 primitive 获取阶段。

统一链路固定为：

```text
InputSource
  -> format parser facade
  -> native primitive surface 或 reference primitive surface
  -> parser-native facts
  -> ParseResult
  -> IRInput
  -> pipeline / DocumentAssembly
  -> renderer
  -> ConvertResult
```

因此：

```text
pipeline 不感知 backend 类型
render 不感知 backend 类型
convert 不按第三方库名字分支产品语义
```

具体禁止：

```text
在 pass 中判断 Expat / Lexbor / PDFium
在 renderer 中补 native 专用输出路径
native path 直接绕过 ParseResult / IRInput
native path 直接绕过 renderer
```

## 5. ABI 设计

### 5.1 MoonBit 只面对稳定 facade

MoonBit 与 native 之间只允许通过：

```text
extern "C"
native-stub
cc-link-flags
```

MoonBit 侧调用单位固定为：

```text
surface facade function
```

而不是第三方库原生 API。

### 5.2 ABI 形态

正式 ABI 只允许两类形态：

```text
1. 输入 bytes/blob + 输出 binary blob
2. 输入 bytes/blob + 输出 status + payload blob
```

推荐的 payload 组织为：

```text
fixed header
version
kind
record_count
payload offset
string table offset
flat records
string table
```

明确不允许：

```text
逐 token callback 回调 MoonBit
跨 ABI 传复杂对象图
把 native 内部裸指针长时间暴露给产品层
依赖异常跨语言传播
```

原因：

```text
bulk ABI 更稳定，更容易做版本演进、错误恢复、跨平台实现和 profile 归因。
```

### 5.3 版本与兼容规则

每个 surface payload 都必须自带：

```text
magic
version
kind
```

版本不匹配时：

```text
native facade 必须返回明确失败
调用方只能 fail-closed 或走 reference path
```

禁止静默按旧版本解码。

## 6. 内存与资源所有权

native acceleration 必须遵守单向所有权规则：

```text
MoonBit 创建的输入由 MoonBit 管理
native 创建的输出要么复制回 MoonBit bytes，
要么通过 surface 自己的释放接口管理
```

首版默认推荐：

```text
一次调用
一次返回完整 payload bytes
MoonBit 负责解码 payload
```

这样可以避免：

```text
跨平台 allocator 差异
悬垂指针
复杂生命周期同步
```

以下行为默认不允许：

```text
跨请求共享可变全局缓存
依赖 backend 进程级隐式状态
不同平台使用不同所有权语义
为了减少复制而牺牲 deterministic 行为
```

## 7. 错误语义、fallback 与 diagnostics

### 7.1 错误语义

surface facade 必须把错误压成稳定结果：

```text
ok
backend_unavailable
invalid_input
decode_failed
internal_error
version_mismatch
```

是否要更细的 backend-specific code，可以有，但只能作为附加字段。

### 7.2 fallback 语义

fallback 规则固定为：

```text
native unavailable -> same-path reference
native payload invalid -> same-path reference 或 fail-closed
native semantic drift detected by tests -> 回退实现，不改产品契约
```

明确禁止：

```text
native xml 失败后改走另一 parser mode
native html 失败后跳 whole-document special path
native pdf 失败后静默关闭 source_map / geometry
```

### 7.3 稳定 diagnostics 键

正式保留这些键：

```text
native_surface
native_backend
native_path
native_error_code
```

取值规则：

```text
native_surface = xml_native | html_native | json_native | yaml_native | pdf_native
native_backend = expat | lexbor | simdjson | libyaml | pdfium | <future backend id>
native_path = accelerated | reference
native_error_code = 仅失败时出现
```

禁止使用：

```text
experimental
beta
near_ready
promotion_target
not_migrated
任何迁移期或路线图措辞
```

## 8. 平台与构建策略

正式支持矩阵写死为：

```text
macOS
Linux
Windows
```

实施节奏允许分阶段：

```text
Phase 1: macOS / Linux
Phase 2: Windows
```

但产品语义不允许分叉。

每个 surface 都必须在文档和实现层写清：

```text
backend 依赖来源
静态/动态链接策略
不支持平台上的 reference path 行为
CI 如何验证 native target
```

## 9. Benchmark 与 anti-fake 规则

native acceleration 进入产品主链后，必须满足：

```text
compare 测的是正式 CLI 行为
samples/check.sh 全绿
samples/check_quality.sh 全绿
stage bench 能单独归因 native surface
```

明确禁止：

```text
benchmark-only fast path
样本特判
隐藏 whole-document rebuild
只在 compare 时启用 native、正式 CLI 不启用
```

必须长期锁定的 anti-fake 原则：

```text
没有 sample-specific shortcut
没有 silent fallback 到另一条 canonical route
没有通过关闭真实输出路径来伪造速度
```

## 10. 演进路线

### 10.1 第一阶段

第一阶段只要求：

```text
把现有 xml_native 继续收稳
明确它只负责 xlsx scanner primitive
把文档、diagnostics、fallback、tests 全部锁成正式规则
```

### 10.2 第二阶段

在有明确热点证据后，允许：

```text
xml_native 扩到 xml/docx/pptx/epub package xml 的 primitive scan
```

前提是：

```text
仍然只替换 XML primitive
不替换 package/container semantics
```

### 10.3 第三阶段

按热点证据逐个引入：

```text
html_native
json_native
yaml_native
```

要求保持同一原则：

```text
surface-first
primitive-only
same-path reference
```

### 10.4 第四阶段

最后再考虑：

```text
pdf_native
```

因为它的 primitive 面更重，错误语义和跨平台复杂度也更高。

## 11. 最终结论

mb-markitdown 的 FFI 架构最终结论固定为：

```text
允许 native，但只允许 scanner primitive surface 进入产品主链。
允许为性能继续下沉到更底层 FFI，但下沉只能发生在 surface 内部。
不允许再把 package/container/document semantics native 化。
MoonBit 主链始终保留统一的 ParseResult / IRInput / renderer 产品契约。
```

这份边界一旦锁定，后续所有 acceleration 工作都只能在这条线内推进。
