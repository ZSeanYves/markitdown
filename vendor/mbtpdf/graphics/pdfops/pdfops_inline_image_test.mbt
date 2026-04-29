///|
test "parse inline image flate data" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
  ])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x7f]))),
  ])
  let stream = @pdfio.bytes_of_string(rendered)
  let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
  let mut saw = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((dict, _, data)) => {
        match pdf.lookup_direct("/W", dict) {
          Some(Integer(1)) => ()
          _ => fail("expected width entry")
        }
        assert_eq(@pdfio.bytes_size(data), 1)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image uses resources for colorspace" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([
    (
      "/ColorSpace",
      Dictionary([("/Cs1", Name(@pdf.PdfName::of_string("/DeviceRGB")))]),
    ),
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/Cs1"))),
  ])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_string("RGB"))),
  ])
  let stream = @pdfio.bytes_of_string(rendered)
  let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
  let mut saw = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 3)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image handles DCT data" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/DeviceRGB"))),
    ("/Filter", Name(@pdf.PdfName::of_string("/DCT"))),
  ])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0xFF, 0xD9]))),
  ])
  let stream = @pdfio.bytes_of_string(rendered)
  let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
  let mut saw = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 2)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "string_of_ops ignores non-name inline filters" {
  let dict : @pdf.PdfObject = Dictionary([("/Filter", Integer(1))])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x61]))),
  ])
  assert_true(rendered.contains("BI"))
  assert_true(rendered.contains("EI"))
}

///|
test "parse inline image handles colorspace array" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    (
      "/CS",
      Array([
        Name(@pdf.PdfName::of_string("/Indexed")),
        Name(@pdf.PdfName::of_string("/DeviceRGB")),
        Integer(1),
        String(""),
      ]),
    ),
  ])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x12]))),
  ])
  let ops = @pdfops.Op::parse_single_stream(
    pdf,
    resources,
    @pdfio.bytes_of_string(rendered),
  )
  let mut saw = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 1)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image uses ImageMask when colorspace missing" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(2)),
    ("/H", Integer(1)),
    ("/BPC", Integer(1)),
    ("/IM", Boolean(true)),
  ])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x80]))),
  ])
  let ops = @pdfops.Op::parse_single_stream(
    pdf,
    resources,
    @pdfio.bytes_of_string(rendered),
  )
  let mut saw = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 1)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image decodes flate filter" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let raw = @pdfio.bytes_of_list([0x7f])
  let encoded = @pdfcodec.PdfCodec::new().encode_flate(raw)
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
    ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
  ])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((dict, None, encoded)),
  ])
  let ops = @pdfops.Op::parse_single_stream(
    pdf,
    resources,
    @pdfio.bytes_of_string(rendered),
  )
  let mut saw = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 1)
        assert_eq(@pdfio.bget_unsafe(data, 0), 0x7f)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image flate handles trailing operators" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let raw = @pdfio.bytes_of_list([0x7f])
  let encoded = @pdfcodec.PdfCodec::new().encode_flate(raw)
  let header = @pdfio.bytes_of_string(
    "BI /W 1 /H 1 /BPC 8 /CS /DeviceGray /Filter /FlateDecode ID ",
  )
  let footer = @pdfio.bytes_of_string(" EI q")
  let stream = concat_bytes([header, encoded, footer])
  let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
  let mut saw_inline = false
  let mut saw_q = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((_, _, data)) => {
        assert_eq(@pdfio.bytes_size(data), 1)
        saw_inline = true
      }
      Opq => saw_q = true
      _ => ()
    }
  }
  assert_true(saw_inline && saw_q)
}

///|
fn parse_inline_image_error(dict : @pdf.PdfObject) -> Unit raise {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let rendered = try
      @pdfops.Op::string_of_ops([
        @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x00]))),
      ])
    catch {
      _ => fail("expected inline image serialization")
    } noraise {
      value => value
    }
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string(rendered),
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse inline image errors on missing width/height/BPC" {
  let dict1 : @pdf.PdfObject = Dictionary([
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
  ])
  parse_inline_image_error(dict1)
  let dict2 : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
  ])
  parse_inline_image_error(dict2)
  let dict3 : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
  ])
  parse_inline_image_error(dict3)
}

