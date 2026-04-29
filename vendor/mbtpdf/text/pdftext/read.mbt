///|
/// Font parsing helpers.

///|
fn PdfText::find_indirect(
  self : PdfText,
  key : String,
  dict : @pdf.PdfObject,
) -> Int? {
  let dict_obj = self.pdf.direct(dict)
  match dict_obj.lookup_immediate(key) {
    Some(Indirect(i)) => Some(i)
    _ => None
  }
}

///|
fn PdfText::parse_matrix(
  self : PdfText,
  key : String,
  dict : @pdf.PdfObject,
) -> @pdftransform.TransformMatrix raise {
  let obj = self.pdf.lookup_fail("No matrix", key, dict)
  match obj {
    Array(vals) if vals.length() == 6 => {
      let a = self.pdf.getnum(vals[0])
      let b = self.pdf.getnum(vals[1])
      let c = self.pdf.getnum(vals[2])
      let d = self.pdf.getnum(vals[3])
      let e = self.pdf.getnum(vals[4])
      let f = self.pdf.getnum(vals[5])
      { a, b, c, d, e, f }
    }
    _ => raise @pdf.PdfError::Msg("Bad matrix")
  }
}

///|
pub fn PdfText::read_type3_data(
  self : PdfText,
  font : @pdf.PdfObject,
) -> @pdffont.Type3Glyphs raise {
  {
    fontbbox: self.pdf.parse_rectangle(
      self.pdf.lookup_fail("No fontbbox", "/FontBBox", font),
    ),
    fontmatrix: self.parse_matrix("/FontMatrix", font),
    charprocs: match self.pdf.lookup_fail("Bad Charprocs", "/CharProcs", font) {
      Dictionary(l) => l
      _ => raise @pdf.PdfError::Msg("Bad charprocs")
    },
    type3_resources: match self.pdf.lookup_direct("/Resources", font) {
      None => Dictionary([])
      Some(d) => d
    },
  }
}

///|
pub fn PdfText::simple_fonttype_of_string(
  self : PdfText,
  font : @pdf.PdfObject,
  subtype : String,
) -> @pdffont.SimpleFontType? raise {
  match subtype {
    "/Type1" => Some(Type1)
    "/MMType1" => Some(MMType1)
    "/Type3" => Some(Type3(self.read_type3_data(font)))
    "/TrueType" => Some(Truetype)
    _ => None
  }
}

///|
pub fn PdfText::read_basefont(self : PdfText, font : @pdf.PdfObject) -> String {
  match self.pdf.lookup_direct("/BaseFont", font) {
    Some(Name(n)) => n.to_string_bytes()
    _ => ""
  }
}

///|
pub fn PdfTextUtil::parse_charset(
  _self : PdfTextUtil,
  s : String,
) -> Array[String] {
  let input = @pdfio.Input::of_string(s)
  let out = Array::new()
  while true {
    try {
      @pdfsyntax.PdfSyntax::new().dropwhite(input)
      match @pdfsyntax.PdfSyntax::new().lex_name(input) {
        LexName(name) => if name == "/" { break } else { out.push(name) }
        _ => break
      }
    } catch {
      _ => break
    }
  }
  out
}

///|
pub fn PdfText::read_fontdescriptor(
  self : PdfText,
  font : @pdf.PdfObject,
) -> @pdffont.FontDescriptor? raise {
  match self.pdf.lookup_direct("/FontDescriptor", font) {
    None => None
    Some(fontdescriptor) => {
      fn num_or_zero(key : String) -> Double raise {
        match self.pdf.lookup_direct(key, fontdescriptor) {
          Some(x) => self.pdf.getnum(x)
          None => 0.0
        }
      }

      fn find_fontfile() -> @pdffont.FontFile? {
        match self.find_indirect("/FontFile", fontdescriptor) {
          Some(i) => Some(FontFile(i))
          None =>
            match self.find_indirect("/FontFile2", fontdescriptor) {
              Some(i) => Some(FontFile2(i))
              None =>
                match self.find_indirect("/FontFile3", fontdescriptor) {
                  Some(i) => Some(FontFile3(i))
                  None => None
                }
            }
        }
      }

      let ascent = num_or_zero("/Ascent")
      let descent = num_or_zero("/Descent")
      let avgwidth = num_or_zero("/AvgWidth")
      let maxwidth = num_or_zero("/MaxWidth")
      let fontfile = find_fontfile()
      let charset = match self.pdf.lookup_direct("/CharSet", fontdescriptor) {
        Some(String(s)) => Some(PdfTextUtil::new().parse_charset(s))
        _ => None
      }
      Some({
        ascent,
        descent,
        avgwidth,
        maxwidth,
        fontfile,
        charset,
        flags: 0,
        fontbbox: (0.0, 0.0, 0.0, 0.0),
        italicangle: 0.0,
        capheight: 0.0,
        xheight: 0.0,
        stemv: 0.0,
        tounicode: None,
        tounicode_bytes: None,
      })
    }
  }
}

