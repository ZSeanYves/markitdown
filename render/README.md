# Render

`render/` owns the final output stage and turns the unified document structure into the text or JSON that users actually consume. It must keep outputs stable while faithfully consuming diagnostics, assembly, source map, and RAG side channels.

## Responsibilities

- Render the primary Markdown output
- Render debug JSON and RAG JSON views
- Manage render context, input adapters, and profile selection consistently
- Deliver Markdown incrementally to an `OutputSink` where the renderer has a
  stable block/event serialization

## Key Entry Points

- `render_types.mbt`
  `RenderContext`, `RenderInput`, `RenderResult`, `Renderer`
- `render.mbt`
  Top-level dispatch and renderer selection
- `markdown_renderer.mbt`
  Markdown renderer entry point
- `markdown_sink.mbt`
  Incremental Markdown sink entry point for document, block, and event inputs
- `render_markdown_blocks.mbt` / `render_markdown_events.mbt`
  Block- and event-level Markdown serialization
- `debug_json_renderer.mbt`
  Debug JSON entry point
- `rag_json_renderer.mbt` / `render_rag_json.mbt`
  RAG JSON entry points and chunk-output integration

## Key Types

- `RenderContext`
  Carries fidelity, output mode, render profile, RAG options, and side data such as diagnostics, metadata, assets, and assembly
- `RenderResult`
  The unified output object for content, accumulated diagnostics, and optional RAG chunks

## Maintenance Rules

- Every new output view should plug into the shared render dispatch instead of assembling content inside convert or CLI
- Keep naming and field semantics aligned across Markdown, debug JSON, and RAG JSON so tests and provenance stay comparable
- Whenever a renderer depends on a new side channel, represent it explicitly in `RenderContext` and the relevant adapters
- Sink rendering must preserve the buffered renderer's bytes and diagnostics;
  empty returned `content` is expected for unbuffered callers

## Validation

```bash
moon test
```
