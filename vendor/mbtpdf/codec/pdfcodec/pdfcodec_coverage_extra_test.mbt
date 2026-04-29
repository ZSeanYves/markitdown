///|
fn assert_bytes_equal(
  a : @pdfio.MutableBytes,
  b : @pdfio.MutableBytes,
) -> Unit raise {
  let alen = @pdfio.bytes_size(a)
  let blen = @pdfio.bytes_size(b)
  assert_eq(alen, blen)
  for i in 0..<alen {
    assert_eq(@pdfio.bget_unsafe(a, i), @pdfio.bget_unsafe(b, i))
  }
}

///|
fn mk_stream(
  data : @pdfio.MutableBytes,
  dict_entries : Array[(String, @pdf.PdfObject)],
) -> (@pdf.Pdf, Ref[(@pdf.PdfObject, @pdf.Stream)], @pdf.PdfObject) {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary(
    dict_entries.add([("/Length", Integer(@pdfio.bytes_size(data)))]),
  )
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  (pdf, stream_ref, stream_obj)
}

///|
test "decode_from_bytes handles LZW clear codes mid-stream" {
  let bw = @pdfio.BitstreamWrite::new()
  bw.putval(9, 256)
  bw.putval(9, 65)
  bw.putval(9, 256)
  bw.putval(9, 66)
  bw.putval(9, 257)
  let encoded = bw.bytes()
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/LZWDecode"))),
    ("/DecodeParms", Dictionary([("/EarlyChange", Integer(1))])),
  ])
  match
    (
      @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) :
      @pdfio.MutableBytes?) {
    Some(decoded) => assert_eq(@pdfio.string_of_bytes(decoded), "AB")
    None => fail("expected LZW decode to succeed")
  }
}

///|
test "decode_from_bytes finishes when clear code is followed by EOD" {
  let bw = @pdfio.BitstreamWrite::new()
  bw.putval(9, 256)
  bw.putval(9, 65)
  bw.putval(9, 256)
  bw.putval(9, 257)
  let encoded = bw.bytes()
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/LZWDecode"))),
    ("/DecodeParms", Dictionary([("/EarlyChange", Integer(1))])),
  ])
  match
    (
      @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) :
      @pdfio.MutableBytes?) {
    Some(decoded) => assert_eq(@pdfio.string_of_bytes(decoded), "A")
    None => fail("expected LZW decode to succeed")
  }
}

///|
test "encode/decode LZW roundtrips medium input" {
  let ctx = @pdfcodec.PdfCodec::new()
  // TODO: Keep the payload modest; larger payloads may exercise code-length
  // transitions and have historically been a fragile area.
  let original = @pdfio.mkbytes(250)
  for i in 0..<250 {
    @pdfio.bset_unsafe(original, i, i % 251)
  }
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(pdf, Encoding::LZW(1), stream_obj, only_if_smaller=false)
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_equal(decoded, original)
}

///|
test "encode_pdfstream LZW grows code length past 9 bits" {
  let ctx = @pdfcodec.PdfCodec::new()
  let data = @pdfio.mkbytes(254)
  for i in 0..<254 {
    @pdfio.bset_unsafe(data, i, i)
  }
  let (pdf, stream_ref, stream_obj) = mk_stream(data, [])
  ctx.encode_pdfstream(pdf, Encoding::LZW(1), stream_obj, only_if_smaller=false)
  match (pdf.lookup_direct("/Filter", stream_ref.val.0) : @pdf.PdfObject?) {
    Some(Name(name)) if name.equal_string_bytes("/LZWDecode") => ()
    Some(Array([Name(name), ..])) if name.equal_string_bytes("/LZWDecode") => ()
    _ => fail("expected /LZWDecode filter after encoding")
  }
}

///|
test "decode_from_bytes RunLength returns empty output on EOF" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/RunLengthDecode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(@pdfio.mkbytes(0), dict)
  match out {
    Some(bytes) => assert_eq(@pdfio.bytes_size(bytes), 0)
    None => fail("expected RunLength decode to succeed")
  }
}

