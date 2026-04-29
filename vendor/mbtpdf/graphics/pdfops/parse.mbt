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
fn decode_operator_stream(
  pdf : @pdf.Pdf,
  stream : @pdf.PdfObject,
) -> @pdfio.MutableBytes raise {
    let direct = pdf.direct(stream)
    @pdfcodec.PdfCodec::new().decode_pdfstream(pdf, direct)
    direct.getstream()
    match direct {
      Stream(r) =>
        match r.val {
          (_, @pdf.Stream::Got(data)) => data
          _ => raise @pdf.PdfError::Msg("Malformed stream")
        }
      _ => raise @pdf.PdfError::Msg("Malformed stream")
    }
}

///|
/// Parse the operators in content streams.
///
/// This keeps the historical concat semantics: multiple streams are decoded,
/// concatenated, and then parsed as one operator stream.
pub fn Op::parse_operators(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  streams : Array[@pdf.PdfObject],
) -> Array[Op] raise {
  let rawstreams : Array[@pdfio.MutableBytes] = Array::new()
  for stream in streams {
    rawstreams.push(decode_operator_stream(pdf, stream))
  }
  Op::parse_stream(pdf, resources, rawstreams)
}

///|
/// Parse content streams while preserving source attribution.
///
/// Unlike parse_operators, this API parses each input stream independently so
/// source_stream_index and source_op_index point back to the original stream.
/// Prefer this when source attribution matters more than concat semantics.
pub fn Op::parse_operators_with_source(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  streams : Array[@pdf.PdfObject],
) -> Array[LocatedOp] raise {
  let located : Array[LocatedOp] = Array::new()
  for source_stream_index = 0; source_stream_index < streams.length(); source_stream_index = source_stream_index + 1 {
    let stream = streams[source_stream_index]
    let source_object_ref = match stream {
      Indirect(i) => Some(i)
      _ => None
    }
    let rawstream = decode_operator_stream(pdf, stream)
    let ops = Op::parse_single_stream(pdf, resources, rawstream)
    for source_op_index = 0; source_op_index < ops.length(); source_op_index = source_op_index + 1 {
      located.push({
        op: ops[source_op_index],
        source_stream_index,
        source_op_index,
        source_object_ref,
      })
    }
  }
  located
}
