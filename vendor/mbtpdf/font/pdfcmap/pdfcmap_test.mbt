///|
fn find_value(pairs : Array[(String, String)], key : String) -> String? {
  for pair in pairs {
    if pair.0 == key {
      return Some(pair.1)
    }
  }
  None
}

///|
fn[T] assert_is_err(result : Result[T, Error]) -> Unit raise {
  match result {
    Ok(_) => fail("expected error")
    Err(_) => ()
  }
}

///|
test "parse_cmap parses bfchar and bfrange" {
  let data = @pdfio.bytes_of_string(
    "/WMode 1 beginbfchar<01><0041>endbfchar" +
    " beginbfrange<02><03><0042>endbfrange",
  )
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let cmap : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.wmode, Some(1))
  let key01 = @pdfio.string_of_int_array([0x01])
  let key02 = @pdfio.string_of_int_array([0x02])
  let key03 = @pdfio.string_of_int_array([0x03])
  let u0041 = @pdfio.string_of_int_array([0x00, 0x41])
  let u0042 = @pdfio.string_of_int_array([0x00, 0x42])
  let u0043 = @pdfio.string_of_int_array([0x00, 0x43])
  assert_eq(find_value(parsed.map, key01), Some(u0041))
  assert_eq(find_value(parsed.map, key02), Some(u0042))
  assert_eq(find_value(parsed.map, key03), Some(u0043))
}

///|
test "parse_cmap parses bfrange array mapping" {
  let data = @pdfio.bytes_of_string(
    "beginbfrange<01><02>[<0041><0042>]endbfrange",
  )
  let dict : @pdf.PdfObject = Dictionary([
    ("/Length", Integer(@pdfio.bytes_size(data))),
  ])
  let cmap : @pdf.PdfObject = Stream(Ref::new((dict, @pdf.Stream::Got(data))))
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.wmode, None)
  let key01 = @pdfio.string_of_int_array([0x01])
  let key02 = @pdfio.string_of_int_array([0x02])
  let u0041 = @pdfio.string_of_int_array([0x00, 0x41])
  let u0042 = @pdfio.string_of_int_array([0x00, 0x42])
  assert_eq(find_value(parsed.map, key01), Some(u0041))
  assert_eq(find_value(parsed.map, key02), Some(u0042))
}

///|
test "parse_cmap handles ToGet streams" {
  let data = "beginbfchar<01><0041>endbfchar"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let toget = @pdf.ToGet::new(@pdfio.Input::of_string(data), 0, data.length())
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::ToGet(toget))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  let key01 = @pdfio.string_of_int_array([0x01])
  let u0041 = @pdfio.string_of_int_array([0x00, 0x41])
  assert_eq(find_value(parsed.map, key01), Some(u0041))
}

///|
test "parse_cmap rejects non-stream objects" {
  let result : Result[@pdfcmap.CMap, Error] = try? @pdfcmap.CMap::parse(
    @pdf.Pdf::empty(),
    Null,
  )
  assert_is_err(result)
}

///|
test "parse_cmap ignores bad hex values" {
  let data = "beginbfchar<0G><0041>endbfchar"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.map.length(), 0)
}

///|
test "parse_cmap skips reversed bfrange entries" {
  let data = "beginbfrange<02><01><0041>endbfrange"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.map.length(), 0)
}

///|
test "parse_cmap ignores invalid wmode digits" {
  let data = "/WMode X beginbfchar<01><0041>endbfchar"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.wmode, None)
}

///|
test "parse_cmap tolerates missing endbfchar" {
  let data = "beginbfchar<01><0041>"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  let key01 = @pdfio.string_of_int_array([0x01])
  let u0041 = @pdfio.string_of_int_array([0x00, 0x41])
  assert_eq(find_value(parsed.map, key01), Some(u0041))
}

///|
test "parse_cmap skips junk between code and unicode" {
  let data = "beginbfchar<01>xx<0041>endbfchar"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  let key01 = @pdfio.string_of_int_array([0x01])
  let u0041 = @pdfio.string_of_int_array([0x00, 0x41])
  assert_eq(find_value(parsed.map, key01), Some(u0041))
}

///|
test "parse_cmap ignores unterminated hex code" {
  let data = "beginbfchar<01"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.map.length(), 0)
}

///|
test "parse_cmap ignores odd-length hex codes" {
  let data = "beginbfchar<0><0041>endbfchar"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.map.length(), 0)
}

///|
test "parse_cmap skips bfrange without destination" {
  let data = "beginbfrange<01><02>endbfrange"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.map.length(), 0)
}

///|
test "parse_cmap bfrange skips junk before dest marker" {
  let data = "beginbfrange<01><02>foo<0041>endbfrange"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.map.length(), 2)
}

///|
test "parse_cmap bfrange ignores invalid dest code" {
  let data = "beginbfrange<01><02><0>endbfrange"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.map.length(), 0)
}

///|
test "parse_cmap bfrange array stops on invalid entry" {
  let data = "beginbfrange<01><02>[<0041><0>]endbfrange"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.map.length(), 1)
}

///|
test "parse_cmap bfrange array missing closing bracket" {
  let data = "beginbfrange<01><02>[<0041><0042>endbfrange"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.map.length(), 2)
}

///|
test "parse_cmap ignores overflowing wmode" {
  let data = "/WMode 999999999999999999999999999999999999 beginbfchar<01><0041>endbfchar"
  let dict : @pdf.PdfObject = Dictionary([("/Length", Integer(data.length()))])
  let cmap : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(@pdfio.bytes_of_string(data)))),
  )
  let parsed = @pdfcmap.CMap::parse(@pdf.Pdf::empty(), cmap)
  assert_eq(parsed.wmode, None)
}
