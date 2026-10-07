# PDF text reader

`formats/pdf` owns the native text-layer PDF route and lowers it into the
shared `DocumentIR` pipeline. It accepts born-digital PDFs whose text, font
maps and page geometry can be recovered by the bounded reader. It does not
invoke OCR, rasterizers or external processes.

## Responsibilities

- preserve page order, source geometry, links, outlines, forms and safe image
  assets;
- report an explicit diagnostic when a PDF has no recoverable text layer;
- keep random reads, object limits, encryption checks and malformed-input
  failures inside the common resource policy;
- return the same `ParseResult` shape used by every other format.

`accurate` keeps its existing Office/ODF semantic meaning. For PDF it selects
the same bounded native text route with the declared geometry and table
policies; it never means scanned-page recognition.

## Key entry points

- `parser.mbt`: native parser registration and route diagnostics;
- `to_ir.mbt`: PDF document to shared IR lowering;
- `parser_native_gate.mbt`: fail-closed text-layer gate;
- `parser_test.mbt` / `parser_wbtest.mbt`: text, geometry and corruption cases.

The package has no Python, model, Poppler, Tesseract or FFmpeg dependency.
