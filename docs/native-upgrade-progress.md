# Native 升级进度与未验收项

记录日期：2026-10-23。范围以用户计划书同步的
[完整升级计划](architecture/native-performance-plan.md) 为准；原始计划、冻结源码和
执行记录保留在本机 `.audit/2026-10-23-native-upgrade/`。

**当前完成的是 P0 的主要质量证据、P1 的迁移与部分安装检查，以及 P2/P3 的若干基础
实现。整个升级没有完成，P0/P1 尚有收尾验证，P2–P6 均未闭环。没有正式 PDF 优化收益、
双平台 RC 或发布后交付通过结论。**

本报告把“已实施”“某次产物已验证”和“阶段退出条件完成”分开。首次 candidate 的
935 条语料结果不覆盖随后全部 P2 编辑；历史某次全量测试通过不自动等于当前工作树
通过。最新通过完整本地正确性与安装检查的是 `budget-empty-fixed` 冻结产物：
Native debug/release 各 981/981，标准与带预算侧车语料各 935/935，本地安装 v5
及全新公共库 consumer 通过。随后 `content-types-step` 完成首个 XML cursor 生产
消费者：992/992 全仓 debug/release；预算 policy 更新后受影响 90/90、strict check、
info/fmt/build 通过；标准与侧车语料各 935/935。P4 PDF bounded decode 与容器资产
补齐没有纳入这两个冻结。随后 RAG 来源索引冻结通过 935/935、3329 equal；PDF
有界解压首个冻结产物全仓 debug/release 各 1021/1021，但标准语料仅 928/935，
7 项 PDF framing 失败保留。修复真实 Length/EOL 边界后，连同 visitor 兼容、剩余
RAG 索引、XML outline consumer/producer、TXT scalar 和 RFC 输出修复、容器资产
检查，已冻结为 `integrated-framing`：debug/release 各 1066/1066，标准与 partial_v3
侧车各 935/935；3319 输出稳定，10 项有意变化全部精确审查，未审定变化为 0。
该冻结以后新增的 SourceRef JSON 保真、JSON/XML 位置修正、关系 cursor、YAML
逻辑工作预算、PDF 结构会话/复制消除及大 JSON RAG 消费已逐项审阅并按哈希恢复；
当前主仓 debug/release 各 1138/1138，strict check、info/fmt 通过，公共 façade
接口与 integrated-framing 相同。新 Native 可执行文件、935 标准/侧车及安装检查正在
冻结执行，不能继承旧产物的 935 通过结论。预算 policy 更新为 partial_v4，明确混合
工作单位和未测量范围；预算覆盖仍不完整，P2/P3 未闭环。

## 已有证据及其边界

下列 `.audit` 路径是本机忽略目录，不是已发布的长期证据包。最终验收仍需将对应
源码、命令、摘要、指纹和失败记录一起归档。

