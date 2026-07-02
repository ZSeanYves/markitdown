# mb-markitdown 音频媒体管线架构草案

> 建议路径：`docs/architecture/audio-media-pipeline-architecture.md`  
> 文档状态：扩展架构草案，不代表当前已产品化能力  
> 主文档关系：本文件补充 `docs/architecture/mb-markitdown-architecture.md` 中的 `media-pipeline` 设计位，不改写当前主架构事实，不覆盖 capability 文档中的正式支持边界。

---

## 0. 文档定位

本文件描述 `mb-markitdown` 若要新增音频输入支持，应如何在不破坏现有主架构的前提下，引入一条独立的 `media-pipeline`。

本文件明确遵守以下边界：

1. 当前仓库尚未正式支持音频输入。
2. 当前 capability 文档未把音频列为已支持格式，本文件不得反向宣称“已落地”。
3. 主架构书中已经预留 `media-pipeline` 与 `mp3 / wav / m4a / mp4` 的设计位置；本文件只负责把这一扩展路线写细，不改写主架构书里的当前实现事实。
4. 当前 `ParserMode::MediaPipeline` 已存在于 parser 抽象中，但 route planner、format detector、registry、format parser 尚未把音频接成正式产品路径。

因此，这是一份“与现有架构兼容的音频扩展设计书”，不是“当前能力说明书”。

---

## 1. 设计目标

音频支持的目标不是“再多支持几个扩展名”，而是补上一条与文本、文档、PDF、OCR 并列的媒体转写产品线。

P0 设计目标：

1. 支持预录音频文件转写为 Markdown / RAG / Debug 输出。
2. 统一处理 `metadata -> transcript -> segment IR`，而不是让 renderer 直接消费供应商原始 JSON。
3. 对接本地或远程 ASR backend，但产品路径必须 fail closed。
4. 与主架构的 `ParseResult / IRInput / DocumentIR / Renderer` 契约保持一致。
5. 首发只关注单文件、预录、语音转写，不承诺实时会话、音乐理解、复杂事件识别。

非目标：

1. 当前不做完整视频理解。
2. 当前不承诺 speaker diarization 必做。
3. 当前不承诺字幕文件成为新的正式 `OutputFormat`。
4. 当前不把音频扩展成独立的“多模态智能体系统”。

---

## 2. 市面成熟产品的共性设计

参考 OpenAI、Google Cloud Speech-to-Text、Amazon Transcribe、Azure Speech、Deepgram 等官方文档，成熟产品通常都不是把音频当作“普通文件解析”处理，而是拆成独立的语音处理产品面。

共性结构大致如下：

```text
audio input
  -> normalization / probe
  -> speech recognition backend
  -> transcript model
  -> optional diarization / utterances / channel split
  -> render / export
```

主流产品共有的能力分层：

1. 预录文件批处理
2. 实时流式转写
3. metadata 与 transcript 分离
4. segment / utterance / word 时间戳
5. diarization 与 multichannel 分开建模
6. 字幕、摘要、章节等能力建立在 transcript 之上，而不是直接建立在音频字节流之上

对 `mb-markitdown` 最值得借鉴的不是某一家供应商的 API 细节，而是以下产品原则：

1. 文件转写与实时转写分开。
2. transcript 是稳定中间层。
3. 时间戳是核心产品事实，不是渲染后猜出来的。
4. diarization 是附加能力，不应阻塞基础转写落地。
5. 输出可以多样，但必须来自统一 transcript/segment 模型。

---

## 3. 与主架构书的兼容关系

主架构书当前已经给出：

```text
media-pipeline
  -> metadata
  -> transcript optional
  -> segment IR
```

并把 `mp3 / wav / m4a / mp4` 放在未来 `media` 类格式之下。

本文件与主架构书的兼容策略如下：

1. 不修改主架构书关于“当前支持范围”的事实。
2. 不把音频写成当前 capability 文档中的正式支持项。
3. 不宣称当前 route planner 已经选择 `media-pipeline`。
4. 只把未来接线规则、数据模型、backend 抽象与产品边界写清楚。

如果后续真正落地音频支持，至少需要同步修改：

1. `input/input.mbt`
2. `formats/registry.mbt`
3. `convert/route_policy.mbt`
4. 相关 `formats/audio/*`
5. `docs/capabilities-and-limitations.md`
6. 样本契约与 quality 回归

在这些实现真正稳定之前，本文件只能视为扩展设计。

---

## 4. 音频产品面建议

### 4.1 P0 产品范围

P0 建议只做：

1. `wav`
2. `mp3`
3. 可选 `m4a`

P0 建议只做预录文件输入，不做实时会话。

原因：

1. 当前 CLI 与 conversion pipeline 以离线文件转换为中心。
2. 预录文件更容易接入现有 `InputSource -> Detect -> Parse -> Render` 主路径。
3. 实时转写天然更接近 session / socket / eventing 系统，不适合在本轮与文本类质量整顿并行铺开。

### 4.2 P0 用户承诺

P0 应该承诺的是：

```text
audio file
  -> transcript
  -> timestamped segments
  -> markdown / rag / debug output
```

