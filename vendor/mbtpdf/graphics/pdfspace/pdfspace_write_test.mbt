///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "write/read CalGray" {
  let pdf = @pdf.Pdf::empty()
  let space = @pdfspace.ColourSpace::CalGray(
    (1.0, 1.0, 1.0),
    (0.0, 0.0, 0.0),
    2.2,
  )
  let obj = space.to_pdf_object(pdf)
  let resources : @pdf.PdfObject = Dictionary([])
  let read = @pdfspace.ColourSpace::read(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::CalGray(white, black, gamma) => {
      assert_close(white.0, 1.0)
      assert_close(black.0, 0.0)
      assert_close(gamma, 2.2)
    }
    _ => fail("expected CalGray")
  }
}

///|
test "write/read Indexed" {
  let pdf = @pdf.Pdf::empty()
  let table : Map[Int, Array[Int]] = Map::new()
  table.set(0, [0, 0, 0])
  table.set(1, [255, 255, 255])
  let space = @pdfspace.ColourSpace::Indexed(
    @pdfspace.ColourSpace::DeviceRGB,
    table,
  )
  let obj = space.to_pdf_object(pdf)
  let resources : @pdf.PdfObject = Dictionary([])
  let read = @pdfspace.ColourSpace::read(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::Indexed(base, read_table) => {
      match base {
        @pdfspace.ColourSpace::DeviceRGB => ()
        _ => fail("expected DeviceRGB base")
      }
      match read_table.get(1) {
        Some(values) => {
          assert_eq(values.length(), 3)
          assert_eq(values[0], 255)
        }
        None => fail("missing index 1")
      }
    }
    _ => fail("expected Indexed")
  }
}

///|
test "write/read ICCBased" {
  let pdf = @pdf.Pdf::empty()
  let dict : @pdf.PdfObject = Dictionary([])
  let data = @pdfio.bytes_of_string("ICC")
  let stream_obj : @pdf.PdfObject = Stream(
    Ref::new((dict, @pdf.Stream::Got(data))),
  )
  let icc = @pdfspace.ICCBased::{
    icc_n: 3,
    icc_alternate: @pdfspace.ColourSpace::DeviceRGB,
    icc_range: [0.0, 1.0, 0.0, 1.0, 0.0, 1.0],
    icc_metadata: None,
    icc_stream: stream_obj,
  }
  let space = @pdfspace.ColourSpace::ICCBased(icc)
  let obj = space.to_pdf_object(pdf)
  let resources : @pdf.PdfObject = Dictionary([])
  let read = @pdfspace.ColourSpace::read(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::ICCBased(read_icc) => {
      assert_eq(read_icc.icc_n, 3)
      match read_icc.icc_alternate {
        @pdfspace.ColourSpace::DeviceRGB => ()
        _ => fail("expected DeviceRGB alternate")
      }
    }
    _ => fail("expected ICCBased")
  }
}

///|
fn sample_tint_function() -> @pdffun.PdfFunction {
  {
    func: @pdffun.PdfFunctionKind::Interpolation({
      c0: [0.0],
      c1: [1.0],
      n: 1.0,
    }),
    domain: [0.0, 1.0],
    range: Some([0.0, 1.0]),
  }
}

///|
test "write/read CalRGB" {
  let pdf = @pdf.Pdf::empty()
  let space = @pdfspace.ColourSpace::CalRGB(
    (1.0, 1.0, 1.0),
    (0.0, 0.0, 0.0),
    [2.2, 2.2, 2.2],
    [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
  )
  let obj = space.to_pdf_object(pdf)
  let resources : @pdf.PdfObject = Dictionary([])
  let read = @pdfspace.ColourSpace::read(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::CalRGB(_, _, gamma, matrix) => {
      assert_eq(gamma.length(), 3)
      assert_eq(matrix.length(), 9)
    }
    _ => fail("expected CalRGB")
  }
}

///|
test "write/read Lab" {
  let pdf = @pdf.Pdf::empty()
  let space = @pdfspace.ColourSpace::Lab((1.0, 1.0, 1.0), (0.0, 0.0, 0.0), [
    -128.0, 127.0, -128.0, 127.0,
  ])
  let obj = space.to_pdf_object(pdf)
  let resources : @pdf.PdfObject = Dictionary([])
  let read = @pdfspace.ColourSpace::read(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::Lab(_, _, range) => assert_eq(range.length(), 4)
    _ => fail("expected Lab")
  }
}

///|
test "write/read PatternWithBaseColourspace" {
  let pdf = @pdf.Pdf::empty()
  let space = @pdfspace.ColourSpace::PatternWithBaseColourspace(
    @pdfspace.ColourSpace::DeviceRGB,
  )
  let obj = space.to_pdf_object(pdf)
  let resources : @pdf.PdfObject = Dictionary([])
  let read = @pdfspace.ColourSpace::read(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::PatternWithBaseColourspace(
      @pdfspace.ColourSpace::DeviceRGB
    ) => ()
    _ => fail("expected PatternWithBaseColourspace")
  }
}

///|
test "write/read Separation and name lookup" {
  let pdf = @pdf.Pdf::empty()
  let tint = sample_tint_function()
  let space = @pdfspace.ColourSpace::Separation(
    "Spot",
    @pdfspace.ColourSpace::DeviceRGB,
    tint,
  )
  let obj = space.to_pdf_object(pdf)
  let resources : @pdf.PdfObject = Dictionary([])
  let read = @pdfspace.ColourSpace::read(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::Separation(name, base, _) => {
      assert_eq(name, "/Spot")
      match base {
        @pdfspace.ColourSpace::DeviceRGB => ()
        _ => fail("expected DeviceRGB base")
      }
    }
    _ => fail("expected Separation")
  }
  match read.name() {
    Some("/Spot") => ()
    _ => fail("expected name lookup")
  }
}

///|
test "write/read DeviceN with attributes" {
  let pdf = @pdf.Pdf::empty()
  let tint = sample_tint_function()
  let attrs : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/NChannel"))),
  ])
  let space = @pdfspace.ColourSpace::DeviceN(
    ["C1", "C2"],
    @pdfspace.ColourSpace::DeviceCMYK,
    tint,
    attrs,
  )
  let obj = space.to_pdf_object(pdf)
  let resources : @pdf.PdfObject = Dictionary([])
  let read = @pdfspace.ColourSpace::read(pdf, resources, obj)
  match read {
    @pdfspace.ColourSpace::DeviceN(names, base, _, attributes) => {
      assert_eq(names.length(), 2)
      assert_eq(names[0], "/C1")
      match base {
        @pdfspace.ColourSpace::DeviceCMYK => ()
        _ => fail("expected DeviceCMYK base")
      }
      match (attributes : @pdf.PdfObject) {
        Dictionary(_) => ()
        _ => fail("expected attributes dictionary")
      }
    }
    _ => fail("expected DeviceN")
  }
}
