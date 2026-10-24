# Native 升级进度与未验收项

记录日期：2026-10-24（起始冻结于2026-10-23）。范围以用户计划书同步的
[完整升级计划](architecture/native-performance-plan.md) 为准；原始计划、冻结源码和
执行记录保留在本机 `.audit/2026-10-23-native-upgrade/`。

2026-10-24按用户要求清理磁盘：已结束实验的生成缓存及旧测试/Wasm产物已移除；
连同随后验收的新v8共七轮大型预算采样的27769个cases文件，经新解包逐一SHA256核对后
无损压缩，原19.53GiB变为约958MiB。源码、冻结exe、日志和摘要保留；读取旧cases路径前，按相应目录的
`CASES-ARCHIVE.md`还原。详情见本机`disk-cleanup-20261023.md`。后续Native构建串行，
阶段验收后及时清生成中间物并归档大型输出，避免继续累积展开副本。

**当前完成的是 P0 的主要质量证据、P1 基础候选的双平台 CI 与固定 Git 安装，以及
P2/P3/P4 的若干基础实现。整个升级没有完成；后续本地源码仍须独立验收，P2–P6
均未闭环。没有正式 PDF 性能收益、完整性能/持续负载 RC 或发布后交付通过结论。**

当前本地冻结为 `cache-atomic-epub-v13`：52项有序SHA guard恢复43个最终路径，
Native严格debug/release各1590/1590，info/fmt/check/build通过；标准、预算侧车、安装后
语料各935/935，实际安装和新公共库consumer通过，安装/源码3329项输出相同。
新1313项预算采样零失败；独立复核13130值、142上下文组、3100个动态maxima及见证，
1246项源码/tar/两个物理副本精确绑定。对v12原始3328equal/1unexpected的W4预算差异
已精确归因，523个资产SHA相同、28项负控拒绝；45次CLI及18项parity负控通过。
本轮补入Loaded Font/CMap复用、Atomic共享临时预算及文件末LF、None JSONL防静默丢行、
EPUB container cursor和partial_v13。用户要求本轮跨平台CI通过后合并关闭候选分支并收尾；
远程结果与合并由关联PR/工作流记录。详见
[本地v13验收及剩余项](native-upgrade-local-v13-acceptance.md)。

此前已完成本地及远程验收的候选为 `temp-loaded-presentation-v12`，提交
`f8b8f9ba9a74649f4a15cb1192ce5763ed3f4d5c`。本地严格Native debug/release各1486/1486，
info/fmt/check/build通过；标准语料、独立预算侧车、实际安装后语料各935/935，安装与源码
产物3329项输出相同。新1313项采样0失败，独立复核10504值、142上下文组、2480最大值及见证，
1228项源码与完整tar及双副本精确绑定。45实际CLI与18项parity负控通过。详见
[本地v12验收与边界](native-upgrade-local-v12-acceptance.md)。

该提交的Native CI `40081552705`、固定Git安装RC `40081624271` 均双平台成功。
Linux/macOS各自debug/release1486/1486，固定提交安装、全新公共库consumer及安装后
935/935通过。两端完整产物ZIP已下载并与服务端SHA256吻合。3329项持久化输出原始比较
为3285equal/44unexpected；逐叶复核363项变化：272个完整输入路径、84个chunk ID及
7个boundary key按同一源码双向重算，0未解释，十项篡改负控拒绝（含数字词法变化）。
报告在本机`v12-fixedgit-exact-path-review-v1/`与`v12-remote-acceptance/`。
保留原始非零比较，不把它称为跨平台字节相同。此前v9提交`2f485127`的双平台CI与
固定Git安装也通过；历史基础候选`d1a71988`的结果保留在下文，不代表当前工作树。

