///|
let predictor_ctx : PdfCodec = PdfCodec::new()

///|
fn lookup_int_entry(
  entries : Array[(String, @pdf.PdfObject)],
  key : String,
) -> Int? {
  match entries.search_by(pair => pair.0 == key) {
    Some(idx) =>
      match entries[idx].1 {
        @pdf.PdfObject::Integer(value) => Some(value)
        @pdf.PdfObject::Real(value) => Some(value.to_int())
        _ => None
      }
    None => None
  }
}

///|
fn assert_decode_parms(
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
  pred : Int,
  columns : Int,
  colors : Int,
  bpc : Int,
) -> Unit raise {
  match pdf.lookup_direct("/DecodeParms", dict) {
    Some(@pdf.PdfObject::Dictionary(entries)) => {
      let got_pred = lookup_int_entry(entries, "/Predictor")
      let got_cols = lookup_int_entry(entries, "/Columns")
      let got_colors = lookup_int_entry(entries, "/Colors")
      let got_bpc = lookup_int_entry(entries, "/BitsPerComponent")
      match (got_pred, got_cols, got_colors, got_bpc) {
        (Some(p), Some(c), Some(col), Some(bits)) => {
          assert_eq(p, pred)
          assert_eq(c, columns)
          assert_eq(col, colors)
          assert_eq(bits, bpc)
        }
        _ => fail("missing decode parms entries")
      }
    }
    _ => fail("expected /DecodeParms dictionary")
  }
}

///|
fn roundtrip_predictor(pred : Predictor, pred_value : Int) -> Unit raise {
  let pdf = @pdf.Pdf::empty()
  let original = @pdfio.bytes_of_string("abcdefghi")
  let dict = @pdf.PdfObject::Dictionary([
    ("/Length", @pdf.PdfObject::Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(original)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  predictor_ctx.encode_pdfstream(
    pdf,
    Encoding::Flate,
    stream_obj,
    predictor=pred,
    predictor_columns=3,
  )
  let (encoded_dict, _encoded_stream) = stream_ref.val
  assert_decode_parms(pdf, encoded_dict, pred_value, 3, 1, 8)
  predictor_ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (_decoded_dict, decoded_stream) = stream_ref.val
  let decoded_bytes = match decoded_stream {
    @pdf.Stream::Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(
    @pdfio.string_of_bytes(decoded_bytes),
    @pdfio.string_of_bytes(original),
  )
}

///|
test "encode/decode flate stream with predictors" {
  let cases = [
    (Predictor::TIFF2, 2),
    (Predictor::PNGNone, 10),
    (Predictor::PNGSub, 11),
    (Predictor::PNGUp, 12),
    (Predictor::PNGAverage, 13),
    (Predictor::PNGPaeth, 14),
    (Predictor::PNGOptimum, 15),
  ]
  for case in cases {
    let (pred, pred_value) = case
    roundtrip_predictor(pred, pred_value)
  }
}
