# hardwrap_en.pdf native extraction diagnosis

## Scope
Only `samples/pdf/hardwrap_en.pdf` was inspected.

## Observed PDF facts (from decompressed page content)
- Page count: 1.
- Content streams on page 0: 1 stream.
- Text operators present in stream:
  - `BT`: 11
  - `ET`: 11
  - `Tf`: 9
  - `Tm`: 9
  - `Tj`: 9
  - `TJ`: 0
- Page font resources include only `/C1` (Type0 + Identity-H + ToUnicode).
- ToUnicode CMap contains mapping `<0189> -> <fb01>` (ligature `ﬁ`).

## Why native currently drops text on this sample
1. `resolve_page_fonts(...)` currently only enumerates a fixed candidate list:
   `F0..F9` and `TT0..TT1`.
2. This sample uses font resource name `C1`, so that font is not registered.
3. During `Tj` decode, `font_ref` becomes `None` and the code falls back to byte-wise text fallback.
4. For this file, `Tj` operands are UTF-16BE-like hex bytes (many leading `0x00`).
5. Those fallback strings are effectively not producing usable text in native event output, and document-level aggregation ends up with empty text, triggering fatal `empty_text_with_pages`.

## extract_text_from_document_result(...) key stats for this sample
These are the expected native-result stats for current code path on this sample:

- `page_count`: `1`
- `success_pages`: `1`
- `failed_pages`: `0`
- `success_streams`: `1`
- `failed_streams`: `0`
- `event_count`: `0`
- `non_whitespace_chars`: `0`
- `is_empty`: `true`
- `is_low_signal`: `true`
- `is_fatal`: `true`
- `fatal_reason`: `"empty_text_with_pages"`
- `page_stats` (single page):
  - `page_index`: `0`
  - `stream_count`: `1`
  - `success_streams`: `1`
  - `failed_streams`: `0`
  - `event_count`: `0`
  - `text_length`: `0`
  - `is_failed`: `false`

## `inter￾national` clue interpretation
- The PDF CMap explicitly maps glyph code `0x0189` to Unicode `U+FB01` (`ﬁ` ligature).
- If the font mapping/decode path is bypassed or mis-decoded, this ligature can become replacement/control artifacts and appear as weird placeholder characters in reconstructed text.
- So this is a **font decode / glyph mapping path symptom**, not a blank-PDF symptom.

## Root cause (single-sample conclusion)
- Not content stream read failure.
- Not text-op discovery failure.
- Primary failure layer: **font resource resolution + decode path** for non-`F*` font names (`/C1` here), which then leads to empty native text and fatal `empty_text_with_pages`.

## Minimal fix suggestion (sample-targeted)
- In `doc_parse/pdf_core/pdf_font.mbt`, change `resolve_page_fonts(...)` to iterate all entries in `/Resources/Font` instead of hard-coded `F0..F9`/`TT0..TT1` names.
- This allows `/C1` to resolve and enables `decode_text_operand(...)` to use ToUnicode correctly on this sample.
- No change needed to global fatal policy for this targeted issue.