///|
test "parse inline image errors on missing colorspace" {
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
  ])
  parse_inline_image_error(dict)
}

///|
test "parse inline image cleans filter arrays" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let raw = @pdfio.bytes_of_list([0x7f])
  let encoded = @pdfcodec.PdfCodec::new().encode_flate(raw)
  let dict : @pdf.PdfObject = Dictionary([
    ("/W", Integer(1)),
    ("/H", Integer(1)),
    ("/BPC", Integer(8)),
    ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
    ("/Filter", Array([Name(@pdf.PdfName::of_string("/FlateDecode"))])),
  ])
  let rendered = @pdfops.Op::string_of_ops([
    @pdfops.Op::InlineImage((dict, None, encoded)),
  ])
  let ops = @pdfops.Op::parse_single_stream(
    pdf,
    resources,
    @pdfio.bytes_of_string(rendered),
  )
  let mut saw = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((dict, _, _)) => {
        assert_true(pdf.lookup_direct("/Filter", dict) is None)
        assert_true(pdf.lookup_direct("/F", dict) is None)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image decode failures raise" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let dict : @pdf.PdfObject = Dictionary([
      ("/W", Integer(1)),
      ("/H", Integer(1)),
      ("/BPC", Integer(8)),
      ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
      ("/Filter", Name(@pdf.PdfName::of_string("/FlateDecode"))),
    ])
    let rendered = @pdfops.Op::string_of_ops([
      @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x00]))),
    ])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string(rendered),
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse inline image errors on missing colorspace entry and type" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let dict : @pdf.PdfObject = Dictionary([
      ("/W", Integer(1)),
      ("/H", Integer(1)),
      ("/BPC", Integer(8)),
      ("/CS", Name(@pdf.PdfName::of_string("/CS1"))),
    ])
    let rendered = @pdfops.Op::string_of_ops([
      @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x00]))),
    ])
    let resources1 : @pdf.PdfObject = Dictionary([
      ("/ColorSpace", Dictionary([])),
    ])
    let missing_entry : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources1,
      @pdfio.bytes_of_string(rendered),
    )
    assert_true(missing_entry is Err(_))
    let resources2 : @pdf.PdfObject = Dictionary([("/ColorSpace", Integer(1))])
    let bad_type : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources2,
      @pdfio.bytes_of_string(rendered),
    )
    assert_true(bad_type is Err(_))
    let bad_cs : @pdf.PdfObject = Dictionary([
      ("/W", Integer(1)),
      ("/H", Integer(1)),
      ("/BPC", Integer(8)),
      ("/CS", Integer(1)),
    ])
    let bad_rendered = @pdfops.Op::string_of_ops([
      @pdfops.Op::InlineImage((bad_cs, None, @pdfio.bytes_of_list([0x00]))),
    ])
    let resources3 : @pdf.PdfObject = Dictionary([])
    let bad_res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources3,
      @pdfio.bytes_of_string(bad_rendered),
    )
    assert_true(bad_res is Err(_))
  })
}

///|
test "parse inline image errors on invalid ID marker" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let text = "BI << /W 1 /H 1 /BPC 8 /CS /DeviceGray >> XX 0 EI"
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string(text),
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse inline image handles bad filters" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let dict : @pdf.PdfObject = Dictionary([
      ("/W", Integer(1)),
      ("/H", Integer(1)),
      ("/BPC", Integer(8)),
      ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
      ("/Filter", Name(@pdf.PdfName::of_string("/BadFilter"))),
    ])
    let rendered = @pdfops.Op::string_of_ops([
      @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x00]))),
    ])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string(rendered),
    )
    assert_true(res is Err(_))
    let dict_array : @pdf.PdfObject = Dictionary([
      ("/W", Integer(1)),
      ("/H", Integer(1)),
      ("/BPC", Integer(8)),
      ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
      ("/Filter", Array([Integer(1)])),
    ])
    let rendered_array = @pdfops.Op::string_of_ops([
      @pdfops.Op::InlineImage((dict_array, None, @pdfio.bytes_of_list([0x00]))),
    ])
    let res_array : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string(rendered_array),
    )
    assert_true(res_array is Err(_))
    let dict_multi : @pdf.PdfObject = Dictionary([
      ("/W", Integer(1)),
      ("/H", Integer(1)),
      ("/BPC", Integer(8)),
      ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
      (
        "/Filter",
        Array([
          Name(@pdf.PdfName::of_string("/FlateDecode")),
          Name(@pdf.PdfName::of_string("/ASCIIHexDecode")),
        ]),
      ),
    ])
    let rendered_multi = @pdfops.Op::string_of_ops([
      @pdfops.Op::InlineImage((dict_multi, None, @pdfio.bytes_of_list([0x00]))),
    ])
    let res_multi : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string(rendered_multi),
    )
    assert_true(res_multi is Err(_))
  })
}

