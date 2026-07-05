# RAG

`rag/` owns the retrieval-oriented output view so results from the unified main path can be projected into stable RAG JSON.

Main responsibilities:

- chunk options
- document chunking
- RAG output structure

Main files:

- `rag.mbt`
- `document_chunking.mbt`
- `types_options.mbt`

Maintenance rules:

- chunking rules should stay centralized here
- do not let CLI, convert, or render each grow their own chunking logic

Validation:

```bash
moon test
```
