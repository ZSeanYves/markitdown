# 音频媒体管线架构书

> 路径：`docs/architecture/audio-media-pipeline-architecture.md`
>
> 本文是 [`docs/architecture/mb-markitdown-architecture.md`](./mb-markitdown-architecture.md)
> 与
> [`docs/architecture/format-mode-and-execution-profile-architecture.md`](./format-mode-and-execution-profile-architecture.md)
> 在音频输入、媒体转写、transcript 中间层与 `media-pipeline` 专项设计上的补充文档。

建议阅读顺序：

1. 先读主架构书，理解统一主链与 `media-pipeline` 预留位。
2. 再读 mode / profile 架构书，理解 `Balanced / Accurate / Stream`、`Output View`、`probe`、`planner`、`ResolvedExecutionPlan` 的稳定语义。
3. 再读本文，理解音频输入应如何进入统一主链，而不是长成单独的语音系统旁路。
4. 最后读 [`docs/capabilities-and-limitations.md`](../capabilities-and-limitations.md)，理解当前正式支持边界。

---

## 0. 文档定位

本文是规范性扩展架构文档，不是当前能力说明书，也不是某个 ASR provider 的接入笔记。

它回答的是以下问题：

1. 音频输入在本项目中应被建模成什么样的产品能力层。
2. 音频为什么应进入独立的 `media-pipeline`，而不是伪装成现有文本或字幕路线。
3. 音频路径中的 `probe`、normalization、transcript backend、lowering、renderer 应如何分层。
4. transcript 为什么必须成为稳定中间层，而不是让 renderer 直接消费供应商原始 JSON。
5. `Balanced / Accurate / Stream` 在音频场景下应如何表达，而不与实时会话、输出视图或 provider 语义混淆。

本文明确遵守以下边界：

1. capability 文档没有把音频列为正式支持格式之前，本文不得反向宣称其已产品化。
2. 本文可以规定音频未来应如何接入正式主链，但不以当前实现状态反向收缩架构边界。
3. `srt / vtt` 作为已支持字幕文本格式，继续属于文本/字幕解析语义；音频转写能力是独立的媒体语义层。
4. 本文服务的是文件转换产品线，不是实时会话平台、会议助手平台或通用多模态代理平台。

### 0.1 产品定位

音频支持的目标不是“多识别几个扩展名”，而是补上一条与文本、包文档、分页文档、OCR 并列的正式媒体转写产品线。

它的长期定位应是：

1. 接收预录媒体文件。
2. 统一产出 metadata、transcript、segments、source refs 与 diagnostics。
3. 通过统一 renderer 投影为 Markdown、RAG、Debug。
4. 与主架构中的 route、planner、profile、provenance 契约一致。

因此，音频路径既不是：

1. “把音频喂给某个云 API，再把 JSON 原样打印出来”。
2. “把音频临时转成字幕文本，再假装它本来就是 `srt / vtt`”。
3. “在主架构之外单独长出一套语音产品栈”。

### 0.2 架构与实现的关系

本文定义音频线应如何向主架构收敛。

因此：

1. 本文是未来实现、测试、操作文档与 capability 声明的收敛标准。
2. 若当前实现尚未具备本文描述的能力，这表示待实现或待收敛，而不是本文应向实现回退。
3. 只有在产品目标、正式承诺或长期演进方向改变时，才应修订本文。

---

## 1. 设计目标

音频媒体管线必须同时满足以下目标：

1. 保持主链一致：
   音频应复用统一主链 `detect -> probe -> planner -> parser -> pipeline -> renderer`。
2. 保持 transcript-first：
   所有上层输出都应建立在统一 transcript / segment 模型上，而不是直接依赖 provider raw payload。
3. 保持可解释性：
   route、normalization、backend 选择、降级、segments 质量都必须能被 diagnostics / provenance 解释。
4. 保持 fail-closed：
   backend 缺失、空结果、不完整 segment、超限资源等情况必须显式失败或显式降级，不得伪造成功。
5. 保持与模式语义解耦：
   `Balanced / Accurate / Stream` 表达的是转换哲学，不是 provider 名称，不是字幕导出类型，也不是实时/离线二选一的别名。
6. 保持扩展空间：
   diarization、multichannel、字幕 sidecar、视频抽音轨等能力都应建立在稳定 transcript 中间层之上。

### 1.1 P0 范围

P0 应聚焦以下范围：

1. 预录单文件音频输入。
2. transcript + timestamped segments。
3. Markdown / RAG / Debug 输出视图。
4. 单语言或基础语言识别辅助。
5. 可控的 normalization 与 backend 依赖。

