# @bobzhang/mbtpdf/graphics/pdffun

PDF function parsing and evaluation.

## Overview

This package parses and evaluates PDF functions (Types 0-4), which are used throughout PDF for color transformations, shadings, and other calculations.

## Types

### PdfFunction

The main function type with domain, range, and implementation.

```moonbit nocheck
///|
pub(all) struct PdfFunction {
  func : PdfFunctionKind
  domain : Array[Double]
  range : Array[Double]?
}
```

- `domain`: Input domain [xmin, xmax, ...]
- `range`: Output range [ymin, ymax, ...] (optional)

### PdfFunctionKind

Function implementation types.

```moonbit nocheck
///|
pub(all) enum PdfFunctionKind {
  Interpolation(Interpolation)
  Stitching(Stitching)
  Sampled(Sampled)
  Calculator(Array[Calculator])
}
```

- `Interpolation`: Type 2 exponential interpolation
- `Stitching`: Type 3 stitched subfunctions
- `Sampled`: Type 0 sampled lookup table
- `Calculator`: Type 4 PostScript calculator

### Sampled

Type 0 sampled function.

```moonbit nocheck
///|
pub(all) struct Sampled {
  size : Array[Int]
  order : Int
  encode : Array[Double]
  decode : Array[Double]
  bps : Int
  samples : Array[Int]
}
```

- `size`: Samples per dimension
- `order`: Interpolation order (1 or 3)
- `encode`: Input encoding
- `decode`: Output decoding
- `bps`: Bits per sample
- `samples`: Sample values

### Interpolation

Type 2 exponential interpolation function.

```moonbit nocheck
///|
pub(all) struct Interpolation {
  c0 : Array[Double]
  c1 : Array[Double]
  n : Double
}
```

- `c0`: Values at x=0
- `c1`: Values at x=1
- `n`: Interpolation exponent

### Stitching

Type 3 stitching function (combines multiple functions).

```moonbit nocheck
///|
pub(all) struct Stitching {
  functions : Array[PdfFunction]
  bounds : Array[Double]
  stitch_encode : Array[Double]
}
```

- `functions`: Subfunctions
- `bounds`: Subdomain boundaries
- `stitch_encode`: Subdomain encoding

### Calculator

Type 4 PostScript calculator operators.

```moonbit nocheck
///|
pub(all) enum Calculator {
  If(Array[Calculator])
  IfElse(Array[Calculator], Array[Calculator])
  Bool(Bool)
  Float(Double)
  Int(Int)
  // Arithmetic: Abs, Add, Atan, Ceiling, Cos, Cvi, Cvr, Div, Exp, Floor, ...
  // Logic: And, Eq, Ge, Gt, Le, Lt, Ne, Not, Or, Xor
  // Stack: Copy, Exch, Pop, Dup, Index, Roll
}
```

## Methods

### PdfFunction::parse

Parse a PDF function from a stream or dictionary.

```moonbit nocheck
pub fn PdfFunction::parse(pdf : @pdf.Pdf, obj : @pdf.PdfObject) -> PdfFunction raise
```

### PdfFunction::eval

Evaluate a function with given inputs.

```moonbit nocheck
pub fn PdfFunction::eval(self : PdfFunction, inputs : Array[Double]) -> Array[Double] raise BadFunctionEvaluation
```

### PdfFunction::to_pdf_object

Convert a function back to a PDF object.

```moonbit nocheck
pub fn PdfFunction::to_pdf_object(self : PdfFunction, pdf : @pdf.Pdf) -> @pdf.PdfObject
```

### PdfFunction::print

Print a function for debugging.

```moonbit nocheck
pub fn PdfFunction::print(self : PdfFunction) -> Unit
```

## Errors

### BadFunctionEvaluation

Raised when function evaluation fails due to bad inputs.

```moonbit nocheck
///|
pub(all) suberror BadFunctionEvaluation {
  Msg(String)
}
```