///|
fn repeat_double(value : Double, count : Int) -> Array[Double] {
  let out = Array::new(capacity=if count > 0 { count } else { 0 })
  for _ in 0..<count {
    out.push(value)
  }
  out
}

///|
pub fn PdfText::read_metrics(
  self : PdfText,
  font : @pdf.PdfObject,
) -> @pdffont.FontMetrics? raise {
  fn read_char(
    key : String,
    missing_msg : String,
    bad_msg : String,
  ) -> Int raise {
    match self.pdf.lookup_direct(key, font) {
      Some(Integer(i)) =>
        if i <= 255 && i >= 0 {
          i
        } else {
          raise @pdf.PdfError::Msg(bad_msg)
        }
      _ => raise @pdf.PdfError::Msg(missing_msg)
    }
  }

  let fontdescriptor = match self.pdf.lookup_direct("/Subtype", font) {
    Some(Name(n)) if n.equal_string_bytes("/Type3") => Some(font)
    _ => self.pdf.lookup_direct("/FontDescriptor", font)
  }
  match fontdescriptor {
    None => None
    Some(descriptor) => {
      let firstchar = read_char("/FirstChar", "No /FirstChar", "Bad /Firstchar")
      let lastchar = read_char("/LastChar", "No /LastChar", "Bad /Lastchar")
      let missingwidth = match
        self.pdf.lookup_direct("/MissingWidth", descriptor) {
        Some(Integer(w)) => Double::from_int(w)
        Some(Real(w)) => w
        _ => 0.0
      }
      let elts = match self.pdf.lookup_direct("/Widths", font) {
        Some(Array(values)) => values
        _ => raise @pdf.PdfError::Msg("No /Widths")
      }
      if elts.length() != lastchar - firstchar + 1 {
        raise @pdf.PdfError::Msg("Bad /Widths")
      }
      let before = repeat_double(missingwidth, firstchar)
      let given = elts.map(elt => match self.pdf.direct(elt) {
        Integer(i) => Double::from_int(i)
        Real(f) => f
        _ => raise @pdf.PdfError::Msg("Bad /Width entry")
      })
      let after = repeat_double(missingwidth, 255 - lastchar)
      let metrics = Array::new(
        capacity=before.length() + given.length() + after.length(),
      )
      metrics.append(before)
      metrics.append(given)
      metrics.append(after)
      Some(metrics)
    }
  }
}

///|
pub fn PdfText::pairs_of_differences(
  self : PdfText,
  differences : @pdf.PdfObject,
) -> @pdffont.Differences raise {
  match differences {
    Array(elts) => {
      let direct = elts.map(obj => self.pdf.direct(obj))
      let out = Array::new()
      let mut i = 0
      while i < direct.length() {
        match direct[i] {
          Integer(n) => {
            i = i + 1
            let names : Array[String] = Array::new()
            while i < direct.length() {
              match direct[i] {
                Name(name) => {
                  names.push(name.to_string_bytes())
                  i = i + 1
                }
                _ => break
              }
            }
            for idx in 0..<names.length() {
              out.push((names[idx], n + idx))
            }
          }
          _ => raise @pdf.PdfError::Msg("Malformed /Differences")
        }
      }
      out
    }
    _ => raise @pdf.PdfError::Msg("Bad /Differences")
  }
}