| 项目 | 已记录结果 | 证据与解释 |
| --- | --- | --- |
| 冻结起点 | 主仓 `035d47a036e7541429113421e67256427c6b3bd7`，外仓 `eb80a4a3ccc8ca2fa6b39816789a854ba2c20d2c`；保留外仓已有改动 | `frozen-inputs/`、`source-before.tar`、`initial-lab.patch`；Git SHA 不能代替 dirty patch 与文件哈希 |
| 初始单测 | 原有 Native 测试 818/818 | `initial-tests.log`；仅为冻结起点的本地正确性证据 |
| 外仓清单 | main 515、quality 403、accurate 17，共 935；有效行全部选中 | `manifest-preflight-v3/summary.tsv`；`validated_only` 执行 0 个产品用例，不算质量通过 |
| 真实基线 | 执行 935，928 通过、7 失败，manifest errors 为 0 | `baseline-regression-v3/summary.tsv`；7 项为 RAG 资产引用不可达，不掩盖为通过 |
| 首次 candidate | 执行 935，935 通过、0 失败 | `candidate-regression/summary.tsv`；针对该次 `candidate.exe`，不是最终 P2 工作树的重验 |
| 同质量输出对照 | 3322 项稳定、7 项 RAG 资产修复、0 项 unexpected | `output-comparison-v2/summary.tsv`；只排除声明的 phase timing 字段。7 项已由[独立代码审查](native-upgrade-rag-repair-review.md)核验为有意正确性修复，不称为全部字节相同 |
| TN 2194 | 两项文字/图像及计数硬合同均在首次 candidate 中执行并通过 | `candidate-regression/cases.tsv` 的 `pdf_nist_tn2194_public_report` 及 `_counts`；`reference` 没有跳过 |
| 基础风险回归 | 围绕已复现风险的 12 项回归通过，包含有效输入对照 | `repro-zip.log`、`repro-xml.log`、`repro-ooxml.log` 与 `foundation-fixed-v2.log`；不是声称发现 12 个独立漏洞 |
| Unicode Sink | emoji 跨分片时不再拆开 surrogate pair；RAG 资产引用增加专门回归 | `repro-sink.log`、`sink-fixed.log`、`native-debug-tests.log` 及对应测试；`rag-fixed.log` 为早期编译失败记录，不计为通过；不等于所有格式端到端流式化 |
| PDF 合同文件 | 恢复两个被 38 字节错误文本替换的项目自有 PDF 原件，改为逐文件合同 | [来源登记](../samples/fixtures/PROVENANCE.md)；来源、外仓 revision 和 SHA-256 已登记，外仓输入/预期未改 |
| benchmark 清单 | 126 accepted 的实际大小/SHA 核对，9 missing candidate 明确登记，0 核对失败 | `install-preflight/benchmark-summary.tsv`；该次安装状态为 `prepared_only`，不是安装或 timing 验收 |
| P0 工程测量 | 5 个代表输入，各 3 次预热、30 次 baseline 测量，另有启动观测 | `p0-engineering-baseline/`；部分与构建并行，有 CPU 噪声。必须连同 `LIMITATIONS.md` 阅读，不能按旧 metadata 的 `controlled` 分类作正式结论 |
| 首次本地安装 | CLI 安装与 help/capabilities/转换通过；独立 consumer 编译通过 | `local-install/phases.tsv`；安装二进制 6,136,288 字节，Mach-O arm64，仅显示系统 `libSystem.B.dylib` 依赖 |
| 首次 consumer 运行 | 首轮 `consumer-run` 失败，整体安装摘要为 fail；后续 v3 已通过 | `local-install/summary.tsv`；曾错误地把 CLI 末尾换行用于库输出断言，已按两个接口的精确合同修正，未通过 trim 放宽断言；失败记录保留 |
| 单一 Registry 冻结 | Native strict check 无 warning，单测 856/856，完整语料 935/935 | `registry-summary.json`、`registry-native-tests.log`、`registry-step-regression/summary.tsv`；对应 Registry 冻结产物，不覆盖随后真正 async Input 编辑 |
| 本地安装 v3 | CLI 安装、运行及独立 consumer 均通过；安装二进制 6,333,664 字节 | `local-install-v3/summary.tsv`、`phases.tsv`；local 安装证据，不是固定 Git SHA 安装或 Linux 平台验收 |
| async Input 全仓验证 | Native 903/903；`--deny-warn` 且 `MOONBIT_ASYNC_CHECK_FD_LEAK=1` | `async-native-tests-v6.log`；本轮统一输入、raw lineage、关闭/取消及预算 leaf 等已纳入，不是所有格式全流式或 P2 完成证明 |
| async Input 严格检查与构建 | 最终 strict check、info/fmt 和 release build 完成 | `async-check-final.log`、`async-info.log`、`async-fmt.log`、`async-release-build.log`；release 构建仍有外部 `libtool: warning: 'watch_windows.o' has no symbols`，不称整个工具链零告警 |
| async Input 冻结语料 | 执行 935，935 通过，0 失败、0 manifest errors | `async-input-step-regression/summary.tsv`；绑定 `async-input-step.exe`，不是随后工作树的自动通过结论 |
| Registry → async Input 差分 | 3329 项 equal、0 项修复变化、0 项 unexpected | `async-input-comparison/summary.tsv`；使用同一比较规则排除已声明 timing 字段，不声明原始文件全部字节相同 |
| 本地安装 v4 | CLI 安装、运行及独立 consumer check/run 均通过；7,462,368 字节 | `local-install-v4/summary.tsv`、`phases.tsv`、`fingerprints.tsv`；仍为本地源码安装，未覆盖固定 Git SHA、Linux 或 registry 发布 |
| Budget leaf | 6 项累计、4 项 resident、首错锁存、lease 与快照实现；11 组边界测试通过 | `budget-zip-tests-v1.log` 的 43/43 含 Budget 11 + ZIP 32，后纳入完整测试；新生产默认值尚未冻结 |
| 生产预算部分接入 | InputSession 共用账本、source read traffic、ZIP cache/transient/visitor 与 collecting/Sink 输出接入；硬错误和 asset cap 传播有回归 | `budget-empty-fixed` 源码；未覆盖非 ZIP inflate、全格式 parse work、来源/RAG/IR、临时存储及非 ZIP resident；MeasurementOnly 不是强制生产预算通过 |
| 冻结预算步全仓 | debug/release 各 981/981，严格检查、info/fmt、release build 通过 | `budget-empty-fix-debug-tests-v2.log`、`budget-empty-fix-release-tests.log`、`budget-empty-fixed-{check,info,fmt,build}.log`；Native 外部 archive 告警与 Moon `--deny-warn` 分开记录 |
| 冻结预算步语料 | 标准 935/935，带预算 provenance 的独立一轮 935/935 | `budget-empty-fixed-regression/` 与 `budget-empty-fixed-quality-profile/`；两轮均实际运行该 Native 二进制 |
| 预算步输出审查 | 3328 equal，1 项预期新增 `budget_usage`，0 项未审定变化 | `budget-empty-fixed-comparison/` 原始结果仍为 1 unexpected；`budget-empty-fixed-provenance-review.json` 验证仅新增十个已声明字段，其余 provenance 除既有 timing 全部不变 |
| 空 CSV/TSV provenance | 预算扩展验收曾发现 SIGABRT，现修复并新增四项回归 | 旧 `budget-step-quality-profile/` 的 933/935 失败保留；`empty-provenance-abort-repro/` 保存旧命令、LLDB 和新命令；最新带侧车 935/935 才接受修复 |
| 本地安装 v5 | CLI 与新 consumer check/run 通过，安装 executable 7,523,232 字节 | `local-install-v5/summary.tsv`、`phases.tsv`、`fingerprints.tsv`；是本地源码安装，未覆盖固定 Git SHA、Linux 或 registry |
| XML cursor 原语 | 新 cursor 十项回归加既有 XML 共 24/24，已纳入 981 全测 | `xml-cursor-main-tests.log`；未接生产消费者，不称 Office/ODF/EPUB 迁移通过 |
| XML content types 首消费者 | ZIP chunk → cursor → Map；11 项分片、namespace、实体、CRC/UTF8、预算与持有期回归 | `content-types-main-{check,readers-tests,office-tests}.log`，reader 66/66、Office 格式 58/58；relationships/props 未迁移 |
| content types 冻结语料 | 标准与 partial_v2 budget 侧车各 935/935；3328 equal、仅 1 项明确计量 policy 改动 | `content-types-step-regression/`、`content-types-quality-profile/`、`content-types-comparison/`、`content-types-provenance-review.json`；原始 comparison 的 1 unexpected 保留 |
| 扩展预算采样 | v1 的 378 次 benchmark 已全部尝试，365 有效、13 不可用；quality 935 有效 | `budget-empty-fixed-budget-profile-review.md`；4 个 RAG 超时、3 个 XLSX visitor 新限额拒绝、6 个 RFC TXT 输出问题。原窗口保持失败，不填零、不入 maxima，不能冻结默认值；不是 timing/RSS 性能窗口 |
| RAG 来源索引 | TXT/generic collector 的实测 N² 签名扫描改为 2N；935/935、3329 equal/0 unexpected | `rag-source-index-regression/`、`rag-source-index-comparison/`；保留原去重规则、首个来源、顺序及 chunk ID；索引 workspace 尚未预算化 |
| TXT huge/RAG 复验 | 同一 12 MB 输入 exit0，单次观测 1521 ms、49,389,533B 输出，83,800 个非空行来源顺序全核对 | `rag-source-refs-huge-check/`；非独占窗口，没有正式 latency/RSS 倍率结论；旧 600s 超时保留 |
| XML outline/RAG 消费修复 | 旧 route 产生空 chunks；专用 consumer 的隔离 935/935、3329 equal，主仓受影响 80/80 | `xml-outline-rag-staging/`；大样本 193,124 标签/完整来源双向与顺序全核对、3295 chunks。1200 scalar peak 只指当前窗口，最终 chunks/refs 仍随输出增长；producer 已有正文遗漏另立修复，不算这一步完成 |
| XLSX visitor 兼容性 | 128MiB 是本轮对原 visitor 的新收紧；隔离 935/935、3329 equal，现已最小补丁合入 | `xlsx-huge-cap-audit/`；旧真实产物及修复正文 SHA 相同。read/transient 原默认保留；省略 visitor cap 恢复旧 declared-size/CRC 语义，共享累计预算不取消；主仓与 RAG 索引受影响合计 104/104，完整冻结仍待验 |
| 剩余 RAG 来源索引 | subtitle/table 与批次索引隔离 935/935、3329 equal，已合入主仓 | `rag-subtitle-index-staging/`；真实 SRT 全部 163,976 cues 的文字、时间与来源已独立核对；CLI SourceRef JSON 尚未序列化时间字段，完整时间值由公共 façade 检查，不隐瞒为 CLI 覆盖 |
| PDF bounded 首次语料失败 | 全仓 debug/release 各 1021/1021；冻结语料 928/935，7 项失败 | `pdf-bounded-step-regression/`；4 个输入的真实 stream Length/EOL 边界问题，不能用单测替代兼容门槛；RFC1950 校验及硬错误原则不放宽，隔离 framing 修复待审定 |
| TXT scalar 修复 | 独立 935/935、3329 equal；主仓受影响 31/31 | `txt-scalar-staging/`；UTF16 line cap 仍保留，截断只在 scalar 边界；首个排除字符后不重新接纳后续 ASCII，CR 回退恢复原 UTF16 索引。旧 Sink 是受控编码 Err，测试 unwrap 的 SIGABRT 单列，不混作生产 abort |
| RFC TXT 输出 | 独立 935/935、3329 equal；主仓 core/render 78/78 | `rfc-text-controls-staging/`；首 BlankLine 不再令全部 Markdown 丢失；完整 C0 JSON 转义保留 FF。两个 RFC 的六个 view、全部 899/3419 行与 FF 数已核对；原 v1 的六失败不覆盖 |
| XML producer 正文保留 | 独立 935/935、3329 equal，七项定向合同与 DOM outline 对照 | `xml-outline-producer-staging/`；大样本补回 35112 条正文，独立 XPath 两类各 17556 条；全部 228236 标签/来源、顺序及去 overlap 后全文核对通过。完整 token/event/chunks 数组仍驻留 |
| 容器资产验证 | 独立 935/935、3322 equal + 7 项仅 asset payload 计量修正，17 文件已合入 | `container-assets-staging/`、`container-assets-restored/`；ZIP/EPUB/nested 同会话 CRC/UTF8/asset cap，CLI 优先已验证 payload。EPUB raw route 保持；早期 33 项路由混变另存独立证据，不混入本步；SourcePath 外部 FS cap 仍未闭环 |
| integrated-framing 冻结 | debug/release 各 1066/1066，标准与 partial_v3 侧车各 935/935 | `integrated-framing-{debug,release}-tests.log`、`integrated-framing-regression/`、`integrated-framing-quality-profile/`；strict/info/fmt/build 全过，仅对应此冻结 |
| integrated-framing 差分审查 | 3319 equal + 10 已审定，0 未审定；原 raw comparator 的 10 unexpected 保留 | `integrated-framing-review.json`、`review-integrated-framing.mbtx`；7 项真实 asset_payload_bytes、1 项 partial_v3 覆盖与实际计量、hello3 阿拉伯文字及 image01 alpha 修复。PDF 数字几何保持；现有 affine/bbox 精度不足仍待 P4 |
| 新 partial_v3 预算采样 | 同一冻结二进制 benchmark 378/378、quality 侧车 935/935 有效，0 失败；9 missing 仍未验 | `integrated-framing-budget-profile-review.md`；八维 maxima 按来源/schema/profile 分组。原 v1 13 项不可用不覆盖；部分测量覆盖，不是正式 timing/RSS 窗口或默认值冻结 |
| SourceRef JSON 保真 | 独立 935/935，3303 equal + 26 项仅字段补齐；主仓受影响 613/613 | `source-ref-json-staging/`、`source-ref-json-integration/`；新增实际 page/bbox/byte/time，缺失字段不变；非有限 bbox 返回 RenderFailed，失败 Sink 不 finish。来源单位与消费者覆盖另验 |
| JSON/XML 位置单位 | 独立 935/935、3329 equal，九项新增合同及真实 CLI 全量边界核对；10 文件哈希恢复 | `source-position-staging/`、`source-position-restored/`；UTF8 lexical/decoded view 与 BOM/CRLF 规则明确，不把 UTF16 或 decoded offset 称为物理文件偏移。大 JSON RAG 缺失另步修复，原失败记录保留 |
| 关系 XML cursor | 最终独立 145/145、935/935、3329 equal；14 文件哈希恢复 | `relationships-cursor-replay-staging/`、`relationships-cursor-replay-restored/`；reader/Strict 共用 EOF+CRC 后的 raw rows；真实 DOCX/PPTX 软恢复需 error-only integrity replay，八组合不再掩盖尾部硬错误。props/Office body 未迁移 |
| YAML 逻辑工作预算 | 修正版独立 42/42、935/935、3329 equal；七文件哈希恢复 | `yaml-logical-budget-v2-staging/`、`yaml-logical-budget-v2-restored/`；别名按最终保留节点、merge 按实际复制收费。原候选误拒绝 2438B 有效文档的反例与失败产物保留；默认仍 MeasurementOnly，非完整 alias 防护验收 |
| PDF 结构会话 | 独立相关 198/198、935/935，3324 equal + 5 项精确审查；15 文件哈希恢复 | `pdf-light-probe-staging/`、`pdf-light-probe-restored/`；结构 probe 复用原 owner/account，正文分类延后；未知 Reader 与修复明确 deferred。解析仍加载完整对象集，不宣称按需对象或收益完成 |
| PDF 临时复制消除 | 独立相关 201/201、935/935、3329 equal；四文件哈希恢复 | `pdf-copy-elimination-staging/`、`pdf-copy-elimination-restored/`；搜索 Byte Arrays、byte-string 中间数组、临时 object-body/prefix Bytes 去除。五个真实 PDF 其它已记录操作同数；累计逻辑复制量不是 RSS 或耗时，范围加载尚未完成 |
| 大 JSON RAG 消费 | 独立 render 80/80、935/935、3329 equal；五路径哈希恢复含一旧文件迁移删除 | `json-list-rag-staging/`、`json-list-rag-restored/`；只消费既有 json_list_v1 完整 preview 行，复用 XML scalar window 且保留其旧 ID。9MiB BOM/CRLF 的全部1000行、328窗口、完整 refs/范围/顺序及双次 ID oracle 通过；小数组子引用问题仍单列 |
| partial_v4 验收器 | 两个独立工具 self-test 通过，旧 schema 保留严格验证 | `budget-v4-{profile,regression}-self-test-v1.log`；v4 ParseWork 为声明的混合 admission units，payload peak 不是 RSS。新主仓 quality/profile 冻结尚待执行 |
| structural-session 主仓全测 | debug/release 各 1138/1138，strict check、info/fmt 通过；公共 façade 接口相同 | `structural-session-{debug,release}-tests.log`、`structural-session-{check,info,fmt}.log`；这是新集成源码的全测，不将旧 935 或安装 v5 自动继承为通过 |