新一轮`partial_v11`已按51项before/proposed guard合入50个独立路径：异步输入及parser
清理、pull reader退休、共享临时账本的收紧/清理完成标记、XLSX实际row cursor及Ranged
ObjStm局部Result缓存。严格debug/release各1424/1424、info/fmt/check/release build通过；
标准/侧车/安装后语料各935/935、安装及新公共库consumer通过，安装产物与源码3329项输出
一致。对v10仅W4 schema/coverage变化，八counter和其余稳定字段/数字词法精确不变，17项
负控拒绝。新1313采样0失败，独立10504值/2488组最大值见证及1208源码/tar/双副本绑定通过。
详见[本地v11验收及边界](native-upgrade-local-v11-acceptance.md)；本候选的跨平台验收已完成。
公共临时上限/实际JSONL spool、Loaded ObjStm工作量补齐及PPTX presentation cursor
不在v11冻结，也没有继承本轮测试结论。下一v12组合已完成66项有序SHA guard、
61个独立路径的恢复；额外修复截断空白前缀导致JSONL内容被当空行丢弃的真实问题。
新组合已冻结为`temp-loaded-presentation-v12`：严格debug/release各1486/1486、
info/fmt/check/build；标准/侧车/安装后各935/935，安装与新公共库consumer通过，
源码/安装3329输出一致。新1313采样及独立10504计数/142上下文组/2480 maxima见证、
1228源码/tar/双副本绑定通过；45实际CLI与18项parity负控通过。原v11差异3328equal/1unexpected，
W4 schema/coverage及两项Loaded逻辑收费精确审查，0未解释。详见
[本地v12验收及边界](native-upgrade-local-v12-acceptance.md)；新提交跨平台验收已通过。
冻结后16次真实CLI还确认旧None pull会把超长空格前缀后的scalar/非BMP内容静默丢弃；
四次无provenance输出为空、四次collect对照及八个正控正常。下一独立修复正在执行，
不称v12已解决该继承问题。

本报告把“已实施”“某次产物已验证”和“阶段退出条件完成”分开。首次 candidate 的
935 条语料结果不覆盖随后全部 P2 编辑；历史某次全量测试通过不自动等于当前工作树
通过。以下按时间保留各次冻结，早期 `budget-empty-fixed` 曾通过完整本地检查：
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
接口与 integrated-framing 相同。已冻结 `structural-session`，标准与 partial_v4
侧车各 935/935；3324 输出相同，五项 PDF 探测/预算变化全部精确审查，0 未审定。
本地安装 v6 与全新库消费者通过，实际安装二进制另跑 935/935，对源码冻结的全部
3329 持久化输出一致。新 v4 预算采样 benchmark 378/378 与 quality 935/935 有效。
临时副本固定 Git 提交已成功检出，但安装器不识别 file:// 为 Git URL，该次实际安装
失败；该历史尝试不构成真实远程固定提交安装证据。预算 policy 明确混合工作单位和未测量范围；
预算覆盖仍不完整，P2/P3 未闭环。

随后复刻 CI 的显式 `--warn-list +73 --deny-warn`，定位并机械移除85项冗余限定名，
保留完整诊断与逐项备份；原规则现已通过，debug/release各1138/1138再次通过。
重建 Native 可执行文件 SHA 与上述冻结逐字相同，原935与采样证据仍对应同一二进制。
用户已授权将该基础冻结推送独立候选分支，供远程Linux CI及固定提交安装验收；
后续隔离候选不自动纳入该快照。

远程基础候选已按用户授权推送至 `codex/native-performance-foundation`。首次
`cb4c97b87838022928c654afb8e90eb8354cff7c` 的两平台 CI 在工具链下载阶段失败：
误将 moon 构建日期作为官方归档版本，HTTP 403；编译和测试尚未执行。修复后提交
`71d32b71713662dbd42cda437bc02ae067c97fe5` 将下载标识独立为
`0.10.17+093cb8f9c`，保留 moon `0.1.20261021` 与完整 moonc 标识校验及原 CI
门槛。官方精确归档的 macOS 17 个工具 SHA 均与本地相同，core 除本地 `_build`
以外逐文件相同。重跑 Native CI `39961132743` 的 Linux/macOS 均已全部通过：
版本校验、严格检查、接口、格式、验收脚本检查、各自 debug/release 1138/1138、
两种构建、本地安装和独立库 consumer。安装证据已上传，Linux artifact12505433984、
macOS12504404650，均绑定该完整SHA。这是基础候选的 hosted 验证，不覆盖后续本地改动。
官方历史归档声明约60日删除期限；固定标识和本次指纹不等于永久可下载承诺。