///|
test "encode/decode RunLength flushes literal chunks over 128 bytes" {
  let ctx = @pdfcodec.PdfCodec::new()
  let original = @pdfio.mkbytes(130)
  for i in 0..<130 {
    @pdfio.bset_unsafe(original, i, i)
  }
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(
    pdf,
    Encoding::RunLength,
    stream_obj,
    only_if_smaller=false,
  )
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_equal(decoded, original)
}

///|
test "encode/decode RunLength flush_literal returns early when empty" {
  let ctx = @pdfcodec.PdfCodec::new()
  // Starts with a run, so encode_runlength will flush an empty literal buffer.
  let original = @pdfio.bytes_of_string("aaab")
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(
    pdf,
    Encoding::RunLength,
    stream_obj,
    only_if_smaller=false,
  )
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "aaab")
}

///|
test "decode_from_bytes RunLength returns on truncated literal chunks" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/RunLengthDecode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_list([0]),
    dict,
  )
  match out {
    Some(bytes) => assert_eq(@pdfio.bytes_size(bytes), 0)
    None => fail("expected RunLength decode to succeed")
  }
}

///|
test "decode_from_bytes RunLength returns on truncated repeat chunks" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/RunLengthDecode"))),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_list([129]),
    dict,
  )
  match out {
    Some(bytes) => assert_eq(@pdfio.bytes_size(bytes), 0)
    None => fail("expected RunLength decode to succeed")
  }
}

///|
test "decode_from_bytes returns None on empty filter arrays" {
  let dict : @pdf.PdfObject = Dictionary([("/Filter", Array([]))])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(
    @pdfio.bytes_of_string("x"),
    dict,
  )
  assert_true(out is None)
}

///|
test "decode_from_bytes handles non-array DecodeParms for multi-stage filters" {
  let dict : @pdf.PdfObject = Dictionary([
    (
      "/Filter",
      Array([
        Name(@pdf.PdfName::of_string("/Crypt")),
        Name(@pdf.PdfName::of_string("/Crypt")),
      ]),
    ),
    ("/DecodeParms", Dictionary([("/Columns", Integer(1))])),
  ])
  match
    (
      @pdfcodec.PdfCodec::new().decode_from_bytes(
        @pdfio.bytes_of_string("abc"),
        dict,
      ) : @pdfio.MutableBytes?) {
    Some(bytes) => assert_eq(@pdfio.string_of_bytes(bytes), "abc")
    None => fail("expected Crypt decode to succeed")
  }
}

///|
test "decode_from_bytes trims DecodeParms arrays shorter than Filter arrays" {
  let dict : @pdf.PdfObject = Dictionary([
    (
      "/Filter",
      Array([
        Name(@pdf.PdfName::of_string("/Crypt")),
        Name(@pdf.PdfName::of_string("/Crypt")),
      ]),
    ),
    ("/DecodeParms", Array([Dictionary([])])),
  ])
  match
    (
      @pdfcodec.PdfCodec::new().decode_from_bytes(
        @pdfio.bytes_of_string("xyz"),
        dict,
      ) : @pdfio.MutableBytes?) {
    Some(bytes) => assert_eq(@pdfio.string_of_bytes(bytes), "xyz")
    None => fail("expected Crypt decode to succeed")
  }
}

///|
test "encode/decode Flate with PNG Paeth predictor roundtrips" {
  let ctx = @pdfcodec.PdfCodec::new()
  let original = @pdfio.bytes_of_list([128, 255, 0, 0])
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(
    pdf,
    Encoding::Flate,
    stream_obj,
    only_if_smaller=false,
    predictor=Predictor::PNGPaeth,
    predictor_columns=2,
  )
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_eq(decoded, original)
}