冻结基线的机器、编译器与二进制指纹分别见 `frozen-inputs/machine.txt`、
`frozen-inputs/toolchain.txt`、回归 `fingerprints.tsv`。旧 HTML/Markdown/XLSX 不同
输入或不同提取量的比较，以及 fake runner 结果，均不进入同质量倍率结论。

本轮指纹绑定如下。主仓 Git HEAD 仍为
`035d47a036e7541429113421e67256427c6b3bd7`，实际变更须连同
`async-input-step.patch` 和源码归档读取；不能将旧 HEAD 当作已包含迁移的 Git 候选。

| 对象 | SHA-256 |
| --- | --- |
| `async-input-source.tar` | `ee4050452c0d0e78c8fa075d7b781d48e7a87a7a2f7ab4411b8e85441c635c18` |
| `async-input-step.exe` | `3d28113945301effc44d4b1e04cd80d6fded895e10d165af38d7cdd0f0e431d9` |
| `async-native-tests-v6.log` | `df47641c90c352a06b2594431ff34f7825387447b550f7a5f078a7d9a8052be5` |
| `async-input-step-regression/summary.tsv` | `b5733b544fbb32fb56dddd19cd1d2ea856c7b9ffd5f5d303b0135f17690309ae` |
| `async-input-comparison/summary.tsv` | `a1749119ad8b68686b221140de5f642757bdf2867e856e2821452d9904d9a27a` |
| `local-install-v4/summary.tsv` | `41ea7b52675d4416d219ce9b72d25aad1b9677e49ae7b902684cbb31d1249bf4` |
| v4 安装的 `install/bin/markitdown` | `d1df32578f1cf3888d64b3cada20ee661e7eabcfb2dd4b731da0baffd27fcce9` |

