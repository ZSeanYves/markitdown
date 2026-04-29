///|
/// Font writing helpers.

///|
type PdfObject = @pdf.PdfObject

///|
pub fn PdfTextUtil::make_font(
  _self : PdfTextUtil,
  fontname : String,
  encoding : @pdffont.Encoding,
) -> @pdf.PdfObject {
  PdfObject::Dictionary([
    ("/Type", PdfObject::Name(@pdf.PdfName::of_string("/Font"))),
    ("/Subtype", PdfObject::Name(@pdf.PdfName::of_string("/Type1"))),
    (
      "/Encoding",
      PdfObject::Name(@pdf.PdfName::of_string("/" + encoding.to_string())),
    ),
    ("/BaseFont", PdfObject::Name(@pdf.PdfName::of_string("/" + fontname))),
  ])
}

///|
pub fn PdfText::write_encoding(
  self : PdfText,
  encoding : @pdffont.Encoding,
) -> Int raise {
  fn encoding_name(enc : @pdffont.Encoding) -> String? {
    match enc {
      StandardEncoding => Some("/StandardEncoding")
      MacRomanEncoding => Some("/MacRomanEncoding")
      WinAnsiEncoding => Some("/WinAnsiEncoding")
      MacExpertEncoding => Some("/MacExpertEncoding")
      CustomEncoding(inner, _) => encoding_name(inner)
      FillUndefinedWithStandard(inner) => encoding_name(inner)
      ImplicitInFontFile => None
    }
  }

  match encoding {
    StandardEncoding | MacRomanEncoding | WinAnsiEncoding | MacExpertEncoding => {
      let name = match encoding_name(encoding) {
        Some(value) => value
        None => raise @pdf.PdfError::Msg("write_encoding: missing name")
      }
      self.pdf.addobj(PdfObject::Name(@pdf.PdfName::of_string(name)))
    }
    FillUndefinedWithStandard(inner) => self.write_encoding(inner)
    CustomEncoding(base, diffs) => {
      let diff_array = Array::new()
      for diff in diffs {
        diff_array.push(PdfObject::Integer(diff.1))
        diff_array.push(PdfObject::Name(@pdf.PdfName::of_string(diff.0)))
      }
      let mut encoding_dict = PdfObject::Dictionary([
        ("/Type", PdfObject::Name(@pdf.PdfName::of_string("/Encoding"))),
        ("/Differences", PdfObject::Array(diff_array)),
      ])
      match encoding_name(base) {
        Some(name) =>
          encoding_dict = encoding_dict.add_entry(
            "/BaseEncoding",
            PdfObject::Name(@pdf.PdfName::of_string(name)),
          )
        None => ()
      }
      self.pdf.addobj(encoding_dict)
    }
    ImplicitInFontFile =>
      raise @pdf.PdfError::Msg("write_encoding: implicit encoding")
  }
}

///|
let tounicode_preamble : String =
  #|/CIDInit /ProcSet findresource begin
  #|12 dict begin
  #|begincmap
  #|/CIDSystemInfo <<
  #|  /Registry (Adobe)
  #|  /Ordering (UCS)
  #|  /Supplement 0
  #|>> def
  #|/CMapName /Adobe-Identity-UCS def
  #|/CMapType 2 def
  #|1 begincodespacerange
  #|<00><FF>
  #|endcodespacerange
  #|

///|
let tounicode_postamble : String =
  #|endbfrange
  #|endcmap
  #|CMapName currentdict /CMap defineresource pop
  #|end
  #|end
  #|

///|
let hex_digits_upper : Array[Char] = "0123456789ABCDEF".to_array()

///|
let hex_digits_lower : Array[Char] = "0123456789abcdef".to_array()

///|
fn hex_byte(digits : Array[Char], value : Int) -> String {
  let hi = value / 16
  let lo = value % 16
  String::from_array([digits[hi], digits[lo]])
}

