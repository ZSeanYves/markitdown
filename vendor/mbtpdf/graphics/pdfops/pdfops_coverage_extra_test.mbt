///|
fn concat_parts(parts : Array[@pdfio.MutableBytes]) -> @pdfio.MutableBytes {
  let mut total = 0
  for part in parts {
    total = total + @pdfio.bytes_size(part)
  }
  let out = @pdfio.mkbytes(total)
  let mut pos = 0
  for part in parts {
    let len = @pdfio.bytes_size(part)
    for i in 0..<len {
      @pdfio.bset_unsafe(out, pos, @pdfio.bget_unsafe(part, i))
      pos = pos + 1
    }
  }
  out
}

///|
test "parse_single_stream reports malformed section without operator" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let ops = @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string("1 2"),
    )
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is OpUnknown(_) }))
  })
}

///|
test "parse_single_stream parses incomplete operators as unknown" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let data = @pdfio.bytes_of_string("w J gs Tf Tj")
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, data)
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is OpUnknown(_) }))
  })
}

///|
test "parse_single_stream parses DP/BDC with comment operand as unknown" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    // Ensure the input ends with whitespace so the lexer doesn't raise End_of_file.
    let data = @pdfio.bytes_of_string("/Tag %c\nDP /Tag2 %c\nBDC ")
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, data)
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is OpUnknown(_) }))
  })
}

///|
test "parse inline image fixes bad end marker after fixed-length data" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let header = @pdfio.bytes_of_string(
      "BI /W 1 /H 1 /BPC 8 /CS /DeviceGray ID ",
    )
    let data = @pdfio.bytes_of_list([0x7f])
    // Wrong end marker EX, then a real EI, then a trailing q.
    let footer = @pdfio.bytes_of_string(" EX EI q")
    let stream = concat_parts([header, data, footer])
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is InlineImage(_) }))
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is Opq }))
  })
}

///|
test "parse inline image flate detects EI at end of stream" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let raw = @pdfio.bytes_of_list([0x7f])
    let encoded = @pdfcodec.PdfCodec::new().encode_flate(raw)
    let header = @pdfio.bytes_of_string(
      "BI /W 1 /H 1 /BPC 8 /CS /DeviceGray /Filter /FlateDecode ID ",
    )
    let footer = @pdfio.bytes_of_string(" EI")
    let stream = concat_parts([header, encoded, footer])
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
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
  })
}

///|
test "parse inline image flate errors when EI missing after whitespace" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let raw = @pdfio.bytes_of_list([0x7f])
    let encoded = @pdfcodec.PdfCodec::new().encode_flate(raw)
    let header = @pdfio.bytes_of_string(
      "BI /W 1 /H 1 /BPC 8 /CS /DeviceGray /Filter /FlateDecode ID ",
    )
    // Trailing whitespace but no EI.
    let footer = @pdfio.bytes_of_string(" ")
    let stream = concat_parts([header, encoded, footer])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf, resources, stream,
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse inline image DCT handles stray 0xD9 bytes" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let header = @pdfio.bytes_of_string(
      "BI /W 1 /H 1 /BPC 8 /CS /DeviceRGB /Filter /DCT ID ",
    )
    let jpeg = @pdfio.bytes_of_list([0x00, 0xD9, 0xFF, 0xD9])
    let footer = @pdfio.bytes_of_string(" EI")
    let stream = concat_parts([header, jpeg, footer])
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
    let mut saw = false
    for op in ops {
      match (op : @pdfops.Op) {
        InlineImage((_, _, data)) => {
          assert_eq(@pdfio.bytes_size(data), 4)
          assert_eq(@pdfio.bget_unsafe(data, 1), 0xD9)
          saw = true
        }
        _ => ()
      }
    }
    assert_true(saw)
  })
}

///|
test "parse inline image DCT errors on truncated data" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let header = @pdfio.bytes_of_string(
      "BI /W 1 /H 1 /BPC 8 /CS /DeviceRGB /Filter /DCT ID ",
    )
    let jpeg = @pdfio.bytes_of_list([0xFF])
    let stream = concat_parts([header, jpeg])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf, resources, stream,
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse inline image ASCIIHexDecode terminates on EI at EOF" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let header = @pdfio.bytes_of_string(
      "BI /W 1 /H 1 /BPC 8 /CS /DeviceGray /Filter /ASCIIHexDecode ID",
    )
    let encoded = @pdfio.bytes_of_string("7F")
    let footer = @pdfio.bytes_of_string(" EI")
    let stream = concat_parts([header, encoded, footer])
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
    let mut saw = false
    for op in ops {
      match (op : @pdfops.Op) {
        InlineImage((_, _, data)) => {
          assert_eq(@pdfio.bytes_size(data), 1)
          assert_eq(@pdfio.bget_unsafe(data, 0), 0x7F)
          saw = true
        }
        _ => ()
      }
    }
    assert_true(saw)
  })
}

