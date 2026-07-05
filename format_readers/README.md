# Format Readers

`format_readers/` handles lower-level source reading and source-model preparation for upper-layer `formats/*` parsers.

Main responsibilities:

- container reading
- OOXML / ODF reading
- HTML / markup / structured-text source-model preparation

Maintenance rules:

- readers focus on understanding the source format correctly
- parsers focus on entering the formal product path
- new low-level format logic should live in the matching reader subtree instead of overgrowing upper-layer parsers

Validation:

```bash
moon test
```
