# Native 升级：7 项 RAG 资产修复审查

审查日期：2026-10-23。结论类型：Codex 独立代理对冻结产物和代码的审查结论，
**不是人类审批，也不是 P5 / 正式性能 / 发布验收。**

这 7 项可以审定为有意正确性修复：原有 chunk 引用了已提取并落盘的资产，但
BlockStream / EventStream 的 RAG 序列化器把顶层 `assets` 写成空数组。
candidate 补回真实资产声明，没有减少正文或删除引用来通过检查。本次没有修改
产品代码、原始比较结果、外仓输入或 golden，也没有运行 `moon`。

## 绑定产物与比较范围

证据根目录为
[`.audit/2026-10-23-native-upgrade/`](../.audit/2026-10-23-native-upgrade/)。

| 产物 | 本次重新计算的 executable SHA-256 |
| --- | --- |
| [baseline.exe](../.audit/2026-10-23-native-upgrade/baseline.exe) | `9fc933d0eacfcd9737ed148a15d613ac5615314b9c16b68db70fd64a44d60662` |
| [candidate.exe](../.audit/2026-10-23-native-upgrade/candidate.exe) | `453a79f955bd38e99860d77d7e8cd0eadc86a1817ba290ccfa875caad9ec028c` |

实际文件哈希与两次回归的 `fingerprints.tsv` 相符；两次使用相同验收器哈希
`8a101283a8eb22ba53cd678142098a7c82a78e6d5d64ed71fc2e21bb672f1a4f`，
三份 main/quality/accurate manifest 的对应哈希也一致。

- [baseline-regression-v3/summary.tsv](../.audit/2026-10-23-native-upgrade/baseline-regression-v3/summary.tsv)：
  原 935 个有效契约全部执行，928 pass、7 fail、0 filtered、0 retired、
  0 manifest errors；7 个失败均为下表中的 RAG dangling asset reference。
- [candidate-regression/summary.tsv](../.audit/2026-10-23-native-upgrade/candidate-regression/summary.tsv)：
  同样 935 个契约全部执行，935 pass、0 fail、0 filtered、0 retired、
  0 manifest errors。
- [output-comparison-v2/summary.tsv](../.audit/2026-10-23-native-upgrade/output-comparison-v2/summary.tsv)：
  3322 个输出比较项稳定、7 个 `rag_assets_repaired_REVIEW_REQUIRED`、0 unexpected。
  摘要 SHA-256 为
  `b1868137b759bc1c10cedeb64d425792ca695e1b3f2ff18bdcf04dd079158d46`。
- [output-comparison-v2/changes.tsv](../.audit/2026-10-23-native-upgrade/output-comparison-v2/changes.tsv)：
  保留原始“需审查”分类；本报告补充审查结论，不覆盖原始记录。其 SHA-256 为
  `8033d279107cc68692cd6dbc0f17e453e89f5d94356f0412a81e5c7515f06427`。

3322 是被比较的输出文件项数，不能写成 3322 个测试。本报告只闭环下面 7 个
差异的分类；后续 P2 或其他 candidate 必须绑定其自己的测试和差分证据。
旧 baseline 的 7 个失败仍是失败，不追溯改记通过；这对产物也不能直接成为正式
同输出性能对照。正式比较仍需两个均满足完整质量合同的对应基线。

## 逐例结论

以下路径的共同前缀分别为
`baseline-regression-v3/cases/main/` 和 `candidate-regression/cases/main/`，
文件均为 `CASE_ID/result.rag.json`。

| 代号 | case ID | 顶层资产数 baseline → candidate | chunk 数 | 审查结论 |
| --- | --- | --- | --- | --- |
| A | `zip_rag_zip_metadata_assets` | 0 → 1 | 1 | 有意正确性修复 |
| B | `epub_rag_epub_metadata_cover` | 0 → 1 | 3 | 有意正确性修复 |
| C | `epub_rag_epub_metadata_assets` | 0 → 1 | 3 | 有意正确性修复 |
| D | `zip_rag_zip_metadata_assets_remap` | 0 → 2 | 2 | 有意正确性修复 |
| E | `epub_rag_epub_metadata_assets_cover` | 0 → 2 | 4 | 有意正确性修复 |
| F | `zip_rag_zip_metadata_unsupported_entries` | 0 → 1 | 3 | 有意正确性修复 |
| G | `epub_rag_epub_metadata_duplicate_asset_names` | 0 → 2 | 3 | 有意正确性修复 |

重新解析了 14 个原始 RAG 文件并逐对象检查重复键，未发现重复键。没有直接把
比较器的 `without_assets` 分类当作批准，而是独立检查了全部其他字段与资产内容：

- 19 个 chunk 的正文、ID、类型、顺序、heading_path、source_refs、asset_refs
  及各自 metadata 完全相同；root metadata 和 source_map 也完全相同。
- root 的格式、解析模式、转换模式、fidelity、output mode 未改变。diagnostics
  的 trace、警告、错误、计数和其他非计时指标完全相同。
