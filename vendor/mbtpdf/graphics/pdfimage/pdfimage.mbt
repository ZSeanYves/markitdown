///|
/// Image extraction and decoding helpers.

///|
pub(all) enum PixelLayout {
  BPP1
  BPP8
  BPP24
  BPP48
} derive(Debug)

///|
pub(all) enum Image {
  JPEG(@pdfio.MutableBytes, Array[Double]?)
  JPEG2000(@pdfio.MutableBytes, Array[Double]?)
  JBIG2(@pdfio.MutableBytes, Array[Double]?, Int?)
  Raw(Int, Int, PixelLayout, @pdfio.MutableBytes)
} derive(Debug)

///|
type PdfObject = @pdf.PdfObject

///|
fn odd(n : Int) -> Bool {
  n % 2 != 0
}

///|
fn fmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn toint(f : Double) -> Int {
  f.to_int()
}

///|
fn invert_bits(bytes : @pdfio.MutableBytes) -> Unit {
  for i in 0..<@pdfio.bytes_size(bytes) {
    @pdfio.bset(bytes, i, @pdfio.bget(bytes, i) ^ 255)
  }
}

///|
fn decode(
  fs : Array[Double],
  bpc : Int,
  image : @pdfio.MutableBytes,
) -> Unit raise {
  if fs.length() == 0 {
    return
  }
  if odd(fs.length()) {
    raise @pdf.PdfError::Msg("Bad /Decode")
  }
  let mut ident = true
  for i in 0..<(fs.length() / 2) {
    if fs[i * 2] != 0.0 || fs[i * 2 + 1] != 1.0 {
      ident = false
    }
  }
  if ident {
    return
  }
  let max_val = (1 << bpc) - 1
  let interpolate = (dmin : Double, dmax : Double, x : Int) => if max_val <= 0 {
    0
  } else {
    let numerator = Double::from_int(x) * (dmax - dmin)
    (dmin + numerator / Double::from_int(max_val)).to_int()
  }
  let pairs = Array::new(capacity=fs.length() / 2)
  for i in 0..<(fs.length() / 2) {
    pairs.push((fs[i * 2], fs[i * 2 + 1]))
  }
  match bpc {
    1 => invert_bits(image)
    2 => ()
    4 => ()
    8 =>
      for p in 0..<@pdfio.bytes_size(image) {
        let pair = pairs[p % pairs.length()]
        let value = interpolate(pair.0, pair.1, @pdfio.bget(image, p))
        @pdfio.bset(image, p, value)
      }
    16 => ()
    _ => raise @pdf.PdfError::Msg("Bad /Decode")
  }
}

///|
fn real_array(values : Array[Double]) -> Array[PdfObject] {
  let out = Array::new(capacity=values.length())
  for v in values {
    out.push(PdfObject::Real(v))
  }
  out
}

///|
fn repeat_decode_pairs(count : Int) -> Array[PdfObject] {
  let out = Array::new(capacity=count * 2)
  for _ in 0..<count {
    out.push(PdfObject::Real(0.0))
    out.push(PdfObject::Real(1.0))
  }
  out
}