本地随后按全部 before/proposed SHA guard 集成 core/app XML cursor 13 文件及
PDF indexed stream range 18 文件，受影响302项通过；再合入小 JSON 根数组子来源6文件
及 partial_v5，冻结 `cursor-range-v5`：主仓严格检查、info/fmt、debug/release各
1177/1177，标准和预算侧车各935/935；3328输出一致，唯一W4 provenance仅schema与
coverage两个字段变化已精确审查，0未审定。v5采样378benchmark+935quality全部有效。
源码SHA `6147ee34f4b979c0648aec7ec57bb1ca54aed54242e385309a7b3bee0848acd1`，
exeSHA `8b661ac4988dcb98d369e178438d923544fd1571a5b8edd156013b389d339ad4`。
该冻结尚未推送，也没有新的安装证据，不称完整P2–P5验收。

随后 SourcePath 资产 v3 修复两处真实阻断：ENOTDIR/ELOOP/EACCES不再被当ENOENT，
空extent不构造最少1B的Buffer。独立166/166、935/935、3329equal及12次真实CLI正负控
通过。主仓10文件SHAguard恢复，execution刷新方法最小合并保留v5，统一改为待验收
partial_v6；主仓strict/info/fmt及166项受影响测试通过。随后 custom properties
10文件与嵌入字体缓存5文件均完成独立935/935及3329equal后按全部 before/proposed
SHA guard 合入，runtime 统一为 partial_v7。新主仓 debug/release 各1220/1220，显式
FD leak检查及+73严格规则通过；标准与预算侧车各935/935。新冻结
`custom-font-assets-v7` 对照v5为3328equal/1unexpected；唯一W4 provenance仅三项
policy字符串变化，八个counter及其它全部字段相同，三类负控均拒绝，0未审定。
本地安装v7及新库consumer通过（8086688B），实际安装二进制另跑935/935，全部3329项
持久化输出与源码冻结一致；新采样378benchmark+935quality共1313有效、0失败，独立
重算八维10504数值、2488个maxima及见证全部吻合，九项缺失仍未验。source inventory
有48项tar外既有文件，报告保留它们与后续工作树drift，不称整个checkout不可变。
源码SHA825a1a89e1caf6d0528cb9b2b442027fbea8b47c47c133adaa26abd1392032aa、
exeSHA39ee00ae5effb9d87345d6d6f579275d5085776b340302ee646e6aabd9c53b86；
不称完整P2–P5验收。剩余Office原archive资产需求仍在独立迁移，未包含在此冻结。

该冻结后，PPTX bounded custom projection 九文件已按完整SHAguard合入，主仓相关
119/119通过；其独立全1076/1076、935/935和3329equal绑定自己的旧custom基底，
不能代替当前主仓全测。明确保留原256候选/过滤顺序/qualified类型，完整尾部UTF8/CRC
检查；修复注释/引号/结构值，并将语法恢复限定为错误前完成的属性，详见stage报告。
它复用已有v7 custom预算单位，新增的PPTX收费须在下一冻结重新采样。
HTML单次准备最终六文件已独立1224/1224、935/935、3329equal，独立复审后6/6SHAguard
合入；原扫描/DOM/normalize入口3/2/4变为1/1/1仅是操作计数。多BOM时旧consumer
二次规范化导致byte范围偏移，已单列真实stdin对照及1/2/3/4BOM×Text/Bytes×
prepared/direct精确回归；四BOM样本由6..17修为其normalized UTF8视图的9..20。
常规935没有这个边界，故不把3329equal外推为任意输入零变化。无正式延迟或RSS结论。

PDF scalar literal成功解码复用3/3 guard已合入：隔离223/223、935/935、3329equal；
主仓相关182/182。五PDF实际decoder入口13559→9672，移除3887个相同成功解码，
15898个source/bbox叶值与五份完整stable Debug精确相等，W4八次未优化分支保留。
Hex/TJ、BOM、ActualText和失败fallback未扩展；无正式性能倍率、几何改进或P4完成结论。

几何before审计另生成五个自有PDF并实际运行Native与本地Poppler，均正常退出：
identity/translation为对照，scale/rotate/shear共同复现现有四分量matrix和文字平移
公式遗漏线性项的同一根因。报告为`pdf-affine-before-v1/review.md`，保留五份原件、
Debug、oracle及命令；文字基线原点与字体bbox、双方Y坐标约定明确区分，未把Poppler
所有box数值直接当golden。尚未修改几何生产代码，也不将此审计称作P4完成。