P0 不应承诺：

1. 实时会话转写。
2. 完整视频理解。
3. 通用音乐理解或环境声音事件识别。
4. 把 diarization 作为所有音频输入的强制前置能力。
5. 把字幕 sidecar 写成首发主输出契约。

---

## 2. 与主架构的关系

主架构书已经为媒体类格式预留：

```text
media
  -> metadata
  -> transcript optional
  -> segment IR
```

并明确媒体类格式应进入 `media-pipeline`。

本文在此基础上补充以下规则：

1. 音频应拥有独立 canonical route：
   `audio -> media-pipeline`
2. `media-pipeline` 是 route 语义，不等于某个具体 provider、某个具体模型或某个具体工具链。
3. 一旦 planner 冻结了 `media-pipeline`，后续 parser、pipeline、renderer、provenance 都只能消费该计划，不再重新决定高层策略。
4. 音频扩展不得破坏已稳定的字幕文本语义：
   `srt / vtt` 仍属于 `streaming-event` 族的文本/字幕格式，而不是“音频的另一种入口”。

### 2.1 音频与字幕的边界

本项目中需要明确区分三类对象：

1. 字幕文本文件：
   如 `srt / vtt`，其输入本体已经是时间化文本。
2. 音频媒体文件：
   如 `wav / mp3 / m4a`，其输入本体是待转写媒体。
3. 音频转写后的字幕投影：
   即从 transcript model 派生出的 sidecar `srt / vtt` 视图。

这三者的关系应是：

```text
audio file
  -> media-pipeline
  -> transcript model
  -> optional subtitle sidecar
```

而不是：

```text
audio file -> pretend subtitle text format
```

---

## 3. 市面成熟产品的共性设计

成熟语音产品通常遵循以下共性结构：

```text
audio input
  -> normalization / probe
  -> speech recognition backend
  -> transcript model
  -> optional diarization / utterance grouping / channel split
  -> render / export
```

最值得借鉴的不是某一家的 API 细节，而是以下架构原则：

1. 文件转写与实时转写分开建模。
2. transcript 是稳定中间层。
3. 时间戳是核心产品事实，不是渲染时猜出来的。
4. diarization 是附加能力，不应阻塞基础转写主链。
5. 字幕、摘要、章节、RAG chunk 都建立在 transcript 之上。

---

## 4. User Mode 与 Output View

### 4.1 Balanced

`Balanced` 是音频路径的默认策略模式。

它的契约应是：

1. 优先选择成熟、稳定、成本可控的 canonical `media-pipeline`。
2. 默认产出可靠 metadata、segment 边界与 transcript 文本。
3. 不依赖隐式重型推断、隐式远程调用或隐式昂贵模型，去换取“看起来更聪明”的结果。
4. 允许在同 mode 内，根据 probe signals 切换更合适的 normalization、execution profile 或 batching 策略。

`Balanced` 不是：

1. 最低能力模式。
2. “不带时间戳的纯文本模式”。
3. “永远不做任何 backend 增强”的模式。

### 4.2 Accurate

`Accurate` 是质量优先模式。

在音频场景下它的契约应是：

1. 仍优先保持同一 `media-pipeline` route，而不是轻易切出第二条 parser 路线。
2. 允许启用更高保真 transcript backend 配置、更细粒度词级时间戳、更强的 segment boundary 修正与更强的语言/说话人恢复。
3. 只允许进入“可解释、可验证、可回归”的增强。
4. 不应把猜测式摘要、猜测式说话人归因或不可验证的语义补全写成正式 Accurate 承诺。

### 4.3 Stream

`Stream` 是显式低峰值策略模式。

在音频场景下它的契约应是：

1. 优先选择更低峰值的 normalization、batching、segment flushing 与 render path。
2. 可以优先使用更流式友好的 transcript 组装与 chunk 输出策略。
3. 不自动等于“实时会话转写”。
4. 在没有 live ingress、session lifecycle 与稳定增量 transcript 契约之前，不应把音频 `Stream` 写成实时产品承诺。

因此音频 `Stream` 更准确的含义是：

- 离线媒体输入上的低峰值、分段友好、尽早产出策略

而不是：

- websocket / live meeting assistant

### 4.4 Output View

音频路径与其他格式一样，`RAG / Debug` 是输出视图，不是核心策略模式。

因此：

1. `Markdown`：
   人类可读的标准输出。
2. `RagJson`：
   面向 chunk、source ref、时间边界与 diagnostics 的结构化投影。
