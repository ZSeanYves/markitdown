///|
/// Tristimulus point.
pub type Point = (Double, Double, Double)

///|
/// ICC based colourspace details.
pub(all) struct ICCBased {
  icc_n : Int
  icc_alternate : ColourSpace
  icc_range : Array[Double]
  icc_metadata : PdfObject?
  icc_stream : PdfObject
}

///|
/// Colour space variants.
pub(all) enum ColourSpace {
  DeviceGray
  DeviceRGB
  DeviceCMYK
  CalGray(Point, Point, Double)
  CalRGB(Point, Point, Array[Double], Array[Double])
  Lab(Point, Point, Array[Double])
  ICCBased(ICCBased)
  Indexed(ColourSpace, Map[Int, Array[Int]])
  Pattern
  PatternWithBaseColourspace(ColourSpace)
  Separation(String, ColourSpace, @pdffun.PdfFunction)
  DeviceN(Array[String], ColourSpace, @pdffun.PdfFunction, PdfObject)
}

///|
/// Produce a debug string.
pub fn ColourSpace::to_string(self : ColourSpace) -> String {
  match self {
    DeviceGray => "/DeviceGray"
    DeviceRGB => "/DeviceRGB"
    DeviceCMYK => "/DeviceCMYK"
    CalGray(_, _, _) => "/CalGray"
    CalRGB(_, _, _, _) => "/CalRGB"
    Lab(_, _, _) => "/Lab"
    ICCBased(icc) => "ICCBased (\{icc.icc_alternate.to_string()})"
    Indexed(base, _) => "Indexed (\{base.to_string()})"
    Pattern => "/Pattern"
    PatternWithBaseColourspace(base) =>
      "PatternWithBaseColourspace (\{base.to_string()})"
    Separation(_, base, _) => "Separation (\{base.to_string()})"
    DeviceN(_, base, _, _) => "DeviceN (\{base.to_string()})"
  }
}

///|
/// Read the name of a colour, if it has one.
pub fn ColourSpace::name(self : ColourSpace) -> String? {
  match self {
    Separation(name, _, _) => Some(name)
    _ => None
  }
}

///|
type PdfObject = @pdf.PdfObject

///|
fn read_point(pdf : @pdf.Pdf, dict : PdfObject, key : String) -> Point raise {
  match (pdf.lookup_direct(key, dict) : PdfObject?) {
    Some(Array([a, b, c])) => (pdf.getnum(a), pdf.getnum(b), pdf.getnum(c))
    _ => (0.0, 0.0, 0.0)
  }
}

///|
fn get_basic_table_colourspace(space : ColourSpace) -> ColourSpace {
  match space {
    Indexed(base, _) => get_basic_table_colourspace(base)
    DeviceN(_, base, _, _) => get_basic_table_colourspace(base)
    Separation(_, base, _) => get_basic_table_colourspace(base)
    ICCBased(icc) => get_basic_table_colourspace(icc.icc_alternate)
    _ => space
  }
}

///|
fn build_table(
  data : @pdfio.MutableBytes,
  hival : Int,
  components : Int,
) -> Map[Int, Array[Int]] raise {
  let total = (hival + 1) * components
  if @pdfio.bytes_size(data) < total {
    raise @pdf.PdfError::Msg("Pdfspace: bad table")
  }
  let table : Map[Int, Array[Int]] = Map::new(capacity=hival + 1)
  let mut offset = 0
  for x in 0..<=hival {
    let row = Array::new(capacity=components)
    for _ in 0..<components {
      row.push(@pdfio.bget_unsafe(data, offset))
      offset = offset + 1
    }
    table.set(x, row)
  }
  table
}