Office原archive资产需求portable v3十六文件也已guard合入，主仓相关116/116。独立
181/181、30次真实CLI及935/935；3317equal/12unexpected均精确限定为
asset_payload_bytes由0改为对应最终logical资产字节数，其余字段及资产hash不变。
CLI文件输出在原会话/原account关闭前补Bytes，删除path reopen fallback；库/stdout
保持MetadataOnly，typed资源5/IO6分类保留。两处测试可移植性修正及root过时注释
更新另有记录。上述四项合并已形成新冻结 `office-html-literal-v7`：主仓严格检查、
info/fmt/build通过，显式FD leak及+73的debug/release各1256/1256；标准与预算侧车
各935/935。对旧v7的原始比较为3317equal/12unexpected，单独精确审查将全部变化
限定为上述资产字节计量，0未解释。实际本地安装v8及全新公共库消费通过，安装后的
二进制另跑935/935，与源码冻结3329项输出全部相同。
新采样从独立提取的冻结源码运行：378benchmark+935quality共1313项有效、0失败；
独立重算10504个原始counter值、2488组最大值及见证全部吻合，1162项source inventory
与新提取的archive逐文件相同，0tar外文件、0drift。source_metadata最大22296B，其余
测量边界仍按partial_v7；九项缺失未验，混合ParseWork与payload模型不等于RSS或正式
性能收益。源码SHA68905ab8e9b61713456c7d15b2292aa0f975830752f78b6b0461fdaa5bd5bdbe，
exeSHAc8742c3fe83570d82ae35ee5d75c77fdf1f17df05b3b1d172a185383bb6f864a。
这些是新本地冻结的独立证据，未推送，不继承远程基础候选的平台通过结论。

后续DOCX段落cursor八文件已独立1270/1270、strict/info/fmt/release、935/935和3329equal，
经root及独立复审后8/8 SHAguard合入。普通段落与cell段落共享一次cursor，重复属性与run
发现扫描移除；保留raw lexical inline/opaque helper交接、空run索引、旧QName兼容。
注释伪tag、quoted `>`、属性实体单次解码及语法错误后仅保完成prefix四项修复有真实before
red，常规935不覆盖它们。新增工作和费用边界单列在`docx-paragraph-staging/README.md`，
该单项先行结果没有继承旧预算采样；随后纳入下述partial_v8集成的独立全测与新采样，
仍不称Office全面流式化。

JSON小文档准备三文件也已独立复审、32/32定向、strict/info/fmt/release、935/935及3329equal，
按3/3 before/ABSENT/proposed SHAguard合入。<=256000UTF16准备复用已验证事件建原有领域树，
保持重复键/数字原词法/一次decode/来源及inspect，实际normalize/stream/DOM入口2/1/1→1/1/0；
大文档、JSONL和独立DOM/profile/native API保持原路径。源码57b318028de777c928c0829a5fd06a2350efdea5cbcce8eef619f08ffc475842，
exee3b980cc934980341cba11f41e3b192e263242ecf10662eb4536ff03d70bb58f。
这是减少重复词法操作的证据，不是全JSON整合或正式性能收益。两个阶段已交付的隔离_build
随后清理，保留stage、源码、冻结exe和验收记录。

PDF单内容解释器五文件经独立复审与5/5 SHAguard合入：同一解释循环产出文字及延后处理的
图像引用，Form文字/图像资源继承差异、原四分量CTM和错误优先级均有明确合同。14项新增
合同、strict/info/fmt/release与935/935独立通过；原比较3328equal/1unexpected保留，精确审查
仅W4的模型化Working峰值增加12B，其余字段/资产相同；18768个来源/几何叶值含数字原词法
精确相同。实际内容扫描34+34→34、UTF16访问981494→490747；仅两份文件Form解压减少7734B，
不据此声称延迟或RSS目标达标。队列56B/项及容量增长重叠、scope name保留有独立计费与清理
合同，未覆盖全部lexer/页面/IR分配。已完成的292MiB隔离构建缓存清理，冻源/exe/诊断保留。

