# pdfcodec

Stream encoding and decoding for PDF compression.

## Overview

The `pdfcodec` package provides:

- Flate (zlib) compression/decompression
- ASCIIHex / ASCII85 / RunLength / LZW decoding (and encoding for some cases)
- CCITT Fax decoding (including Group 4)
- Stream decoding pipelines for `/Filter` chains

## Encoding Types

```mbt nocheck
///|
pub(all) enum Encoding {
  ASCIIHex
  ASCII85
  RunLength
  LZW(Int) // EarlyChange
  Flate
  CCITT(Int, Int) // Columns, Rows
  CCITTG4(Int, Int) // Columns, Rows
}
```

## Types

### PdfCodec

PDF stream codec context.

```mbt nocheck
pub struct PdfCodec { ... }
pub fn PdfCodec::new() -> PdfCodec
```

## Predictor Filters (Optional)

`PdfCodec::encode_pdfstream` supports optional predictor encoding.

```mbt nocheck
///|
pub enum Predictor {
  TIFF2
  PNGNone
  PNGSub
  PNGUp
  PNGAverage
  PNGPaeth
  PNGOptimum
}
```

## Flate Compression

### Encode

```mbt nocheck
///|
let compressed = @pdfcodec.PdfCodec::new().encode_flate(data)
```

### Decode

```mbt nocheck
///|
let decompressed = @pdfcodec.PdfCodec::new().decode_flate(input)
```

### Compression Level

```mbt nocheck
// Configure flate compression level (0-9, default 6)

///|
let codec = @pdfcodec.PdfCodec::new(flate_level=9) // Maximum compression
```

## Stream Decoding

Decode stream data based on its /Filter entry:

```mbt nocheck
///|
let decoded = @pdfcodec.PdfCodec::new().decode_pdfstream_until_unknown(
  pdf, stream,
)
```

## Filter Dispatch Trait

The package exposes a small trait to centralize "decode one filter stage by
name" logic:

- `trait PdfFilterNameDecode` (implemented for `String`)
- Used internally by both `decode_pdfstream_onestage` (mutating a PDF stream)
  and `decode_from_bytes` (pure bytes decoding).

Unsupported filters raise `CodecError::DecodeNotSupported` so callers can
decide whether to stop or keep decoding.

## Error Handling

```mbt nocheck
///|
pub suberror CodecError {
  CouldntDecodeStream(String)
  DecodeNotSupported(String)
}
```