///|
pub fn PdfTextUtil::standard_font_of_name(
  _self : PdfTextUtil,
  name : String,
) -> @pdffont.StandardFont? {
  match name {
    "/Times-Roman" | "/TimesNewRoman" => Some(TimesRoman)
    "/Times-Bold" | "/TimesNewRoman,Bold" => Some(TimesBold)
    "/Times-Italic" | "/TimesNewRoman,Italic" => Some(TimesItalic)
    "/Times-BoldItalic" | "/TimesNewRoman,BoldItalic" => Some(TimesBoldItalic)
    "/Helvetica" | "/Arial" => Some(Helvetica)
    "/Helvetica-Bold" | "/Arial,Bold" => Some(HelveticaBold)
    "/Helvetica-Oblique" | "/Arial,Italic" => Some(HelveticaOblique)
    "/Helvetica-BoldOblique" | "/Arial,BoldItalic" => Some(HelveticaBoldOblique)
    "/Courier" | "/CourierNew" => Some(Courier)
    "/Courier-Bold" | "/CourierNew,Bold" => Some(CourierBold)
    "/Courier-Oblique" | "/CourierNew,Italic" => Some(CourierOblique)
    "/Courier-BoldOblique" | "/CourierNew,BoldItalic" =>
      Some(CourierBoldOblique)
    "/Symbol" => Some(Symbol)
    "/ZapfDingbats" => Some(ZapfDingbats)
    _ => None
  }
}

///|
pub fn PdfText::is_standard14font(
  self : PdfText,
  font : @pdf.PdfObject,
) -> Bool {
  match self.pdf.lookup_direct("/Subtype", font) {
    Some(Name(n)) if n.equal_string_bytes("/Type1") =>
      match self.pdf.lookup_direct("/BaseFont", font) {
        Some(Name(name)) => {
          let basefont = name.to_string_bytes()
          if PdfTextUtil::new().standard_font_of_name(basefont) is Some(_) {
            self.pdf.lookup_direct("/Widths", font) is None
          } else {
            false
          }
        }
        _ => false
      }
    _ => false
  }
}

///|
pub fn PdfText::is_embedded(self : PdfText, font : @pdf.PdfObject) -> Bool {
  match self.pdf.lookup_direct("/FontDescriptor", font) {
    None => false
    Some(fontdescriptor) =>
      if self.pdf.lookup_direct_orelse(
          "/FontFile", "/FontFile2", fontdescriptor,
        )
        is Some(_) {
        true
      } else {
        self.pdf.lookup_direct("/FontFile3", fontdescriptor) is Some(_)
      }
  }
}

///|
pub fn PdfText::is_symbolic(
  self : PdfText,
  font : @pdf.PdfObject,
) -> Bool raise {
  match self.pdf.lookup_direct("/FontDescriptor", font) {
    None => false
    Some(fontdescriptor) =>
      match self.pdf.lookup_direct("/Flags", fontdescriptor) {
        Some(Integer(flags)) => (flags & (1 << 3)) > 0
        _ => raise @pdf.PdfError::Msg("No /Flags in font descriptor")
      }
  }
}

///|
pub fn PdfText::read_encoding(
  self : PdfText,
  font : @pdf.PdfObject,
) -> @pdffont.Encoding raise {
  match self.pdf.lookup_direct("/Encoding", font) {
    Some(Name(n)) if n.equal_string_bytes("/MacRomanEncoding") =>
      Encoding::MacRomanEncoding
    Some(Name(n)) if n.equal_string_bytes("/MacExpertEncoding") =>
      Encoding::MacExpertEncoding
    Some(Name(n)) if n.equal_string_bytes("/WinAnsiEncoding") =>
      Encoding::WinAnsiEncoding
    Some(encdict) =>
      match encdict {
        Dictionary(_) =>
          match self.pdf.lookup_direct("/Subtype", font) {
            Some(Name(fonttype_name)) => {
              let fonttype = fonttype_name.to_string_bytes()
              if fonttype == "/Type1" ||
                fonttype == "/MMType1" ||
                fonttype == "/Type3" ||
                fonttype == "/TrueType" {
                let base_encoding = match
                  self.pdf.lookup_direct("/BaseEncoding", encdict) {
                  Some(Name(n)) if n.equal_string_bytes("/MacRomanEncoding") =>
                    Encoding::MacRomanEncoding
                  Some(Name(n)) if n.equal_string_bytes("/MacExpertEncoding") =>
                    Encoding::MacExpertEncoding
                  Some(Name(n)) if n.equal_string_bytes("/WinAnsiEncoding") =>
                    Encoding::WinAnsiEncoding
                  None =>
                    if self.is_embedded(font) {
                      Encoding::ImplicitInFontFile
                    } else if self.is_symbolic(font) {
                      Encoding::ImplicitInFontFile
                    } else {
                      Encoding::StandardEncoding
                    }
                  _ => raise @pdf.PdfError::Msg("unknown /BaseEncoding")
                }
                let encoding = match
                  self.pdf.lookup_direct("/Differences", encdict) {
                  Some(differences) =>
                    Encoding::CustomEncoding(
                      base_encoding,
                      self.pairs_of_differences(differences),
                    )
                  _ => base_encoding
                }
                if fonttype == "/TrueType" {
                  Encoding::FillUndefinedWithStandard(encoding)
                } else {
                  encoding
                }
              } else {
                raise @pdf.PdfError::Msg("Bad font /Subtype")
              }
            }
            _ => raise @pdf.PdfError::Msg("Bad font /Subtype")
          }
        _ => Encoding::ImplicitInFontFile
      }
    _ => Encoding::ImplicitInFontFile
  }
}