上述DOCX/JSON/PDF合并已形成`paragraph-json-content-v8`本地候选，统一使用partial_v8政策；
运行时和两验收工具已按独立before/proposed SHAguard合入，旧v1–v7工具分支逐段字节保持。
新增六个覆盖标签只描述DOCX局部cursor/选中字段与PDF待处理引用的实际计量；既有未测范围、
resident政策及数值默认值不变。新主仓strict/info/fmt/release build通过，显式FD leak及+73的
debug/release各1287/1287；新标准与独立预算侧车各935/935。原始比较3328equal/1unexpected
保留，精确审查只允许W4的schema/coverage更新及Working峰值1264895→1264907（+12B），其余
稳定字段、数字词法、资产相同；五项负控拒绝，0未解释。实际本地安装v9及新公共库consumer
通过，安装产物独立935/935、与源码冻结的3329项输出全部相同。公共façade与计划副本哈希不变。

新冻结源码SHA3fa3fd531475f41a5f9d61b2977f0f5ac4152f64b5aa35a88559c8e544b8b058、
exeSHA23e5343a69869bde93f1e685995dc34e22995d3b50b1913799a6cc4099be1e3c（8104192B）。
独立冻源的新1313采样及独立复审均通过：10504计量值、2488组最大值/见证全部吻合；实际
1171个source_file与两个独立副本及tar payload精确一致。126accepted×3view与935quality全数
执行，九项缺失仍未验。ParseWork最大355911 modeled units（新增DOCX工作覆盖），其余全局
最大值为Read47586693B、Inflate373376428B、Working373998986B、Cache8127767B、SourceMetadata
22296B、admitted=confirmed179356432B；新计量不等于性能回退或收益。报告在
`paragraph-json-content-v8-review-preparation/README.md`；旧v7/隔离通过没有自动继承。
实际安装的已完成缓存随后清理1388个生成中间文件，三个保留二进制SHA前后相同；大输出
在独立复审后进行逐文件核验的无损压缩。以上仍是本地候选阶段证据，P2–P5完整退出未完成。

后续MIME range八路径、共享typed资源五路径、PDF局部CMap四路径及v9运行时/两工具已按
21次before/ABSENT/proposed文件守卫（execution同文件分两阶段）恢复主仓，形成新本地冻结
`mime-cmap-v9`。MIME隔离39合同、32实际CLI边界控制、935/935及3329equal已过；raw owned
line/join/trim临时String移除，huge改181 compact ranges，但最终owned body仍31910415UTF16、
inspect仍两次、normalize输入累计15972656→47909962UTF16，244bounded验证chunks是新增工作，
不据此声明CPU/RSS改善或全流式。depth8/9、parts1024/1025默认不变，超限现在typed hard
exit5且无输出/资产残留，迁移说明已更新；附件decode/bytes-only/eagerinspect未扩入本slice。

局部CMap缓存只复用Ranged local Result，parent lookup/visited/depth/merge仍独立；14合同、
strict/info/fmt/release、935/935和3329equal通过，18768来源/几何叶与全部五例debug/资产精确。
真实五例Read/Inflate/Working无收益，仅Cache峰值hello3/Arabic/images增加536/4344/842B，
iw9/W4为Loaded路径不变；构造例8次共享读取/解压→1次不等于真实语料性能收益。实际C确认
key60B（packedOptionInt8常驻）、选中Entryrefs16B、Resultref8B、Info5refs40B及inner容量/String
计量；这是postparse payload，外bucket/其它bookkeeping/headers/allocator/parse/merge未测。
v9工具完整Native strict/selftest四项通过，旧v1–v8六段分支字节保持。新集成info/fmt/strict、
release build及显式FD检查、+73/deny-warn的debug/release各1316/1316通过；已结束测试缓存
随后清理，原始日志保留。冻结源码SHA为
`b2ad6acb8cd27588b48c52510376d27adfdc502662b2ba44583932e0e36dc21e`，
exeSHA为`45fb7433de513e44e896992d0a217d95079a6c63b359355f24eb5017a0612bc3`
（8122608B）。标准及独立partial_v9侧车各935/935，原比较3328equal/1unexpected保留；精确
审查仅允许W4 schema/coverage变化，全部八项counter和其它稳定字段不变，七项负控拒绝、
0未审定。实际本地安装v10及新公共库consumer通过，安装exe8122832B，另跑935/935后全部
3329输出与源码产物相同。126accepted×3view+935quality共1313项新采样已完成、0失败、
九项缺失仍未验；独立重算10504值、2488组maxima与见证全部吻合，1177实际源码文件与
完整tar及两个独立副本精确绑定，未继承v8的源码计数。结果JSON SHA为
`13efb0e8cc1947be7bff14253fcd5a6070d4ae893c73a02bf0f900bdc6d5576d`，
见`mime-cmap-v9-review-preparation/actual-review-v1/`；partial_v9仍为部分payload测量，
不是正式性能或新默认值验收。

