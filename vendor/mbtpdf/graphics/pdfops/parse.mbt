///|
fn parse_lexemes(
  compatibility : Ref[Int],
  lexemes : Array[Lexeme],
) -> Array[Op] raise {
  let ops : Array[Op] = Array::new()
  let mut index = 0
  while index < lexemes.length() {
    let (op, next_index) = parse_operator(compatibility, lexemes, index)
    ops.push(op)
    index = next_index
  }
  ops
}

///|
/// Parse the operators in content streams.
pub fn Op::parse_operators(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  streams : Array[@pdf.PdfObject],
) -> Array[Op] raise {
  let rawstreams : Array[@pdfio.MutableBytes] = Array::new()
  for stream in streams {
    let direct = pdf.direct(stream)
    @pdfcodec.PdfCodec::new().decode_pdfstream(pdf, direct)
    direct.getstream()
    match direct {
      Stream(r) =>
        match r.val {
          (_, @pdf.Stream::Got(data)) => rawstreams.push(data)
          _ => raise @pdf.PdfError::Msg("Malformed stream")
        }
      _ => raise @pdf.PdfError::Msg("Malformed stream")
    }
  }
  Op::parse_stream(pdf, resources, rawstreams)
}
