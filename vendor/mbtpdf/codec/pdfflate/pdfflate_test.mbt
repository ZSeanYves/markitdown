///|
let ctx : @pdfflate.PdfFlate = PdfFlate::new()

///|
fn run_uncompress(
  data : @pdfio.MutableBytes,
  header : Bool,
) -> @pdfio.MutableBytes raise FlateError {
  let mut pos = 0
  let input = (buf : @pdfio.MutableBytes) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      for i in 0..<n {
        buf[i] = data[pos + i]
      }
      pos = pos + n
      n
    }
  }
  let out : @pdfio.MutableBytes = Array::new()
  let output = (buf : @pdfio.MutableBytes, length : Int) => for i in 0..<length {
    out.push(buf[i])
  }
  ctx.uncompress(header~, input, output)
  out
}

///|
fn run_compress(
  data : @pdfio.MutableBytes,
  header : Bool,
) -> @pdfio.MutableBytes {
  let mut pos = 0
  let input = (buf : @pdfio.MutableBytes) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      for i in 0..<n {
        buf[i] = data[pos + i]
      }
      pos = pos + n
      n
    }
  }
  let out : @pdfio.MutableBytes = Array::new()
  let output = (buf : @pdfio.MutableBytes, length : Int) => for i in 0..<length {
    out.push(buf[i])
  }
  ctx.compress(header~, input, output)
  out
}

///|
fn[T] assert_flate_error(
  result : Result[T, Error],
  expected : String,
) -> Unit raise {
  match result {
    Err(FlateError::Error(_stage, msg)) => assert_eq(msg, expected)
    Ok(_) => fail("expected flate error")
    Err(_) => fail("unexpected error")
  }
}

///|
test "uncompress stored zlib" {
  let data : @pdfio.MutableBytes = [
    120, 1, 1, 11, 0, 244, 255, 104, 101, 108, 108, 111, 32, 119, 111, 114, 108,
    100, 26, 11, 4, 93,
  ]
  let out = run_uncompress(data, true) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let ints = out.map(b => b.to_int())
  inspect(
    ints,
    content="[104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]",
  )
}

///|
test "uncompress fixed huffman" {
  let data : @pdfio.MutableBytes = [
    203, 72, 205, 201, 201, 87, 40, 207, 47, 202, 73, 1, 0,
  ]
  let out = run_uncompress(data, false) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let ints = out.map(b => b.to_int())
  inspect(
    ints,
    content="[104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]",
  )
}

///|
test "uncompress fixed huffman with length/distance pairs" {
  // Hand-crafted raw DEFLATE stream (fixed Huffman) which emits:
  // "ABCDEF" then (len=11, dist=5) then (len=3, dist=1) then end-of-block.
  let data : @pdfio.MutableBytes = [
    0x73, 0x74, 0x72, 0x76, 0x71, 0x75, 0x43, 0x22, 0x80, 0x00, 0x00,
  ]
  let out = run_uncompress(data, false) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  assert_eq(@pdfio.string_of_bytes(out), "ABCDEFBCDEFBCDEFBBBB")
}

///|
test "uncompress dynamic huffman" {
  let data : @pdfio.MutableBytes = [
    120, 156, 237, 196, 57, 1, 0, 0, 8, 4, 160, 172, 231, 211, 191, 130, 41, 220,
    96, 32, 213, 179, 145, 36, 73, 146, 36, 73, 146, 244, 217, 1, 198, 122, 142,
    2,
  ]
  let out = run_uncompress(data, true) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  let expected = @pdfio.bytes_of_string("abcde".repeat(1000))
  assert_eq(out, expected)
}

///|
test "compress/uncompress roundtrip zlib" {
  let input = @pdfio.bytes_of_string("hello flate")
  let encoded = run_compress(input, true)
  let decoded = run_uncompress(encoded, true) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "hello flate")
}

///|
test "compress/uncompress roundtrip raw" {
  let input = @pdfio.bytes_of_string("hello flate raw")
  let encoded = run_compress(input, false)
  let decoded = run_uncompress(encoded, false) catch {
    FlateError::Error(stage, msg) => fail("\{stage}: \{msg}")
  }
  assert_eq(@pdfio.string_of_bytes(decoded), "hello flate raw")
}

///|
test "uncompress rejects empty data" {
  let data : @pdfio.MutableBytes = []
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, false,
  )
  assert_flate_error(result, "unexpected end of input")
}

///|
test "uncompress rejects short zlib header" {
  let data : @pdfio.MutableBytes = [120]
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, true,
  )
  assert_flate_error(result, "zlib header too short")
}

///|
test "uncompress rejects unsupported method" {
  let data : @pdfio.MutableBytes = [0, 0]
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, true,
  )
  assert_flate_error(result, "unsupported compression method")
}

///|
test "uncompress rejects invalid header checksum" {
  let data : @pdfio.MutableBytes = [0x78, 0x00]
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, true,
  )
  assert_flate_error(result, "invalid zlib header")
}

///|
test "uncompress rejects preset dictionary flag" {
  let data : @pdfio.MutableBytes = [0x78, 0x20]
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, true,
  )
  assert_flate_error(result, "preset dictionary not supported")
}

///|
test "uncompress rejects invalid block type" {
  let data : @pdfio.MutableBytes = [0x07]
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, false,
  )
  assert_flate_error(result, "invalid block type")
}

///|
test "uncompress rejects stored length mismatch" {
  let data : @pdfio.MutableBytes = [0x01, 0x01, 0x00, 0x00, 0x00]
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, false,
  )
  assert_flate_error(result, "stored block length mismatch")
}

///|
test "uncompress rejects invalid literal/length symbol" {
  let data : @pdfio.MutableBytes = [0x1B, 0x03]
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, false,
  )
  assert_flate_error(result, "invalid literal/length symbol")
}

///|
test "uncompress rejects invalid distance symbol" {
  let data : @pdfio.MutableBytes = [0x03, 0x3E]
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, false,
  )
  assert_flate_error(result, "invalid distance symbol")
}

///|
test "uncompress rejects distance beyond output" {
  // Starts with a (len=3, dist=1) copy with no prior output.
  let data : @pdfio.MutableBytes = [0x03, 0x02, 0x00]
  let result : Result[@pdfio.MutableBytes, Error] = try? run_uncompress(
    data, false,
  )
  assert_flate_error(result, "distance beyond output")
}

///|
test "compress handles empty input" {
  let data : @pdfio.MutableBytes = []
  let encoded = run_compress(data, true)
  let decoded = run_uncompress(encoded, true)
  assert_eq(decoded.length(), 0)
}
