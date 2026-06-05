///|
/// Decode predictor (placeholder).
fn decode_predictor(
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
  if pred == 2 {
    decode_tiff_predictor(colors, bpc, columns, stream)
  } else {
    decode_png_predictor(colors, bpc, columns, stream)
  }
}

///|
fn decode_tiff_predictor(
  colors : Int,
  bpc : Int,
  columns : Int,
  stream : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  if bpc != 8 {
    raise CodecError::DecodeNotSupported("TIFF predictor only supports 8bpc")
  }
  let scanline_width = (colors * bpc * columns + 7) / 8
  let out = stream.copy()
  let lines = if scanline_width == 0 {
    0
  } else {
    out.length() / scanline_width
  }
  for line in 0..<lines {
    let line_start = line * scanline_width
    for p in colors..<scanline_width {
      let val = (
          out[line_start + p - colors].to_int() + out[line_start + p].to_int()
        ) %
        256
      out[line_start + p] = val.to_byte()
    }
  }
  out
}

///|
fn decode_png_predictor(
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
  let mut pos = 0
  let prev_decoded = Array::make(scanline_width, 0)
  // Output is always <= input length (predictor bytes are dropped).
  let output : @pdfio.MutableBytes = Array::new(capacity=stream.length())
  while pos < stream.length() {
    let predictor = stream[pos].to_int()
    pos = pos + 1
    let curr = Array::make(scanline_width, 0)
    let mut i = 0
    while i < scanline_width && pos < stream.length() {
      curr[i] = stream[pos].to_int()
      pos = pos + 1
      i = i + 1
    }
    let decoded = decode_scanline_pair(
      prev_decoded, curr, predictor, bytes_per_pixel,
    )
    for v in decoded {
      output.push(v.to_byte())
    }
    for i in 0..<scanline_width {
      prev_decoded[i] = decoded[i]
    }
    if i < scanline_width {
      break
    }
  }
  output
}