///|
pub fn PdfText::read_simple_font(
  self : PdfText,
  font : @pdf.PdfObject,
) -> @pdffont.Font raise {
  match self.pdf.lookup_direct("/Subtype", font) {
    Some(Name(n)) => {
      let subtype = n.to_string_bytes()
      match self.simple_fonttype_of_string(font, subtype) {
        Some(fonttype) => {
          let fontdescriptor = self.read_fontdescriptor(font)
          let fontmetrics = self.read_metrics(font)
          SimpleFont({
            fonttype,
            basefont: self.read_basefont(font),
            fontmetrics,
            firstchar: 0,
            lastchar: 0,
            widths: [],
            fontdescriptor,
            encoding: self.read_encoding(font),
          })
        }
        None => raise @pdf.PdfError::Msg("Not a simple font")
      }
    }
    _ => raise @pdf.PdfError::Msg("No font /Subtype")
  }
}

///|
pub fn PdfText::read_standard14font(
  self : PdfText,
  font : @pdf.PdfObject,
) -> @pdffont.Font raise {
  match self.pdf.lookup_direct("/BaseFont", font) {
    Some(Name(name)) => {
      let basefont = name.to_string_bytes()
      match PdfTextUtil::new().standard_font_of_name(basefont) {
        None => raise @pdf.PdfError::Msg("Not a base 14 font")
        Some(f) => StandardFont(f, self.read_encoding(font))
      }
    }
    _ => raise @pdf.PdfError::Msg("Bad base 14 font")
  }
}

///|
pub fn PdfText::is_simple_font(self : PdfText, font : @pdf.PdfObject) -> Bool {
  match self.pdf.lookup_direct("/Subtype", font) {
    Some(Name(name)) => {
      let fonttype = name.to_string_bytes()
      fonttype == "/Type1" ||
      fonttype == "/MMType1" ||
      fonttype == "/Type3" ||
      fonttype == "/TrueType"
    }
    _ => false
  }
}

///|
pub fn PdfText::is_cidkeyed_font(self : PdfText, font : @pdf.PdfObject) -> Bool {
  match self.pdf.lookup_direct("/Subtype", font) {
    Some(Name(n)) if n.equal_string_bytes("/Type0") => true
    _ => false
  }
}

///|
pub fn PdfText::read_cid_system_info(
  self : PdfText,
  dict : @pdf.PdfObject,
) -> @pdffont.CIDSystemInfo raise {
  let registry = match self.pdf.lookup_direct("/Registry", dict) {
    Some(String(s)) => s
    _ => raise @pdf.PdfError::Msg("No /Registry")
  }
  let ordering = match self.pdf.lookup_direct("/Ordering", dict) {
    Some(String(s)) => s
    _ => raise @pdf.PdfError::Msg("No /Ordering")
  }
  let supplement = match self.pdf.lookup_direct("/Supplement", dict) {
    Some(Integer(i)) => i
    _ => raise @pdf.PdfError::Msg("No /Supplement")
  }
  { registry, ordering, supplement }
}

///|
pub fn PdfTextUtil::read_cid_widths(
  _self : PdfTextUtil,
  elts : Array[@pdf.PdfObject],
) -> Array[(Int, Double)] raise {
  let out = Array::new(capacity=elts.length())
  let mut i = 0
  while i < elts.length() {
    match elts[i] {
      Integer(c) =>
        if i + 1 >= elts.length() {
          raise @pdf.PdfError::Msg("Bad /W array")
        } else {
          match elts[i + 1] {
            Array(ws) => {
              for j, wobj in ws {
                let w = match wobj {
                  Integer(n) => Double::from_int(n)
                  Real(r) => r
                  _ => raise @pdf.PdfError::Msg("Bad /W array")
                }
                out.push((c + j, w))
              }
              i = i + 2
            }
            Integer(c_last) => {
              if i + 2 >= elts.length() {
                raise @pdf.PdfError::Msg("Bad /W array")
              }
              let w = match elts[i + 2] {
                Integer(n) => Double::from_int(n)
                Real(r) => r
                _ => raise @pdf.PdfError::Msg("Bad /W array")
              }
              if c_last < c {
                raise @pdf.PdfError::Msg("Bad /W array")
              }
              for code in c..<=c_last {
                out.push((code, w))
              }
              i = i + 3
            }
            _ => raise @pdf.PdfError::Msg("Bad /W array")
          }
        }
      _ => raise @pdf.PdfError::Msg("Malformed /W in CIDfont")
    }
  }
  out
}