P0 不应承诺的是：

```text
live meeting assistant
speaker diarization everywhere
subtitle authoring suite
music understanding
general audio event recognition
```

### 4.3 P1 / P2 扩展方向

P1 可扩展：

1. diarization
2. multichannel split
3. 字幕 sidecar 导出
4. 更强的语言识别与术语提示

P2 可扩展：

1. 实时流式转写
2. 视频抽音轨复用同一路径
3. 章节摘要、action items、meeting note 等上层能力

---

## 5. route 与 mode 设计

### 5.1 canonical route

音频应进入独立 canonical route：

```text
audio -> media-pipeline
```

它不应伪装成：

```text
txt -> streaming-event
pdf -> layout-two-stage
html -> dom-ast-model
```

### 5.2 与 ConvertMode 的关系

建议语义如下：

1. `Fast`
   使用轻量 backend 配置，优先拿到 transcript 与粗粒度 segments。
2. `Balanced`
   默认产品模式；启用稳定 metadata、segment 边界、基础语言/置信度信息。
3. `Accurate`
   仍然走同一 `media-pipeline`，但允许 backend 选择更高保真模型、补充词级时间戳、启用更重的 post-pass。
4. `Stream`
   当前不应为音频首发自动映射到“实时会话能力”；在没有 live ingress 与 session lifecycle 前，音频 `Stream` 不应被产品化承诺。
5. `Rag`
   仍是同一路径，只是 segment/chunk 输出更强。
6. `Debug`
   输出更多 backend diagnostics 与 lowering 细节。

与 Markdown Accurate 的设计原则一致，音频未来也应优先采用“同 route 增强”，而不是轻易制造多条相互切换的 parser route。

### 5.3 不与主架构冲突的做法

当前主架构书只写了 `media-pipeline` 这个预留 route，没有写它已接入 route planner。

因此在实现前，本文件只能把下面这句话写成未来规则：

```text
当音频格式正式接入后，canonical route 应为 media-pipeline。
```

而不能写成：

```text
当前音频已经由 route planner 选择 media-pipeline。
```

---

## 6. 输入检测与预处理

### 6.1 未来 DetectedFormat 扩展

建议未来扩展为：

```moonbit
pub enum AudioFormat {
  Wav
  Mp3
  M4a
}

pub enum DetectedFormat {
  ...
  Audio(AudioFormat)
  ...
}
```

### 6.2 检测顺序

音频检测建议沿用主架构书已有原则：

```text
1. explicit format
2. magic bytes / container signature
3. MIME
4. extension
5. lightweight probe
```

对于音频，轻量 probe 可额外收集：

1. duration
2. sample rate
3. channel count
4. codec/container
5. bit rate

### 6.3 规范化阶段

成熟产品几乎都会在转写前做统一音频规范化。

`mb-markitdown` 也应显式保留这一层：

```text
original audio
  -> probe
  -> optional normalize
  -> backend request audio
```

建议规范化职责：

1. 统一采样率
2. 统一声道策略
3. 统一 PCM/WAV 中间形态
4. 截断或分片超长文件
5. 记录原始 metadata 与规范化 metadata

当前最现实的实现形态是外部工具驱动，例如：

1. `ffprobe` 用于 metadata probe
2. `ffmpeg` 用于重采样、转码、单声道化、裁片

但具体工具名不应成为架构契约本身；真正的契约应是“有一个 normalization backend”。

---

## 7. backend 抽象

### 7.1 backend 分层

建议把音频 parser 分为三层：

```text
audio parser
  -> audio probe / normalization runtime
  -> transcript backend
  -> lowering
```

### 7.2 transcript backend 契约

backend 应返回“标准化 transcript 事实”，而不是让上层直接依赖供应商 JSON。

推荐抽象：

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

### 7.3 backend 选择策略

P0 建议优先支持：

1. 本地 backend
2. 显式依赖检查
3. 明确 fail closed

原因：

1. 与当前 PDF OCR 的本地依赖风格一致。
2. 对 benchmark、quality lab、本地开发更可控。
3. 不引入默认云依赖与隐式计费面。

远程 backend 可以作为后续可选插件化方向，但不应成为第一条必须路径。

---

## 8. transcript 标准模型

### 8.1 为什么要先统一 transcript 模型

主流产品虽然 API 风格不同，但都稳定返回以下信息子集：

1. 全文 transcript
2. segment / utterance
3. word timestamps
4. speaker 或 channel 信息
5. confidence

因此 `mb-markitdown` 最好先定义自己的标准 transcript 中间模型，再做 lowering。

### 8.2 推荐标准模型

建议至少有三个层级：

```text
AudioTranscript
  -> metadata
  -> segments[]
  -> optional words[]
```

`segment` 建议包含：

1. `segment_id`
2. `start_ms`
3. `end_ms`
4. `text`
5. `speaker?`
6. `channel?`
7. `confidence?`
8. `language?`

`word` 建议包含：

1. `text`
2. `start_ms`
3. `end_ms`
4. `speaker?`
5. `channel?`
6. `confidence?`

### 8.3 diarization 与 multichannel