///|
fn decode_defaults(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  entry : @pdf.PdfObject?,
  image : @pdf.PdfObject,
) -> @pdf.PdfObject? raise {
  match entry {
    None =>
      match pdf.lookup_direct("/ColorSpace", image) {
        None => None
        Some(cspace) =>
          match @pdfspace.ColourSpace::read(pdf, resources, cspace) {
            @pdfspace.ColourSpace::DeviceGray
            | @pdfspace.ColourSpace::CalGray(_, _, _)
            | @pdfspace.ColourSpace::Separation(_, _, _) =>
              Some(
                PdfObject::Array([PdfObject::Real(0.0), PdfObject::Real(1.0)]),
              )
            @pdfspace.ColourSpace::DeviceRGB
            | @pdfspace.ColourSpace::CalRGB(_, _, _, _) =>
              Some(
                PdfObject::Array([
                  PdfObject::Real(0.0),
                  PdfObject::Real(1.0),
                  PdfObject::Real(0.0),
                  PdfObject::Real(1.0),
                  PdfObject::Real(0.0),
                  PdfObject::Real(1.0),
                ]),
              )
            @pdfspace.ColourSpace::DeviceCMYK =>
              Some(
                PdfObject::Array([
                  PdfObject::Real(0.0),
                  PdfObject::Real(1.0),
                  PdfObject::Real(0.0),
                  PdfObject::Real(1.0),
                  PdfObject::Real(0.0),
                  PdfObject::Real(1.0),
                  PdfObject::Real(0.0),
                  PdfObject::Real(1.0),
                ]),
              )
            @pdfspace.ColourSpace::Lab(_, _, range) => {
              let values = Array::new(capacity=range.length() + 2)
              values.push(PdfObject::Real(0.0))
              values.push(PdfObject::Real(1.0))
              values.append(real_array(range))
              Some(PdfObject::Array(values))
            }
            @pdfspace.ColourSpace::ICCBased(icc) =>
              Some(PdfObject::Array(real_array(icc.icc_range)))
            @pdfspace.ColourSpace::Indexed(_, _) =>
              Some(
                PdfObject::Array([PdfObject::Real(0.0), PdfObject::Real(1.0)]),
              )
            @pdfspace.ColourSpace::Pattern
            | @pdfspace.ColourSpace::PatternWithBaseColourspace(_) => None
            @pdfspace.ColourSpace::DeviceN(names, _, _, _) =>
              Some(PdfObject::Array(repeat_decode_pairs(names.length())))
          }
      }
    Some(_) =>
      match pdf.lookup_direct("/ColorSpace", image) {
        None => entry
        Some(cspace) =>
          match @pdfspace.ColourSpace::read(pdf, resources, cspace) {
            @pdfspace.ColourSpace::Indexed(_, _) => None
            _ => entry
          }
      }
  }
}

///|
fn decode_to_image(pdf : @pdf.Pdf, stream : @pdf.PdfObject) -> Unit raise {
  fn is_direct_image_filter(name : @pdf.PdfName) -> Bool {
    name.equal_string_bytes("/DCTDecode") ||
    name.equal_string_bytes("/DCT") ||
    name.equal_string_bytes("/JBIG2Decode") ||
    name.equal_string_bytes("/JPXDecode")
  }

  match (stream : @pdf.PdfObject) {
    Stream(r) => {
      let (dict, _) = r.val
      match pdf.lookup_direct("/Filter", dict) {
        None => ()
        Some(Array([])) => ()
        Some(Name(n)) if is_direct_image_filter(n) => ()
        Some(Array([Name(n)])) if is_direct_image_filter(n) => ()
        _ => {
          @pdfcodec.PdfCodec::new().decode_pdfstream_onestage(pdf, stream)
          decode_to_image(pdf, stream)
        }
      }
    }
    _ => raise @pdf.PdfError::Msg("decode_to_image: bad stream")
  }
}

///|
fn rgb_of_cmyk(c : Int, m : Int, y : Int, k : Int) -> (Int, Int, Int) {
  let c = Double::from_int(c)
  let m = Double::from_int(m)
  let y = Double::from_int(y)
  let k = Double::from_int(k)
  let r = 255.0 - fmin(255.0, c / 255.0 * (255.0 - k) + k)
  let g = 255.0 - fmin(255.0, m / 255.0 * (255.0 - k) + k)
  let b = 255.0 - fmin(255.0, y / 255.0 * (255.0 - k) + k)
  (toint(r), toint(g), toint(b))
}

