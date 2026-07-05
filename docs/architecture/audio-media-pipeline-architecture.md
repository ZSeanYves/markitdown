# Audio Media Pipeline Architecture Guide

> Path: `docs/architecture/audio-media-pipeline-architecture.md`
>
> This document complements [mb-markitdown-architecture.md](./mb-markitdown-architecture.md)
> and [format-mode-and-execution-profile-architecture.md](./format-mode-and-execution-profile-architecture.md)
> with focused rules for audio input, transcript modeling, backend integration, and the `media_pipeline` route.

Recommended reading order:

1. Read the main architecture guide first.
2. Then read the mode and profile guide.
3. Then read this document to understand how audio enters the unified main chain.
4. Finally read [../capabilities-and-limitations.md](../capabilities-and-limitations.md) for the current public boundary.

---

## 0. Document Scope

This is a normative extension architecture document, not a temporary ASR integration note.

It answers:

1. what product-layer capability audio should be in this project
2. why audio should use a dedicated `media_pipeline` route instead of pretending to be plain text or subtitle input
3. how probe, normalization, transcript backend, lowering, and renderer should be layered
4. why transcript must be a stable middle layer instead of passing raw provider JSON directly to renderers
5. how `Balanced`, `Accurate`, and `Stream` should be expressed for audio

This document also keeps several explicit boundaries:

1. capability docs define the current public support boundary
2. this document may describe the long-term architecture target even if implementation is still narrower
3. `srt` and `vtt` remain subtitle-text formats, not audio inputs in disguise
4. this product line is for file conversion, not live meeting or generic multimodal assistant platforms

### 0.1 Product Positioning

The goal of audio support is not just "recognize a few more extensions".

The goal is to add a formal media-transcript product line that stands beside:

- text conversion
- package-document conversion
- paged-document conversion
- OCR routes

Its long-term positioning should be:

1. accept prerecorded media files
2. produce metadata, transcript, segments, source refs, and diagnostics
3. project results into Markdown, RAG, and debug views through the unified renderer layer
4. stay aligned with the same route, planner, profile, and provenance contracts used by the rest of the product

So the audio path should not become:

1. "send audio to some cloud API and dump raw JSON"
2. "convert audio into subtitle text and pretend it always was subtitle input"
3. "a totally separate speech stack outside the main architecture"

### 0.2 Architecture Versus Implementation

This document defines how the audio line should converge into the main architecture.

That means:

1. it is a target contract for code, tests, and operational docs
2. gaps between implementation and this document are convergence work, not a reason to shrink the architecture language
3. only product-direction changes should justify rewriting the architecture boundary

---

## 1. Design Goal

The audio media pipeline should satisfy all of the following:

1. reuse the unified chain `detect -> probe -> planner -> parser -> pipeline -> renderer`
2. stay transcript-first
3. keep route, normalization, backend choice, degradation, and segment quality explainable
4. fail closed when dependencies or results are missing or broken
5. keep mode meaning separate from provider naming
6. leave room for future extensions such as diarization, multichannel, subtitle sidecars, and audio extraction from video

### 1.1 P0 Scope

The current P0 scope should remain intentionally narrow:

1. prerecorded single-file audio input
2. transcript plus timestamped segments
3. Markdown, RAG, and debug output views
4. basic language handling
5. controlled normalization and backend dependencies

P0 should not promise:

1. real-time transcription
2. full video understanding
3. music understanding or general audio-event recognition
4. mandatory diarization for every file
5. subtitle sidecars as the primary launch contract

---

## 2. Relationship to the Main Architecture

The main architecture already reserves a media-oriented slot:

```text
media
  -> metadata
  -> transcript optional
  -> segment IR
```

This document makes the audio rules more explicit:

1. audio should have its own canonical route: `audio -> media_pipeline`
2. `media_pipeline` is a route category, not a provider name
3. once the planner freezes `media_pipeline`, downstream stages should consume that plan instead of inventing new top-level policy
4. audio support must not break stable subtitle-text semantics

### 2.1 Audio Versus Subtitle Boundary

