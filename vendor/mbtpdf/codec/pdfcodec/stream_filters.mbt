///|
/// Decode a PDF stream, updating the document.
pub fn PdfCodec::decode_pdfstream(
  self : PdfCodec,
  _pdf : @pdf.Pdf,
  _obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  fn decode_one_stage(
    pdf : @pdf.Pdf,
    obj : @pdf.PdfObject,
  ) -> Unit raise CodecError {
    match (obj : @pdf.PdfObject) {
      Stream(r) => {
        let (dict, _stream) = r.val
        let filter_opt = pdf.lookup_direct_orelse("/Filter", "/F", dict)
        match filter_opt {
          None => ()
          Some(Name(_)) | Some(Array(_)) => {
            let before = dict.to_string()
            self.decode_pdfstream_onestage(pdf, obj, jbig2dec?)
            let (after_dict, _after_stream) = r.val
            let after = after_dict.to_string()
            if before != after {
              decode_one_stage(pdf, obj)
            }
          }
          Some(_) => raise CodecError::CouldntDecodeStream("malformed /Filter")
        }
      }
      Indirect(i) => decode_one_stage(pdf, pdf.direct(Indirect(i)))
      _ => raise CodecError::CouldntDecodeStream("malformed stream")
    }
  }

  decode_one_stage(_pdf, _obj)
}

///|
/// Decode until there's an unknown decoder.
pub fn PdfCodec::decode_pdfstream_until_unknown(
  self : PdfCodec,
  _pdf : @pdf.Pdf,
  _obj : @pdf.PdfObject,
  jbig2dec? : String,
) -> Unit raise CodecError {
  self.decode_pdfstream(_pdf, _obj, jbig2dec?) catch {
    CodecError::DecodeNotSupported(_) => ()
    CodecError::CouldntDecodeStream(msg) =>
      raise CodecError::CouldntDecodeStream(msg)
  }
}