成熟产品通常把这两个概念分开：

1. `diarization`
   解决“谁在说话”
2. `multichannel`
   解决“音频轨道来自哪一路”

`mb-markitdown` 也应分开建模，不要把二者揉成一个字段。

---

## 9. lowering 到现有 Core IR

### 9.1 设计原则

音频支持不应为了首发而要求 Core IR 大重构。

当前 `DocumentIR / CoreBlock / DocumentMetadata / SourceRef.extra` 已经足够承载 P0 音频结果，因此建议优先复用现有结构。

### 9.2 推荐 lowering 形态

P0 可直接降为：

```text
Document
  Heading(file name or title)
  Paragraph(transcript summary or full transcript intro)
  Paragraph(segment 1)
  Paragraph(segment 2)
  ...
```

每个 segment block 可以在：

1. `attrs`
2. `source_ref.extra`
3. `metadata`

中记录时间边界与说话人信息。

推荐最小映射：

```text
DocumentMetadata:
  media_kind=audio
  duration_ms
  sample_rate_hz
  channels
  codec
  transcript_backend
  transcript_language

CoreBlock attrs / source_ref.extra:
  start_ms
  end_ms
  speaker
  channel
  confidence
```

### 9.3 为什么不急着新增专用 BlockKind

P0 不建议先引入 `TranscriptSegmentBlock` 等新 block kind。

原因：

1. 当前 Markdown renderer 对 `Paragraph` 最成熟。
2. RAG 对“有时间边界的段落块”已经足够有用。
3. 先用现有 IR 跑通产品路径，再判断是否真的需要音频专用 block。

如果未来字幕、speaker view、时间线 UI 需求明确，再讨论新增专用 block kind。

---

## 10. 渲染与输出

### 10.1 Markdown

P0 Markdown 输出建议稳定、文本优先：

```text
# file name

> duration: ...
> language: ...
> backend: ...

## Transcript

[00:00.000 - 00:07.200] ...
[00:07.200 - 00:15.900] ...
```

这比“把所有 metadata 藏进 JSON only 输出”更符合 `markitdown` 的核心产品形态。

### 10.2 RAG

RAG 输出建议以 segment 为天然 chunk 边界。

每个 chunk 应至少带：

1. `start_ms`
2. `end_ms`
3. `speaker?`
4. `channel?`
5. `language?`
6. `source file`

### 10.3 Debug

Debug 输出应能看见：

1. probe metadata
2. normalization decision
3. backend name
4. backend version if available
5. transcript segment count
6. optional degradation notes

### 10.4 字幕 sidecar

主流产品经常支持 `srt / vtt` 导出，但对 `mb-markitdown` 而言，这不应在第一步改写当前 `OutputFormat` 契约。

更稳妥的做法是：

1. P0 仍以 Markdown / RAG / Debug 为主
2. 后续若确有需要，再新增 sidecar subtitle export
3. subtitle export 应建立在统一 transcript model 上，而不是直接重跑 backend

---

## 11. diagnostics 与 fail-closed

音频路径必须延续现有产品的 fail-closed 风格。

典型错误面包括：

1. 音频格式检测失败
2. probe 工具缺失
3. normalization 工具缺失
4. backend 未配置
5. backend 空结果
6. backend 返回不完整 segments
7. 文件超长或超出资源限制
8. 不支持的 codec / channel layout

建议 diagnostics 中至少记录：

1. `selected_route`
2. `route_reason`
3. `probe_summary`
4. `normalization_applied`
5. `backend_name`
6. `backend_latency_ms`
7. `segment_count`
8. `word_timestamps_available`
9. `speaker_labels_available`
10. `channel_labels_available`

---

## 12. 分阶段落地建议

### 12.1 P0

建议范围：

1. `wav`
2. `mp3`
3. 可选 `m4a`
4. 预录文件
5. transcript + timestamped segments
6. Markdown / RAG / Debug

必须同步的工程项：

1. `DetectedFormat::Audio`
2. `formats/audio/parser.mbt`
3. `convert/route_policy.mbt` 中的 `media-pipeline`
4. 样本契约
5. dependency/runtime diagnostics

### 12.2 P1

建议范围：

1. diarization
2. multichannel
3. sidecar subtitle export
4. 更强的词级时间戳与语言识别

### 12.3 P2

建议范围：

1. 实时流式转写
2. `mp4` / video 抽音轨
3. 章节、摘要、meeting note

---

## 13. 文档同步规则

为了不与主架构书和 capability 文档冲突，音频线必须遵守以下同步规则：

1. 本文件可以描述未来 `media-pipeline` 的细节设计。
2. 主架构书继续只保留全局架构事实与高层 route 设计。
3. capability 文档只能在实现真正稳定后，才把音频写成“正式支持”。
4. 在 `input/input.mbt`、`formats/registry.mbt`、`convert/route_policy.mbt`、样本契约、回归脚本未同步之前，不得把音频描述为产品化能力。

---

## 14. 参考的成熟产品官方资料

以下资料仅用于提炼产品架构共性，不表示 `mb-markitdown` 将复制其 API 细节：

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