本地全局SDK在11:17:07–08发生替换；v10首版本记录11:01:23为moon20261021/moonc093cb8f9c，
所有安装/consumer阶段11:02:56前结束，现有证据未见中途混用。初始版本记录不能代替每阶段
编译器SHA，详见`local-install-v10-toolchain-window-review.md`。11:19的新compiler对复核器
发出新增导入语法Warning96，旧失败日志保留；隔离固定093工具链下的Native负控自测和
完整review随后通过，checker源c3a603f...、exe cb135a811bf61c5b1b02d3c576342bb98c0281189229cba2e1056c051d5c7671。
该阻断不改写已冻结exe及其执行记录。新v9已以精确提交
`2f4851276791927ba87ca395806bdf63967b8006`推送独立候选分支。CI40059008133与固定Git
RC40059027636均双平台success：debug/release各1316，实际安装、新公共库consumer及各935
语料通过。新下载包、实际checkout/source-head与工具链均重新核对；跨平台原始比较保留
3285equal/44unexpected，逐叶重算363变化均来自272输入路径、84派生chunkID和7边界CRC，
0未解释，九项负控拒绝。证据见`v9-remote-acceptance/`。这些结果覆盖2f485127；主仓和计划
副本仍无完整P2–P6退出、正式延迟/RSS或发布通过结论。

随后集成的font/JSONL/TempOwner候选已通过严格检查、info/fmt、release构建和显式FD、
+73/deny-warn的debug/release各1358/1358。字体local Result缓存的独立935/935、3329equal及
五个PDF全部正文/资产/18768来源几何叶一致；Cache新增字段按实际Native布局计量，五例
精确增加460/1840/0/230/0B，Read/Inflate/Working不变。JSONL列索引复用独立935/935和
3329equal，仍有三遍读取/解析；新增索引未构成完整resident模型。临时文件leaf十九合同
覆盖短写、部分写取消后重入、关闭/删除失败及租约释放，尚未接生产消费端或公开临时限额。
新partial_v10仅扩大字体local Result postparse Cache范围，其他七scope、单位和旧默认值
不变；两验收工具Wasm/Native严格检查及完整自测均通过。新`font-jsonl-v10`冻结已实际完成
标准/侧车各935、独立本地安装与新consumer、安装产物另935及3329输出一致。新1313项
采样0失败，独立重算10504值/2488 maxima及见证全部吻合，完整tar与1188源码文件及两个
副本精确绑定；九项缺失仍未验。v9→v10原始3328equal/1unexpected保留，精确审查仅W4
schema/coverage变化，全部八counter和其它稳定字段不变，七负控拒绝。详见
`native-upgrade-local-v10-acceptance.md`；本地门槛通过后才推送本轮远端验证，不继承v9 CI。

两个已交付隔离Native缓存309MiB/237MiB及工具35.7MiB已清理，源码/exe/原始证据保留。
v10另清理1388个已结束生成中间文件，三个保留exe路径的SHA前后相同。新v9的3969个cases文件
在独立复核后完成fresh解包逐项SHA、打包前后原件及gzip完整性验证；原3033596KiB压为
147656KiB，archiveSHA为`eaa860a74ea2384ca0d21e51bc8a3e19739258af2a8e6e6beaf7e0a52703aff8`。
摘要、profile TSV和独立review保留，恢复位置见本轮`CASES-ARCHIVE.md`；不套用旧七轮结论。
用户优先清理请求
已完成：最后实测可用38GiB（初始9.6GiB），七轮27769文件经逐项SHA校验无损归档，大产物
由19.53GiB降至约958MiB归档目录（含清单；gzip本体约950MiB）；详细范围、校验和恢复命令
见disk-cleanup-20261023.md及各归档标记。