///|
fn hex_byte_upper(value : Int) -> String {
  hex_byte(hex_digits_upper, value)
}

///|
fn hex_byte_lower(value : Int) -> String {
  hex_byte(hex_digits_lower, value)
}

///|
pub fn PdfTextUtil::hex(_self : PdfTextUtil, u : String) -> String {
  let sb = StringBuilder::new()
  let bytes = @pdfio.bytes_of_string(u)
  for b in bytes {
    sb.write_string(hex_byte_upper(b.to_int()))
  }
  sb.to_string()
}

///|
pub fn PdfTextUtil::tounicode_map(
  self : PdfTextUtil,
  start_code : Int,
  us : Array[String],
) -> @pdfio.MutableBytes {
  let sb = StringBuilder::new()
  let mut code = start_code
  sb
  ..write_string(tounicode_preamble)
  ..write_string("\{us.length()} beginbfrange\n")
  for u in us {
    sb.write_string(
      "<\{hex_byte_lower(code)}><\{hex_byte_lower(code)}><\{self.hex(u)}>\n",
    )
    code = code + 1
  }
  sb.write_string(tounicode_postamble)
  @pdfio.bytes_of_string(sb.to_string())
}

///|
pub fn PdfText::write_tounicode(self : PdfText, u : Map[Int, String]) -> Int {
  let pairs = @pdfutil.PdfUtil::new().list_of_hashtbl(u)
  pairs.sort_by((a, b) => a.0 - b.0)
  let strings = pairs.map(pair => pair.1)
  let bytes = PdfTextUtil::new().tounicode_map(33, strings)
  let dict = PdfObject::Dictionary([
    ("/Length", PdfObject::Integer(@pdfio.bytes_size(bytes))),
  ])
  self.pdf.addobj(PdfObject::Stream(Ref::new((dict, @pdf.Stream::Got(bytes)))))
}