3. `DebugJson`：
   面向 probe、normalization、backend、lowering 与 provenance 的结构化投影。

同一音频输入在 `Balanced / Accurate / Stream` 下，即使都输出 `RagJson` 或 `DebugJson`，也允许得到不同结果。

---

## 5. Route、Probe 与 Planner 边界

### 5.1 Canonical Route

音频应进入独立 canonical route：

```text
audio -> media-pipeline
```

它不应伪装成：

1. `streaming-event`
2. `block-streaming`
3. `dom-ast-model`
4. `layout-two-stage`

### 5.2 ProbeOutcome

音频路径的 probe 层只负责提供证据，不负责冻结 route。

它至少应产出以下几类信息：

1. `probe_signals`：
   如 duration、sample rate、channel count、codec、container、bit rate、estimated speech density。
2. `prepared_source`：
   如已验证可读的媒体句柄、轻量 metadata handle。
3. `probe_artifacts`：
   如 cheap metadata inventory、container summary、短时采样结果。
4. `probe_failures`：
   如 probe tool 缺失、header 异常、codec 不支持、媒体信息不完整。

probe 不得：

1. 直接决定最终 backend。
2. 直接冻结 `selected_route`。
3. 自行声明 `route_reason`。
4. 在入口层实现第二套 planner。

### 5.3 Planner

planner 仍然是唯一决策者。

音频场景下，planner 至少应统一冻结以下决策：

1. 是否进入 `media-pipeline`
2. `strategy_mode`
3. `output_view`
4. normalization profile
5. transcript backend profile
6. lowering profile
7. render path / render profile
8. same-mode adaptive switches

一旦 `ResolvedExecutionPlan` 冻结完成，后续 parser、pipeline、renderer 都只能消费该计划，而不再重复做高层策略判断。

### 5.4 Same-Mode Adaptive Switch

音频路径允许的自动切换，只能发生在同一 mode 内部。

典型允许项包括：

1. 长音频切换 normalization batching 策略。
2. 长音频切换 segment flush 粒度。
3. 因资源约束切换更保守的 transcript backend profile。
4. 调整 render batching / chunk boundary 组织方式。

不允许的切换包括：

1. 因文件长自动把 `Balanced` 升级成 `Accurate`。
2. 因文件长自动把 `Stream` 解释成实时转写。
3. 在 renderer 阶段重新决定 route。

---

## 6. 输入检测与规范化

### 6.1 DetectedFormat

音频应作为独立媒体格式族进入统一检测体系，而不是借壳字幕格式或附件格式。

架构上，检测层至少应能区分：

1. `wav`
2. `mp3`
3. `m4a`
4. 未来可扩展的 `mp4/video`

### 6.2 检测顺序

音频检测应沿用统一检测原则：

```text
1. explicit format
2. magic bytes / container signature
3. MIME
4. extension
5. lightweight probe
```

其中 lightweight probe 的目标是补足 planner 所需证据，而不是提早做高层决策。

### 6.3 Normalization Backend

音频路径应显式保留 normalization 层：

```text
original audio
  -> probe
  -> optional normalize
  -> backend-ready audio
```

normalization 的正式职责至少包括：

1. 统一采样率策略
2. 统一声道策略
3. 统一容器/编码中间形态
4. 对超长媒体做可解释的分片或窗口化准备
5. 记录原始 metadata 与规范化 metadata

这里的正式契约是：

- 存在一个 normalization capability

而不是：

- 必须绑定某个具体工具名

### 6.4 超长媒体与资源限制

音频路径应和其他格式一样受资源策略约束。

对超长输入，系统可以：

1. 显式 fail closed。
2. 在同 mode 内切换更保守的 batching / windowing 策略。
3. 在 `Stream` 模式下优先选择更早 flush 的组织方式。

系统不应：

1. 无解释地截断内容。
2. 伪造“完整全文 transcript 已成功生成”。

---

## 7. Transcript Backend 抽象

### 7.1 分层模型

音频 parser 应至少分为三层：

```text
media parser
  -> probe / normalization runtime
  -> transcript backend
  -> lowering
```

这样分层的原因是：

1. probe / normalization 解决“音频能否被稳定消费”。
2. transcript backend 解决“音频被识别成什么结构化事实”。
3. lowering 解决“这些事实如何进入项目统一 IR 与 renderer 契约”。

### 7.2 Backend Contract

backend 应返回标准化 transcript 事实，而不是 provider-specific raw payload。

推荐抽象至少包括：

