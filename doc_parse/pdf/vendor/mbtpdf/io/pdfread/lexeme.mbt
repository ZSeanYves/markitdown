///|
fn lex_object_for_xref(
  input : @pdfio.Input,
  xrefs : Map[Int, XRef],
  read_stream_data : Bool,
  objnum : Int,
) -> Array[@pdfgenlex.Token] raise {
  let current_pos = (input.pos_in)()
  match xrefs.get(objnum) {
    Some(XRef::Plain(offset, _gen)) => {
      (input.seek_in)(offset)
      let tokens = @pdfsyntax.PdfSyntax::new().lex_object_at(
        false,
        input,
        read_stream_data,
        fn(k : Int) -> Array[@pdfgenlex.Token] raise {
          lex_object_for_xref(input, xrefs, read_stream_data, k)
        },
      )
      (input.seek_in)(current_pos)
      tokens
    }
    Some(XRef::Stream(_, _)) => {
      let message = @pdf.input_pdferror(input, "Object in object stream")
      raise @pdf.PdfError::Msg(message)
    }
    None => {
      let message = @pdf.input_pdferror(input, "Object not in xref table")
      raise @pdf.PdfError::Msg(message)
    }
  }
}
