# PDF Reader

`format_readers/pdf/` owns native PDF syntax, xref/object recovery, stream
filters, fonts/CMaps, geometry, text extraction, annotations, forms, and image
decoding. Product routing and Markdown lowering remain in `formats/pdf/`.

## Cursor And Fallback

The primary native path opens an `input.SourceCursor`, reads the header and
tail, resolves supported xref chains, then fetches bounded object ranges.
Known-size inputs above the cursor ceiling are rejected before content reads.
If indexed recovery is not safe for a supported file, the reader may use the
existing bounded full-payload fallback; fallback is diagnostic-visible and
does not relax input, object, page, stream, or decode limits.

## Resource Boundaries

Image filters and PNG/JPEG export keep decode working sets bounded. Unsupported
or oversized assets remain explicit diagnostics instead of fabricated payloads.
The reader never performs OCR, launches external commands, fetches remote
resources, or reads XML entities.

## Validation

```bash
moon test format_readers/pdf --target native
bash tools/regression/check_balance.sh --format pdf
```