冻结可执行文件与安装后可执行文件各自有独立指纹，不能互相代替。以上都是本机单轮
工程与质量证据；正式性能窗口、双平台 RC、固定 Git 安装和 P6 发布确认仍未验收。

最新预算步 executable SHA-256 为
`9a3c44c201743323cfe9936cda8ee688a8030bc8e69a50f2115a7ee82abac6fb`；
源码归档和验收工具修正后的 v2 归档分别保留独立文件及 SHA 侧车，不能覆盖原件。
v5 安装 executable 为
`21782d380de8cfd04eb3dd12a829b3d5b71333a80c1c4e56f1e572b01f9e5db0`。
输出预算测试曾因两轮 phase timing 不同失败（979/980），现只规范化三个已登记
timing 字段，并按各次实际 UTF8 输出计量；保留原失败与修复后的 981/981 记录。

## P0：证据与合同冻结——主要质量证据已建立，退出条件未全部验收

- [x] 保留主仓/外仓 revision、dirty state、源码与真实 Native 基线二进制；没有
  覆盖外仓已有工作。
- [x] 修复真实 Native 验收入口，清单在筛选前校验；记录 total、retired、valid、
  filtered、selected、executed、passed、failed 和 manifest errors。缺文件、重复 ID、
  未知非空字段/信号、非法行、无选中用例均失败；已知 schema 空尾列正规化单独记录。