///|
pub fn PdfText::write_font(
  self : PdfText,
  objnum? : Int,
  font : @pdffont.Font,
) -> Int raise {
  match font {
    SimpleFont(simple) =>
      match simple.fonttype {
        Type3(type3) =>
          match simple.fontdescriptor {
            Some(_) => {
              let encoding_entry = match simple.encoding {
                ImplicitInFontFile => []
                _ =>
                  [
                    (
                      "/Encoding",
                      PdfObject::Indirect(self.write_encoding(simple.encoding)),
                    ),
                  ]
              }
              let dict = PdfObject::Dictionary(
                [
                  ("/Type", PdfObject::Name(@pdf.PdfName::of_string("/Font"))),
                  (
                    "/Subtype",
                    PdfObject::Name(@pdf.PdfName::of_string("/Type3")),
                  ),
                  (
                    "/FontBBox",
                    PdfObject::Array([
                      PdfObject::Real(0.0),
                      PdfObject::Real(0.0),
                      PdfObject::Real(0.0),
                      PdfObject::Real(0.0),
                    ]),
                  ),
                  (
                    "/FontMatrix",
                    PdfObject::Array([
                      PdfObject::Real(0.0),
                      PdfObject::Real(0.0),
                      PdfObject::Real(0.0),
                      PdfObject::Real(0.0),
                      PdfObject::Real(0.0),
                      PdfObject::Real(0.0),
                    ]),
                  ),
                  (
                    "/CharProcs",
                    PdfObject::Dictionary(
                      type3.charprocs.map(pair => (pair.0, Null)),
                    ),
                  ),
                  ("/FirstChar", PdfObject::Integer(0)),
                  ("/LastChar", PdfObject::Integer(0)),
                  ("/Widths", PdfObject::Array([PdfObject::Real(0.0)])),
                ].add(encoding_entry),
              )
              self.pdf.addobj(dict)
            }
            None => raise @pdf.PdfError::Msg("Missing font descriptor")
          }
        Truetype =>
          match simple.fontdescriptor {
            Some(fd) =>
              match fd.fontfile {
                Some(FontFile2(ttf)) => {
                  let (minx, miny, maxx, maxy) = fd.fontbbox
                  let fontdesc = PdfObject::Dictionary([
                    (
                      "/Type",
                      PdfObject::Name(
                        @pdf.PdfName::of_string("/FontDescriptor"),
                      ),
                    ),
                    (
                      "/FontName",
                      PdfObject::Name(@pdf.PdfName::of_string(simple.basefont)),
                    ),
                    ("/Flags", PdfObject::Integer(fd.flags)),
                    (
                      "/FontBBox",
                      PdfObject::Array([
                        PdfObject::Integer(minx.to_int()),
                        PdfObject::Integer(miny.to_int()),
                        PdfObject::Integer(maxx.to_int()),
                        PdfObject::Integer(maxy.to_int()),
                      ]),
                    ),
                    (
                      "/ItalicAngle",
                      PdfObject::Integer(fd.italicangle.to_int()),
                    ),
                    ("/Ascent", PdfObject::Integer(fd.ascent.to_int())),
                    ("/Descent", PdfObject::Integer(fd.descent.to_int())),
                    ("/CapHeight", PdfObject::Integer(fd.capheight.to_int())),
                    ("/StemV", PdfObject::Integer(fd.stemv.to_int())),
                    ("/XHeight", PdfObject::Integer(fd.xheight.to_int())),
                    ("/AvgWidth", PdfObject::Integer(fd.avgwidth.to_int())),
                    ("/MaxWidth", PdfObject::Integer(fd.maxwidth.to_int())),
                    ("/FontFile2", PdfObject::Indirect(ttf)),
                  ])
                  let fontdesc_num = self.pdf.addobj(fontdesc)
                  let mut font_dict_entries : Array[(String, @pdf.PdfObject)] = [
                    ("/Type", PdfObject::Name(@pdf.PdfName::of_string("/Font"))),
                    (
                      "/Subtype",
                      PdfObject::Name(@pdf.PdfName::of_string("/TrueType")),
                    ),
                    (
                      "/BaseFont",
                      PdfObject::Name(@pdf.PdfName::of_string(simple.basefont)),
                    ),
                    ("/FontDescriptor", PdfObject::Indirect(fontdesc_num)),
                    ("/FirstChar", PdfObject::Integer(simple.firstchar)),
                    ("/LastChar", PdfObject::Integer(simple.lastchar)),
                    (
                      "/Widths",
                      PdfObject::Array(
                        simple.widths.map(w => PdfObject::Integer(w)),
                      ),
                    ),
                  ]
                  font_dict_entries = match fd.tounicode {
                    None =>
                      font_dict_entries.add([
                        (
                          "/Encoding",
                          PdfObject::Name(
                            @pdf.PdfName::of_string(
                              "/" + simple.encoding.to_string(),
                            ),
                          ),
                        ),
                      ])
                    Some(u) =>
                      font_dict_entries.add([
                        (
                          "/ToUnicode",
                          PdfObject::Indirect(self.write_tounicode(u)),
                        ),
                      ])
                  }
                  let font_obj = PdfObject::Dictionary(font_dict_entries)
                  match objnum {
                    None => self.pdf.addobj(font_obj)
                    Some(o) => {
                      self.pdf.addobj_given_num((o, font_obj))
                      o
                    }
                  }
                }
                _ => raise @pdf.PdfError::Msg("Missing FontFile2")
              }
            None => raise @pdf.PdfError::Msg("Missing font descriptor")
          }
        _ =>
          raise @pdf.PdfError::Msg(
            "Pdftext.write_font does not support this font",
          )
      }
    StandardFont(standard, encoding) =>
      self.pdf.addobj(
        PdfTextUtil::new().make_font(standard.to_string(), encoding),
      )
    _ =>
      raise @pdf.PdfError::Msg("Pdftext.write_font does not support this font")
  }
}
