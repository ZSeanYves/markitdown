# pdfops

PDF content stream operators for graphics and text.

## Overview

The `pdfops` package provides:

- The `Op` enum representing all PDF content stream operators
- Parsing content streams into operator sequences
- Serializing operators back to content streams
- Operator manipulation utilities

## Op Enum

The `Op` enum represents PDF graphics operators:

### Graphics State

- `Opq` - Save graphics state
- `OpQ` - Restore graphics state
- `Opcm(TransformMatrix)` - Concatenate matrix
- `Opw(Double)` - Line width
- `OpJ(Int)` - Line cap style
- `Opj(Int)` - Line join style
- `OpM(Double)` - Miter limit
- `Opd(Array[Double], Double)` - Dash pattern
- `Opri(String)` - Rendering intent
- `Opi(Int)` - Flatness
- `Opgs(String)` - Graphics state dictionary

### Path Construction

- `Opm(Double, Double)` - Move to
- `Opl(Double, Double)` - Line to
- `Opc(...)` - Curve (Bezier)
- `Opv(...)` - Curve (v variant)
- `Opy(...)` - Curve (y variant)
- `Oph` - Close path
- `Opre(Double, Double, Double, Double)` - Rectangle

### Path Painting

- `OpS` - Stroke path
- `Ops` - Close and stroke
- `Opf` - Fill (non-zero winding)
- `OpF` - Fill (same as f)
- `OpfStar` - Fill (even-odd rule)
- `OpB` - Fill and stroke (non-zero)
- `OpBStar` - Fill and stroke (even-odd)
- `Opb` - Close, fill and stroke
- `OpbStar` - Close, fill and stroke (even-odd)
- `Opn` - End path (no-op)

### Clipping

- `OpW` - Clip (non-zero winding)
- `OpWStar` - Clip (even-odd)

### Text State

- `OpBT` - Begin text object
- `OpET` - End text object
- `OpTc(Double)` - Character spacing
- `OpTw(Double)` - Word spacing
- `OpTz(Double)` - Horizontal scaling
- `OpTL(Double)` - Leading
- `OpTf(String, Double)` - Font and size
- `OpTr(Int)` - Rendering mode
- `OpTs(Double)` - Text rise

### Text Positioning

- `OpTd(Double, Double)` - Move text position
- `OpTD(Double, Double)` - Move and set leading
- `OpTm(TransformMatrix)` - Set text matrix
- `OpTStar` - Move to next line

### Text Showing

- `OpTj(String)` - Show string
- `OpTJ(PdfObject)` - Show strings with positioning
- `OpSingleQuote(String)` - Move and show
- `OpDoubleQuote(Double, Double, String)` - Set spacing, move and show

### Color

- `OpCS(String)` - Set stroke color space
- `Opcs(String)` - Set fill color space
- `OpSC(Array[Double])` - Set stroke color
- `Opsc(Array[Double])` - Set fill color
- `OpSCN(Array[Double])` - Set stroke color (extended)
- `Opscn(Array[Double])` - Set fill color (extended)
- `OpSCNName(String, Array[Double])` - With pattern name
- `OpscnName(String, Array[Double])` - With pattern name
- `OpG(Double)` - Stroke gray
- `Opg(Double)` - Fill gray
- `OpRG(Double, Double, Double)` - Stroke RGB
- `Oprg(Double, Double, Double)` - Fill RGB
- `OpK(Double, Double, Double, Double)` - Stroke CMYK
- `Opk(Double, Double, Double, Double)` - Fill CMYK

### Shading and XObjects

- `Opsh(String)` - Paint shading
- `OpDo(String)` - Paint XObject
- `InlineImage(...)` - Inline image data

### Marked Content

- `OpMP(String)` - Marked content point
- `OpDP(String, PdfObject)` - Marked content with properties
- `OpBMC(String)` - Begin marked content
- `OpBDC(String, PdfObject)` - Begin with properties
- `OpEMC` - End marked content

### Compatibility

- `OpBX` - Begin compatibility section
- `OpEX` - End compatibility section

### Other

- `OpUnknown(String)` - Unrecognized operator
- `OpComment(String)` - PDF comment

## Parsing Content Streams

### Parse to Operators

```mbt nocheck
///|
let ops = @pdfops.Op::parse_stream(pdf, resources, content_stream)
```

## Serializing Operators

### To String

```mbt check
///|
test "string_of_op" {
  let op = @pdfops.Op::Opq
  let s = op.to_string()
  inspect(s, content="q")
}
```

```mbt check
///|
test "string_of_ops" {
  let ops = [@pdfops.Op::Opq, @pdfops.Op::Opm(10.0, 20.0), @pdfops.Op::OpQ]
  let s = @pdfops.Op::string_of_ops(ops)
  assert_true(s.contains("q"))
  assert_true(s.contains("Q"))
}
```

### Concatenate Bytes

```mbt nocheck
///|
let bytes = @pdfops.Op::concat_bytess(byte_arrays)
```

## Common Patterns

### Save/Restore Graphics State

```mbt nocheck
let ops = [Opq, /* drawing operations */, OpQ]
```

### Set Color and Draw

```mbt nocheck
///|
let ops = [
  Oprg(1.0, 0.0, 0.0), // Set fill to red
  Opre(100.0, 100.0, 200.0, 150.0), // Rectangle
  Opf,
] // Fill
```

### Text Operations

```mbt nocheck
///|
let ops = [
  OpBT, // Begin text
  OpTf("/F1", 12.0), // Font F1, size 12
  OpTd(100.0, 700.0), // Position
  OpTj("Hello, World!"), // Show text
  OpET, // End text
]
```

## Artifact Markers

Pre-defined operators for marking artifacts:

```mbt nocheck
///|
pub let begin_artifact : Op = OpBMC("/Artifact")

///|
pub let end_artifact : Op = OpEMC
```

## Debug Options

```mbt nocheck
// Enable debug output
@pdfops.debug.val = true

// Include comments in output
@pdfops.write_comments.val = true

// Control whitespace
@pdfops.whitespace.val = " "
@pdfops.always_add_whitespace.val = false
```