- [x] 全部已有有效合同执行，包含 `reference` 行；预期拒绝必须有退出码及明确错误
  信号。RAG 使用结构断言，正文、Debug、provenance、stdout、stderr 分开匹配。
- [x] 每次新建输出目录，保存失败摘要、命令、完整输出、资产集合/哈希和引用可达性。
  真实基线 7 项失败及首次 candidate 的修复变化没有被隐藏。
- [x] PDF 从“10 个成功 8 个”改为逐文件成功/明确拒绝合同；恢复损坏的项目自有
  fixture 并登记来源；TN 2194 硬合同保留。
- [x] 建立首次 candidate 935/935 和 3322 稳定输出 + 7 项 RAG 修复的差分证据。
- [x] 核对 benchmark 126 accepted/9 missing candidate 的实际文件状态和哈希。
- [ ] 对所有随后 P2 改动重建最终产物，重新执行完整语料与差分，固定新候选指纹。
- [x] 对 7 项 RAG 修复独立核验：19 个 chunk 及来源/引用不变，10 个资产声明与原包
  文件哈希一致；审查报告绑定两次产物、14 个输出及比较摘要的 SHA。外仓 golden 未改，
  历史 baseline 仍保留 7 个失败；这不代表最终所有后续修改均已验收。
- [ ] 建立可用于正式比较的无构建争用基线。已有工程 raw 数据只用于观察，不满足
  两个独立、同质量、baseline/candidate 交错窗口的要求。

## P1：Native 工具链与安装——迁移已实施，安装/平台闭环未完成

- [x] 主模块默认/支持 Native，根及 `lib`/`internal` 产品包限定 Native；删除产品
  Wasm/JavaScript 分支、portable adapters 和未用的 `horideicom/encoding_sjis`。
- [x] 保留薄根 `main.mbt`、公共 `lib`、私有 `internal`；没有引入第二条转换链。
- [x] 固定 MoonBit `0.1.20261021` / `moonc v0.10.17+093cb8f9c`；保留 exact
  `async@0.22.4`、`x@0.5.5`、`flate@0.8.5`，迁移旧 manifest/编译器不兼容处，
  工具链变化与语义修复分别记录。
- [x] CLI 文档与入口改为 `moon install`；更新 Native 能力、迁移、依赖/FFI 清单及
  [ADR 0008](adr/0008-native-only-delivery-and-acceptance.md)。历史决策保留 supersession 指针。
- [x] CI 配置双平台 Native check/info/fmt、debug/release test/build、安装和独立库
  consumer；保留 `MoonBit core (ubuntu-24.04)` / `(macos-15)` required-check 名称。
  YAML 检查通过不代表 hosted job 已执行。
- [x] 首次本地 CLI 确实由 `moon install` 安装，独立 Native consumer 确实编译。
- [x] 本地安装 v3 的 CLI + consumer 精确运行断言及完整成功摘要通过；首轮失败
  记录保留。6,333,664 字节仅属于该冻结产物，不作为后续最终候选体积。
- [x] async Input 冻结后的本地安装 v4 与独立 consumer 通过；该次安装产物为
  7,462,368 字节，保留外部 native archive 的 `watch_windows.o` 无符号构建告警。
