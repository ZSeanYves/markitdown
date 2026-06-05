///|
fn bytes_from_runs(
  start_white : Bool,
  runs : Array[Int],
) -> @pdfio.MutableBytes {
  let writer = @pdfio.BitstreamWrite::new()
  let mut white = start_white
  for run in runs {
    let bit = if white { 1 } else { 0 }
    for _ in 0..<run {
      writer.putbit(bit)
    }
    white = !white
  }
  writer.bytes()
}

///|
fn build_runs() -> Array[Int] {
  let runs = Array::new()
  for i = 1; i <= 63; i = i + 1 {
    runs.push(i)
  }
  for v = 64; v <= 2560; v = v + 64 {
    runs.push(v)
  }
  runs
}

///|
fn bytes_from_rows(rows : Array[Array[Int]]) -> @pdfio.MutableBytes {
  let writer = @pdfio.BitstreamWrite::new()
  for row in rows {
    let mut white = true
    for run in row {
      let bit = if white { 1 } else { 0 }
      for _ in 0..<run {
        writer.putbit(bit)
      }
      white = !white
    }
    writer.align()
  }
  writer.bytes()
}

///|
test "encode_ccitt produces output" {
  let columns = 8
  let rows = 2
  let raw = @pdfio.bytes_of_list([0xF0, 0x0F])
  let encoded = encode_ccitt(columns, rows, raw)
  assert_true(encoded.length() > 0)
}

///|
test "encode_ccittg4 produces output" {
  let columns = 8
  let rows = 2
  let raw = @pdfio.bytes_of_list([0xAA, 0xAA])
  let encoded = encode_ccittg4(columns, rows, raw)
  assert_true(encoded.length() > 0)
}

///|
test "encode_ccittg4 handles pass mode patterns" {
  let columns = 16
  let rows = 2
  let raw = bytes_from_rows([[4, 2, 10], [8, 2, 6]])
  let encoded = encode_ccittg4(columns, rows, raw)
  assert_true(encoded.length() > 0)
}

///|
test "encode_ccittg4 handles vertical mode patterns" {
  let columns = 16
  let rows = 4
  let raw = bytes_from_rows([[5, 5, 6], [7, 3, 6], [10, 1, 5], [7, 3, 6]])
  let encoded = encode_ccittg4(columns, rows, raw)
  assert_true(encoded.length() > 0)
}

///|
test "encode_ccitt handles varied runs" {
  let runs = build_runs()
  let mut columns = 0
  for run in runs {
    columns = columns + run
  }
  let raw = bytes_from_runs(true, runs)
  let encoded = encode_ccitt(columns, 1, raw)
  assert_true(encoded.length() > 0)
}

///|
test "encode_ccitt handles shifted runs" {
  let runs = build_runs()
  let mut columns = 0
  for run in runs {
    columns = columns + run
  }
  let raw = bytes_from_runs(false, runs)
  let encoded = encode_ccitt(columns, 1, raw)
  assert_true(encoded.length() > 0)
}

///|
test "encode_ccittg4 rejects imagemagick path" {
  let raw = @pdfio.bytes_of_list([0xFF])
  let res : Result[@pdfio.MutableBytes, Error] = try? encode_ccittg4(
    8,
    1,
    raw,
    im="magick",
  )
  assert_true(res is Err(_))
}
