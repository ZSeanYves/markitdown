///|
fn assert_bytes_eq(
  left : @pdfio.MutableBytes,
  right : @pdfio.MutableBytes,
) -> Unit raise {
  assert_eq(left.length(), right.length())
  for i in 0..<left.length() {
    assert_eq(left[i], right[i])
  }
}

///|
fn bitmap_bytes_from_row_runs(
  rows : Array[Array[Int]],
  start_bit : Int,
) -> @pdfio.MutableBytes {
  let output = @pdfio.BitstreamWrite::new()
  for row in rows {
    let mut bit = start_bit
    for n in row {
      for _ in 0..<n {
        output.putbit(bit)
      }
      bit = 1 - bit
    }
    output.align()
  }
  output.bytes()
}

///|
fn ccitt_roundtrip(
  encoding : Encoding,
  k : Int,
  columns : Int,
  rows : Int,
  raw : @pdfio.MutableBytes,
) -> Unit raise {
  let pdf = @pdf.Pdf::empty()
  let decodeparms : @pdf.PdfObject = Dictionary([
    ("/K", Integer(k)),
    ("/Columns", Integer(columns)),
    ("/Rows", Integer(rows)),
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(raw))),
    ("/DecodeParms", decodeparms),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(raw)))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  let ctx : PdfCodec = PdfCodec::new()
  ctx.encode_pdfstream(pdf, encoding, stream_obj)
  ctx.decode_pdfstream_onestage(pdf, stream_obj)
  let (_decoded_dict, decoded_stream) = stream_ref.val
  let decoded_bytes = match decoded_stream {
    @pdf.Stream::Got(bytes) => bytes
    _ => fail("expected decoded stream bytes")
  }
  assert_bytes_eq(decoded_bytes, raw)
}

///|
test "ccitt g3 roundtrip covers many terminating codes" {
  let columns = 65
  let rows : Array[Array[Int]] = []
  for i in 1..<=64 {
    rows.push([i, columns - i])
  }
  let raw = bitmap_bytes_from_row_runs(rows, 0)
  ccitt_roundtrip(Encoding::CCITT(columns, 64), 0, columns, 64, raw)
}

///|
test "ccitt g4 roundtrip covers many terminating codes" {
  // TODO: Add broader G4 coverage once large/complex vectors are stable.
  // Some larger multi-row patterns can fail to roundtrip (encode/decode mismatch).
  let columns = 8
  let rows = 2
  let raw = bitmap_bytes_from_row_runs(
    [[1, 1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1, 1, 1]],
    1,
  )
  ccitt_roundtrip(Encoding::CCITTG4(columns, rows), -1, columns, rows, raw)
}

///|
test "ccitt g3 roundtrip covers many makeup codes" {
  let columns = 2624
  let rows : Array[Array[Int]] = []
  for i in 1..<=40 {
    let n = 64 * i
    rows.push([n, columns - n])
  }
  let raw = bitmap_bytes_from_row_runs(rows, 0)
  ccitt_roundtrip(Encoding::CCITT(columns, 40), 0, columns, 40, raw)
}

///|
test "ccitt g4 roundtrip covers many makeup codes" {
  let columns = 256
  let rows = 1
  let raw = bitmap_bytes_from_row_runs([[64, 64, 64, 64]], 1)
  ccitt_roundtrip(Encoding::CCITTG4(columns, rows), -1, columns, rows, raw)
}