- [ ] 固定完整 Git SHA 的真实安装和绑定同 SHA 的独立库消费。
- [ ] Linux x86_64 和 macOS arm64 各自完成全部安装/编译消费验证。当前只有本地
  macOS 证据；Linux Docker daemon 不存在，未据此产生 Linux 通过记录，hosted CI 未验收。
- [ ] 检查安装后 executable/依赖及最终发布归档的体积与内容；实验、外部语料、调试
  产物不进入发布包。保留最小 FFI 必要性、所有权、传递依赖和移除条件。

## P2：单一执行与预算基座——若干边界已实施，整体仍在迁移

- [x] 增加公共异步 `convert_to_sink`、façade 自有 `OutputSink` 和不含完整正文的摘要；
  Markdown、Debug、RAG 的 Sink 路径使用异步写入/完成回调，JSON 收集与 Sink 共用 cursor。
- [x] 现有 Sink Unicode 分片修复；RAG 顶层资产与 chunk 引用保持可达，没有靠删除资产
  引用获取通过。
- [x] 增加 InputSession：Path cursor 在转换退出时显式关闭，复用同会话文件，调用方
  Reader 所有权不转移；读失败锁存，阻止探测/恢复吞掉硬读取错误后继续成功。
- [x] `parse_result_to_ir_input` 对缺失或冲突形状返回错误，恰好一种形状才接受；
  pipeline/child 路径传播错误，相关生产 `abort` 改为可返回错误，没有空文档 fallback。
  PDF 内置常量解包与测试辅助的 abort 未当作本次外部输入问题修改。
- [x] 单一异步 Registry 迁移及嵌套 child 链已完成冻结验证：只保留 ParserRegistry、
  async parse/open/next/finish，旧注册协议与同步投影删除；856/856 单测、935/935 语料
  和本地安装 v3 通过。该结论不扩大为完整异步输入或 P2 阶段完成。
- [x] 删除 `normalize_async_reader_source` 的整份输入物化，Path、Bytes、Text、
  同步/异步 Reader 共用单一 async cursor 协议；同步 Reader 只作 callback 适配。
  扫描、解码及语义计算保持同步；格式自身的整份 prepare 并未全部消除。
- [x] 原始 input byte extent 与 prepared UTF8 表示分开：可信 decode/materialize
  适配保留 physical lineage，cursor offsets/size 仍指当前表示；精确 raw 上限的
  Latin1 XML、Reader 短读及较小原始上限拒绝已有回归，手工替换 payload 不能伪造证明。
- [x] 实现无 I/O 的 `internal/resource_budget` leaf，含显式 Enforced/MeasurementOnly、
  6 项累计和 4 项 resident、首错、幂等 lease、close/快照及 11 组边界测试；不新增
  未测生产默认数值。InputSession、source read traffic、ZIP 与输出已有部分生产接入。
- [x] ZIP cache/transient/visitor 共用增量实现、完整性与实际产出计量；缓存命中仍
  检查当前较小 cap。bare Bytes 可能逃逸，resident lease 保守保留至会话结束，
  没有把删 Map key 伪装成已释放借用；尚未实现 LRU 与全部格式 resident 覆盖。
- [x] 收集与 Sink 使用同一输出路径，区分 admitted 和成功确认的 UTF8 bytes；失败
  chunk 不退款，承认 callback 不提供实际部分提交数。provenance 明列未计量维度。
- [x] CRC、非法编码、资源上限首错在会话锁存，经过 Office/ODF 可选 part 与嵌套
  文档传播；六种 Office/ODF asset 小上限有回归。任意 SourcePath 资产及所有嵌套
  资产分配前的全局 admission 仍需补齐。
- [ ] 完成分块短读、明确 EOF/I/O、读取/解析入口/pull/Sink 的取消及背压协议，保持
  扫描、解码和语义计算同步；所有硬错误直接终止，只有明确可恢复语法可修复并诊断。
- [ ] 集中登记解压、token/嵌套/对象/页面工作量、输出、文档缓存、临时文件及
  source/asset/RAG 元数据预算；默认上限不得为性能而放宽，缓存命中仍扣当前请求预算。
- [ ] 完成文档内缓存容量、键、所有权、淘汰和失败缓存；不建设全局用户文档缓存。
- [ ] 跨页/跨记录语义使用有界摘要或受限临时文件；正常、取消、读/写失败均清理。
- [ ] Sink 不额外保留完整输出，收集 API 允许随最终输出增长；消除 event/block/IR/
  renderer 多份完整表示的无谓共存，保持资产、来源、RAG 顺序稳定。
- [ ] 保真策略与交付方式分离，保持 balance/accurate/stream 语义；领域错误、退出
  分类、能力登记、CLI 帮助、文档及接口 golden 一致。
- [x] 本轮真正 async Input 冻结完成全仓 903/903、935/935 语料、3329 equal 差分
  及 local install v4。该冻结后的新消费端与完整 P2 仍须再次全量验证。

真正 async Input 已完成这一轮跨包冻结：读取函数保留原名升为 async，统一 cursor，
移除整份 AsyncReader normalization，SourceIO、文本 pull、树 prepare、ZIP/Office
和 PDF 调用链已通过上述全仓验证。公共库 Reader/Sink 回归覆盖大 TXT 首次输出前
未读完整输入、写等待时停止读取、短读跨字符/BOM/CRLF 和读取取消。它们不证明所有
格式端到端流式化；完整生产预算、缓存淘汰及 P3 消费者迁移仍是未验收项。