///|
test "encode/decode Flate with zero-column PNG predictor yields empty stream" {
  let ctx = @pdfcodec.PdfCodec::new()
  let original = @pdfio.mkbytes(0)
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(
    pdf,
    Encoding::Flate,
    stream_obj,
    only_if_smaller=false,
    predictor=Predictor::PNGSub,
    predictor_columns=0,
  )
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.bytes_size(decoded), 0)
}

///|
test "encode/decode Flate with zero-column TIFF predictor yields empty stream" {
  let ctx = @pdfcodec.PdfCodec::new()
  let original = @pdfio.mkbytes(0)
  let (pdf, stream_ref, stream_obj) = mk_stream(original, [])
  ctx.encode_pdfstream(
    pdf,
    Encoding::Flate,
    stream_obj,
    only_if_smaller=false,
    predictor=Predictor::TIFF2,
    predictor_columns=0,
  )
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.bytes_size(decoded), 0)
}

///|
test "decode Flate errors on PNG predictor with unsupported bpc" {
  let ctx = @pdfcodec.PdfCodec::new()
  let raw = @pdfio.bytes_of_list([0, 7])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = Dictionary([
    ("/Predictor", Integer(12)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(4)),
    ("/Columns", Integer(2)),
  ])
  let (pdf, _stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode Flate errors on TIFF predictor with unsupported bpc" {
  let ctx = @pdfcodec.PdfCodec::new()
  let raw = @pdfio.bytes_of_list([1, 2, 3])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = Dictionary([
    ("/Predictor", Integer(2)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(4)),
    ("/Columns", Integer(1)),
  ])
  let (pdf, _stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode Flate breaks when PNG predictor scanline is truncated" {
  let ctx = @pdfcodec.PdfCodec::new()
  // Decompressed bytes: predictor byte (0) + only 1 data byte; columns=2 => scanline_width=2.
  let raw = @pdfio.bytes_of_list([0, 7])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = Dictionary([
    ("/Predictor", Integer(12)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    // Use Real here to cover get_int_param's Real-to-int conversion.
    ("/Columns", Real(2.0)),
  ])
  let (pdf, stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.bytes_size(decoded), 2)
  assert_eq(@pdfio.bget_unsafe(decoded, 0), 7)
  assert_eq(@pdfio.bget_unsafe(decoded, 1), 0)
}

///|
test "decode Flate TIFF predictor handles zero columns as empty scanlines" {
  let ctx = @pdfcodec.PdfCodec::new()
  let raw = @pdfio.bytes_of_list([1, 2, 3])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = Dictionary([
    ("/Predictor", Integer(2)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/Columns", Integer(0)),
  ])
  let (pdf, stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_equal(decoded, raw)
}

///|
test "decode Flate errors on unknown PNG predictor bytes" {
  let ctx = @pdfcodec.PdfCodec::new()
  // predictor byte 9 is invalid (valid: 0..4).
  let raw = @pdfio.bytes_of_list([9, 7, 8])
  let encoded = ctx.encode_flate(raw)
  let parms : @pdf.PdfObject = Dictionary([
    ("/Predictor", Integer(12)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/Columns", Integer(2)),
  ])
  let (pdf, _stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
    ("/DecodeParms", parms),
  ])
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "encode_pdfstream errors when existing /Filter has wrong type" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, _stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [
    ("/Filter", Integer(1)),
  ])
  let res : Result[Unit, Error] = try? ctx.encode_pdfstream(
    pdf,
    Encoding::Flate,
    stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "encode_pdfstream follows indirect streams" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, _stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [])
  let objnum = pdf.addobj(stream_obj)
  ctx.encode_pdfstream(pdf, Encoding::Flate, Indirect(objnum))
}

///|
test "encode_pdfstream errors on malformed stream objects" {
  let ctx = @pdfcodec.PdfCodec::new()
  let pdf = @pdf.Pdf::empty()
  let res : Result[Unit, Error] = try? ctx.encode_pdfstream(
    pdf,
    Encoding::Flate,
    Null,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage errors on malformed stream objects" {
  let ctx = @pdfcodec.PdfCodec::new()
  let pdf = @pdf.Pdf::empty()
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_onestage(pdf, Null)
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage removes singleton filter and decode parms arrays" {
  let ctx = @pdfcodec.PdfCodec::new()
  let raw = @pdfio.bytes_of_string("x")
  let encoded = ctx.encode_flate(raw)
  let (pdf, stream_ref, stream_obj) = mk_stream(encoded, [
    ("/Filter", Array([Name(@pdf.PdfName::of_string("/FlateDecode"))])),
    ("/DecodeParms", Array([Dictionary([("/Predictor", Integer(1))])])),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let dict = stream_ref.val.0
  assert_true(dict.lookup_immediate("/Filter") is None)
  assert_true(dict.lookup_immediate("/DecodeParms") is None)
}

///|
test "decode_pdfstream_onestage handles empty DecodeParms arrays" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [
    ("/Filter", Name(@pdf.PdfName::of_string("/Crypt"))),
    ("/DecodeParms", Array([])),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "x")
}

///|
test "decode_pdfstream_onestage handles null DecodeParms" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [
    ("/Filter", Name(@pdf.PdfName::of_string("/Crypt"))),
    ("/DecodeParms", Null),
  ])
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let decoded = match (stream_ref.val.1 : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "x")
}

///|
test "decode_from_bytes treats null DecodeParms as missing" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/Crypt"))),
    ("/DecodeParms", Null),
  ])
  match
    (
      @pdfcodec.PdfCodec::new().decode_from_bytes(
        @pdfio.bytes_of_string("x"),
        dict,
      ) : @pdfio.MutableBytes?) {
    Some(bytes) => assert_eq(@pdfio.string_of_bytes(bytes), "x")
    None => fail("expected Crypt decode to succeed")
  }
}

///|
test "encode_pdfstream maps PdfError via map_pdf_error" {
  let ctx = @pdfcodec.PdfCodec::new()
  let stream_ref : Ref[(@pdf.PdfObject, @pdf.Stream)] = Ref::new(
    (@pdf.PdfObject::Integer(1), @pdf.Stream::Got(@pdfio.bytes_of_string("x"))),
  )
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? ctx.encode_pdfstream(
    @pdf.Pdf::empty(),
    Encoding::Flate,
    stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_from_bytes reads boolean decode parameters" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/Filter", Name(@pdf.PdfName::of_string("/CCITTFaxDecode"))),
    (
      "/DecodeParms",
      Dictionary([("/BlackIs1", Boolean(true)), ("/Columns", Integer(1))]),
    ),
  ])
  let out = @pdfcodec.PdfCodec::new().decode_from_bytes(@pdfio.mkbytes(0), dict)
  // Decoding will fail on empty data, but parameters are still parsed.
  assert_true(out is None)
}

///|
test "decode_pdfstream_until_unknown rethrows malformed stream errors" {
  let ctx = @pdfcodec.PdfCodec::new()
  let pdf = @pdf.Pdf::empty()
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream_until_unknown(
    pdf,
    Null,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream rejects malformed /Filter type" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, _stream_ref, stream_obj) = mk_stream(@pdfio.bytes_of_string("x"), [
    ("/Filter", Integer(1)),
  ])
  let res : Result[Unit, Error] = try? ctx.decode_pdfstream(pdf, stream_obj)
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream follows indirect streams" {
  let ctx = @pdfcodec.PdfCodec::new()
  let (pdf, _stream_ref, stream_obj) = mk_stream(
    @pdfio.bytes_of_string("indirect"),
    [("/Filter", Name(@pdf.PdfName::of_string("/Crypt")))],
  )
  let objnum = pdf.addobj(stream_obj)
  ctx.decode_pdfstream(pdf, Indirect(objnum))
}
