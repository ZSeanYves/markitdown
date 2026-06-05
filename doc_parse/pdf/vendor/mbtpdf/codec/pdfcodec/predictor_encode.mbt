///|
/// Encode predictor.
fn sub_mod(a : Int, b : Int) -> Int {
  let mut delta = a - b
  if delta < 0 {
    delta = delta + 256
  }
  delta
}

///|
fn paeth(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = (p - a).abs()
  let pb = (p - b).abs()
  let pc = (p - c).abs()
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
fn encode_png_filter(
  current : Array[Int],
  prior : Array[Int],
  bytes_per_pixel : Int,
  filter : Int,
) -> Array[Int] {
  let out = Array::new(capacity=current.length())
  for i in 0..<current.length() {
    let left = if i < bytes_per_pixel {
      0
    } else {
      current[i - bytes_per_pixel]
    }
    let up = if i < prior.length() { prior[i] } else { 0 }
    let up_left = if i < bytes_per_pixel {
      0
    } else {
      prior[i - bytes_per_pixel]
    }
    let predicted = match filter {
      0 => 0
      1 => left
      2 => up
      3 => (left + up) / 2
      4 => paeth(left, up, up_left)
      _ => 0
    }
    out.push(sub_mod(current[i], predicted))
  }
  out
}

///|
fn predictor_cost(values : Array[Int]) -> Int {
  let mut total = 0
  for v in values {
    let signed = if v > 127 { v - 256 } else { v }
    total = total + signed.abs()
  }
  total
}

///|
fn encode_png_line(
  current : Array[Int],
  prior : Array[Int],
  bytes_per_pixel : Int,
  pred : Int,
) -> (Int, Array[Int]) {
  let filter = if pred == 15 { -1 } else { pred - 10 }
  if filter >= 0 && filter <= 4 {
    let encoded = encode_png_filter(current, prior, bytes_per_pixel, filter)
    return (filter, encoded)
  }
  let mut best_filter = 0
  let mut best_encoded = encode_png_filter(current, prior, bytes_per_pixel, 0)
  let mut best_cost = predictor_cost(best_encoded)
  for f in 1..<=4 {
    let candidate = encode_png_filter(current, prior, bytes_per_pixel, f)
    let cost = predictor_cost(candidate)
    if cost < best_cost {
      best_cost = cost
      best_filter = f
      best_encoded = candidate
    }
  }
  (best_filter, best_encoded)
}

///|
fn encode_png_predictor(
  pred : Int,
  colors : Int,
  bpc : Int,
  columns : Int,
  stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  if bpc != 8 {
    raise CodecError::DecodeNotSupported("PNG predictor only supports 8bpc")
  }
  let scanline_width = (colors * bpc * columns + 7) / 8
  let bytes_per_pixel = (bpc * colors + 7) / 8
  let (output, data) = @pdfio.Output::of_bytes(4096)
  let lines = if scanline_width == 0 {
    0
  } else {
    @pdfio.bytes_size(stream) / scanline_width
  }
  let prior = Array::make(scanline_width, 0)
  for line in 0..<lines {
    let current = Array::make(scanline_width, 0)
    for i in 0..<scanline_width {
      current[i] = @pdfio.bget(stream, line * scanline_width + i)
    }
    let (filter, encoded) = encode_png_line(
      current, prior, bytes_per_pixel, pred,
    )
    (output.output_byte)(filter)
    for v in encoded {
      (output.output_byte)(v)
    }
    for i in 0..<scanline_width {
      prior[i] = current[i]
    }
  }
  output.extract_bytes(data)
}

///|
fn encode_tiff_predictor(
  colors : Int,
  bpc : Int,
  columns : Int,
  stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  if bpc != 8 {
    raise CodecError::DecodeNotSupported("TIFF predictor only supports 8bpc")
  }
  let bytes_per_pixel = (bpc * colors + 7) / 8
  let scanline_width = (colors * bpc * columns + 7) / 8
  let out = stream.copy()
  let lines = if scanline_width == 0 {
    0
  } else {
    @pdfio.bytes_size(stream) / scanline_width
  }
  for line in 0..<lines {
    let line_start = line * scanline_width
    for p in bytes_per_pixel..<scanline_width {
      let curr = @pdfio.bget(stream, line_start + p)
      let left = @pdfio.bget(stream, line_start + p - bytes_per_pixel)
      out[line_start + p] = sub_mod(curr, left).to_byte()
    }
  }
  out
}

///|
fn encode_predictor(
  _pred : Int,
  _colors : Int,
  _bpc : Int,
  _columns : Int,
  _stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let pred = _pred
  let colors = _colors
  let bpc = _bpc
  let columns = _columns
  let stream = _stream
  match pred {
    2 => encode_tiff_predictor(colors, bpc, columns, stream)
    10 | 11 | 12 | 13 | 14 | 15 =>
      encode_png_predictor(pred, colors, bpc, columns, stream)
    _ =>
      raise CodecError::DecodeNotSupported(
        "encode_predictor: not supported - \{pred}",
      )
  }
}

///|
fn decode_scanline_pair(
  prior_decoded : Array[Int],
  current : Array[Int],
  pred : Int,
  bytes_per_pixel : Int,
) -> Array[Int] raise CodecError {
  let output = current.copy()
  let get0 = (arr : Array[Int], idx : Int) => if idx < 0 { 0 } else { arr[idx] }
  match pred {
    0 => ()
    1 =>
      for i in 0..<output.length() {
        output[i] = (get0(current, i) + get0(output, i - bytes_per_pixel)) % 256
      }
    2 =>
      for i in 0..<output.length() {
        output[i] = (get0(current, i) + get0(prior_decoded, i)) % 256
      }
    3 =>
      for i in 0..<output.length() {
        let left = get0(output, i - bytes_per_pixel)
        let up = get0(prior_decoded, i)
        output[i] = (get0(current, i) + (left + up) / 2) % 256
      }
    4 => {
      let paeth = (a : Int, b : Int, c : Int) => {
        let p = a + b - c
        let pa = (p - a).abs()
        let pb = (p - b).abs()
        let pc = (p - c).abs()
        if pa <= pb && pa <= pc {
          a
        } else if pb <= pc {
          b
        } else {
          c
        }
      }
      for i in 0..<output.length() {
        let curr = get0(current, i)
        let left = get0(output, i - bytes_per_pixel)
        let up = get0(prior_decoded, i)
        let up_left = get0(prior_decoded, i - bytes_per_pixel)
        output[i] = (curr + paeth(left, up, up_left)) % 256
      }
    }
    _ => raise CodecError::DecodeNotSupported("unknown PNG predictor")
  }
  output
}