```text
AudioTranscriptResult
  metadata
  transcript_text
  segments
  optional words
  optional speaker labels
  optional channel labels
  diagnostics
```

backend 可分为：

1. local backend
2. remote API backend
3. mock backend for tests

### 7.3 Backend 选择策略

正式架构不应把 mode 绑死到具体 provider。

更准确的关系应是：

1. `Balanced`：
   优先成熟、成本可控、依赖面清晰的 backend profile。
2. `Accurate`：
   允许启用更高保真 backend profile 或更强后处理。
3. `Stream`：
   优先更低峰值、更早产出的 backend / batching profile。

P0 若优先支持本地 backend，这是 implementation strategy，不是架构语义本身。

真正的架构要求是：

1. backend 选择必须显式。
2. backend 缺失必须可解释。
3. 默认行为不得隐式引入不可见计费面或不可解释远程依赖。

---

## 8. Transcript 标准模型

### 8.1 为什么需要统一 Transcript Model

不同 provider 的返回风格可以差异很大，但正式产品路径至少需要统一以下信息子集：

1. 全文 transcript
2. segment / utterance
3. word timestamps
4. speaker 或 channel 信息
5. confidence

因此，媒体路径必须先定义自己的 transcript 中间模型，再做 lowering 与 render。

### 8.2 推荐模型

建议至少有三个层级：

```text
AudioTranscript
  -> metadata
  -> segments[]
  -> optional words[]
```

`segment` 至少应支持：

1. `segment_id`
2. `start_ms`
3. `end_ms`
4. `text`
5. `speaker?`
6. `channel?`
7. `confidence?`
8. `language?`

`word` 至少应支持：

1. `text`
2. `start_ms`
3. `end_ms`
4. `speaker?`
5. `channel?`
6. `confidence?`

### 8.3 Diarization 与 Multichannel

这两个概念必须分开建模：

1. `diarization`：
   解决“谁在说话”。
2. `multichannel`：
   解决“声音来自哪一路输入轨道”。

正式 transcript model 不应把二者揉成单一字段，否则会污染后续 RAG、Debug 与字幕 sidecar 的长期语义。

---

## 9. Lowering 到统一 IR

### 9.1 设计原则

音频支持不应为了首发而要求 Core IR 大重构。

P0 更合理的策略是：

1. 先复用现有 `DocumentIR / CoreBlock / DocumentMetadata / SourceRef.extra`。
2. 先把 transcript segment 作为统一文档块事实接入。
3. 待字幕、时间线 UI、speaker view 等能力稳定后，再评估是否引入专用 media block kind。

### 9.2 推荐 Lowering 形态

P0 可直接降为：

```text
Document
  Heading(file name or title)
  Paragraph(transcript intro or summary)
  Paragraph(segment 1)
  Paragraph(segment 2)
  ...
```

每个 segment block 至少应携带：

1. `start_ms`
2. `end_ms`
3. `speaker?`
4. `channel?`
5. `confidence?`

这些信息可以承载于：

1. `attrs`
2. `source_ref.extra`
3. `document metadata`

### 9.3 SourceRef 语义

对音频路径，`SourceRef` 的一等事实应当是时间边界，而不是行列位置。

也就是说，音频 segment 的核心引用面应优先是：

```text
time_start / time_end
```

而不是假装自己天然拥有文本文件那样的 line/column 语义。

### 9.4 为什么暂不引入专用 BlockKind

P0 不建议把 `TranscriptSegmentBlock` 写成前置要求。

原因是：

1. Markdown renderer 对 `Paragraph` 最成熟。
2. RAG 对“有时间边界的段落块”已经足够有用。
3. 先跑通统一主链，再决定是否需要新的长期 block 契约，更符合本项目一贯的收敛策略。

---

## 10. 渲染与输出

### 10.1 Markdown

P0 Markdown 输出应保持稳定、文本优先、时间边界清晰。

推荐投影形态：

```text
# file name

> duration: ...
> language: ...
> transcript backend: ...

## Transcript

[00:00.000 - 00:07.200] ...
[00:07.200 - 00:15.900] ...
```

Markdown 的职责是：

1. 让用户稳定读到 transcript。
2. 让关键媒体 metadata 可见。
3. 让 segment 的时间边界不丢失。

### 10.2 RagJson

RAG 输出应以 segment 作为天然 chunk 边界起点。

每个 chunk 至少应携带：

1. `start_ms`
2. `end_ms`
3. `speaker?`
4. `channel?`
5. `language?`
6. `source file`

后续若引入更强 chunking，也应建立在 transcript model 之上，而不是回头重新消费 provider raw payload。