The project should keep three things clearly separate:

1. subtitle text files such as `srt` and `vtt`
2. audio media files such as `wav`, `mp3`, and `m4a`
3. subtitle sidecar views projected from transcript output

The right relationship is:

```text
audio file
  -> media_pipeline
  -> transcript model
  -> optional subtitle sidecar
```

Not:

```text
audio file -> pretend subtitle text format
```

---

## 3. Common Design Pattern in Mature Audio Products

Most mature speech products follow a familiar structure:

```text
audio input
  -> normalization / probe
  -> speech recognition backend
  -> transcript model
  -> optional diarization / utterance grouping / channel split
  -> render / export
```

The important lessons are architectural, not vendor-specific:

1. file transcription is not the same thing as real-time conversation transcription
2. transcript is the stable middle layer
3. timestamps are product facts, not renderer guesses
4. diarization is an optional enhancement, not a prerequisite for the basic route
5. subtitles, summaries, sections, and RAG chunks all derive from transcript

---

## 4. User Mode and Output View

### 4.1 Balanced

`Balanced` is the default audio strategy mode.

Its contract:

1. prefer a mature and cost-controlled canonical `media_pipeline`
2. return reliable metadata, segment boundaries, and transcript text by default
3. avoid hidden heavy inference or expensive remote behavior as the product baseline
4. allow same-mode switches for normalization, batching, or execution profile when probe evidence supports them

### 4.2 Accurate

`Accurate` is the quality-priority mode for audio.

Its contract should remain modest and honest:

1. prefer staying inside the same `media_pipeline` route
2. allow stronger transcript backend settings, better word timing, or stronger segment recovery when supported
3. keep every enhancement explainable and regression-friendly
4. avoid promising speculative speaker attribution or unverifiable semantic completion

Important current boundary:

- audio does not currently have a strong separate accurate product line in the same way PDF does

### 4.3 Stream

`Stream` is the low-peak-resource strategy mode.

For audio, it should mean:

1. lower-peak normalization and batching
2. more streaming-friendly transcript assembly and chunk flushing
3. earlier partial output where the route supports it

It should not automatically mean:

- live meeting transcription
- websocket session semantics
- a full real-time conversation platform

### 4.4 Output View

As with other formats, `RAG` and `Debug` are output views, not strategy modes.

Audio should therefore support:

1. `Markdown`
2. `RagJson`
3. `DebugJson`

Different modes may still produce different results even when the output view is the same.

---

## 5. Route, Probe, and Planner Boundary

### 5.1 Canonical Route

Audio should use the dedicated canonical route:

```text
audio -> media_pipeline
```

It should not pretend to be:

1. `streaming_event`
2. `block_streaming`
3. `dom_ast_model`
4. `layout_two_stage`

### 5.2 ProbeOutcome

Probe for audio should stay lightweight and evidence-oriented.

Useful probe signals include:

- codec or container information
- duration
- sample rate
- channel count
- estimated size or resource posture
- normalization requirement hints

Probe should not secretly choose the final backend or fake route truth.

### 5.3 Planner

Planner is still the single owner of execution truth.

For audio it should freeze:

- selected route
- execution profile
- normalization posture
- backend intent
- same-mode switches
- fallback reasons if any

### 5.4 Same-Mode Adaptive Switch

Audio may need same-mode adaptation for:

- long duration
- high channel count
- resource constraints

But these must remain explainable and must not silently pretend to be a new product mode.

---

## 6. Input Detection and Normalization

### 6.1 DetectedFormat

Audio detection should distinguish supported audio inputs clearly from subtitle-text and unsupported video/container inputs.

### 6.2 Detection Order

Detection should continue to be:

1. lightweight
2. explicit
3. compatible with the main detector model

### 6.3 Normalization Backend

Normalization may use helper tooling such as `ffmpeg`, but:

1. it should remain explicit in diagnostics
2. it should not become hidden product truth
3. missing normalization dependencies should be visible and fail closed when required

### 6.4 Long Media and Resource Limits