- 7 例的 stdout、stderr 分别逐字节相同。F 仍保留
  `warning: unsupported/blob.bin: Skipped: unsupported file type: bin`，
  没有隐藏不支持条目的诊断。
- 每例 baseline 与 candidate 的输入、`balance --rag` 参数相同。7 份输入和
  7 份现有 golden 的实际 SHA-256 均与双方冻结的 fingerprint 记录相符。
  golden 未更新；修复落实的是原本已经要求的图片/封面引用契约。

## 资产集合、来源和实际文件

下表每行均已核验三方一致：baseline 落盘文件、candidate 落盘文件、原始
ZIP/EPUB 对应条目的解压字节。表中路径相对于各 case 输出目录；SHA-256 是实际
文件字节哈希，不是对 JSON 描述计算的哈希。

| 代号 | asset ID | 输出路径 | 包内原始条目 | SHA-256 |
| --- | --- | --- | --- | --- |
| A | `zip:site/page.html:html-image-1` | `assets/archive/site_page.html/image01.jpg` | `site/img/img_red.jpg` | `4a79ca03d796cf716afeafcd6be6a87332ff38b77beef7279b0cb8ec6e44fce1` |
| B | `epub:OPS/images/cover.png:cover` | `assets/archive/OPS_images_cover.png/image01.png` | `OPS/images/cover.png` | `294facf567564d5117e5284141f659b6eab30e0e4d5273bf62f8f3e2c0f089e5` |
| C | `epub:OPS/chapter.xhtml:html-image-1` | `assets/archive/OPS_chapter.xhtml/image01.png` | `OPS/images/pic.png` | `b7651267937a138383ea1a04fca6ce437914a4997db3ec6d6a2aa38d0bfb1ce0` |
| D | `zip:alpha/page.html:html-image-1` | `assets/archive/alpha_page.html/image01.jpg` | `alpha/img/img_red.jpg` | `4a79ca03d796cf716afeafcd6be6a87332ff38b77beef7279b0cb8ec6e44fce1` |
| D | `zip:beta/page.html:html-image-1` | `assets/archive/beta_page.html/image01.jpg` | `beta/img/img_red.jpg` | `4a79ca03d796cf716afeafcd6be6a87332ff38b77beef7279b0cb8ec6e44fce1` |
| E | `epub:OPS/images/cover.jpg:cover` | `assets/archive/OPS_images_cover.jpg/image01.jpg` | `OPS/images/cover.jpg` | `4a79ca03d796cf716afeafcd6be6a87332ff38b77beef7279b0cb8ec6e44fce1` |
| E | `epub:OPS/chapter.xhtml:html-image-1` | `assets/archive/OPS_chapter.xhtml/image01.jpg` | `OPS/images/pic.jpg` | `4a79ca03d796cf716afeafcd6be6a87332ff38b77beef7279b0cb8ec6e44fce1` |
| F | `zip:standalone:unsupported/raw.jpg` | `assets/archive/unsupported_raw.jpg/raw.jpg` | `unsupported/raw.jpg` | `4a79ca03d796cf716afeafcd6be6a87332ff38b77beef7279b0cb8ec6e44fce1` |
| G | `epub:OPS/text/chapter-01.xhtml:html-image-1` | `assets/archive/OPS_text_chapter-01.xhtml/image01.jpg` | `OPS/text/images/pic.jpg` | `4a79ca03d796cf716afeafcd6be6a87332ff38b77beef7279b0cb8ec6e44fce1` |
| G | `epub:OPS/text/chapter-02.xhtml:html-image-1` | `assets/archive/OPS_text_chapter-02.xhtml/image01.jpg` | `OPS/text/shared/pic.jpg` | `4a79ca03d796cf716afeafcd6be6a87332ff38b77beef7279b0cb8ec6e44fce1` |

每例的 asset ID、输出路径均唯一。chunk 引用的去重 ID 集合与顶层声明集合双向
相等，10 个声明没有悬空引用或无引用的额外声明；每个声明的 source_ref 与引用它的
chunk 中对应 source_ref 完全一致。实际资产目录的文件集合与声明路径集合相等，
baseline/candidate 文件集合也相等。重名图片保留不同章节命名空间，没有相互覆盖。

这 7 例的 `source_map.asset_entries` 在两边都为空数组。本次保持它不变；引用可达
检查依据 root `assets`，不能把本结论扩大为“所有资产来源索引已补齐”。这里新增的
asset.source_ref 已与原 chunk 来源逐项对照。

## 原契约与代码依据

[验收器](../tools/regression/run_native_regression.mbtx) 对 RAG 先检查每个 chunk 的
asset_refs 都能在 root assets 中解析，再匹配外仓现有结构契约。原 golden 已要求
image_caption、对应 source/asset 引用数以及正文/章节位置。baseline 已经生成那些
chunk 和真实资产文件，却没有序列化声明，因此 7 个 dangling 失败有实际依据。