///|
fn concat_bytes(parts : Array[@pdfio.MutableBytes]) -> @pdfio.MutableBytes {
  let mut total = 0
  for part in parts {
    total = total + @pdfio.bytes_size(part)
  }
  let out = @pdfio.mkbytes(total)
  let mut pos = 0
  for part in parts {
    let len = @pdfio.bytes_size(part)
    let mut i = 0
    while i < len {
      @pdfio.bset_unsafe(out, pos, @pdfio.bget_unsafe(part, i))
      pos = pos + 1
      i = i + 1
    }
  }
  out
}

///|
test "parse inline image reads raw bytes without filter" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let header = @pdfio.bytes_of_string("BI /W 1 /H 1 /BPC 8 /CS /DeviceGray ID ")
  let data = @pdfio.bytes_of_list([0x7f])
  let footer = @pdfio.bytes_of_string(" EI")
  let stream = concat_bytes([header, data, footer])
  let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
  let mut saw = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((_, _, bytes)) => {
        assert_eq(@pdfio.bytes_size(bytes), 1)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image DCT reads JPEG marker data" {
  let pdf = @pdf.Pdf::empty()
  let resources : @pdf.PdfObject = Dictionary([])
  let header = @pdfio.bytes_of_string(
    "BI /W 1 /H 1 /BPC 8 /CS /DeviceRGB /Filter /DCT ID ",
  )
  let jpeg = @pdfio.bytes_of_list([0xFF, 0xD9])
  let footer = @pdfio.bytes_of_string(" EI")
  let stream = concat_bytes([header, jpeg, footer])
  let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
  let mut saw = false
  for op in ops {
    match (op : @pdfops.Op) {
      InlineImage((_, _, bytes)) => {
        assert_eq(@pdfio.bytes_size(bytes), 2)
        saw = true
      }
      _ => ()
    }
  }
  assert_true(saw)
}

///|
test "parse inline image errors on invalid filter array" {
  @pdfe.with_logger(_ => (), fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let dict : @pdf.PdfObject = Dictionary([
      ("/W", Integer(1)),
      ("/H", Integer(1)),
      ("/BPC", Integer(8)),
      ("/CS", Name(@pdf.PdfName::of_string("/DeviceGray"))),
      ("/Filter", Array([Integer(1)])),
    ])
    let rendered = @pdfops.Op::string_of_ops([
      @pdfops.Op::InlineImage((dict, None, @pdfio.bytes_of_list([0x00]))),
    ])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string(rendered),
    )
    assert_true(res is Err(_))
    ()
  })
}

///|
test "components handles indexed shorthand and errors" {
  @pdfe.with_logger(_ => (), fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let indexed : @pdf.PdfObject = Array([
      Name(@pdf.PdfName::of_string("/I")),
      Name(@pdf.PdfName::of_string("/DeviceRGB")),
    ])
    assert_eq(@pdfops.Op::components(pdf, resources, indexed), 1)
    let bad_first : Result[Int, Error] = try? @pdfops.Op::components(
      pdf,
      resources,
      Array([Integer(1), Name(@pdf.PdfName::of_string("/DeviceRGB"))]),
    )
    assert_true(bad_first is Err(_))
    ()
  })
}

///|
test "parse_single_stream errors on ID keyword" {
  @pdfe.with_logger(_ => (), fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let old = @pdfe.read_debug.val
    @pdfe.read_debug.val = true
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string("ID"),
    )
    @pdfe.read_debug.val = old
    assert_true(res is Err(_))
    ()
  })
}