Audio routes should remain honest under long or heavy inputs:

1. low-peak strategies should be explicit
2. resource caps should not silently drop transcript truth
3. overflow behavior should remain diagnosable

---

## 7. Transcript Backend Abstraction

### 7.1 Layered Model

Audio backend integration should stay layered:

```text
audio input
  -> normalization
  -> transcript backend
  -> transcript model
  -> lowering
  -> renderer
```

### 7.2 Backend Contract

Backend outputs should be normalized into one stable transcript model instead of leaking raw vendor JSON into downstream layers.

### 7.3 Backend Selection Strategy

Backend choice should remain plan-driven and diagnosable.

It should not be defined by:

- user-facing mode names alone
- hidden runtime shortcuts
- ad hoc special cases outside the planner

---

## 8. Standard Transcript Model

### 8.1 Why a Unified Transcript Model Is Required

Without one transcript model:

1. renderers become vendor-specific
2. provenance becomes inconsistent
3. RAG and debug output become harder to stabilize

### 8.2 Recommended Model Shape

The project should keep a transcript model that can carry:

- global media metadata
- transcript text
- segments
- timestamps
- optional word-level timing when available
- optional confidence or speaker-like information when supported

### 8.3 Diarization and Multichannel

These should remain optional extensions on top of the stable transcript model, not prerequisites for the basic product contract.

---

## 9. Lowering Into the Unified IR

### 9.1 Design Principle

Audio should still lower into the same downstream product language used by the rest of the system.

### 9.2 Recommended Lowering Shape

Audio lowering should preserve:

- transcript sequence
- segment boundaries
- timing source refs
- backend diagnostics

### 9.3 SourceRef Semantics

Time is a first-class provenance dimension for audio.

That means source refs should preserve:

- time start
- time end
- segment identity where appropriate

### 9.4 Why There Is No Need for a Totally Separate Output Stack

Audio does not need to bypass the product output architecture.

It still benefits from:

- Markdown projection
- RAG chunk projection
- debug projection
- shared diagnostics and provenance

---

## 10. Rendering and Output

### 10.1 Markdown

Markdown should remain the default human-readable output.

A simple pattern is:

```text
# file name

## Transcript
...
```

### 10.2 RagJson

RAG output should keep transcript chunks, time boundaries, and source refs structured and reusable.

### 10.3 DebugJson

Debug output should expose probe, normalization, backend, lowering, and provenance facts clearly.

### 10.4 Subtitle Sidecar

Subtitle sidecars may exist as a derived projection, but they should not replace transcript as the stable middle layer.

---

## 11. Diagnostics, Provenance, and Fail-Closed Behavior

Audio paths are only trustworthy when they remain visible.

Diagnostics and provenance should answer:

1. which route was selected
2. which backend was requested or used
3. whether normalization happened
4. whether fallback happened
5. why a capability was unsupported
6. whether timing or segment information is partial or degraded

Fail-closed rules matter especially for:

- missing backend dependencies
- empty transcript results
- broken segment structures
- unsupported mode expectations

---

## 12. Staged Delivery Suggestion

### 12.1 P0

Keep the current product contract narrow:

- prerecorded audio
- transcript and segments
- Markdown, RAG, and debug output
- clear provenance

### 12.2 P1

Possible next steps:

- stronger timing fidelity
- better normalization posture
- more detailed diagnostics
- optional richer transcript shaping

### 12.3 P2

Longer-term candidates:

- better diarization handling
- multichannel-aware views
- video-to-audio extraction flows
- stronger subtitle-sidecar support

---

## 13. Document Sync Rule

This architecture note should stay aligned with:

- the main architecture guide
- the mode and profile guide
- the capability boundary document
- operational docs describing environment dependencies and CLI usage

If the product boundary changes, the docs should be updated together rather than drifting apart.

---

## 14. Relevant Mature Product References

The most useful references are not one specific vendor API, but the broader design pattern shared by mature speech products:

1. transcript-first design
2. timing as product truth
3. backend isolation
4. separate file-transcription and live-session product lines
