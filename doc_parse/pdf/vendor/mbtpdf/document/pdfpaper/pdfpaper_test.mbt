///|
test "landscape swaps width and height" {
  let paper : @pdfpaper.Paper = Paper::new(unit=Inch, width=8.5, height=11.0)
  let swapped = paper.landscape()
  assert_eq(swapped.width(), 11.0)
  assert_eq(swapped.height(), 8.5)
}

///|
test "paper accessors return values" {
  let paper : @pdfpaper.Paper = Paper::new(
    unit=Centimetre,
    width=10.0,
    height=20.0,
  )
  match paper.unit() {
    Centimetre => ()
    _ => fail("expected centimetre unit")
  }
  assert_eq(paper.width(), 10.0)
  assert_eq(paper.height(), 20.0)
}

///|
test "paper constants match expected sizes" {
  match @pdfpaper.a4.unit() {
    Millimetre => ()
    _ => fail("expected millimetre unit")
  }
  assert_eq(@pdfpaper.a4.width(), 210.0)
  assert_eq(@pdfpaper.a4.height(), 297.0)
  match @pdfpaper.usletter.unit() {
    Inch => ()
    _ => fail("expected inch unit")
  }
  assert_eq(@pdfpaper.usletter.width(), 8.5)
  assert_eq(@pdfpaper.usletter.height(), 11.0)
  match @pdfpaper.uslegal.unit() {
    Inch => ()
    _ => fail("expected inch unit")
  }
  assert_eq(@pdfpaper.uslegal.width(), 8.5)
  assert_eq(@pdfpaper.uslegal.height(), 14.0)
}

///|
test "rectangle converts to points" {
  let paper : @pdfpaper.Paper = Paper::new(unit=Inch, width=1.0, height=2.0)
  match paper.rectangle() {
    @pdf.PdfObject::Array(
      [
        @pdf.PdfObject::Real(x0),
        @pdf.PdfObject::Real(y0),
        @pdf.PdfObject::Real(x1),
        @pdf.PdfObject::Real(y1),
      ]
    ) => {
      assert_eq(x0, 0.0)
      assert_eq(y0, 0.0)
      assert_eq(x1, 72.0)
      assert_eq(y1, 144.0)
    }
    other => fail("unexpected rectangle: \{other.to_string()}")
  }
}

///|
test "a-series constants are portrait" {
  let papers : Array[@pdfpaper.Paper] = [
    @pdfpaper.a0, @pdfpaper.a1, @pdfpaper.a2, @pdfpaper.a3, @pdfpaper.a4, @pdfpaper.a5,
    @pdfpaper.a6, @pdfpaper.a7, @pdfpaper.a8, @pdfpaper.a9, @pdfpaper.a10,
  ]
  for paper in papers {
    assert_true(paper.height() > paper.width())
  }
}