[原序列化器与当前修复](../lib/render/render_rag_json.mbt) 的代码差分显示：
direct input 原先固定输出 `"assets": []`；当前 payload 从
`context.assets` 获取同一批资产，Document 路径从 `document.assets` 获取资产，
再由共享 JSON cursor 输出。chunk 构造没有通过删除引用绕过约束。这与本次产物中
“资产文件和 chunks 早已存在，仅补 root 声明”的变化一致。
当前源码还包含后续 Sink/异步迁移，不能据此将工作目录等同于上表冻结 executable；
本次差异结论直接绑定上表二进制及实际输出指纹。

[新增 reachability 测试](../lib/render/rag_asset_reachability_test.mbt) 审阅覆盖：

- ZIP 的 remapped ID/path、声明顺序、source map 对应项、chunk 引用可达、
  Document/BlockStream 一致性和重复渲染稳定性。
- EPUB EventStream 的封面 asset ID/path、图注正文及 container/entry 来源可达性。

它们是构造型回归，不替代 935 个原契约或真实文件哈希检查。本次没有重跑这些测试；
已有 [native-debug-tests.log](../.audit/2026-10-23-native-upgrade/native-debug-tests.log)
记录当时全量 Native 单测 834/834。该历史记录不能自动证明后续异步迁移版本通过。

## 计时字段的允许排除与禁止排除

这 7 对原始 JSON 除 root assets 外，实际仅出现以下 4 个计时叶子变化：

| 代号 | 字段 | baseline → candidate |
| --- | --- | --- |
| B | `diagnostics.metrics.timing_detect_probe_ms` | `"0" → "1"` |
| C | `diagnostics.metrics.timing_pipeline_ms` | `"0" → "1"` |
| E | `diagnostics.metrics.timing_detect_probe_ms` | `"1" → "0"` |
| F | `diagnostics.metrics.timing_detect_probe_ms` | `"1" → "0"` |

允许排除的是声明的执行阶段耗时：同一精确 `diagnostics.metrics` 路径下的
`timing_detect_probe_ms`、`timing_parse_lower_ms`、`timing_pipeline_ms`、
`timing_render_ms`、`timing_total_ms`。root `stage_timings_ms` 属于 provenance 的
对应计时汇总；这 14 个 RAG 产物中没有该字段，因此未依赖这项排除。

旧比较器按 `timing_` 前缀做候选分类的范围较宽，本报告重新枚举原始结构差异，
确认没有其他字段被该规则隐藏。以下排除不能作为本次审定依据：忽略整份
diagnostics、任意 `timing_*` 新字段、root/chunk metadata、创建/修改日期、正文、
source_refs、asset_refs、数组顺序或资产字节。root assets 也只在完成本报告的
逐项内容/来源/文件核验后才被接受为正确性变化，不能形成通用忽略名单。

计时值只解释输出比较中的非确定性，不构成性能数据，不能计算本次修复的倍率。

## 原始 RAG 文件指纹

| 代号 | baseline result.rag.json SHA-256 | candidate result.rag.json SHA-256 |
| --- | --- | --- |
| A | `7fb3504e6a6fb1b2328622d6f2db762704058dd42b1a94b70627e565de499901` | `580ea2ccc5b97130347713fb2b39ce5f5711aeaf681e38012a16ac46d578eaac` |
| B | `3442fa059409b4495f095c295e797ac1ef4c5d00f1b8c02620a43a128758e113` | `60d0a6dac0c9df3e4e5df7500a51984b5c35384be1851f47d4f2a1dcf6b49fd4` |
| C | `8a6f6b39c4786a8aadf279699ae79938ca6678c5cd194b945ae8031b8fa10c42` | `a49368ab76c11ed6679957b9f9c76c267ae8060e8ba286216563be0166726415` |
| D | `dbaafdb0eaa1d71568f936f7ab9c784b389a2b0cd3faa808eff10e52aba15db4` | `d932bcb55842005c6fd9103d629cfcefaa7e2f48f7f61bae69ab5aab64cc5c89` |
| E | `2e32b2c2ac1ba4f9c0fdc6c3e0c5e963cab52508ae37b18e326c1aaf0835fbc4` | `29b4a527af47257cbb8466f250159d5c3a1ed2e11ee54865846c5737786af8ed` |
| F | `0b6ccfaa4a2c428f704d779b310afd37ef02294987637c0b51f79b79f15ea7c4` | `cd1e9e9cf22ad701e16eb198a80c402ba9f55686aa3b65c06abd16eb0185924b` |
| G | `1149732b18671910d4aaaeabab6eb22d9560e1fa638ce7ee200524e3f7804519` | `2db248791aa7abe50878ee6a0877e461cc91175ed5c835d939f32d733eca2b59` |

本次代码审查将上述 7 项归类为“已审查的有意 RAG 资产序列化修复”。它闭环 P0 的这
7 项变化分类，不改变全部 Native 升级、预算管理、Linux 验收、两窗口性能、持续负载
或精确版本安装/发布的待办状态。