///|
/// Read a colourspace from a PDF.
pub fn ColourSpace::read(
  pdf : @pdf.Pdf,
  resources : PdfObject,
  space : PdfObject,
) -> ColourSpace raise {
  let direct = match (space : PdfObject) {
    Indirect(_) => pdf.direct(space)
    _ => space
  }
  match (direct : PdfObject) {
    Name(n) if n.equal_string_bytes("/DeviceGray") || n.equal_string_bytes("/G") =>
      DeviceGray
    Name(n) if n.equal_string_bytes("/DeviceRGB") ||
      n.equal_string_bytes("/RGB") => DeviceRGB
    Name(n) if n.equal_string_bytes("/DeviceCMYK") ||
      n.equal_string_bytes("/CMYK") => DeviceCMYK
    Name(n) if n.equal_string_bytes("/Pattern") => Pattern
    Array([Name(n), base]) if n.equal_string_bytes("/Pattern") =>
      PatternWithBaseColourspace(ColourSpace::read(pdf, resources, base))
    Array([one]) => ColourSpace::read(pdf, resources, one)
    Name(name) =>
      match pdf.lookup_direct("/ColorSpace", resources) {
        Some(csdict) =>
          match pdf.lookup_direct(name.to_string_bytes(), csdict) {
            Some(space_obj) => ColourSpace::read(pdf, resources, space_obj)
            None => fail("Not_found")
          }
        None => fail("Not_found")
      }
    Array([Name(n), dict]) if n.equal_string_bytes("/CalGray") => {
      let whitepoint = read_point(pdf, dict, "/WhitePoint")
      let blackpoint = read_point(pdf, dict, "/BlackPoint")
      let gamma = match pdf.lookup_direct("/Gamma", dict) {
        Some(n) => pdf.getnum(n)
        None => 1.0
      }
      CalGray(whitepoint, blackpoint, gamma)
    }
    Array([Name(n), dict]) if n.equal_string_bytes("/CalRGB") => {
      let whitepoint = read_point(pdf, dict, "/WhitePoint")
      let blackpoint = read_point(pdf, dict, "/BlackPoint")
      let gamma = match (pdf.lookup_direct("/Gamma", dict) : PdfObject?) {
        Some(Array([a, b, c])) => [pdf.getnum(a), pdf.getnum(b), pdf.getnum(c)]
        _ => [1.0, 1.0, 1.0]
      }
      let matrix = match (pdf.lookup_direct("/Matrix", dict) : PdfObject?) {
        Some(Array([a, b, c, d, e, f, g, h, i])) =>
          [
            pdf.getnum(a),
            pdf.getnum(b),
            pdf.getnum(c),
            pdf.getnum(d),
            pdf.getnum(e),
            pdf.getnum(f),
            pdf.getnum(g),
            pdf.getnum(h),
            pdf.getnum(i),
          ]
        _ => [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
      }
      CalRGB(whitepoint, blackpoint, gamma, matrix)
    }
    Array([Name(n), dict]) if n.equal_string_bytes("/Lab") => {
      let whitepoint = read_point(pdf, dict, "/WhitePoint")
      let blackpoint = read_point(pdf, dict, "/BlackPoint")
      let range = match (pdf.lookup_direct("/Range", dict) : PdfObject?) {
        Some(Array([a, b, c, d])) =>
          [pdf.getnum(a), pdf.getnum(b), pdf.getnum(c), pdf.getnum(d)]
        _ => [-100.0, 100.0, -100.0, 100.0]
      }
      Lab(whitepoint, blackpoint, range)
    }
    Array([Name(n), stream]) if n.equal_string_bytes("/ICCBased") =>
      match (pdf.direct(stream) : PdfObject) {
        Stream(r) => {
          let (dict, _) = r.val
          let n = match (pdf.lookup_direct("/N", dict) : PdfObject?) {
            Some(Integer(value)) =>
              if value == 1 || value == 3 || value == 4 {
                value
              } else {
                raise @pdf.PdfError::Msg("Bad /N in ICCBased")
              }
            _ => raise @pdf.PdfError::Msg("Bad /N in ICCBased")
          }
          let alternate = match pdf.lookup_direct("/Alternate", dict) {
            Some(cs) => ColourSpace::read(pdf, resources, cs)
            _ =>
              match n {
                1 => DeviceGray
                3 => DeviceRGB
                4 => DeviceCMYK
                _ => raise @pdf.PdfError::Msg("Bad /N in ICCBased")
              }
          }
          let range = match (pdf.lookup_direct("/Range", dict) : PdfObject?) {
            Some(Array(values)) if values.length() == 2 * n =>
              values.map(v => pdf.getnum(v))
            _ => interleave_defaults(n)
          }
          let metadata = pdf.lookup_direct("/Metadata", dict)
          ICCBased({
            icc_n: n,
            icc_alternate: alternate,
            icc_range: range,
            icc_metadata: metadata,
            icc_stream: stream,
          })
        }
        _ => raise @pdf.PdfError::Msg("ICCBased not a stream")
      }
    Array([Name(n), base, hival_obj, lookup_data]) if n.equal_string_bytes(
        "/Indexed",
      ) ||
      n.equal_string_bytes("/I") => {
      let hival = match (hival_obj : PdfObject) {
        Integer(h) => h
        _ => raise @pdf.PdfError::Msg("Bad /Hival")
      }
      let base_space = ColourSpace::read(pdf, resources, base)
      let table = match (pdf.direct(lookup_data) : PdfObject) {
        Stream(_) as stream => {
          @pdfcodec.PdfCodec::new().decode_pdfstream(pdf, stream)
          match (stream : PdfObject) {
            Stream(r) =>
              match r.val {
                (_, @pdf.Stream::Got(data)) =>
                  match get_basic_table_colourspace(base_space) {
                    DeviceCMYK => build_table(data, hival, 4)
                    DeviceRGB | CalRGB(_, _, _, _) | Lab(_, _, _) =>
                      build_table(data, hival, 3)
                    Pattern | PatternWithBaseColourspace(_) | Indexed(_, _) =>
                      raise @pdf.PdfError::Msg(
                        "Disallowed base colourspace in index colourspace",
                      )
                    _ =>
                      raise @pdf.PdfError::Msg(
                        "Unsupported base colourspace in index colourspace",
                      )
                  }
                _ => raise @pdf.PdfError::Msg("Indexed/Inconsistent")
              }
            _ => raise @pdf.PdfError::Msg("Indexed/Inconsistent")
          }
        }
        String(s) => {
          let data = @pdfio.bytes_of_string(s)
          match get_basic_table_colourspace(base_space) {
            DeviceRGB | CalRGB(_, _, _, _) | Lab(_, _, _) =>
              build_table(data, hival, 3)
            DeviceCMYK => build_table(data, hival, 4)
            Pattern | PatternWithBaseColourspace(_) | Indexed(_, _) =>
              raise @pdf.PdfError::Msg(
                "Disallowed base colourspace in index colourspace",
              )
            _ =>
              raise @pdf.PdfError::Msg(
                "Unsupported base colourspace in index colourspace",
              )
          }
        }
        _ => raise @pdf.PdfError::Msg("Pdfspace: unknown indexed colourspace")
      }
      Indexed(base_space, table)
    }
    Array([Name(n), Name(sep_name), alternate, tint]) if n.equal_string_bytes(
        "/Separation",
      ) => {
      let alt_space = ColourSpace::read(pdf, resources, alternate)
      let tint_transform = @pdffun.PdfFunction::parse(pdf, tint)
      Separation(sep_name.to_string_bytes(), alt_space, tint_transform)
    }
    Array([Name(n), Array(names), alternate, tint]) if n.equal_string_bytes(
        "/DeviceN",
      ) => {
      let out_names = Array::new(capacity=names.length())
      for name in names {
        match (name : PdfObject) {
          Name(value) => out_names.push(value.to_string_bytes())
          _ => fail("Not_found")
        }
      }
      let alt_space = ColourSpace::read(pdf, resources, alternate)
      let tint_transform = @pdffun.PdfFunction::parse(pdf, tint)
      let empty_dict : PdfObject = Dictionary([])
      DeviceN(out_names, alt_space, tint_transform, empty_dict)
    }
    Array([Name(n), Array(names), alternate, tint, attributes]) if n.equal_string_bytes(
        "/DeviceN",
      ) => {
      let out_names = Array::new(capacity=names.length())
      for name in names {
        match (name : PdfObject) {
          Name(value) => out_names.push(value.to_string_bytes())
          _ => fail("Not_found")
        }
      }
      let alt_space = ColourSpace::read(pdf, resources, alternate)
      let tint_transform = @pdffun.PdfFunction::parse(pdf, tint)
      DeviceN(out_names, alt_space, tint_transform, attributes)
    }
    _ => fail("Not_found")
  }
}

///|
fn interleave_defaults(n : Int) -> Array[Double] {
  let out = Array::new(capacity=2 * n)
  for _ in 0..<n {
    out.push(0.0)
    out.push(1.0)
  }
  out
}

///|
fn normalize_name(name : String) -> String {
  if name.has_prefix("/") {
    name
  } else {
    "/\{name}"
  }
}

///|
fn array_of_point(point : Point) -> PdfObject {
  Array([
    @pdf.ToPdfNumber::to_pdf_number(point.0),
    @pdf.ToPdfNumber::to_pdf_number(point.1),
    @pdf.ToPdfNumber::to_pdf_number(point.2),
  ])
}

///|
fn dict_entries(obj : PdfObject) -> Array[(String, PdfObject)] {
  match (obj : PdfObject) {
    Dictionary(entries) => entries
    _ => []
  }
}

///|
fn dict_has_key(entries : Array[(String, PdfObject)], key : String) -> Bool {
  entries.search_by(pair => pair.0 == key) is Some(_)
}

///|
fn dict_set(
  entries : Array[(String, PdfObject)],
  key : String,
  value : PdfObject,
) -> Array[(String, PdfObject)] {
  let out = Array::new(capacity=entries.length() + 1)
  let mut found = false
  for pair in entries {
    if pair.0 == key {
      out.push((key, value))
      found = true
    } else {
      out.push(pair)
    }
  }
  if !found {
    out.push((key, value))
  }
  out
}

///|
fn ensure_length(
  entries : Array[(String, PdfObject)],
  stream_data : @pdf.Stream,
) -> Array[(String, PdfObject)] {
  if dict_has_key(entries, "/Length") {
    return entries
  }
  match stream_data {
    @pdf.Stream::Got(bytes) =>
      dict_set(
        entries,
        "/Length",
        @pdf.ToPdfNumber::to_pdf_number(@pdfio.bytes_size(bytes)),
      )
    _ => entries
  }
}

///|
fn is_empty_dict(obj : PdfObject) -> Bool {
  match (obj : PdfObject) {
    Dictionary(entries) => entries.length() == 0
    _ => false
  }
}

///|
fn components_of_colourspace(space : ColourSpace) -> Int {
  match get_basic_table_colourspace(space) {
    DeviceGray | CalGray(_, _, _) => 1
    DeviceRGB | CalRGB(_, _, _, _) | Lab(_, _, _) => 3
    DeviceCMYK => 4
    _ => 0
  }
}

///|
fn table_bytes(
  table : Map[Int, Array[Int]],
  hival : Int,
  components : Int,
) -> @pdfio.MutableBytes {
  let total = if hival >= 0 { (hival + 1) * components } else { 0 }
  let data = @pdfio.mkbytes(total)
  let mut offset = 0
  let mut i = 0
  while i <= hival {
    let row = match table.get(i) {
      Some(values) => values
      None => Array::make(components, 0)
    }
    let mut j = 0
    while j < components {
      let value = if j < row.length() { row[j] } else { 0 }
      if offset < data.length() {
        data[offset] = value.to_byte()
      }
      offset = offset + 1
      j = j + 1
    }
    i = i + 1
  }
  data
}

///|
fn write_iccbased(pdf : @pdf.Pdf, icc : ICCBased) -> PdfObject {
  match (icc.icc_stream : PdfObject) {
    Stream(r) => {
      let (dict_obj, stream_data) = r.val
      let entries = dict_entries(dict_obj)
      let entries = dict_set(
        entries,
        "/N",
        @pdf.ToPdfNumber::to_pdf_number(icc.icc_n),
      )
      let entries = dict_set(
        entries,
        "/Alternate",
        icc.icc_alternate.to_pdf_object(pdf),
      )
      let entries = if icc.icc_range.length() == 2 * icc.icc_n {
        let range_arr : PdfObject = Array(
          icc.icc_range.map(x => @pdf.ToPdfNumber::to_pdf_number(x)),
        )
        dict_set(entries, "/Range", range_arr)
      } else {
        entries
      }
      let entries = match icc.icc_metadata {
        Some(metadata) => dict_set(entries, "/Metadata", metadata)
        None => entries
      }
      let entries = ensure_length(entries, stream_data)
      let stream_obj : PdfObject = Stream(
        Ref::new((Dictionary(entries), stream_data)),
      )
      let objnum = pdf.addobj(stream_obj)
      Indirect(objnum)
    }
    _ => {
      @pdfe.log("write_colourspace: ICCBased stream missing\n")
      icc.icc_alternate.to_pdf_object(pdf)
    }
  }
}

///|
/// Write a colourspace to a PDF.
pub fn ColourSpace::to_pdf_object(
  self : ColourSpace,
  pdf : @pdf.Pdf,
) -> PdfObject {
  let _ = pdf
  match self {
    DeviceGray => Name(@pdf.PdfName::of_string("/DeviceGray"))
    DeviceRGB => Name(@pdf.PdfName::of_string("/DeviceRGB"))
    DeviceCMYK => Name(@pdf.PdfName::of_string("/DeviceCMYK"))
    CalGray(white, black, gamma) =>
      Array([
        Name(@pdf.PdfName::of_string("/CalGray")),
        Dictionary([
          ("/WhitePoint", array_of_point(white)),
          ("/BlackPoint", array_of_point(black)),
          ("/Gamma", @pdf.ToPdfNumber::to_pdf_number(gamma)),
        ]),
      ])
    CalRGB(white, black, gamma, matrix) =>
      Array([
        Name(@pdf.PdfName::of_string("/CalRGB")),
        Dictionary([
          ("/WhitePoint", array_of_point(white)),
          ("/BlackPoint", array_of_point(black)),
          ("/Gamma", Array(gamma.map(x => @pdf.ToPdfNumber::to_pdf_number(x)))),
          (
            "/Matrix",
            Array(matrix.map(x => @pdf.ToPdfNumber::to_pdf_number(x))),
          ),
        ]),
      ])
    Lab(white, black, range) =>
      Array([
        Name(@pdf.PdfName::of_string("/Lab")),
        Dictionary([
          ("/WhitePoint", array_of_point(white)),
          ("/BlackPoint", array_of_point(black)),
          ("/Range", Array(range.map(x => @pdf.ToPdfNumber::to_pdf_number(x)))),
        ]),
      ])
    ICCBased(icc) =>
      Array([
        Name(@pdf.PdfName::of_string("/ICCBased")),
        write_iccbased(pdf, icc),
      ])
    Indexed(base, table) => {
      let components = components_of_colourspace(base)
      if components == 0 {
        @pdfe.log("write_colourspace: Indexed base not supported\n")
        Null
      } else {
        let mut hival = -1
        for idx, _ in table {
          if idx > hival {
            hival = idx
          }
        }
        if hival < 0 {
          hival = 0
        }
        let data = table_bytes(table, hival, components)
        let lookup = @pdfio.string_of_bytes(data)
        Array([
          Name(@pdf.PdfName::of_string("/Indexed")),
          base.to_pdf_object(pdf),
          Integer(hival),
          String(lookup),
        ])
      }
    }
    Pattern => Name(@pdf.PdfName::of_string("/Pattern"))
    PatternWithBaseColourspace(base) =>
      Array([Name(@pdf.PdfName::of_string("/Pattern")), base.to_pdf_object(pdf)])
    Separation(name, alternate, tint) =>
      Array([
        Name(@pdf.PdfName::of_string("/Separation")),
        Name(@pdf.PdfName::of_string(normalize_name(name))),
        alternate.to_pdf_object(pdf),
        tint.to_pdf_object(pdf),
      ])
    DeviceN(names, alternate, tint, attrs) => {
      let names_arr : Array[PdfObject] = names.map(fn(name) {
        Name(@pdf.PdfName::of_string(normalize_name(name)))
      })
      let names_obj : PdfObject = Array(names_arr)
      let base : Array[PdfObject] = [
        Name(@pdf.PdfName::of_string("/DeviceN")),
        names_obj,
        alternate.to_pdf_object(pdf),
        tint.to_pdf_object(pdf),
      ]
      if is_empty_dict(attrs) {
        Array(base)
      } else {
        let with_attrs = Array::new(capacity=base.length() + 1)
        for item in base {
          with_attrs.push(item)
        }
        with_attrs.push(attrs)
        Array(with_attrs)
      }
    }
  }
}