### 10.3 DebugJson

Debug 输出至少应可观察：

1. probe metadata
2. normalization decision
3. backend identity
4. backend version if available
5. transcript segment count
6. words / speaker / channel 能力是否可用
7. degradation notes

### 10.4 字幕 Sidecar

音频转写的字幕 sidecar 是 transcript model 的一种后续投影。

它的正确关系应是：

```text
audio
  -> transcript model
  -> optional subtitle export
```

而不是：

```text
audio -> subtitle parser
```

因此，更稳妥的正式演进顺序是：

1. P0 先稳定 Markdown / RagJson / DebugJson。
2. 后续若有需要，再增加 sidecar `srt / vtt` export。
3. sidecar export 应复用统一 transcript model，而不是重跑 backend。

---

## 11. Diagnostics、Provenance 与 Fail-Closed

音频路径必须延续正式主链的 fail-closed 风格。

典型错误面包括：

1. 音频格式检测失败
2. probe 能力缺失
3. normalization 能力缺失
4. backend 未配置或不可用
5. backend 空结果
6. backend 返回不完整 segments
7. 文件超长或超出资源限制
8. 不支持的 codec / channel layout

正式 diagnostics / provenance 至少应能解释：

1. `selected_route`
2. `route_reason`
3. `route_probe_summary`
4. normalization 是否生效
5. backend identity
6. backend profile / latency if available
7. segment count
8. word timestamps 是否可用
9. speaker labels 是否可用
10. channel labels 是否可用

这意味着：

1. 音频路径不能只有 transcript 文本，没有决策解释面。
2. renderer 不能反向猜测 route、normalization 或 backend 真相。
3. 若 transcript 结果明显不完整或结构事实缺失，应显式降级或失败，而不是静默输出看似正常的正文。

---

## 12. 分阶段落地建议

### 12.1 P0

建议范围：

1. `wav`
2. `mp3`
3. 可选 `m4a`
4. 预录文件
5. transcript + timestamped segments
6. Markdown / RagJson / DebugJson

### 12.2 P1

建议范围：

1. diarization
2. multichannel
3. subtitle sidecar export
4. 更强词级时间戳与语言识别

### 12.3 P2

建议范围：

1. 实时流式转写
2. `mp4` / video 抽音轨
3. 章节、摘要、meeting note 等上层能力

这里需要强调的是：

1. P1/P2 是建立在 transcript model 稳定之后的扩展。
2. 不应在 P0 尚未稳定前，先把实时能力、会议助手能力或摘要能力写成主承诺。

---

## 13. 文档同步规则

为了不与主架构书和 capability 文档冲突，音频线必须遵守以下同步规则：

1. 本文可以描述未来 `media-pipeline` 的细节设计。
2. 主架构书继续只保留全局架构事实与高层 route 设计。
3. capability 文档只能在实现真正稳定后，才把音频写成正式支持。
4. 在 detection、planner、registry、samples、regression、diagnostics 与输出契约没有同步前，不得把音频描述为产品化能力。

---

## 14. 参考的成熟产品官方资料

以下资料仅用于提炼产品架构共性，不表示本项目将复制其 API 细节：

1. OpenAI Speech to text guide
   https://developers.openai.com/api/docs/guides/speech-to-text
2. OpenAI Realtime guide
   https://developers.openai.com/api/docs/guides/realtime
3. OpenAI `gpt-4o-transcribe-diarize` model page
   https://developers.openai.com/api/docs/models/gpt-4o-transcribe-diarize
4. Google Cloud Speech-to-Text speaker diarization
   https://docs.cloud.google.com/speech-to-text/docs/multiple-voices
5. Amazon Transcribe streaming
   https://docs.aws.amazon.com/transcribe/latest/dg/streaming.html
6. Amazon Transcribe subtitles
   https://docs.aws.amazon.com/transcribe/latest/dg/subtitles.html
7. Amazon Transcribe input/output structure
   https://docs.aws.amazon.com/transcribe/latest/dg/how-input.html
8. Azure Speech to text overview
   https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-to-text
9. Azure batch transcription overview
   https://learn.microsoft.com/en-us/azure/ai-services/speech-service/batch-transcription
10. Deepgram STT getting started
    https://developers.deepgram.com/docs/stt/getting-started
11. Deepgram utterances
    https://developers.deepgram.com/docs/utterances
12. Deepgram diarization
    https://developers.deepgram.com/docs/diarization
13. Deepgram multichannel vs diarization
    https://developers.deepgram.com/docs/multichannel-vs-diarization