///|
pub fn PdfText::read_descendant(
  self : PdfText,
  dict : @pdf.PdfObject,
) -> @pdffont.CompositeCIDFont raise {
  let cid_system_info = match self.pdf.lookup_direct("/CIDSystemInfo", dict) {
    Some(cid_dict) => self.read_cid_system_info(cid_dict)
    None => raise @pdf.PdfError::Msg("No CIDSystemInfo")
  }
  let cid_basefont = match self.pdf.lookup_direct("/BaseFont", dict) {
    Some(Name(n)) => n.to_string_bytes()
    _ => raise @pdf.PdfError::Msg("No /BaseFont")
  }
  let cid_fontdescriptor = match self.read_fontdescriptor(dict) {
    Some(f) => f
    None => raise @pdf.PdfError::Msg("No FontDescriptor in CIDkeyed font")
  }
  let cid_widths = match self.pdf.lookup_direct("/W", dict) {
    Some(Array(ws)) => PdfTextUtil::new().read_cid_widths(ws)
    _ => []
  }
  let default_width = match self.pdf.lookup_direct("/DW", dict) {
    Some(Integer(d)) => d
    _ => 1000
  }
  {
    cid_system_info,
    cid_basefont,
    cid_fontdescriptor,
    cid_widths,
    cid_default_width: default_width,
  }
}

///|
pub fn PdfText::read_cidkeyed_font(
  self : PdfText,
  font : @pdf.PdfObject,
) -> @pdffont.Font raise {
  let basefont = match self.pdf.lookup_direct("/BaseFont", font) {
    Some(Name(b)) => b.to_string_bytes()
    _ => raise @pdf.PdfError::Msg("Bad /BaseFont")
  }
  let composite = match self.pdf.lookup_direct("/DescendantFonts", font) {
    Some(Array(elts)) =>
      if elts.length() == 1 {
        self.read_descendant(self.pdf.direct(elts[0]))
      } else {
        raise @pdf.PdfError::Msg("Bad descendant font")
      }
    _ => raise @pdf.PdfError::Msg("Bad descendant font")
  }
  let encoding = match self.pdf.lookup_direct("/Encoding", font) {
    Some(Name(e)) => CMapEncoding::Predefined(e.to_string_bytes())
    Some(Stream(_)) =>
      match self.find_indirect("/Encoding", font) {
        Some(n) => CMapEncoding::CMap(n)
        None => raise @pdf.PdfError::Msg("malformed /Encoding")
      }
    _ => raise @pdf.PdfError::Msg("malformed or missing /Encoding")
  }
  CIDKeyedFont(basefont, composite, encoding)
}

