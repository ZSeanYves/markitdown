///|
let ctx : @pdfcodec.PdfCodec = PdfCodec::new()

///|
test "encode/decode flate stream" {
  let pdf = @pdf.Pdf::empty()
  let original = @pdfio.bytes_of_string("hello flate")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(original)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, Encoding::Flate, stream_obj)
  let (encoded_dict, encoded_stream) = stream_ref.val
  let encoded_bytes = match (encoded_stream : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected encoded stream bytes")
  }
  match (pdf.lookup_direct("/Filter", encoded_dict) : @pdf.PdfObject?) {
    Some(Name(name)) | Some(Array([Name(name), ..])) =>
      if !name.equal_string_bytes("/FlateDecode") {
        fail("expected /FlateDecode filter")
      }
    _ => fail("expected /Filter entry")
  }
  match (pdf.lookup_direct("/Length", encoded_dict) : @pdf.PdfObject?) {
    Some(Integer(len)) => assert_eq(len, @pdfio.bytes_size(encoded_bytes))
    _ => fail("expected /Length entry")
  }
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (decoded_dict, decoded_stream) = stream_ref.val
  let decoded_bytes = match (decoded_stream : @pdf.Stream) {
    Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_eq(
    @pdfio.string_of_bytes(decoded_bytes),
    @pdfio.string_of_bytes(original),
  )
  match decoded_dict.lookup_immediate("/Filter") {
    None => ()
    _ => fail("expected /Filter removed after decode")
  }
  match (pdf.lookup_direct("/Length", decoded_dict) : @pdf.PdfObject?) {
    Some(Integer(len)) => assert_eq(len, @pdfio.bytes_size(original))
    _ => fail("expected /Length entry")
  }
}

///|
fn roundtrip_encoding(
  encoding : Encoding,
  original : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(original)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, encoding, stream_obj, only_if_smaller=false)
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  match (stream_ref.val : (@pdf.PdfObject, @pdf.Stream)) {
    (_, Got(bytes)) => bytes
    _ => fail("expected decoded bytes")
  }
}

///|
test "encode/decode ASCIIHex stream" {
  let original = @pdfio.bytes_of_string("hello hex")
  let decoded = roundtrip_encoding(Encoding::ASCIIHex, original)
  assert_eq(@pdfio.string_of_bytes(decoded), "hello hex")
}

///|
test "encode/decode ASCII85 stream" {
  let original = @pdfio.bytes_of_string("ascii85 data")
  let decoded = roundtrip_encoding(Encoding::ASCII85, original)
  assert_eq(@pdfio.string_of_bytes(decoded), "ascii85 data")
}

///|
test "encode/decode RunLength stream" {
  let original = @pdfio.bytes_of_string("runlength data")
  let decoded = roundtrip_encoding(Encoding::RunLength, original)
  assert_eq(@pdfio.string_of_bytes(decoded), "runlength data")
}

///|
test "encode/decode LZW stream" {
  let original = @pdfio.bytes_of_string("TOBEORNOTTOBEORTOBEORNOT")
  let decoded = roundtrip_encoding(Encoding::LZW(1), original)
  assert_eq(@pdfio.string_of_bytes(decoded), "TOBEORNOTTOBEORTOBEORNOT")
}

///|
test "encode_pdfstream prepends filter when name already set" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("filter chain")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Name(@pdf.PdfName::of_string("/ASCII85Decode"))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, Encoding::Flate, stream_obj)
  match (pdf.lookup_direct("/Filter", stream_ref.val.0) : @pdf.PdfObject?) {
    Some(Array(filters)) => {
      assert_true(filters.length() >= 2)
      match (filters[0] : @pdf.PdfObject) {
        Name(name) if name.equal_string_bytes("/FlateDecode") => ()
        _ => fail("expected /FlateDecode to be first")
      }
    }
    _ => fail("expected filter array")
  }
}

///|
test "encode_pdfstream prepends filter when array already set" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("array filter")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
    ("/Filter", Array([Name(@pdf.PdfName::of_string("/ASCIIHexDecode"))])),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, Encoding::Flate, stream_obj)
  match (pdf.lookup_direct("/Filter", stream_ref.val.0) : @pdf.PdfObject?) {
    Some(Array(filters)) =>
      match (filters[0] : @pdf.PdfObject) {
        Name(name) if name.equal_string_bytes("/FlateDecode") => ()
        _ => fail("expected /FlateDecode to be first")
      }
    _ => fail("expected filter array")
  }
}

///|
test "encode_pdfstream keeps data when only_if_smaller" {
  let pdf = @pdf.Pdf::empty()
  let data = @pdfio.bytes_of_string("x")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(data)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(pdf, Encoding::Flate, stream_obj, only_if_smaller=true)
  match pdf.lookup_direct("/Filter", stream_ref.val.0) {
    None => ()
    _ => fail("expected no /Filter when not smaller")
  }
}

///|
test "decode_pdfstream handles filter arrays" {
  let pdf = @pdf.Pdf::empty()
  let original = @pdfio.bytes_of_string("decode chain")
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(original))),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(original)))
  let stream_obj : @pdf.PdfObject = Stream(stream_ref)
  ctx.encode_pdfstream(
    pdf,
    Encoding::ASCII85,
    stream_obj,
    only_if_smaller=false,
  )
  ctx.encode_pdfstream(
    pdf,
    Encoding::ASCIIHex,
    stream_obj,
    only_if_smaller=false,
  )
  ctx.decode_pdfstream(pdf, stream_obj)
  match (stream_ref.val : (@pdf.PdfObject, @pdf.Stream)) {
    (decoded_dict, Got(bytes)) => {
      assert_eq(@pdfio.string_of_bytes(bytes), "decode chain")
      match decoded_dict.lookup_immediate("/Filter") {
        None => ()
        _ => fail("expected /Filter removed")
      }
    }
    _ => fail("expected decoded bytes")
  }
}
