# RFC 0001: 收缩为文档文本提取，并复用社区解析库

- Status: implemented incrementally; P4-P6 remain open
- Risk: R3（公开 API、格式支持和解析器替换）
- Owners: 待指定
- 核验日期：2026-10-07（Asia/Shanghai）
- 代码基线：`6e7a7a2`，工作区原先干净，`moon.mod` 为未发布的 `0.8.0`
- 工具链：`moon 0.1.20260920 (914d7da)`、`moonx 0.1.0`；隔离探针覆盖 native 与线性内存 Wasm，不代表产品已支持双后端
- 范围：调查、实验和迁移记录；0.8 工作树已落实文本边界、flate 依赖和 Native/Wasm 目标隔离，社区解析候选仍未强行替换

## 结论

建议将产品边界定义为：**从文档中已有的文字、结构与元数据生成 Markdown、结构化结果和 RAG 输入。** 暂时移除图像 OCR、扫描 PDF OCR、音频转录。Office、EPUB、带文本层 PDF、字幕文件仍属于核心范围。

社区现在已经有可认真评估的 HTML、Markdown、XML、TOML、压缩、DOCX、XLSX、PPTX、PDF 和 MIME 库。应逐步减少自行维护通用语法与二进制解码的代码，保留本项目的文档语义、统一 IR、来源定位、资源边界、资产管理和输出契约。

“公开存在”“可以编译”“小样例通过”和“完整替换验收通过”是四个不同结论。本次尚无候选达到完整替换验收。

交付目标是支持 `moonx`，并在 Native / Wasm 上分别提供可验证的最大文本能力。采用共享 MoonBit 文本核心与后端适配层：Native 可以保留必要 FFI，Wasm 的实际依赖路径不包含不可用的 native stub。两端共享输出契约，能力差异按格式、编码和输入方式明确声明；不要求整个仓库零 C，也不以 Wasm 当前缺口限制 Native。

## 调查方法与证据

1. 阅读实际模块依赖、reader/format/API 接线、能力矩阵和依赖治理要求。
2. 执行 `moon update`，查询更新后的注册表，以未撤回版本的发布时间确定本次候选版本。网页搜索缓存显示的版本明显落后于注册表，因此版本以注册表和下载包为准。
3. 下载发布包，阅读其 README、生成接口和相关实现；对手动下载并供编译使用的归档核对注册表 SHA-256。
4. 在独立 MoonBit 模块中编译九个候选库，并用本仓库已有 DOCX/XLSX/PDF 样例及小型语义样例执行 11 项检查。
5. 没有执行完整兼容性语料、性能/RSS 基准、所有后端测试或安全审计。上游 README 的一致性测试数字是上游自述，本次没有复跑。

可复查的本地证据位于 `.audit/2026-10-07-community-packages/`（Git 忽略）：`registry-snapshot.json`、独立模块的 `moon.mod` / `moon.pkg` / `probe_test.mbt`、检查日志和 PDF 实际输出；本轮升级证据位于 `.audit/2026-10-07-upgrade/`。探针中的样例根目录为本机绝对路径，跨机器复跑需修改 `fixture()`。

首次 Moon 包下载出现超时；改用发布包直链并校验后完成编译。用户开启 VPN 后再次下载 `pdflite@0.3.8`：HTTP 200，3,503,966 字节，约 1.31 秒，SHA-256 与注册表相同。这是下载验证，不是解析性能数据。

## 建议的产品边界

| 保留 | 暂时移除 |
| --- | --- |
| TXT、CSV/TSV、JSON/JSONL、YAML、TOML、XML、HTML、Markdown | 顶层图片的 OCR 输入能力 |
| DOCX、XLSX、PPTX、ODT/ODS/ODP、EPUB、EML、受限 ZIP | PDF 栅格化、PaddleOCR、Tesseract、扫描页识字 |
| PDF 已有文本层及其结构、元数据、可导出资产 | WAV/MP3/M4A 转录、Vosk、FFmpeg 音频处理 |
| SRT/VTT、IPYNB 的既有文本输出、TeX/RST/AsciiDoc 的既有解析子集 | 模型管理、识别语言参数、provider 选择和回退 |
| 标题、表格、列表、链接、页码、来源定位、批处理、RAG | 产品为上述多模态能力启动的外部运行时 |