固定Git RC首次run39961420763因语料commit未在远程而失败；用户另行授权后已将原有
`eb80a4a3ccc8ca2fa6b39816789a854ba2c20d2c`推送到语料仓独立
`codex/native-performance-corpus`，六项未提交删除不变。重跑取得语料后发现RC新runner
未初始化registry，安装脚本尚未启动；保留失败日志，补`moon update`。远程产品分支
当前`d1a7198896417a2ae5f439432d2e805facdef174`仅新增两workflow四行修复；
固定该SHA的双平台RC run39964818181已通过：Linux/macOS实际固定Git安装、独立
库消费和各935项安装产物语料。归档artifact为12506243825/12505944007；本地下载
SHA核对通过。Linux executable8640968B、macOS7819744B，分别保留独立SHA，
不以体积相同代替指纹相同；没有tag、正式发布或新本地优化的远程验收。

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
| structural-session 冻结 | 新产物标准与 partial_v4 侧车各 935/935，3324 equal + 五项精确审查，0 未审定 | `structural-session-freeze.md`、`structural-session-output-review.json`；来源位置冻结为比较基线，原始 comparator 五项 unexpected 与非零退出保留；每个其它字段和资产完全相同 |
| 本地安装 v6 | moon install、CLI 与新库 consumer check/run 通过；安装二进制 7,833,856B；另跑935/935、3329输出一致 | `local-install-v6/`、`local-install-v6-regression/`、`local-install-v6-comparison/`；Mach-O arm64，系统 libSystem 依赖。安装/源码构建 SHA 独立，不互相代替 |
| 临时固定 Git 安装尝试 | clone/checkout/SHA 成功，实际 install exit255 失败 | `pinned-local-git-install-v1/`；file:// 不被当前 moon install 分类为 Git URL。只在临时源副本创建提交，主仓未提交/推送；不称真实远程固定 Git 验收通过 |
| structural-session v4 采样 | benchmark378/378、quality935/935有效，合计1313 measured/0 failures；九条缺失候选保留 | `structural-session-budget-profile-review.md`；混合ParseWork与payload模型按schema/profile独立分组；非 timing/RSS、默认值或完整预算验收 |
| CI 精确规则兼容 | +73 strict通过，debug/release各1138/1138再次通过，Native产物SHA完全相同 | `w73-ci-overlay-review.md`与`structural-session-ci-*`；仅去85个compiler精确指出的prefix，无规则放宽。原失败日志保留，新源码归档独立于原freeze |

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

冻结可执行文件与安装后可执行文件各自有独立指纹，不能互相代替。以上历史对象都是
本机单轮工程与质量证据；最新远程基础候选的双平台 CI/固定 Git 安装见前文。正式
性能窗口、完整持续负载 RC 与 P6 发布确认仍未验收。

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

## P1：Native 工具链与安装——基础候选双平台与固定 Git 安装已通过

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
- [x] 基础候选d1a71988的固定完整Git SHA真实安装、同SHA独立库消费在Linux/macOS
  通过，安装二进制分别执行935/935；run39964818181。后续本地候选须重新验证。
- [x] 基础冻结71d32b7已在Linux x86_64/macOS arm64通过完整Native CI、本地安装及
  独立consumer；run39961132743；d1a71988的run39964545691亦通过。完整性能及持续
  负载RC仍待验，后续主仓候选不继承基础候选通过。
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

公共库稳定调用的独立collect benchmark工具已建立：仅导入public lib的真实Native消费者，
五种Input构造器×两lane×一次调用的10进程开发验收通过，完整Output Eq在每次计时后检查，
保留诊断/来源/chunk/资产及数字词法。该工具单独冻结源码/依赖/编译产物和用例，严格绑定
prepared用例、校准N及两窗口的不重叠顺序，空/错/缺失metric为inconclusive。process RSS
包含oracle/校验，不称纯转换RSS；collect首次输出null、预算/阶段counter为API不可用。
工具严格检查/纯工具负控通过，正式校准与两窗口尚未运行，P5仍未验收。详见tools/regression/README。

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
