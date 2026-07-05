# Render

`render/` owns the formal output stage and turns unified main-path results into the content users actually consume.

Main responsibilities:

- Markdown output
- debug JSON output
- RAG JSON output

Main files:

- `render.mbt`: top-level dispatch
- `markdown_renderer.mbt`
- `debug_json_renderer.mbt`
- `rag_json_renderer.mbt`
- `render_input_adapters.mbt`

Maintenance rules:

- new output views should plug into the shared render dispatch
- do not duplicate rendering logic inside `convert` or the CLI

Validation:

```bash
moon test
```
