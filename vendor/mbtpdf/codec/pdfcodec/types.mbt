///|
/// Supported stream encodings.
pub(all) enum Encoding {
  ASCIIHex
  ASCII85
  RunLength
  LZW(Int)
  Flate
  CCITT(Int, Int)
  CCITTG4(Int, Int)
} derive(Debug)

///|
pub struct PdfCodec {
  // Keep configuration on the codec instance instead of global `Ref` state.
  flate_level : Int
}

///|
pub fn PdfCodec::new(flate_level? : Int = 6) -> PdfCodec {
  { flate_level, }
}

///|
/// Predictors for decoded data.
pub(all) enum Predictor {
  TIFF2
  PNGNone
  PNGSub
  PNGUp
  PNGAverage
  PNGPaeth
  PNGOptimum
} derive(Debug)

///|
/// There was bad data.
pub suberror CodecError {
  CouldntDecodeStream(String)
  DecodeNotSupported(String)
}

///|
/// Decode a *single* stream filter stage by its `/Filter` name.
///
/// Why a trait?
/// - In PDF, filters are chosen dynamically by name (`/FlateDecode`, `/LZW`, ...).
/// - We want one well-documented place that defines what "decode one stage"
///   means, and reuse it from both:
///   - `PdfCodec::decode_pdfstream_onestage` (in-place stream decoding), and
///   - `PdfCodec::decode_from_bytes` (pure bytes -> bytes decoding).
/// - Implementing the trait for `@pdf.PdfName` keeps call sites readable:
///   `PdfFilterNameDecode::decode_stage(filter_name, codec, pdf, parms, bytes, ...)`.
///
/// Note: PDF names are byte sequences; `@pdf.PdfName` preserves the raw bytes.
///
/// Semantics:
/// - "One stage" means applying exactly the first filter in `/Filter` and the
///   corresponding entry in `/DecodeParms` (if any).
/// - `/Crypt` is treated as identity here (it returns the input bytes
///   unchanged). Real encryption/decryption is handled elsewhere.
/// - Some filters are intentionally unsupported in the synchronous path
///   (notably `/JBIG2Decode`), and must raise `CodecError::DecodeNotSupported`.
pub trait PdfFilterNameDecode {
  decode_stage(
    Self,
    ctx : PdfCodec,
    pdf : @pdf.Pdf,
    parms : @pdf.PdfObject?,
    data : @pdfio.MutableBytes,
    jbig2dec : String?,
  ) -> @pdfio.MutableBytes raise CodecError
}

///|
/// Encode data in FlateDecode.
pub fn PdfCodec::encode_flate(
  self : PdfCodec,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes {
  let mut pos = 0
  let input = (buf : @pdfio.MutableBytes) => {
    let remaining = data.length() - pos
    if remaining <= 0 {
      0
    } else {
      let n = if remaining < buf.length() { remaining } else { buf.length() }
      data[pos:pos + n].blit_to(buf)
      pos = pos + n
      n
    }
  }
  let out : @pdfio.MutableBytes = Array::new()
  let output = (buf : @pdfio.MutableBytes, length : Int) => out.append(
    buf[:length],
  )
  @pdfflate.PdfFlate::new().compress(
    level=self.flate_level,
    header=true,
    input,
    output,
  )
  out
}
