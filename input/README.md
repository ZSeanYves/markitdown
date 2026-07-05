# Input

`input/` describes input sources and normalizes external input into a format identity the product understands.

Main responsibilities:

- represent path, text, and byte-based input sources
- perform formal format detection
- handle extensions and explicit format hints

Main files:

- `input.mbt`

Maintenance rules:

- aliases, extensions, and detection rules for new formats should converge here first
- detection should answer only “what is this input”, not “how should it be parsed”

Validation:

```bash
moon test
```