## P3：公共解析与格式迁移——局部正确性修复，完整迁移未验收

首个 content-types 消费者已完成独立冻结，ZIP CRC 与 XML EOF 成功前不发布 Map，
不再构造该 part 的整份 bytes/text/DOM 缓存。Map payload 的 lease 保留至转换 scope
结束，visitor 的 owned Bytes 仍可能逃逸，因此 Working 仍为保守 scope 上界；这一步
没有解决所有缓存生命周期或冻结新的 XML 数值默认值。`partial_v2` 计量政策使用通用
resident 名称，并明确 XML work/source metadata 只覆盖 content types。

该冻结 binary SHA 为
`ce78bf279d2de1f71be3e869d7c3c555e0b8e6e9778fd24a82d8d978849ed67e`，
source tar SHA 为
`73b33f9b179b7c46b22445f6fade537d57528625efab948e58c72753d540c2a7`；
935 语料稳定不等于 relationships、Office 语义 XML、ODF/EPUB 和独立 XML 均已迁移。

已经修复并加入回归的是：ZIP cache 命中仍遵守较小当前预算；XML 十进制/十六进制
数值实体溢出与 Unicode scalar 校验；OOXML 非法 UTF-8 拒绝、非 BMP 文本/属性/part
路径及 core/custom metadata 的位置和错误传播。12 项回归包括正向对照，未扩大为
“所有编码/所有 XML 消费者已迁移”的结论。

完整待办保留如下：

- [ ] 增量字符解码只保留未完成字符，统一原始 byte、UTF-16、行列位置单位；覆盖
  当前承诺编码，减少重复打开及 bytes/string 转换，不默认引入 mmap。
- [ ] ZIP/DEFLATE 所有 cache/transient/visitor 路径统一完整性和预算；中央目录及
  规范路径只索引一次，保留 CRC、碰撞、条目数、比例和按需读取。
- [ ] 建立私有、可暂停、有深度限制的 XML token cursor，涵盖必要 namespace、属性、
  混合文本和来源；按包元数据/关系 → Office → ODF/EPUB → 独立 XML 顺序迁移。
- [ ] 去除重复 XML tokenization/DOM 和 HTML prepare 解析；同扫描产出统计，修复
  引号内 `>`、实体单次解码、前缀重绑定。HTML 维持受控恢复，不引入浏览器排版。
- [ ] Markdown delimiter/嵌套/异常输入改进保持现有 CommonMark/GFM 风格及脚注/
  frontmatter 合同；JSON 合并重复验证/数字扫描，保留数字词法、键顺序和重复键策略。
- [ ] JSONL 复用列索引与读取；YAML alias/merge 预算覆盖逻辑展开；TOML 保留表/键
  索引并减少切片/解码分配。不同语言不共享通用 AST。
- [ ] Office/ODF/EPUB 复用 ZIP/XML/路径/关系索引，减少 bytes/text/DOM 重复驻留；
  XLSX 按 worksheet/row、ODF 受限重复行列、EPUB 按 spine/chapter 消费并释放。
- [ ] 保留合并单元格、公式缓存值、隐藏策略、notes/comments、链接、图像、来源；
  不增加公式重算、宏或文档编辑器。
- [ ] MIME 改用 bytes range/边界扫描，按需解码附件；预算错误不得 raw fallback。
  IPYNB、字幕、CSV/TSV、TeX/RST/AsciiDoc 复用已验证原语且保留格式边界/时间信息。
- [ ] 公共原语至少有两个真实消费者或一个实测热点；算法移植记录来源、revision、
  许可证、涉及片段和测试，社区参考不自动扩大标准支持范围。
- [ ] 每项迁移独立差分验收后再测性能、删除冗余；旧实现只在冻结证据中保留。

## P4：PDF 与算法优化——审计及逐文件门槛已做，优化实现/收益未验收

有界 zlib adapter 已完成 142/142 相关测试和父 ZIP 硬错误锁存回归，
确切来源/许可证、25 个 scoped 文件及恢复检查在 `pdf-bounded-staging/`。主仓首轮
全仓 debug/release 各 1021/1021 后，首个冻结语料只有 928/935；7 项失败来自四个输入的
stream 长度/换行边界，该失败产物不计为接受。后续修复解析真实 Length/raw span，
保留严格 Adler32 与首预算错误；只有源 CR/LF framing 的 Truncated/TrailingData 才
尝试有限边界，校验失败终止，重复解压按实际产出扣账。`integrated-framing` 已通过
上述 1066 全测、两轮 935 和全部差分审查；hello3 文字与 image01 alpha 有意变化有
独立 Poppler/像素 oracle，不能将几何数字保持当作 font-tight geometry 正确。
该层只测 PDF Flate 的实际产出、模型化 scratch/retained Bytes；其它 filters、
predictor、bytes/string、token/page/IR 仍不完整，不宣布 P2/P4 完成或 PDF 性能收益。

随后轻量 probe/session 已独立验证并恢复主仓：路由前不再完整解释文档，header、
xref、Catalog/page-tree 的必要事实与解析复用同一输入 owner/account。Unknown-size
Reader 与普通修复明确 deferred，不猜测文本页；完成分类在真正 parse 成功后记录。
W4 的普通 xref 修复仍会重复 42B 解压，实际产出再次收费；没有从该单例声称性能改善。
该候选仍待新的主仓完整集成冻结。按需对象、重复解释/解码、字体/CMap 及页面生命周期
仍需按依赖顺序解决。没有 PDF 延迟降低 50% 或 RSS 降低 30% 的实测声明。

