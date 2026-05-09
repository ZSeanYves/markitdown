///|
/// PostScript calculator operators.
pub(all) enum Calculator {
  If(Array[Calculator])
  IfElse(Array[Calculator], Array[Calculator])
  Bool(Bool)
  Float(Double)
  Int(Int)
  Abs
  Add
  Atan
  Ceiling
  Cos
  Cvi
  Cvr
  Div
  Exp
  Floor
  Idiv
  Ln
  Log
  Mod
  Mul
  Neg
  Round
  Sin
  Sqrt
  Sub
  Truncate
  And
  Bitshift
  Eq
  Ge
  Gt
  Le
  Lt
  Ne
  Not
  Or
  Xor
  Copy
  Exch
  Pop
  Dup
  Index
  Roll
} derive(Debug)

///|
/// Sampled functions.
pub(all) struct Sampled {
  size : Array[Int]
  order : Int
  encode : Array[Double]
  decode : Array[Double]
  bps : Int
  samples : Array[Int]
} derive(Debug)

///|
/// Interpolation functions.
pub(all) struct Interpolation {
  c0 : Array[Double]
  c1 : Array[Double]
  n : Double
} derive(Debug)

///|
/// Stitching functions.
pub(all) struct Stitching {
  functions : Array[PdfFunction]
  bounds : Array[Double]
  stitch_encode : Array[Double]
} derive(Debug)

///|
/// Function kinds.
pub(all) enum PdfFunctionKind {
  Interpolation(Interpolation)
  Stitching(Stitching)
  Sampled(Sampled)
  Calculator(Array[Calculator])
} derive(Debug)

///|
/// Main function type.
pub(all) struct PdfFunction {
  func : PdfFunctionKind
  domain : Array[Double]
  range : Array[Double]?
} derive(Debug)

///|
/// Bad inputs have been given to a function.
pub(all) suberror BadFunctionEvaluation {
  Msg(String)
}

///|
type PdfObject = @pdf.PdfObject

///|
type Token = @pdfgenlex.Token