///|
test "parse inline image ASCIIHexDecode errors when EI missing at EOF" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let header = @pdfio.bytes_of_string(
      "BI /W 1 /H 1 /BPC 8 /CS /DeviceGray /Filter /ASCIIHexDecode ID",
    )
    // Trailing whitespace but no EI.
    let encoded = @pdfio.bytes_of_string("7F ")
    let stream = concat_parts([header, encoded])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf, resources, stream,
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse_single_stream parses dash pattern 'd' op" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let data = @pdfio.bytes_of_string("[1 2] 0 d")
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, data)
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is Opd(_, _) }))
  })
}

///|
test "parse_single_stream errors on malformed dash pattern 'd' op" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    // Missing the left bracket and the right bracket.
    let data = @pdfio.bytes_of_string("1 2 0 d")
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf, resources, data,
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse_single_stream parses TJ arrays and skips malformed elements" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let data = @pdfio.bytes_of_string("[(A) 20 /Bad (B)] TJ")
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, data)
    let mut saw = false
    for op in ops {
      match (op : @pdfops.Op) {
        OpTJ(Array(items)) => {
          // /Bad is skipped, so we should have 3 elements: "A", 20, "B".
          assert_eq(items.length(), 3)
          saw = true
        }
        _ => ()
      }
    }
    assert_true(saw)
  })
}

///|
test "parse_single_stream errors on malformed TJ op" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let data = @pdfio.bytes_of_string("TJ")
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf, resources, data,
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse_single_stream fills sc defaults when operand not a number" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let data = @pdfio.bytes_of_string("/DeviceRGB sc")
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, data)
    assert_true(
      ops.exists(fn(op : @pdfops.Op) {
        match (op : @pdfops.Op) {
          Opsc(values) => values.length() == 3
          _ => false
        }
      }),
    )
  })
}

///|
test "parse_single_stream errors on too-short dash pattern op" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string("d"),
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse_single_stream errors on dash pattern op with non-numeric phase" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string("[] /Phase d"),
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse_single_stream errors on dash pattern op missing left bracket" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string("1 ] 0 d"),
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse_single_stream errors on dash pattern op with non-numeric entries" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string("[/Bad] 0 d"),
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse_single_stream errors on TJ missing left bracket" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string("(A) ] TJ"),
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse_single_stream makes invalid string operands unknown" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let data = @pdfio.bytes_of_string("1 '")
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, data)
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is OpUnknown(_) }))
  })
}

///|
test "Op::components handles Cal* colourspaces in array form" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let calrgb : @pdf.PdfObject = Array([
      Name(@pdf.PdfName::of_string("/CalRGB")),
      Null,
    ])
    let calgray : @pdf.PdfObject = Array([
      Name(@pdf.PdfName::of_string("/CalGray")),
      Null,
    ])
    let calcmky : @pdf.PdfObject = Array([
      Name(@pdf.PdfName::of_string("/CalCMYK")),
      Null,
    ])
    assert_eq(@pdfops.Op::components(pdf, resources, calrgb), 3)
    assert_eq(@pdfops.Op::components(pdf, resources, calgray), 1)
    assert_eq(@pdfops.Op::components(pdf, resources, calcmky), 4)
  })
}

///|
test "parse_single_stream errors on invalid leading character" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf,
      resources,
      @pdfio.bytes_of_string("{"),
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse inline image supports DCT filter specified as a single-element array" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let header = @pdfio.bytes_of_string(
      "BI /W 1 /H 1 /BPC 8 /CS /DeviceRGB /Filter [/DCTDecode] ID ",
    )
    let jpeg = @pdfio.bytes_of_list([0xFF, 0xD9])
    let footer = @pdfio.bytes_of_string(" EI")
    let stream = concat_parts([header, jpeg, footer])
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, stream)
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is InlineImage(_) }))
  })
}

///|
test "parse inline image errors when /Filter has wrong type" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let header = @pdfio.bytes_of_string(
      "BI /W 1 /H 1 /BPC 8 /CS /DeviceGray /Filter 1 ID ",
    )
    let data = @pdfio.bytes_of_string("x")
    let footer = @pdfio.bytes_of_string(" EI")
    let stream = concat_parts([header, data, footer])
    let res : Result[Array[@pdfops.Op], Error] = try? @pdfops.Op::parse_single_stream(
      pdf, resources, stream,
    )
    assert_true(res is Err(_))
  })
}

///|
test "Op::components errors on unknown colourspace array" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let bad : @pdf.PdfObject = Array([
      Name(@pdf.PdfName::of_string("/NotAColourSpace")),
      Null,
    ])
    let res : Result[Int, Error] = try? @pdfops.Op::components(
      pdf, resources, bad,
    )
    assert_true(res is Err(_))
  })
}

///|
test "parse_single_stream treats non-numeric i operand as unknown" {
  @pdfe.with_silenced_logs(fn() {
    let pdf = @pdf.Pdf::empty()
    let resources : @pdf.PdfObject = Dictionary([])
    let data = @pdfio.bytes_of_string("/X i")
    let ops = @pdfops.Op::parse_single_stream(pdf, resources, data)
    assert_true(ops.exists(fn(op : @pdfops.Op) { op is OpUnknown(_) }))
  })
}
