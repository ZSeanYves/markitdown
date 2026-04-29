///|
/// PDF font and encoding types.

///|
pub(all) struct Type3Glyphs {
  fontbbox : (Double, Double, Double, Double)
  fontmatrix : @pdftransform.TransformMatrix
  charprocs : Array[(String, @pdf.PdfObject)]
  type3_resources : @pdf.PdfObject
}

///|
pub(all) enum SimpleFontType {
  Type1
  MMType1
  Type3(Type3Glyphs)
  Truetype
}

///|
pub type FontMetrics = Array[Double]

///|
pub(all) enum FontFile {
  FontFile(Int)
  FontFile2(Int)
  FontFile3(Int)
} derive(Debug)

///|
pub(all) struct FontDescriptor {
  ascent : Double
  descent : Double
  avgwidth : Double
  maxwidth : Double
  flags : Int
  fontbbox : (Double, Double, Double, Double)
  italicangle : Double
  capheight : Double
  xheight : Double
  stemv : Double
  fontfile : FontFile?
  charset : Array[String]?
  tounicode : Map[Int, String]?
  tounicode_bytes : Map[String, String]?
}

///|
pub type Differences = Array[(String, Int)]

///|
pub(all) enum Encoding {
  ImplicitInFontFile
  StandardEncoding
  MacRomanEncoding
  WinAnsiEncoding
  MacExpertEncoding
  CustomEncoding(Encoding, Differences)
  FillUndefinedWithStandard(Encoding)
}

///|
pub(all) struct SimpleFont {
  fonttype : SimpleFontType
  basefont : String
  firstchar : Int
  lastchar : Int
  widths : Array[Int]
  fontdescriptor : FontDescriptor?
  fontmetrics : FontMetrics?
  encoding : Encoding
}

///|
pub(all) enum StandardFont {
  TimesRoman
  TimesBold
  TimesItalic
  TimesBoldItalic
  Helvetica
  HelveticaBold
  HelveticaOblique
  HelveticaBoldOblique
  Courier
  CourierBold
  CourierOblique
  CourierBoldOblique
  Symbol
  ZapfDingbats
} derive(Eq, Debug)

///|
pub fn StandardFont::to_string(self : StandardFont) -> String {
  match self {
    StandardFont::TimesRoman => "Times-Roman"
    StandardFont::TimesBold => "Times-Bold"
    StandardFont::TimesItalic => "Times-Italic"
    StandardFont::TimesBoldItalic => "Times-BoldItalic"
    StandardFont::Helvetica => "Helvetica"
    StandardFont::HelveticaBold => "Helvetica-Bold"
    StandardFont::HelveticaOblique => "Helvetica-Oblique"
    StandardFont::HelveticaBoldOblique => "Helvetica-BoldOblique"
    StandardFont::Courier => "Courier"
    StandardFont::CourierBold => "Courier-Bold"
    StandardFont::CourierOblique => "Courier-Oblique"
    StandardFont::CourierBoldOblique => "Courier-BoldOblique"
    StandardFont::Symbol => "Symbol"
    StandardFont::ZapfDingbats => "ZapfDingbats"
  }
}

///|
pub(all) struct CIDSystemInfo {
  registry : String
  ordering : String
  supplement : Int
} derive(Debug)

///|
pub(all) struct CompositeCIDFont {
  cid_system_info : CIDSystemInfo
  cid_basefont : String
  cid_fontdescriptor : FontDescriptor
  cid_widths : Array[(Int, Double)]
  cid_default_width : Int
}

///|
pub(all) enum CMapEncoding {
  Predefined(String)
  CMap(Int)
} derive(Debug)

///|
pub(all) enum Font {
  StandardFont(StandardFont, Encoding)
  SimpleFont(SimpleFont)
  CIDKeyedFont(String, CompositeCIDFont, CMapEncoding)
}

///|
pub fn SimpleFontType::to_string(self : SimpleFontType) -> String {
  match self {
    SimpleFontType::Type1 => "Type 1"
    SimpleFontType::MMType1 => "MM Type 1"
    SimpleFontType::Type3(glyphs) =>
      "Type 3: charprocs for" + glyphs.charprocs.map(pair => pair.0).join("")
    SimpleFontType::Truetype => "Truetype"
  }
}

///|
pub fn Encoding::to_string(self : Encoding) -> String {
  match self {
    Encoding::ImplicitInFontFile => "ImplicitInFontFile"
    Encoding::StandardEncoding => "StandardEncoding"
    Encoding::MacRomanEncoding => "MacRomanEncoding"
    Encoding::WinAnsiEncoding => "WinAnsiEncoding"
    Encoding::MacExpertEncoding => "MacExpertEncoding"
    Encoding::CustomEncoding(enc, diff) =>
      "CustomEncoding with base " +
      enc.to_string() +
      " and differences " +
      diff.map(pair => "\{pair.1} -> \{pair.0}, ").join("")
    Encoding::FillUndefinedWithStandard(enc) =>
      "FillUndefinedWithStandard " + enc.to_string()
  }
}

///|
pub fn SimpleFont::to_string(self : SimpleFont) -> String {
  "fonttype = " +
  self.fonttype.to_string() +
  "\nbasefont " +
  self.basefont +
  "\nencoding is " +
  self.encoding.to_string() +
  "\n"
}

///|
pub fn Font::to_string(self : Font) -> String {
  match self {
    Font::StandardFont(standard, _) => "StandardFont " + standard.to_string()
    Font::SimpleFont(simple) => "SimpleFont " + simple.to_string()
    Font::CIDKeyedFont(name, _, _) => "CIDKeyedFont " + name
  }
}