文档内的图片仍可作为资产保留，alt/title/caption 等已有文字仍可提取。这不要求识别图片内容。PDF 的几何信息、页码和 `BoundingBox` 也不应随着 OCR 一起删除。

扫描 PDF 必须明确诊断“没有可提取文本层，当前不支持 OCR”；混合 PDF 可提取已有文本，同时标记未能提取文字的页面。不能把只有扫描页的文件当作完整转换成功，也不能隐式调用外部工具。

`accurate` 不能全局删除：目前 DOCX/XLSX/PPTX/ODT/ODS/ODP 用它控制原生语义恢复；应先移除 PDF/图片的 OCR accurate 路由，保留 Office/ODF 的现有语义。之后可以单独讨论是否把模式名称改为更清晰的文本提取选项。

## 候选包与替换判断

以下版本为本次注册表快照，均不表示已经进入产品依赖。除另行标注外，所列主候选的注册表许可证为 Apache-2.0；`mizchi/markdown` 为 MIT。

| 领域 | 核实到的公开包 | 可以接替的实现 | 当前判断与缺口 |
| --- | --- | --- | --- |
| XML | [Milky2018/xml@0.5.0](https://mooncakes.io/docs/Milky2018/xml@0.5.0) | `internal/readers/xml` 的 tokenizer/parser，可评估供包格式共用 | 第一批候选。支持命名空间、事件/属性源范围；命名空间和拒绝外部实体引用的探针通过。其 pull 是完整读入文本后的拉取事件，不能当作增量 I/O；内部实体策略需适配现有契约。 |
| HTML | [bobzhang/html_parser@0.2.0](https://mooncakes.io/docs/bobzhang/html_parser@0.2.0)；备选 [moonbit-community/html@0.2.1](https://mooncakes.io/docs/moonbit-community/html@0.2.1) | HTML tokenizer、容错建树、实体处理 | 第一批候选。前者畸形段落恢复与源位置探针通过；继续保留本项目 ARIA、表格、figure、资产与 IR lowering。直接调用上游 HTML→Markdown 不等于保留这些语义。后者本次仅文档核验。 |
| TOML | [moonbit-community/toml@0.5.0](https://mooncakes.io/docs/moonbit-community/toml@0.5.0) | `formats/toml/toml_parser.mbt` 的语法解析 | 第一批候选。整数、日期、重复键拒绝探针通过。公开值树没有本项目逐表/逐成员行范围；需解决来源定位，并明确是否继续限定 TOML 1.0，因为候选接受部分 1.1 语法。 |
| Markdown | [moonbit-community/cmark@0.4.10](https://mooncakes.io/docs/moonbit-community/cmark@0.4.10)；[mizchi/markdown@0.8.3](https://mooncakes.io/docs/mizchi/markdown@0.8.3) | 本地 scanner 与 block/inline 语法解析 | 值得替换，先选型。cmark 的 GFM 表格/task list 探针通过，支持源位置，但发布包 `src/char/moon.pkg` 仍以 Python 生成实体表，增加消费者构建依赖。mizchi 发布源码有 CST、span 和扩展节点，本次未编译；根库及传递依赖仍需核验，不能只凭 README 选定。 |
| 压缩 / ZIP | [moonbit-community/flate@0.8.5](https://mooncakes.io/docs/moonbit-community/flate@0.8.5) | 优先替换 `bikallem/compress` 的 DEFLATE/zlib/checksum 使用；ZIP 结构层另评估 | 已能读取本仓库 DOCX 归档。现有压缩本来就是社区依赖，不应算作删除自研实现。新版库为纯 MoonBit 候选；其 ZIP `read` 会物化归档，默认 limits 无实用上限，且不校验解压内容 CRC。必须保留/移植本地路径、碰撞、CRC、大小/比例和 `read_at` 按需读取策略。 |
| DOCX | [moonbitlang/docx2html@0.6.1](https://mooncakes.io/docs/moonbitlang/docx2html@0.6.1) | OOXML/DOCX 读取、关系与文档对象构建 | 第二批候选。已有标题样例探针通过，并暴露文档树与 annotated/package reader，可映射到现有 IR。需验证脚注、批注、文本框、合并单元格、图片和原始来源映射；显式关闭 external file access。 |
| XLSX | [moonbitlang/mbtexcel@0.2.1](https://mooncakes.io/docs/moonbitlang/mbtexcel@0.2.1) | 工作簿、共享字符串、单元格、样式/批注等读取 | 第二批候选。已有多表、中英文字与 emoji 样例探针通过；提供 `ReadLimits`、Reader/bytes 输入。仍需验证稀疏大表、隐藏状态、合并单元格、公式缓存和资源限制。不要引入公式重算行为。 |
| PPTX | [t-ujiie-g/moon-pptx@0.10.1](https://mooncakes.io/docs/t-ujiie-g/moon-pptx@0.10.1) | OOXML 包、slide、notes、图表模型读取 | 第二批候选。已下载并核对公开 `Presentation::open`、slides/notes 接口；并非只有写入功能。本次未编译。需要验证文本顺序、隐藏页、notes、group、图表缓存及新的 ZIP 依赖 `hustcer/fzip`。 |
| EML/MIME | [oyjh0381/moonmime@0.3.1](https://mooncakes.io/docs/oyjh0381/moonmime@0.3.1) | RFC 5322 headers、multipart、transfer encoding、附件来源范围 | 第二批候选。已下载源码，提供 bytes 输入、递归 MIME 树和独立预算；本次未编译。严格/兼容模式与现有恢复语义不同，字符集转码、正文选择、CID、附件落盘仍需本项目适配。 |
| PDF | [moonbitlang/pdflite@0.3.8](https://mooncakes.io/docs/moonbitlang/pdflite@0.3.8) | PDF object/xref、字体、过滤器、文本读取等底层 | 可继续作为 Native 候选，含 C stub 本身不构成排除理由；当前不直接整包替换，因为 Native 探针暴露中文差异，Markdown 子包也不负责表格、图片、注释或可访问性标签。该子包排除 moonx 的线性内存 Wasm，不能直接用于 Wasm 路线；根库更窄的读取路径能否复用尚未验证。两端均先以现有 PDF 文本算法为基线。 |
| YAML | [moonbitstack/moonyaml@0.1.1](https://mooncakes.io/docs/moonbitstack/moonyaml@0.1.1)；[moonbit-community/yaml@0.0.7](https://mooncakes.io/docs/moonbit-community/yaml@0.0.7) | YAML 语法解析 | 暂不直接替换。前者多文档和 alias 探针通过，但 `<<` 被保留为普通键，不执行现有 merge 语义；Json 结果也不携带现有来源信息。后者公开范围仍是可转 JSON 的简化 YAML 子集。 |

补充筛选：`moonbit-community/XMLParser@0.2.6`、`moonbitstack/moontoml@0.1.0`、`hustcer/html2md@0.1.2`、`moonbit-community/zipc@0.2.2` 都是公开候选，但本次优先考察能返回所需结构和来源信息的接口。`kokic/cmark@0.1.1` 的注册表许可证是 AGPL-3.0，与本项目当前依赖基线不同，不列为本轮首选。`moonbit-community/NyaCSV@0.3.3` 可以进一步调查，但本地 CSV/TSV 已有 parser-pull 和输出预算，普通数组解析接口不足以证明可替换。

对 ODT/ODS/ODP、EPUB、IPYNB、TeX/RST/AsciiDoc，本次未确认能完整承接现有契约的直接替代库；这不代表社区不存在相关包。`moonods` 的公开定位是写入 ODS，`pptz` 是生成 PPTX，不能据此替换读取器。通用 ZIP/XML/HTML 库仍可减少这些格式底层的重复实现。

## 实际执行结果及含义

九个候选依赖在隔离模块中完成 native 编译：HTML、cmark、TOML、XML、flate、moonyaml、DOCX、XLSX、pdflite。最终 `moon check --target native --deny-warn` 通过。

| 检查 | 结果 |
| --- | --- |
| HTML 畸形段落恢复与 authored location | 通过 |
| TOML 整数、日期、重复键拒绝 | 通过 |
| XML namespace 和 source range | 通过 |
| XML 外部实体引用拒绝 | 通过 |
| YAML 多文档和 alias | 通过 |
| YAML merge key 差异记录 | 通过，但证明存在兼容性缺口 |
| cmark 的 GFM table / task list | 通过 |
| flate 读取现有 DOCX 的 ZIP entry | 通过 |
| docx2html 读取现有 heading fixture | 通过，仅为粗粒度提取检查 |
| mbtexcel 读取已有多表/中文/emoji fixture | 通过 |
| pdflite 读取已有中英混合 PDF 文本层 | 中文连续文本检查失败；英文文本检查通过 |

最终为 **11 项、10 通过、1 失败**。没有把失败样例改成通过，也没有把“YAML 差异被成功复现”计为行为兼容。

PDF 输入是 `samples/fixtures/contracts/pdf/text_simple.pdf`。已有预期包含 `第一段：这是一个用于验证 PDF文本抽取的样例`；候选输出包含 `第 ⼀ 段：这是 ⼀ 个 ⽤ 于验证 PDF ⽂ 本抽取的样例`，并添加 `# Page 1`。这说明它确实能提取文字，但字符归一化、字间空格、段落和页标题策略仍需本项目适配。此结论只针对这个输入，不外推为全部中文 PDF 失败。

这些探针没有比较完整 IR、所有诊断和所有资产，不是完整生产兼容性验证，也没有建立任何性能优劣结论。

## 保留的架构职责

```text
输入识别 / 字节与 Reader 预算
  -> 社区 parser / format reader
  -> 本项目 adapter + 资源策略 + 语义选择
  -> DocumentIR / 受控 pull
  -> Markdown / Debug / RAG + metadata + assets + provenance
```

不应让上游 Markdown 字符串绕过 IR 再丢失元数据、表格语义、来源、诊断和资产策略。`internal/readers/*` 已经是可替换的内部边界，可先在这里接适配器，不必重新设计公共框架或提前设计多模态插件系统。

现有 `bikallem/compress`、`bikallem/blit`、`tonyfettes/encoding` 已是社区复用。字符集库仍用于正文/PDF/RAG，移除 OCR 不构成删除它的理由。只有替换 ZIP 中全部 blit 使用后才能判断 blit 是否可删。

本次候选图解析到 `moonbitlang/async@0.22.4` 和 `moonbitlang/x@0.5.5`，产品仍固定在 `0.20.2` / `0.4.40`。隔离模块通过不代表候选已与旧产品依赖集成；尤其已有依赖登记记录了 x/fs 错误 API 迁移成本。依赖基线升级应独立、显式地验证。

## OCR/audio 移除的具体影响面

仅 `lib/formats/ocr` 和 `lib/formats/audio` 下非测试 `.mbt` 文件就有 6,522 行，计数包含注释/空行；没有包含 PDF OCR、CLI、API、测试和安装器，因此不是总删除行数估算。

实施时需要一起处理：

1. `api/types.mbt`、`api/options.mbt`、`api/adapter.mbt`：移除或按版本策略迁移 `OcrMode`、`with_ocr`、`with_audio_language`、语言字段；重新评估仅供外部命令使用的公开 limits。
2. `internal/parser`、`internal/formats/meta`、`input`、`product`、`convert`、`cli`：删除 OCR/audio 注册、格式路由、选项、探测和能力声明；旧参数必须明确报错，不能静默忽略。
3. `formats/pdf`：保留 native text 提取及来源/资产/几何模型，删除栅格化、provider、hybrid OCR 合并和 PDF accurate OCR 接线。
4. `formats/zip` / `internal/formats/zip`、`container`：取消独立图片和音频的识别子任务；不支持的 child 必须有诊断，文档已有图片仍走资产策略。
5. `tools/env`、CI 和回归矩阵：移除产品 OCR/audio 模型与系统依赖、相应测试任务；保留文本/Office 语义回归。Python MarkItDown 仍可作为测试基准，不成为产品运行依赖。
6. 能力矩阵、CLI/API 文档、依赖登记、模块关键词、迁移说明同步更新；以新 ADR 取代旧增强链决策，保留历史 benchmark 和发布记录的原始事实。

不能整目录盲删 `runtime`、async 或共享 geometry 类型；需先检查剩余 CLI、文件 I/O、取消/超时及 benchmark 用途。

注册表当前最新已发布版本为 `ZSeanYves/markitdown@0.5.3`，仓库标记 `0.8.0` 为未发布。建议在 0.8 发布前完成这一轮边界调整并明确记录相对旧版本的迁移；这不授权修改或覆盖任何已发布包。稳定 API 文档已经承诺的成员删除仍属于需要清楚说明的破坏性变更。

## 迁移顺序、回退与验收

1. **先只收缩多模态边界。** 使用现有文本读取器，验证文本输入、Office/ODF accurate、资产和 RAG 不回退；图片/音频/扫描页的行为明确。这样能独立判断删除是否引入问题。
2. **再做 XML、HTML、TOML 的单格式 adapter。** 优先复用语法解析；先解决 source span、非法输入、编码和语义差异，再决定删除本地实现。Markdown 同时完成 cmark/mizchi 选型，明确 Python 构建依赖的取舍。
3. **单独评估压缩依赖替换。** 保持现有 ZIP 读取与预算契约，对比输出限制、CRC、截断与分块行为。完整 ZIP reader 替换另立变更。
4. **DOCX/XLSX/PPTX/MIME 逐个做语义对照。** 使用已有格式 contract corpus，比较结构、来源、诊断、附件和读取预算；不以“产生了 Markdown”作为验收。
5. **PDF 先保留算法，再按后端评估 reader。** Native 可以评估含 FFI 的 pdflite 底层；Wasm 优先迁移现有算法的压缩与 I/O，也可评估真正支持线性内存 Wasm 的依赖路径。两端替换都须验证字符归一化、阅读顺序、表格、链接/元数据/资产及随机读取成本。

沿用 [依赖登记](../dependency-register.md) 已有的候选采用门槛：单独依赖变更、两轮候选双跑、语义和资源限制验证、相应 sanitizer/fuzz 证据、许可证/NOTICE/SBOM 与维护责任、可逆切换。具体检查与格式风险相称；本次探针不替代这些门槛。

适配器迁移期间保留旧实现作为回退，完成验收后再删除重复代码；每次只切换一个格式或一层依赖。多模态暂不保留空 provider 接口占位，未来有实际需求时再以独立扩展包讨论。

## 待后续实现明确的决策

- 文本能力边界采用本 RFC；Office/ODF 的模式名称是否另行简化。
- Markdown 是接受 cmark 的 Python 构建依赖、推动上游发布预生成表，还是选另一解析库。
- TOML 是否保持 1.0 严格范围，以及上游缺失 source range 时的处理办法。
- 每个格式候选的维护负责人、完整对照结果和最终采用版本。

这些是迁移中的独立决策点，不阻碍先实施多模态范围收缩。

## 双后端交付与 MoonBit/FFI 边界

### 验收口径

共享解析算法、IR、输出和资源策略优先用纯 MoonBit 实现。Native 的文件、编码或格式适配器可以保留有实际用途的 FFI，也可采用带 Native FFI 的社区包；官方库已能保持契约的地方则减少自维护 stub。Wasm 使用可编译到线性内存 Wasm 的算法和官方运行时 I/O。某个依赖在其他后端含 C，不等于它的 Wasm 路径不可用。

后端差异必须在编译依赖边界隔离。只在运行时用 `if native` 包住调用，不足以让 Wasm 避开不兼容依赖；必须核实按目标选择的源文件、导入及 package 支持范围。保留一套核心和现有 reader 适配边界，不复制两套完整格式实现。两端都移除 OCR/audio，不因 Native 可用 FFI 而恢复多模态或增加系统转换器兜底。

实查 `moonx 0.1.0 --help`：默认 `--target wasm`，也接受 `--target native`。本次已实际执行 `moonx --target native --verbose cli/rev@0.1.1 --help`，完成本机编译并运行缓存的 `.exe`，退出码 0；随后 stdin 输入 `abc` 得到 `cba`。`file` 确认产物为 macOS arm64 Mach-O。Native 路径可用，不应由默认 Wasm 推导 moonx 一律禁止 FFI。独立 `.mbtx` 则只允许 Wasm；`wasm-gc` 不在 moonx 的 target 选项中。

两条执行路径不同：Wasm 包从注册表获取预构建 `.wasm`，Native 路径下载源码、在本机构建并缓存可执行文件。因此 Native 首次调用需要相应构建工具与依赖，不能承诺其具有相同的预编译分发体验。上游 [moonx 源码](https://github.com/moonbitlang/moon/blob/0a3f0d43b228a5338417d8a569d3cdaa833e467d/crates/moon/internal/cli/moonx.rs) 与 [registry runner](https://github.com/moonbitlang/moon/blob/0a3f0d43b228a5338417d8a569d3cdaa833e467d/crates/moon/internal/cli/registry_runner.rs) 可复查该分流。

同时，[2026-09-21 官方发布说明](https://www.moonbitlang.com/updates/2026/09/21/index) 明确宣布 moonx 聚焦 Wasm、弃用 `--target native`；本机帮助中的计划移除日期为 2026-09-14，但此版本仍实际可用。交付应保留独立 Native 二进制和默认 moonx/Wasm；把当前 moonx Native 视为兼容入口，不作为 Native 唯一分发渠道。发布验收分开记录各入口及精确工具链版本。

（历史记录）当时 `moon.mod` 使用 `source = "src"`，入口和包发布尚未实现。
当前 0.8 实现已按根 `moon.pkg`/`main.mbt`、公开 `lib/`、私有
`internal/` 重构；moonx 目标仍为 `moonx ZSeanYves/markitdown@<version>`，
但精确版本的注册表消费验收必须在实际发布后单独执行。

### 每个后端的最大支持目标

以下是实施目标，不是当前产品支持声明。共享能力以完整语料对照为准；Native 的既有行为作为迁移基线。

| 能力 | Native | moonx / 线性内存 Wasm |
| --- | --- | --- |
| 纯文本、结构化文本、HTML/Markdown/XML | 保留现有语义，逐项替换成熟语法库 | 复用相同核心；多个候选已完成探针，产品接线和完整契约仍待验收 |
| Office、ODF、EPUB、MIME、ZIP | 保留现有文本/结构/附件能力；按语义收益评估社区 reader | 逐项移植相同能力，不预先删除整类格式；本次 DOCX/XLSX 小样例通过，其他格式尚不能宣称全量支持 |
| PDF 文本层 | 保留现有能力，可评估含 FFI 的 Native reader | 以现有 MoonBit PDF 算法为迁移候选；先打通压缩与随机 I/O，不承诺 pdflite/markdown 可直接使用 |
| CP932 等编码 | 保留现有 iconv 路径直到纯 MoonBit 替代通过完整对照 | 使用经验证的 MoonBit 映射；不支持的编码/字节序列明确诊断，不输出空文本或隐式替换字符 |
| 文件、stdin、原子输出、随机读取 | 可先保留已有同步/FFI 路径，避免强制改变既有 API | 官方 async I/O 正常路径已验证；需完成 API 适配、资源限制及取消/失败清理 |
| IR、Markdown、RAG、元数据、资产、来源 | 共用语义与输出契约 | 对共同支持的输入保持同一契约；缺失能力及资源上限明确报告 |
| OCR、音频转录、扫描页识字 | 移除 | 移除 |

沿用并扩展现有 `api.capabilities()`，让声明反映当前构建的格式、输入种类、模式、编码及限制，并由 CLI 暴露同源信息。共同支持的输入应比较 IR、Markdown、来源和诊断；Native 独有能力必须单独列明。遇到缺口可提示用户使用 Native 版本，但不自动启动另一个后端。不把“实现尚未迁移”描述为 Wasm 原理上不可能。

### 本地 C/FFI 现状

（历史记录）当时在 `src/` 下找到 9 个 C 文件。当前 FFI 清单以
`docs/ffi-inventory.md` 为准，产品 C stub 已集中在 `internal/` 的目标隔离包，
并由根 `main.mbt` 统一调用链。

| 用途 | 当前实现 | 后端处理方向 |
| --- | --- | --- |
| 输入文件 `read_at` / size / 生命周期 | `input/source_cursor_native_stub.c` | Native 可先保留；Wasm 接官方 `async/fs.File` 的随机读取与关闭 |
| 原子输出与 fsync | `cli/atomic_file_sink_native_stub.c` | Native 可先保留；Wasm 采用同目录排他创建临时文件、write、sync、close、rename，补齐取消/失败清理与跨平台对照 |
| stdin、stderr、退出码 | CLI 两个 C stub，`runtime/process` 的 libc exit | Native 可先保留；Wasm 可用 `async/stdio` 和已验证的公开 `x/sys.exit`，采用时确认该 API 的弃用策略 |
| CP932 fallback | `source_io/cp932_native_stub.c` 动态加载 iconv | Native 可保留；Wasm 用纯 MoonBit 字符映射库加严格错误适配，完整 CP932 对照尚未完成 |
| 外部命令与 PATH 查找 | `runtime/command` 的两个 C stub | 多模态移除后审计剩余调用，移除无用途部分；不得引入系统转换器兜底 |
| RSS/进程测量与终端探测 | `internal/bench_runner` 的两个 C stub | 保留在 Native 测量路径；独立验证 Wasm 测量办法，不能直接继承 Native 性能证据 |

基线审计中的两个 portable fallback 不能原样视为无损方案：
`input/source_cursor_portable.mbt` 会读完整文件再提供 cursor，
`cli/stdin_portable.mbt` 返回空 bytes。`cp932_portable.mbt` 的空 bytes
占位也已在迁移中替换为 `horideicom/encoding_sjis@0.1.1` 的严格适配；它
覆盖 Shift_JIS/JIS X 0208，遇到 CP932 扩展行或非法序列会报错，完整 CP932
对照仍是后续扩大 Wasm 声明前的门槛。

### 本次新增执行证据

证据保存于 `.audit/2026-10-07-moonx/`；其中 `.mbtx` 探针直接使用本机 `moonx` 执行，未添加自定义 FFI。

- `io_probe.mbtx`：在 macOS 上以默认 Wasm 实测文件 size、指定偏移读取、`CreateNew`、write、sync、替换 rename、stdin、stdout、stderr，全部成功。它验证 API 正常路径可用，不证明断电持久性或所有取消/故障路径。
- `exit_probe.mbtx`：公开 `moonbitlang/x/sys.exit(7)` 使 moonx 返回退出码 7。
- `encoding_probe.mbtx`：`horideicom/encoding_sjis@0.1.1` 将现有样例 `96 BC 91 4F` 解码为 `名前`；`0x80` 产生 replacement 标志。适配器可以据此返回错误，而不能直接输出替换字符。此项不是完整 CP932/Windows 扩展字符等价证明。
- 独立 Wasm 格式模块：移除 pdflite/markdown 后，HTML、XML、TOML、cmark、flate、moonyaml、DOCX、XLSX 八个候选的 **10 项检查通过**。其中 YAML merge 检查依然只是复现不兼容行为。Wasm 检查使用 `--deny-warn`。
- 含 pdflite/markdown 的第一次 Wasm 尝试只报告 **0 tests**，不是通过：详细日志说明 test target 只可在 native 实现。发布包 `markdown/moon.pkg` 明确仅列 `wasm-gc/js/native/llvm`。根包还列有 `pdf_clip_native.c`、`pdf_random_native.c`、`pdf_time_native.c`。

八库 Wasm 模块在 `/tmp/markitdown-moonx-NTw5Hq` 执行，源码与最终日志另存于本地 evidence 目录。不能把上述 `.mbtx` 成功称为 markitdown 的注册表二进制验收；新产品必须在未来发布后再验证精确版本的 `moonx` 调用。

Native moonx 的额外证据在 `.audit/2026-10-07-dual-backend/`。首次 `cli/rev@0.1.1` 下载因 TLS 握手失败；使用 curl 下载同一发布归档，核对注册表 SHA-256 后填入源码缓存，再执行成功。编译有五项 libtool 无符号告警，未妨碍命令执行；这不是无告警发布验收。上游源码快照和实际构建/运行日志均保留。此项证明当前 moonx 的 Native 执行链可用，不代表 markitdown 自身已通过注册表验收。

### 能保持到什么程度

**Native 的目标是保留移除多模态之后的全部既有文本能力；Wasm 的目标是逐步覆盖相同契约，并如实声明尚未支持的部分。** 不要求为了 Wasm 删除 Native 的有效实现，也不保证一次迁移即可达到两端完全一致。本次没有发现必须为了 moonx 主动删除 DOCX/XLSX/PPTX/EPUB/PDF 文本格式的理由。

不能承诺“一次全换成社区包即可无损”。为保持行为，需要继续保留现有 IR、格式语义、资源防护，以及尚无等价候选的 PDF、YAML 等算法。Native 接受 FFI 后增加了候选选择，但 PDF 中文归一化、YAML merge 和来源定位等已观察到的语义缺口仍须解决。Wasm 优先适配 I/O 和压缩依赖，不必等待所有格式解析器先被替换。

最大的架构差异是同步与异步：当前稳定 `api.convert` 和 `Input::from_reader`/`SourceCursor.read_at` 是同步接口；官方文件随机 I/O 是 async。Native 可先保留同步实现，Wasm 增加 async 文件输入/输出通路，复用 Text/Bytes 的纯计算核心；应明确各 API 的后端可用性，避免强制改变已有 Native 调用。若用整文件缓存来绕过 async，虽然可能保持文本输出，却改变峰值内存和资源契约，不属于完全无损。

性能也需要单独验收：Wasm 的内存模型、启动/预编译缓存、分配与解压行为都与 native 不同；原 native 性能数字不能直接适用于 moonx/Wasm。此轮没有测试 Windows/Linux、超大文件、取消清理、全部字符映射或完整输出等价。

Markdown 的 Python pre-build 属于源代码构建依赖，不是已发布 Wasm 二进制的运行依赖；默认 moonx/Wasm 用户不因此需要安装 Python。moonx/Native 本机源码构建则可能需要它。如果要求源码构建也不使用 Python，应要求预生成表或改选其他库。

最终迁移顺序为：**收缩多模态并冻结 Native 文本基线 → 隔离后端适配和 Native FFI → 打通根包入口、Wasm I/O 与压缩 → 按格式/编码补齐 Wasm 并发布真实能力清单 → 逐个采用通过语义对照的社区 reader。** 每步保持 Native 回归可验证。发布验收分别覆盖独立 Native、默认 moonx/Wasm 和仍受支持的 moonx/Native 入口，检查 stdout/stderr/exit code、stdin、文件和 batch、资产与来源、资源失败行为；格式清单不以“命令启动成功”来验收。