///|
fn read_cmyk_8bpp_as_rgb24(
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes {
  let out = @pdfio.mkbytes(width * height * 3)
  for p in 0..<(width * height) {
    let c = @pdfio.bget(data, p * 4)
    let m = @pdfio.bget(data, p * 4 + 1)
    let y = @pdfio.bget(data, p * 4 + 2)
    let k = @pdfio.bget(data, p * 4 + 3)
    let (r, g, b) = rgb_of_cmyk(c, m, y, k)
    @pdfio.bset(out, p * 3, r)
    @pdfio.bset(out, p * 3 + 1, g)
    @pdfio.bset(out, p * 3 + 2, b)
  }
  out
}

///|
fn read_gray_8bpp_as_rgb24(
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes {
  let out = @pdfio.mkbytes(width * height * 3)
  for p in 0..<(width * height) {
    let v = @pdfio.bget(data, p)
    @pdfio.bset(out, p * 3, v)
    @pdfio.bset(out, p * 3 + 1, v)
    @pdfio.bset(out, p * 3 + 2, v)
  }
  out
}

///|
fn read_1bpp_as_rgb24(
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes {
  let out = @pdfio.mkbytes(width * height * 3)
  let row_bytes = (width + 7) / 8
  let mut out_pos = 0
  for row in 0..<height {
    let row_base = row * row_bytes
    for x in 0..<width {
      let byte = @pdfio.bget(data, row_base + x / 8)
      let bit = 7 - x % 8
      let v = if ((byte >> bit) & 1) == 1 { 255 } else { 0 }
      @pdfio.bset(out, out_pos, v)
      @pdfio.bset(out, out_pos + 1, v)
      @pdfio.bset(out, out_pos + 2, v)
      out_pos = out_pos + 3
    }
  }
  out
}

///|
fn read_4bpp_gray_as_rgb24(
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes {
  let out = @pdfio.mkbytes(width * height * 3)
  let row_bytes = (width + 1) / 2
  let mut out_pos = 0
  for row in 0..<height {
    let row_base = row * row_bytes
    for x in 0..<width {
      let byte = @pdfio.bget(data, row_base + x / 2)
      let nibble = if x % 2 == 0 { byte >> 4 } else { byte & 15 }
      let col = nibble * 17
      @pdfio.bset(out, out_pos, col)
      @pdfio.bset(out, out_pos + 1, col)
      @pdfio.bset(out, out_pos + 2, col)
      out_pos = out_pos + 3
    }
  }
  out
}

///|
fn read_8bpp_indexed_as_rgb24(
  table : Map[Int, Array[Int]],
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  let out = @pdfio.mkbytes(width * height * 3)
  for x in 0..<(width * height) {
    let key = @pdfio.bget(data, x)
    match table.get(key) {
      Some([r, g, b]) => {
        @pdfio.bset(out, x * 3, r)
        @pdfio.bset(out, x * 3 + 1, g)
        @pdfio.bset(out, x * 3 + 2, b)
      }
      _ => raise @pdf.PdfError::Msg("read_8bpp_indexed_as_rgb24")
    }
  }
  out
}

///|
fn clamp10(f : Double) -> Double {
  if f > 1.0 {
    1.0
  } else if f < 0.0 {
    0.0
  } else {
    f
  }
}

///|
fn xyz_of_lab(
  l_in : Double,
  a_in : Double,
  b_in : Double,
  xw : Double,
  yw : Double,
  zw : Double,
) -> (Double, Double, Double) {
  let g = (x : Double) => if x >= 6.0 / 29.0 {
    x * x * x
  } else {
    108.0 / 841.0 * (x - 4.0 / 29.0)
  }
  let l = (l_in + 16.0) / 116.0 + a_in / 500.0
  let m = (l_in + 16.0) / 116.0
  let n = (l_in + 16.0) / 116.0 - b_in / 200.0
  (clamp10(xw * g(l)), clamp10(yw * g(m)), clamp10(zw * g(n)))
}

///|
fn rgb_of_xyz(x : Double, y : Double, z : Double) -> (Double, Double, Double) {
  (
    clamp10(2.5623 * x + -1.1661 * y + -0.3962 * z),
    clamp10(-1.0215 * x + 1.9778 * y + 0.0437 * z),
    clamp10(0.0752 * x + -0.2562 * y + 1.1810 * z),
  )
}

///|
fn convert_lab_to_rgb(
  width : Int,
  height : Int,
  p : (Double, Double, Double),
  _q : (Double, Double, Double),
  _rs : Array[Double],
  data : @pdfio.MutableBytes,
) -> Unit {
  let (xw, yw, zw) = p
  for idx in 0..<(width * height) {
    let l = @pdfio.bget(data, idx * 3) - 127
    let a = @pdfio.bget(data, idx * 3 + 1) - 127
    let b = @pdfio.bget(data, idx * 3 + 2) - 127
    let l_in = Double::from_int(l) / 255.0
    let a_in = Double::from_int(a) / 255.0
    let b_in = Double::from_int(b) / 255.0
    let (x, y, z) = xyz_of_lab(l_in, a_in, b_in, xw, yw, zw)
    let (r, g, b_out) = rgb_of_xyz(x, y, z)
    let r_out = toint(r * 255.0)
    let g_out = toint(g * 255.0)
    let b_out = toint(b_out * 255.0)
    @pdfio.bset(data, idx * 3, r_out)
    @pdfio.bset(data, idx * 3 + 1, g_out)
    @pdfio.bset(data, idx * 3 + 2, b_out)
  }
}

///|
fn read_8bpp_lab_indexed_as_rgb24(
  table : Map[Int, Array[Int]],
  width : Int,
  height : Int,
  p : (Double, Double, Double),
  q : (Double, Double, Double),
  rs : Array[Double],
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  let out = read_8bpp_indexed_as_rgb24(table, width, height, data)
  convert_lab_to_rgb(width, height, p, q, rs, out)
  out
}

///|
fn read_8bpp_cmyk_indexed_as_rgb24(
  table : Map[Int, Array[Int]],
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  let out = @pdfio.mkbytes(width * height * 3)
  for x in 0..<(width * height) {
    let key = @pdfio.bget(data, x)
    match table.get(key) {
      Some([c, m, y, k]) => {
        let (r, g, b) = rgb_of_cmyk(c, m, y, k)
        @pdfio.bset(out, x * 3, r)
        @pdfio.bset(out, x * 3 + 1, g)
        @pdfio.bset(out, x * 3 + 2, b)
      }
      _ => raise @pdf.PdfError::Msg("read_8bpp_indexed_as_rgb24")
    }
  }
  out
}

///|
fn read_4bpp_indexed_as_rgb24(
  table : Map[Int, Array[Int]],
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  let out = @pdfio.mkbytes(width * height * 3)
  let mut pos_in = 0
  let mut pos_out = 0
  let row_bytes = (width + 1) / 2
  let mut row = 0
  while row < height {
    let mut byte = 0
    while byte < row_bytes {
      let value = @pdfio.bget(data, pos_in)
      let p1 = value >> 4
      let p2 = value & 15
      match table.get(p1) {
        Some([r1, g1, b1]) => {
          @pdfio.bset(out, pos_out, r1)
          pos_out = pos_out + 1
          @pdfio.bset(out, pos_out, g1)
          pos_out = pos_out + 1
          @pdfio.bset(out, pos_out, b1)
          pos_out = pos_out + 1
        }
        _ => raise @pdf.PdfError::Msg("read_4bpp_indexed_as_rgb24")
      }
      if !(odd(width) && byte == row_bytes - 1) {
        match table.get(p2) {
          Some([r2, g2, b2]) => {
            @pdfio.bset(out, pos_out, r2)
            pos_out = pos_out + 1
            @pdfio.bset(out, pos_out, g2)
            pos_out = pos_out + 1
            @pdfio.bset(out, pos_out, b2)
            pos_out = pos_out + 1
          }
          _ => raise @pdf.PdfError::Msg("read_4bpp_indexed_as_rgb24")
        }
      }
      pos_in = pos_in + 1
      byte = byte + 1
    }
    row = row + 1
  }
  out
}

///|
fn read_4bpp_cmyk_indexed_as_rgb24(
  table : Map[Int, Array[Int]],
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  let out = @pdfio.mkbytes(width * height * 3)
  let mut pos_in = 0
  let mut pos_out = 0
  let row_bytes = (width + 1) / 2
  let mut row = 0
  while row < height {
    let mut byte = 0
    while byte < row_bytes {
      let value = @pdfio.bget(data, pos_in)
      let p1 = value >> 4
      let p2 = value & 15
      match table.get(p1) {
        Some([c, m, y, k]) => {
          let (r1, g1, b1) = rgb_of_cmyk(c, m, y, k)
          @pdfio.bset(out, pos_out, r1)
          pos_out = pos_out + 1
          @pdfio.bset(out, pos_out, g1)
          pos_out = pos_out + 1
          @pdfio.bset(out, pos_out, b1)
          pos_out = pos_out + 1
        }
        _ => raise @pdf.PdfError::Msg("read_4bpp_cmyk_indexed_as_rgb24")
      }
      if !(odd(width) && byte == row_bytes - 1) {
        match table.get(p2) {
          Some([c, m, y, k]) => {
            let (r2, g2, b2) = rgb_of_cmyk(c, m, y, k)
            @pdfio.bset(out, pos_out, r2)
            pos_out = pos_out + 1
            @pdfio.bset(out, pos_out, g2)
            pos_out = pos_out + 1
            @pdfio.bset(out, pos_out, b2)
            pos_out = pos_out + 1
          }
          _ => raise @pdf.PdfError::Msg("read_4bpp_cmyk_indexed_as_rgb24")
        }
      }
      pos_in = pos_in + 1
      byte = byte + 1
    }
    row = row + 1
  }
  out
}

///|
fn read_separation_cmyk_as_rgb24(
  fnn : @pdffun.PdfFunction,
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  let out = @pdfio.mkbytes(width * height * 3)
  for p in 0..<(width * height) {
    let v = @pdfio.bget(data, p)
    try {
      match fnn.eval([Double::from_int(v) / 255.0]) {
        [c, y, m, k] => {
          let c = toint(c * 255.0)
          let m = toint(m * 255.0)
          let y = toint(y * 255.0)
          let k = toint(k * 255.0)
          let (r, g, b) = rgb_of_cmyk(c, m, y, k)
          @pdfio.bset(out, p * 3, r)
          @pdfio.bset(out, p * 3 + 1, g)
          @pdfio.bset(out, p * 3 + 2, b)
        }
        _ => raise @pdf.PdfError::Msg("Bad tint transform function")
      }
    } catch {
      @pdffun.BadFunctionEvaluation::Msg(msg) =>
        raise @pdf.PdfError::Msg("Bad tint transform function " + msg)
      _ => raise @pdf.PdfError::Msg("Bad tint transform function")
    }
  }
  out
}

///|
fn is_rgb_base(space : @pdfspace.ColourSpace) -> Bool {
  match space {
    @pdfspace.ColourSpace::DeviceRGB
    | @pdfspace.ColourSpace::CalRGB(_, _, _, _) => true
    @pdfspace.ColourSpace::ICCBased(icc) =>
      icc.icc_alternate
      is (@pdfspace.ColourSpace::DeviceRGB
      | @pdfspace.ColourSpace::CalRGB(_, _, _, _))
    @pdfspace.ColourSpace::DeviceN(_, base, _, _) =>
      match base {
        @pdfspace.ColourSpace::DeviceRGB
        | @pdfspace.ColourSpace::CalRGB(_, _, _, _) => true
        @pdfspace.ColourSpace::ICCBased(icc) =>
          icc.icc_alternate
          is (@pdfspace.ColourSpace::DeviceRGB
          | @pdfspace.ColourSpace::CalRGB(_, _, _, _))
        _ => false
      }
    _ => false
  }
}

///|
fn is_cmyk_base(space : @pdfspace.ColourSpace) -> Bool {
  match space {
    @pdfspace.ColourSpace::DeviceCMYK => true
    @pdfspace.ColourSpace::ICCBased(icc) =>
      icc.icc_alternate is @pdfspace.ColourSpace::DeviceCMYK
    @pdfspace.ColourSpace::DeviceN(_, base, _, _) =>
      match base {
        @pdfspace.ColourSpace::DeviceCMYK => true
        @pdfspace.ColourSpace::ICCBased(icc) =>
          icc.icc_alternate is @pdfspace.ColourSpace::DeviceCMYK
        _ => false
      }
    _ => false
  }
}

///|
fn bpc_value(bpc : @pdf.PdfObject?) -> Int? {
  match bpc {
    Some(Integer(n)) => Some(n)
    _ => None
  }
}

///|

///|
pub fn Image::from_raw(
  size : Int,
  colspace : @pdfspace.ColourSpace,
  bpc : @pdf.PdfObject?,
  width : Int,
  height : Int,
  data : @pdfio.MutableBytes,
) -> Image raise {
  let bpc_val = bpc_value(bpc)
  if bpc_val is Some(8) {
    match colspace {
      @pdfspace.ColourSpace::DeviceRGB
      | @pdfspace.ColourSpace::CalRGB(_, _, _, _) =>
        if size >= width * height * 3 {
          return Image::Raw(width, height, PixelLayout::BPP24, data)
        }
      @pdfspace.ColourSpace::DeviceCMYK =>
        if size >= width * height * 4 {
          return Image::Raw(
            width,
            height,
            PixelLayout::BPP24,
            read_cmyk_8bpp_as_rgb24(width, height, data),
          )
        }
      @pdfspace.ColourSpace::DeviceGray
      | @pdfspace.ColourSpace::CalGray(_, _, _) =>
        if size >= width * height {
          return Image::Raw(
            width,
            height,
            PixelLayout::BPP24,
            read_gray_8bpp_as_rgb24(width, height, data),
          )
        }
      @pdfspace.ColourSpace::Indexed(base, table) => {
        if size >= width * height && is_rgb_base(base) {
          return Image::Raw(
            width,
            height,
            PixelLayout::BPP24,
            read_8bpp_indexed_as_rgb24(table, width, height, data),
          )
        }
        if size >= width * height && is_cmyk_base(base) {
          return Image::Raw(
            width,
            height,
            PixelLayout::BPP24,
            read_8bpp_cmyk_indexed_as_rgb24(table, width, height, data),
          )
        }
        match base {
          @pdfspace.ColourSpace::Lab(p, q, rs) =>
            if size >= width * height / 2 {
              return Image::Raw(
                width,
                height,
                PixelLayout::BPP24,
                read_8bpp_lab_indexed_as_rgb24(
                  table, width, height, p, q, rs, data,
                ),
              )
            }
          _ => ()
        }
      }
      @pdfspace.ColourSpace::Separation(
        _,
        @pdfspace.ColourSpace::DeviceCMYK,
        fnn
      ) =>
        if size >= width * height {
          return Image::Raw(
            width,
            height,
            PixelLayout::BPP24,
            read_separation_cmyk_as_rgb24(fnn, width, height, data),
          )
        }
      _ => ()
    }
  }
  if bpc_val is Some(1) && size >= width * height / 8 {
    return Image::Raw(
      width,
      height,
      PixelLayout::BPP24,
      read_1bpp_as_rgb24(width, height, data),
    )
  }
  if bpc_val is Some(4) {
    match colspace {
      @pdfspace.ColourSpace::DeviceGray =>
        if size >= width * height / 2 {
          return Image::Raw(
            width,
            height,
            PixelLayout::BPP24,
            read_4bpp_gray_as_rgb24(width, height, data),
          )
        }
      @pdfspace.ColourSpace::Indexed(base, table) => {
        if size >= width * height / 2 && is_rgb_base(base) {
          return Image::Raw(
            width,
            height,
            PixelLayout::BPP24,
            read_4bpp_indexed_as_rgb24(table, width, height, data),
          )
        }
        if size >= width * height / 2 && is_cmyk_base(base) {
          return Image::Raw(
            width,
            height,
            PixelLayout::BPP24,
            read_4bpp_cmyk_indexed_as_rgb24(table, width, height, data),
          )
        }
      }
      _ => ()
    }
  }
  match colspace {
    @pdfspace.ColourSpace::ICCBased(icc) =>
      Image::from_raw(size, icc.icc_alternate, bpc, width, height, data)
    _ => raise @pdf.PdfError::Msg("No image")
  }
}

///|
pub fn Image::colspace(
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
  resources : @pdf.PdfObject,
) -> @pdfspace.ColourSpace raise {
  match pdf.lookup_direct_orelse("/ImageMask", "/IM", dict) {
    Some(Boolean(true)) => @pdfspace.ColourSpace::DeviceGray
    _ => {
      let colspace = pdf.lookup_direct_orelse("/ColorSpace", "/CS", dict)
      let space = match pdf.lookup_direct("/ColorSpace", resources) {
        Some(Dictionary(_) as dict_obj) =>
          match colspace {
            Some(Name(name)) =>
              match pdf.lookup_direct(name.to_string_bytes(), dict_obj) {
                Some(found) => found
                None => PdfObject::Name(name)
              }
            Some(c) => c
            None => raise @pdf.PdfError::Msg("Pdf image: no colourspace")
          }
        _ =>
          match colspace {
            Some(c) => c
            None => raise @pdf.PdfError::Msg("Pdf image: no colourspace")
          }
      }
      @pdfspace.ColourSpace::read(pdf, resources, space)
    }
  }
}

///|
pub fn Image::bpc(pdf : @pdf.Pdf, dict : @pdf.PdfObject) -> @pdf.PdfObject? {
  match pdf.lookup_direct_orelse("/BitsPerComponent", "/BPC", dict) {
    Some(bpc) => Some(bpc)
    None =>
      match pdf.lookup_direct("/ImageMask", dict) {
        Some(Boolean(true)) => Some(PdfObject::Integer(1))
        _ => None
      }
  }
}

///|

///|
pub fn Image::from_stream_data(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  width : Int,
  height : Int,
  dict : @pdf.PdfObject,
  data : @pdfio.MutableBytes,
) -> Image raise {
  let size = @pdfio.bytes_size(data)
  let space = Image::colspace(pdf, dict, resources)
  let bits = Image::bpc(pdf, dict)
  Image::from_raw(size, space, bits, width, height, data)
}

///|
pub fn Image::get_image_24bpp(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  stream : @pdf.PdfObject,
) -> Image raise {
  let stream = pdf.direct(stream)
  stream.getstream()
  let (streamdict, data) = match (stream : @pdf.PdfObject) {
    Stream(r) => {
      let (dict, payload) = r.val
      match (payload : @pdf.Stream) {
        Got(bytes) => (dict, bytes)
        _ => raise @pdf.PdfError::Msg("get_image_24bpp: bad stream")
      }
    }
    _ => raise @pdf.PdfError::Msg("get_image_24bpp: bad stream")
  }
  let width = match pdf.lookup_direct_orelse("/Width", "/W", streamdict) {
    Some(Integer(x)) => x
    _ => raise @pdf.PdfError::Msg("Malformed /Image width")
  }
  let height = match pdf.lookup_direct_orelse("/Height", "/H", streamdict) {
    Some(Integer(x)) => x
    _ => raise @pdf.PdfError::Msg("Malformed /Image height")
  }
  let bpc_val = match
    pdf.lookup_direct_orelse("/BitsPerComponent", "/BPC", streamdict) {
    Some(Integer(n)) => n
    _ => 0
  }
  decode_to_image(pdf, stream)
  let get_decode = () => {
    let decode_entry = pdf.lookup_direct_orelse("/Decode", "/D", streamdict)
    let decode_entry = decode_defaults(pdf, resources, decode_entry, streamdict)
    match decode_entry {
      Some(Array(nums)) => Some(nums.map(n => pdf.getnum(n)))
      _ => None
    }
  }
  fn is_dct_filter(name : @pdf.PdfName) -> Bool {
    name.equal_string_bytes("/DCTDecode") || name.equal_string_bytes("/DCT")
  }

  fn is_jbig2_filter(name : @pdf.PdfName) -> Bool {
    name.equal_string_bytes("/JBIG2Decode")
  }

  fn is_jpx_filter(name : @pdf.PdfName) -> Bool {
    name.equal_string_bytes("/JPXDecode")
  }

  match pdf.lookup_direct_orelse("/Filter", "/F", streamdict) {
    None | Some(Array([])) => {
      let raw = Image::from_stream_data(
        pdf, resources, width, height, streamdict, data,
      )
      let decode_entry = pdf.lookup_direct_orelse("/Decode", "/D", streamdict)
      let decode_entry = decode_defaults(
        pdf, resources, decode_entry, streamdict,
      )
      let floats = match decode_entry {
        Some(Array(elts)) => elts.map(e => pdf.getnum(e))
        None => []
        _ => raise @pdf.PdfError::Msg("Bad /Decode")
      }
      match raw {
        Image::Raw(_, _, _, img) =>
          if floats.length() > 0 {
            decode(floats, bpc_val, img)
          }
        _ => ()
      }
      raw
    }
    Some(Name(n)) if is_dct_filter(n) => Image::JPEG(data, get_decode())
    Some(Array([Name(n)])) if is_dct_filter(n) =>
      Image::JPEG(data, get_decode())
    Some(Name(n)) if is_jbig2_filter(n) => {
      let globals = match pdf.lookup_direct("/DecodeParms", streamdict) {
        Some(Dictionary(parms)) =>
          match PdfObject::Dictionary(parms).lookup_immediate("/JBIG2Globals") {
            Some(Indirect(i)) => Some(i)
            _ => None
          }
        _ => None
      }
      Image::JBIG2(data, get_decode(), globals)
    }
    Some(Array([Name(n)])) if is_jbig2_filter(n) => {
      let globals = match pdf.lookup_direct("/DecodeParms", streamdict) {
        Some(Dictionary(parms)) =>
          match PdfObject::Dictionary(parms).lookup_immediate("/JBIG2Globals") {
            Some(Indirect(i)) => Some(i)
            _ => None
          }
        _ => None
      }
      Image::JBIG2(data, get_decode(), globals)
    }
    Some(Name(n)) if is_jpx_filter(n) => Image::JPEG2000(data, get_decode())
    Some(Array([Name(n)])) if is_jpx_filter(n) =>
      Image::JPEG2000(data, get_decode())
    _ => raise @pdf.PdfError::Msg("decode_to_image")
  }
}