- [ ] 轻量 header/xref/catalog/page-tree probe，返回可复用会话，移除路由前完整提取。
- [ ] xref 保留 offset/generation/ObjStm index，从可达页面/资源按需访问；stream
  保存范围，ObjStm 解压按文档预算缓存，减少反复 bytes/string 转换。
- [ ] 内容、CMap、字体、ObjStm 有界增量解压；token/嵌套/对象/页面/图形栈/Form
  深度与修复扫描工作量上限，I/O/取消/超限不宽松回退。
- [ ] 单内容解释同时生成文字、图片引用、marked content；文字一次解码同时得到字符、
  advance 和诊断；annotation 一次解析后派生链接。
- [ ] 字体、ToUnicode、CMap、ObjStm 按对象身份和参数复用，缓存成功/失败；不跨文档。
- [ ] 逐页进入同一 lowering/pipeline 后释放流/fragment；跨页页眉页脚用受限事实或
  临时存储，避免完整页面模型和完整 IR 同时驻留。
- [ ] 六元仿射矩阵、旋转、CropBox/继承页面框、glyph advance、阅读顺序、链接关联和
  简单表格修复；保留 CJK、垂直文字、ActualText、图像及 Unicode 校验。
- [ ] 每一步保留 profile、同质量差分和阶段性能；参考算法记录准确来源/许可证，
  Poppler/PDFium 仅作离线对照，不引入第二条转换链或 PDF 渲染器。

## P5：完整 RC——未验收

- [ ] P2–P4 退出条件完成后，对最终候选执行全部日常/样例/935 有效合同和输出差分，
  零新增质量失败；正确性变化分类、审定并说明 golden 更新原因。
- [ ] Linux x86_64/macOS arm64 的 Native debug/release、接口及适用 coverage、mutation、
  sanitizer/fuzz 门槛完成；工具不可用必须标为未验收。
- [ ] 安装/构建成本、安装后 CLI 启动/单文件/batch、公共库稳定调用和阶段热点分别
  测量。小输入增加库内批量，避免计时分辨率失真。
- [ ] **两个独立窗口，每组 3 次预热、30 次测量，baseline/candidate 交错**；固定
  输入、模式、限额、资产、输出目标，记录逐例 p50/p95、峰值 RSS、CPU、首次输出、
  吞吐、安装体积、机器和编译指纹；不能使用已有噪声工程 raw 数据宣称正式通过。
- [ ] 同指纹逐例延迟/RSS 不超过 10% 回退，不用整体平均掩盖；安装体积增加对应能力
  收益，工具链升级独立基线；PDF 目标延迟 -50%/RSS -30% 未达时如实记录。
- [ ] 数据不足或波动过大标为结论不足；外部库只是参考，差异按合同/规范/人工审定。
- [ ] 覆盖 Path/Text/Bytes/同步及异步 Reader、stdin、单文件、serial batch、收集/
  Sink；覆盖短读、提前 EOF、取消、写失败、cache budget、解压炸弹、深度、循环引用、
  损坏结构、临时文件清理，不以 façade smoke 代替全量回归。
- [ ] 双平台各持续 60 分钟混合负载及 1/2/4 个独立转换进程；RSS、FD、临时文件
  不随已处理文档数持续增长，不新增通用线程池或常驻 worker。
- [ ] 独立安装/库消费完成；能力/迁移/接口/回退说明与最终源码一致，发布归档剔除
  实验/语料/调试数据，完整证据和 FFI/依赖清单可复现。

## P6：发布后确认——未执行

- [ ] 正式发布单独执行，不把当前优化任务或本地 candidate 结果当作已发布。
- [ ] 精确版本 `moon install` 在全新目录完成，保留安装产物和依赖哈希。
- [ ] 全新独立项目消费同一精确版本公共 Native 库，不含本地 override；双平台确认。
- [ ] 发布包内容/哈希与已验收 candidate 一致，回退版本及操作记录完整。
- [ ] 只有 P5 完整通过才称“候选验收通过”；P6 精确版本安装/库消费确认后才称
  “正式交付通过”。

## 紧接着的验证顺序

1. 保留已冻结的 Registry 与 async Input 源码、产物、安装和差分证据；后续预算、
   CRC/encoding hook 每轮编辑后串行运行相应 strict Native 检查、测试及接口/格式检查，
   再冻结新产物，不把已通过数字自动继承给新工作树。
2. 完成共享预算的最小生产接入、profile 与默认值依据，至少覆盖 ZIP 和 Sink 两个
   真实消费者；保留 local install v4，通过新候选再次重装、语料与差分后，再落实固定
   Git SHA 安装/独立消费。MeasurementOnly 结果不等于 enforced 预算通过。
3. 按 P2→P3→P4 保留最小实现、回归和阶段 profile；基础接口未冻结前不宣称 PDF
   生命周期/性能工作已完成。
4. 获得可执行 Linux 环境和 hosted CI 后落实 P5 两平台、正式性能/可靠性；再单独
   进入 P6 发布及发布后确认。本报告不删除任何后续退出条件。
