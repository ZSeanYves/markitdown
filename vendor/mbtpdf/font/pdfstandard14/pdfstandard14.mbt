///|
/// The 14 Standard PDF Fonts (Widths and Kerns).

///|
pub struct PdfStandard14 {
  unit : Unit
}

///|
pub fn PdfStandard14::new() -> PdfStandard14 {
  { unit: () }
}

///|
type AfmTables = (
  Map[String, String],
  Map[Int, Int],
  Map[(Int, Int), Int],
  Map[String, Int],
)

///|
fn read_afm(afm : Array[Byte]) -> AfmTables raise {
  let decompressed = @pdfio.string_of_bytes(
    @pdfcodec.PdfCodec::new().decode_flate(afm),
  )
  let (headers, ws, ks, ws_prime) = @pdfafm.PdfAfm::new().read(
    @pdfio.Input::of_string(decompressed),
  )
  (
    @pdfutil.PdfUtil::new().hashtable_of_dictionary(headers),
    @pdfutil.PdfUtil::new().hashtable_of_dictionary(ws),
    @pdfutil.PdfUtil::new().hashtable_of_dictionary(
      ks.map(pair => ((pair.0, pair.1), pair.2)),
    ),
    @pdfutil.PdfUtil::new().hashtable_of_dictionary(ws_prime),
  )
}

///|
let tables : Array[(@pdffont.StandardFont, () -> AfmTables raise)] = [
  (
    @pdffont.StandardFont::TimesRoman,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().times_roman_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::TimesBold,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().times_bold_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::TimesItalic,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().times_italic_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::TimesBoldItalic,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().times_bold_italic_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::Helvetica,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().helvetica_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::HelveticaBold,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().helvetica_bold_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::HelveticaOblique,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().helvetica_oblique_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::HelveticaBoldOblique,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().helvetica_bold_oblique_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::Courier,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().courier_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::CourierBold,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().courier_bold_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::CourierOblique,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().courier_oblique_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::CourierBoldOblique,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().courier_bold_oblique_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::Symbol,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().symbol_afm(),
    )),
  ),
  (
    @pdffont.StandardFont::ZapfDingbats,
    @pdfutil.PdfUtil::new().memoize(() => read_afm(
      @pdfafmdata.PdfAfmData::new().zapf_dingbats_afm(),
    )),
  ),
]

///|
fn lookup_tables(font : @pdffont.StandardFont) -> AfmTables raise {
  for entry in tables {
    if entry.0 == font {
      return (entry.1)()
    }
  }
  fail("standard14: missing font data")
}

///|
pub fn PdfStandard14::baseline_adjustment(
  _self : PdfStandard14,
  font : @pdffont.StandardFont,
) -> Int {
  match font {
    @pdffont.StandardFont::TimesRoman => 662 / 2
    @pdffont.StandardFont::TimesBold => 676 / 2
    @pdffont.StandardFont::TimesItalic => 653 / 2
    @pdffont.StandardFont::TimesBoldItalic => 669 / 2
    @pdffont.StandardFont::Helvetica => 718 / 2
    @pdffont.StandardFont::HelveticaBold => 718 / 2
    @pdffont.StandardFont::HelveticaOblique => 718 / 2
    @pdffont.StandardFont::HelveticaBoldOblique => 718 / 2
    @pdffont.StandardFont::Courier => 562 / 2
    @pdffont.StandardFont::CourierBold => 562 / 2
    @pdffont.StandardFont::CourierOblique => 562 / 2
    @pdffont.StandardFont::CourierBoldOblique => 562 / 2
    @pdffont.StandardFont::Symbol => 673 / 2
    @pdffont.StandardFont::ZapfDingbats => 705 / 2
  }
}

///|
fn find_kern(kerns : Map[(Int, Int), Int], key : (Int, Int)) -> Int {
  match kerns.get(key) {
    Some(value) => value
    None => 0
  }
}

///|
fn find_width(
  widths : Map[Int, Int],
  charname_to_width : Map[String, Int],
  encoding : @pdffont.Encoding,
  encoding_table : Map[Int, String],
  code : Int,
) -> Int raise {
  match encoding {
    @pdffont.Encoding::ImplicitInFontFile =>
      match widths.get(code) {
        Some(value) => value
        None => 0
      }
    _ => {
      let charname = match encoding_table.get(code) {
        Some(value) => value
        None => "/space"
      }
      let stripped = match charname.get_char(0) {
        Some('/') => charname[1:].to_string()
        _ => charname
      }
      match charname_to_width.get(stripped) {
        Some(value) => value
        None => 0
      }
    }
  }
}

///|
fn width(
  dokern : Bool,
  widths : Map[Int, Int],
  charname_to_width : Map[String, Int],
  encoding : @pdffont.Encoding,
  encoding_table : Map[Int, String],
  kerns : Map[(Int, Int), Int],
  codes : Array[Int],
) -> Int raise {
  if codes.length() == 0 {
    return 0
  }
  let mut total = 0
  for i in 0..<codes.length() {
    let h = codes[i]
    total = total +
      find_width(widths, charname_to_width, encoding, encoding_table, h)
    if dokern && i + 1 < codes.length() {
      total = total + find_kern(kerns, (h, codes[i + 1]))
    }
  }
  total
}

///|
pub fn PdfStandard14::textwidth(
  _self : PdfStandard14,
  dokern : Bool,
  encoding : @pdffont.Encoding,
  font : @pdffont.StandardFont,
  s : String,
) -> Int raise {
  let (_, widths, kerns, charname_to_width) = lookup_tables(font)
  let encoding_table = @pdffont.Encoding::table(encoding)
  let codes = Array::new(capacity=s.length())
  for c in s {
    codes.push(c.to_int())
  }
  width(
    dokern, widths, charname_to_width, encoding, encoding_table, kerns, codes,
  )
}

///|
pub fn PdfStandard14::afm_data(
  _self : PdfStandard14,
  font : @pdffont.StandardFont,
) -> AfmTables raise {
  lookup_tables(font)
}

///|
pub fn PdfStandard14::stemv_of_standard_font(
  _self : PdfStandard14,
  font : @pdffont.StandardFont,
) -> Int {
  match font {
    @pdffont.StandardFont::TimesRoman => 116
    @pdffont.StandardFont::TimesBold => 122
    @pdffont.StandardFont::TimesItalic => 105
    @pdffont.StandardFont::TimesBoldItalic => 108
    @pdffont.StandardFont::Helvetica => 114
    @pdffont.StandardFont::HelveticaBold => 123
    @pdffont.StandardFont::HelveticaOblique => 127
    @pdffont.StandardFont::HelveticaBoldOblique => 136
    @pdffont.StandardFont::Courier => 88
    @pdffont.StandardFont::CourierBold => 93
    @pdffont.StandardFont::CourierOblique => 100
    @pdffont.StandardFont::CourierBoldOblique => 104
    @pdffont.StandardFont::Symbol => 0
    @pdffont.StandardFont::ZapfDingbats => 125
  }
}

///|
pub fn PdfStandard14::flags_of_standard_font(
  _self : PdfStandard14,
  font : @pdffont.StandardFont,
) -> Int {
  match font {
    @pdffont.StandardFont::Symbol => 65541
    @pdffont.StandardFont::ZapfDingbats => 4
    @pdffont.StandardFont::Courier
    | @pdffont.StandardFont::CourierBold
    | @pdffont.StandardFont::CourierOblique
    | @pdffont.StandardFont::CourierBoldOblique => 33
    _ => 32
  }
}
