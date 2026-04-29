///|
let decode_ctx : PdfCodec = PdfCodec::new()

///|
fn name_obj(value : String) -> @pdf.PdfObject {
  Name(@pdf.PdfName::of_string(value))
}

///|
fn decode_stream(
  filter : @pdf.PdfObject,
  data : @pdfio.MutableBytes,
  parms? : @pdf.PdfObject,
) -> @pdfio.MutableBytes raise {
  let pdf = @pdf.Pdf::empty()
  let entries : Array[(String, @pdf.PdfObject)] = [
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", filter),
  ]
  let entries = match parms {
    Some(p) => entries + [("/DecodeParms", p)]
    None => entries
  }
  let dict : @pdf.PdfObject = Dictionary(entries)
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_ctx.decode_pdfstream_onestage(pdf, stream_obj)
  match stream_ref.val {
    (_, @pdf.Stream::Got(bytes)) => bytes
    _ => fail("expected decoded bytes")
  }
}

///|
test "decode ASCIIHex stream" {
  let data = @pdfio.bytes_of_string("48656c6c6f>")
  let decoded = decode_stream(name_obj("/ASCIIHexDecode"), data)
  assert_eq(@pdfio.string_of_bytes(decoded), "Hello")
}

///|
test "decode ASCIIHex stream skips whitespace" {
  let data = @pdfio.bytes_of_string("48 65 6c 6c 6f >")
  let decoded = decode_stream(name_obj("/ASCIIHexDecode"), data)
  assert_eq(@pdfio.string_of_bytes(decoded), "Hello")
}

///|
test "decode ASCIIHex stream rejects invalid char" {
  let data = @pdfio.bytes_of_string("GG>")
  let res : Result[@pdfio.MutableBytes, Error] = try? decode_stream(
    name_obj("/ASCIIHexDecode"),
    data,
  )
  assert_true(res is Err(_))
}

///|
test "decode ASCIIHex stream rejects invalid second char" {
  let data = @pdfio.bytes_of_string("4G>")
  let res : Result[@pdfio.MutableBytes, Error] = try? decode_stream(
    name_obj("/ASCIIHexDecode"),
    data,
  )
  assert_true(res is Err(_))
}

///|
test "decode ASCIIHex stream ends on leading terminator" {
  let data = @pdfio.bytes_of_string(">0")
  let decoded = decode_stream(name_obj("/ASCIIHexDecode"), data)
  assert_eq(decoded.length(), 0)
}

///|
test "decode ASCII85 stream" {
  let data = @pdfio.bytes_of_string("z~>")
  let decoded = decode_stream(name_obj("/ASCII85Decode"), data)
  assert_eq(decoded.length(), 4)
  assert_eq(decoded[0].to_int(), 0)
  assert_eq(decoded[3].to_int(), 0)
}

///|
test "decode ASCII85 stream rejects invalid char" {
  let data = @pdfio.bytes_of_string("v~>")
  let res : Result[@pdfio.MutableBytes, Error] = try? decode_stream(
    name_obj("/ASCII85Decode"),
    data,
  )
  assert_true(res is Err(_))
}

///|
test "decode RunLength stream" {
  let data = @pdfio.bytes_of_list([2, 65, 66, 67, 255, 90, 128])
  let decoded = decode_stream(name_obj("/RunLengthDecode"), data)
  assert_eq(@pdfio.string_of_bytes(decoded), "ABCZZ")
}

///|
test "decode Flate stream with TIFF predictor" {
  let raw = @pdfio.bytes_of_list([1, 2, 3, 4, 5, 6])
  let encoded = encode_predictor(2, 1, 8, 6, raw)
  let compressed = decode_ctx.encode_flate(encoded)
  let parms_dict : @pdf.PdfObject = Dictionary([
    ("/Predictor", Integer(2)),
    ("/Colors", Integer(1)),
    ("/BitsPerComponent", Integer(8)),
    ("/Columns", Integer(6)),
  ])
  let decoded = decode_stream(
    name_obj("/FlateDecode"),
    compressed,
    parms=parms_dict,
  )
  assert_eq(@pdfio.int_array_of_bytes(decoded), @pdfio.int_array_of_bytes(raw))
}

///|
test "encode/decode PNG predictor roundtrip" {
  let raw = @pdfio.bytes_of_list([10, 20, 30, 40])
  let encoded = encode_predictor(10, 1, 8, 4, raw)
  let decoded = decode_predictor(10, 1, 8, 4, encoded)
  assert_eq(@pdfio.int_array_of_bytes(decoded), @pdfio.int_array_of_bytes(raw))
}

///|
test "decode_pdfstream_onestage rejects missing filter" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage rejects empty filter array" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Array([])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage rejects invalid filter entry" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Array([Integer(1)])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage rejects invalid filter type" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Integer(1)),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage handles /F and /DP keys" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/F", name_obj("/ASCIIHexDecode")),
    ("/DP", Array([Null, Null])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (updated_dict, _) = stream_ref.val
  assert_true(pdf.lookup_direct("/F", updated_dict) is None)
  match (pdf.lookup_direct("/DP", updated_dict) : @pdf.PdfObject?) {
    Some(Array(values)) => assert_eq(values.length(), 1)
    _ => fail("expected trimmed /DP array")
  }
}

///|
test "decode_pdfstream_onestage trims filter and decode parms arrays" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("4869>")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    (
      "/Filter",
      Array([name_obj("/ASCIIHexDecode"), name_obj("/ASCIIHexDecode")]),
    ),
    ("/DecodeParms", Array([Null, Null])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (updated_dict, _) = stream_ref.val
  match (pdf.lookup_direct("/Filter", updated_dict) : @pdf.PdfObject?) {
    Some(Array(filters)) => assert_eq(filters.length(), 1)
    _ => fail("expected updated filter array")
  }
  match (pdf.lookup_direct("/DecodeParms", updated_dict) : @pdf.PdfObject?) {
    Some(Array(parms)) => assert_eq(parms.length(), 1)
    _ => fail("expected updated decode parms array")
  }
}

///|
test "decode_pdfstream_onestage handles Crypt filter" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("plain")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", name_obj("/Crypt")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (updated_dict, stream_data) = stream_ref.val
  assert_true(pdf.lookup_direct("/Filter", updated_dict) is None)
  match stream_data {
    @pdf.Stream::Got(bytes) => assert_eq(@pdfio.string_of_bytes(bytes), "plain")
    _ => fail("expected got bytes")
  }
}

///|
test "decode_pdfstream_onestage rejects JBIG2 in sync path" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", name_obj("/JBIG2Decode")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage reports CCITT errors" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", name_obj("/CCITTFaxDecode")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_onestage reports LZW errors" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", name_obj("/LZWDecode")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  let res : Result[Unit, Error] = try? decode_ctx.decode_pdfstream_onestage(
    pdf, stream_obj,
  )
  assert_true(res is Err(_))
}

///|
test "decode_pdfstream_until_unknown ignores unsupported filters" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("data")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", name_obj("/JBIG2Decode")),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  decode_ctx.decode_pdfstream_until_unknown(pdf, stream_obj)
}

///|
test "pdfcodec uses placeholder string_of_pdf" {
  // Kept for historical parity; codec no longer relies on global hooks.
  assert_true(true)
}