///|
pub fn PdfText::add_tounicode(
  self : PdfText,
  font : @pdffont.Font,
  fontdict : @pdf.PdfObject,
) -> @pdffont.Font {
  fn code_int_of_string(code : String) -> Int {
    let bytes = @pdfio.bytes_of_string(code)
    let mut value = 0
    for b in bytes {
      value = (value << 8) | b.to_int()
    }
    value
  }

  let (tounicode, tounicode_bytes) = match
    self.pdf.lookup_direct("/ToUnicode", fontdict) {
    Some(tounicode) =>
      try {
        let parsed = @pdfcmap.CMap::parse(self.pdf, tounicode)
        let bytes_map = @pdfutil.PdfUtil::new().hashtable_of_dictionary(
          parsed.map,
        )
        let int_pairs = parsed.map.map(pair => (
          code_int_of_string(pair.0),
          pair.1,
        ))
        let int_map = @pdfutil.PdfUtil::new().hashtable_of_dictionary(int_pairs)
        (Some(int_map), Some(bytes_map))
      } catch {
        err => {
          @pdfe.log("bad tounicode\n")
          let _ = err
          (None, None)
        }
      }
    None => (None, None)
  }
  match font {
    SimpleFont(simple) =>
      match simple.fontdescriptor {
        Some(fd) => {
          let updated_fd : @pdffont.FontDescriptor = {
            ascent: fd.ascent,
            descent: fd.descent,
            avgwidth: fd.avgwidth,
            maxwidth: fd.maxwidth,
            flags: fd.flags,
            fontbbox: fd.fontbbox,
            italicangle: fd.italicangle,
            capheight: fd.capheight,
            xheight: fd.xheight,
            stemv: fd.stemv,
            fontfile: fd.fontfile,
            charset: fd.charset,
            tounicode,
            tounicode_bytes,
          }
          SimpleFont({
            fonttype: simple.fonttype,
            basefont: simple.basefont,
            firstchar: simple.firstchar,
            lastchar: simple.lastchar,
            widths: simple.widths,
            fontdescriptor: Some(updated_fd),
            fontmetrics: simple.fontmetrics,
            encoding: simple.encoding,
          })
        }
        None => {
          let default_fd : @pdffont.FontDescriptor = {
            ascent: 0.0,
            descent: 0.0,
            avgwidth: 0.0,
            maxwidth: 0.0,
            flags: 0,
            fontbbox: (0.0, 0.0, 0.0, 0.0),
            italicangle: 0.0,
            capheight: 0.0,
            xheight: 0.0,
            stemv: 0.0,
            fontfile: None,
            charset: None,
            tounicode,
            tounicode_bytes,
          }
          SimpleFont({
            fonttype: simple.fonttype,
            basefont: simple.basefont,
            firstchar: simple.firstchar,
            lastchar: simple.lastchar,
            widths: simple.widths,
            fontdescriptor: Some(default_fd),
            fontmetrics: simple.fontmetrics,
            encoding: simple.encoding,
          })
        }
      }
    CIDKeyedFont(name, composite, encoding) => {
      let updated_cid_fd : @pdffont.FontDescriptor = {
        ascent: composite.cid_fontdescriptor.ascent,
        descent: composite.cid_fontdescriptor.descent,
        avgwidth: composite.cid_fontdescriptor.avgwidth,
        maxwidth: composite.cid_fontdescriptor.maxwidth,
        flags: composite.cid_fontdescriptor.flags,
        fontbbox: composite.cid_fontdescriptor.fontbbox,
        italicangle: composite.cid_fontdescriptor.italicangle,
        capheight: composite.cid_fontdescriptor.capheight,
        xheight: composite.cid_fontdescriptor.xheight,
        stemv: composite.cid_fontdescriptor.stemv,
        fontfile: composite.cid_fontdescriptor.fontfile,
        charset: composite.cid_fontdescriptor.charset,
        tounicode,
        tounicode_bytes,
      }
      let updated_composite : @pdffont.CompositeCIDFont = {
        cid_system_info: composite.cid_system_info,
        cid_basefont: composite.cid_basefont,
        cid_fontdescriptor: updated_cid_fd,
        cid_widths: composite.cid_widths,
        cid_default_width: composite.cid_default_width,
      }
      CIDKeyedFont(name, updated_composite, encoding)
    }
    other => other
  }
}

///|
pub fn PdfTextUtil::find_tounicode(
  _self : PdfTextUtil,
  font : @pdffont.Font,
) -> Map[Int, String]? {
  match font {
    SimpleFont(simple) =>
      match simple.fontdescriptor {
        Some(fd) => fd.tounicode
        None => None
      }
    CIDKeyedFont(_, composite, _) => composite.cid_fontdescriptor.tounicode
    _ => None
  }
}

///|
pub fn PdfTextUtil::find_tounicode_bytes(
  _self : PdfTextUtil,
  font : @pdffont.Font,
) -> Map[String, String]? {
  match font {
    SimpleFont(simple) =>
      match simple.fontdescriptor {
        Some(fd) => fd.tounicode_bytes
        None => None
      }
    CIDKeyedFont(_, composite, _) =>
      composite.cid_fontdescriptor.tounicode_bytes
    _ => None
  }
}

///|
pub fn PdfText::read_font(
  self : PdfText,
  fontdict : @pdf.PdfObject,
) -> @pdffont.Font raise {
  let without_tounicode = if self.is_standard14font(fontdict) {
    self.read_standard14font(fontdict)
  } else if self.is_simple_font(fontdict) {
    self.read_simple_font(fontdict)
  } else if self.is_cidkeyed_font(fontdict) {
    self.read_cidkeyed_font(fontdict)
  } else {
    raise @pdf.PdfError::Msg("Unknown font type")
  }
  self.add_tounicode(without_tounicode, fontdict)
}
