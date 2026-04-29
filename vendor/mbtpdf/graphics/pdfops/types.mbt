///|
/// Parsing PDF graphics content stream operators.
///
pub(all) enum Op {
  Opw(Double)
  OpJ(Int)
  Opj(Int)
  OpM(Double)
  Opd(Array[Double], Double)
  Opri(String)
  Opi(Int)
  Opgs(String)
  Opq
  OpQ
  Opcm(@pdftransform.TransformMatrix)
  Opm(Double, Double)
  Opl(Double, Double)
  Opc(Double, Double, Double, Double, Double, Double)
  Opv(Double, Double, Double, Double)
  Opy(Double, Double, Double, Double)
  Oph
  Opre(Double, Double, Double, Double)
  OpS
  Ops
  Opf
  OpF
  OpfStar
  OpB
  OpBStar
  Opb
  OpbStar
  Opn
  OpW
  OpWStar
  OpBT
  OpET
  OpTc(Double)
  OpTw(Double)
  OpTz(Double)
  OpTL(Double)
  OpTf(String, Double)
  OpTr(Int)
  OpTs(Double)
  OpTd(Double, Double)
  OpTD(Double, Double)
  OpTm(@pdftransform.TransformMatrix)
  OpTStar
  OpTj(String)
  OpTJ(@pdf.PdfObject)
  OpSingleQuote(String)
  OpDoubleQuote(Double, Double, String)
  Opd0(Double, Double)
  Opd1(Double, Double, Double, Double, Double, Double)
  OpCS(String)
  Opcs(String)
  OpSC(Array[Double])
  Opsc(Array[Double])
  OpSCN(Array[Double])
  Opscn(Array[Double])
  OpSCNName(String, Array[Double])
  OpscnName(String, Array[Double])
  OpG(Double)
  Opg(Double)
  OpRG(Double, Double, Double)
  Oprg(Double, Double, Double)
  OpK(Double, Double, Double, Double)
  Opk(Double, Double, Double, Double)
  Opsh(String)
  InlineImage((@pdf.PdfObject, @pdf.PdfObject?, @pdfio.MutableBytes))
  OpDo(String)
  OpMP(String)
  OpDP(String, @pdf.PdfObject)
  OpBMC(String)
  OpBDC(String, @pdf.PdfObject)
  OpEMC
  OpBX
  OpEX
  OpUnknown(String)
  OpComment(String)
}

///|
type PdfObject = @pdf.PdfObject

///|
type Token = @pdfgenlex.Token

///|
type PdfSyntax = @pdfsyntax.PdfSyntax

///|
priv enum Lexeme {
  Op(String)
  Obj(Token)
  PdfObj(PdfObject)
  LexInlineImage((PdfObject, PdfObject?, @pdfio.MutableBytes))
  LexComment
}

///|
priv suberror LexingEnd

///|
priv suberror CouldntHandleContent

///|
let debug : Ref[Bool] = { val: false }

///|
let write_comments : Ref[Bool] = { val: false }

///|
let whitespace : Ref[String] = { val: " " }

///|
let always_add_whitespace : Ref[Bool] = { val: false }

///|
pub let begin_artifact : Op = Op::OpBMC("/Artifact")

///|
pub let end_artifact : Op = Op::OpEMC
