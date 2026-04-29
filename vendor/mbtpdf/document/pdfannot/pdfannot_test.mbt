///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
fn[T] assert_is_err(res : Result[T, Error]) -> Unit raise {
  match res {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
test "annotation border dash array" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(100.0),
    Real(100.0),
  ])
  let page = @pdfpage.Page::custom(rect)
  let border = @pdfannot.Border::new(1.0, dasharray=[2, 3])
  let annot = @pdfannot.Annotation::new(@pdfannot.Subtype::Text, border~)
  let updated = @pdfannot.PdfAnnot::new(pdf).add_annotation(page, annot)
  match (pdf.lookup_direct("/Annots", updated.rest) : @pdf.PdfObject?) {
    Some(Array([annot_obj, ..])) =>
      match (pdf.lookup_direct("/Border", annot_obj) : @pdf.PdfObject?) {
        Some(Array([_, _, _, Array(dash)])) => {
          assert_eq(dash.length(), 2)
          match (dash[0] : @pdf.PdfObject) {
            Integer(2) => ()
            _ => fail("expected dash value 2")
          }
        }
        _ => fail("expected border dash array")
      }
    _ => fail("expected /Annots array")
  }
}

///|
test "add_annotation and read back" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(50.0),
    Real(50.0),
  ])
  let page = @pdfpage.Page::custom(rect)
  let border = @pdfannot.Border::new(2.0)
  let annot = @pdfannot.Annotation::new(
    @pdfannot.Subtype::Link,
    content="Go",
    border~,
    rectangle=(1.0, 2.0, 3.0, 4.0),
    colour=(10, 20, 30),
    subject="Subject",
  )
  let updated = @pdfannot.PdfAnnot::new(pdf).add_annotation(page, annot)
  let annots = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(updated)
  assert_eq(annots.length(), 1)
  let a = annots[0]
  match (a.subtype : @pdfannot.Subtype) {
    Link => ()
    _ => fail("expected Link subtype")
  }
  match a.annot_contents {
    Some("Go") => ()
    _ => fail("expected contents")
  }
  assert_close(a.rectangle.0, 1.0)
  assert_close(a.rectangle.1, 2.0)
  assert_close(a.rectangle.2, 3.0)
  assert_close(a.rectangle.3, 4.0)
  match a.colour {
    Some((10, 20, 30)) => ()
    _ => fail("expected color")
  }
}

///|
test "transform_annotations updates rect and quadpoints" {
  let pdf = @pdf.Pdf::empty()
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)])),
    (
      "/QuadPoints",
      Array([
        Real(0.0),
        Real(0.0),
        Real(10.0),
        Real(0.0),
        Real(10.0),
        Real(20.0),
        Real(0.0),
        Real(20.0),
      ]),
    ),
    ("/L", Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)])),
  ])
  let objnum = pdf.addobj(annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let tr = @pdftransform.TransformMatrix::translate(10.0, 20.0)
  @pdfannot.PdfAnnot::new(pdf).transform_annotations(tr, rest)
  let updated = pdf.lookup_obj(objnum)
  match pdf.lookup_direct("/Rect", updated) {
    Some(rect) => {
      let (x0, y0, x1, y1) = pdf.parse_rectangle(rect)
      assert_close(x0, 10.0)
      assert_close(y0, 20.0)
      assert_close(x1, 20.0)
      assert_close(y1, 40.0)
    }
    _ => fail("expected updated rect")
  }
  match (pdf.lookup_direct("/QuadPoints", updated) : @pdf.PdfObject?) {
    Some(Array(values)) => {
      assert_close(pdf.getnum(values[0]), 10.0)
      assert_close(pdf.getnum(values[1]), 20.0)
    }
    _ => fail("expected quadpoints")
  }
  match pdf.lookup_direct("/L", updated) {
    Some(line) => {
      let (x0, y0, x1, y1) = pdf.parse_rectangle(line)
      assert_close(x0, 10.0)
      assert_close(y0, 20.0)
      assert_close(x1, 20.0)
      assert_close(y1, 40.0)
    }
    _ => fail("expected line updated")
  }
}

///|
test "annotations_of_page skips popup parent" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let parent_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
    ("/Rect", rect),
  ])
  let parent_num = pdf.addobj(parent_dict)
  let popup_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Popup"))),
    ("/Rect", rect),
    ("/Parent", Indirect(parent_num)),
  ])
  let popup_num = pdf.addobj(popup_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(parent_num), Indirect(popup_num)])),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page)
  assert_eq(annots.length(), 1)
  match (annots[0].subtype : @pdfannot.Subtype) {
    Popup(inner) =>
      match (inner.subtype : @pdfannot.Subtype) {
        Text => ()
        _ => fail("expected popup parent text subtype")
      }
    _ => fail("expected popup subtype")
  }
}

///|
test "read_annotation uses /BS style" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", rect),
    (
      "/BS",
      Dictionary([
        ("/W", Real(2.0)),
        ("/S", Name(@pdf.PdfName::of_string("/D"))),
        ("/D", Array([Integer(2), Integer(1)])),
      ]),
    ),
  ])
  let objnum = pdf.addobj(annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page)
  assert_eq(annots.length(), 1)
  match (annots[0].border.style : @pdfannot.Style) {
    Dashed => ()
    _ => fail("expected dashed style")
  }
  assert_eq(annots[0].border.dasharray.length(), 2)
}

///|
test "read_annotation parses styles and extras" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let solid : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Highlight"))),
    ("/Rect", rect),
    (
      "/BS",
      Dictionary([
        ("/S", Name(@pdf.PdfName::of_string("/S"))),
        ("/W", Real(3.0)),
        ("/D", Array([Integer(1), Integer(2)])),
      ]),
    ),
  ])
  let underline : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Underline"))),
    ("/Rect", rect),
    ("/BS", Dictionary([("/S", Name(@pdf.PdfName::of_string("/U")))])),
  ])
  let border : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", rect),
    ("/Border", Array([Real(1.0), Real(2.0), Real(3.0)])),
  ])
  let extras : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
    ("/Rect", rect),
    ("/Contents", String("Note")),
    ("/Subj", String("Subject")),
    ("/C", Array([Integer(1), Integer(2), Integer(3)])),
    ("/Foo", Integer(7)),
  ])
  let nums = [
    pdf.addobj(solid),
    pdf.addobj(underline),
    pdf.addobj(border),
    pdf.addobj(extras),
  ]
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array(nums.map(fn(n) { Indirect(n) }))),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page)
  assert_eq(annots.length(), 4)
  match (annots[0].border.style : @pdfannot.Style) {
    Solid => ()
    _ => fail("expected solid style")
  }
  assert_eq(annots[0].border.dasharray.length(), 2)
  match (annots[1].border.style : @pdfannot.Style) {
    UnderlineStyle => ()
    _ => fail("expected underline style")
  }
  assert_close(annots[2].border.hradius, 1.0)
  assert_close(annots[2].border.vradius, 2.0)
  assert_close(annots[2].border.width, 3.0)
  match annots[3].annot_contents {
    Some("Note") => ()
    _ => fail("expected contents")
  }
  match annots[3].subject {
    Some("Subject") => ()
    _ => fail("expected subject")
  }
  match annots[3].colour {
    Some((1, 2, 3)) => ()
    _ => fail("expected colour")
  }
  match (pdf.lookup_direct("/Foo", annots[3].annotrest) : @pdf.PdfObject?) {
    Some(Integer(7)) => ()
    _ => fail("expected extra field")
  }
}

///|
test "read_annotation handles unknown subtype and missing strings" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Weird"))),
    ("/Rect", rect),
    ("/Contents", Name(@pdf.PdfName::of_string("/Nope"))),
    ("/Subj", Name(@pdf.PdfName::of_string("/Nope"))),
  ])
  let objnum = pdf.addobj(annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let annots = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page)
  match (annots[0].subtype : @pdfannot.Subtype) {
    Unknown("/Weird") => ()
    _ => fail("expected unknown subtype")
  }
  match annots[0].annot_contents {
    None => ()
    _ => fail("expected no contents")
  }
  match annots[0].subject {
    None => ()
    _ => fail("expected no subject")
  }
}

///|
test "annotations_of_page handles non-array and add_annotation rejects" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: Dictionary([("/Annots", Null)]),
  }
  let pdf = @pdf.Pdf::empty()
  let annots = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page)
  assert_eq(annots.length(), 0)
  let annot = @pdfannot.Annotation::new(@pdfannot.Subtype::Text)
  assert_is_err(try? @pdfannot.PdfAnnot::new(pdf).add_annotation(page, annot))
}

///|
test "transform_annotations keeps malformed quadpoints" {
  let pdf = @pdf.Pdf::empty()
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)])),
    ("/QuadPoints", Array([Real(0.0), Real(0.0), Real(10.0), Real(0.0)])),
  ])
  let objnum = pdf.addobj(annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let tr = @pdftransform.TransformMatrix::translate(5.0, 5.0)
  @pdfe.with_silenced_logs(fn() {
    @pdfannot.PdfAnnot::new(pdf).transform_annotations(tr, rest)
  })
  let updated = pdf.lookup_obj(objnum)
  match pdf.lookup_direct("/Rect", updated) {
    Some(rect) => {
      let (x0, y0, x1, y1) = pdf.parse_rectangle(rect)
      assert_close(x0, 5.0)
      assert_close(y0, 5.0)
      assert_close(x1, 15.0)
      assert_close(y1, 25.0)
    }
    _ => fail("expected rect update")
  }
  match (pdf.lookup_direct("/QuadPoints", updated) : @pdf.PdfObject?) {
    Some(Array(values)) => {
      assert_close(pdf.getnum(values[0]), 0.0)
      assert_close(pdf.getnum(values[1]), 0.0)
      assert_close(pdf.getnum(values[2]), 10.0)
      assert_close(pdf.getnum(values[3]), 0.0)
    }
    _ => fail("expected quadpoints")
  }
}

///|
test "read_annotation handles more subtypes and popup fallback" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annots : Array[@pdf.PdfObject] = [
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/FreeText"))),
      ("/Rect", rect),
    ]),
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Stamp"))),
      ("/Rect", rect),
    ]),
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Line"))),
      ("/Rect", rect),
    ]),
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Squiggly"))),
      ("/Rect", rect),
    ]),
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Popup"))),
      ("/Rect", rect),
      ("/Parent", String("nope")),
    ]),
    Dictionary([("/Rect", rect)]),
  ]
  let nums = annots.map(fn(annot) { pdf.addobj(annot) })
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array(nums.map(fn(n) { Indirect(n) }))),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let parsed = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page)
  assert_eq(parsed.length(), 6)
  match (parsed[0].subtype : @pdfannot.Subtype) {
    FreeText => ()
    _ => fail("expected freetext subtype")
  }
  match (parsed[1].subtype : @pdfannot.Subtype) {
    Stamp => ()
    _ => fail("expected stamp subtype")
  }
  match (parsed[2].subtype : @pdfannot.Subtype) {
    Line => ()
    _ => fail("expected line subtype")
  }
  match (parsed[3].subtype : @pdfannot.Subtype) {
    Squiggly => ()
    _ => fail("expected squiggly subtype")
  }
  match (parsed[4].subtype : @pdfannot.Subtype) {
    Unknown("") => ()
    _ => fail("expected popup fallback subtype")
  }
  match (parsed[5].subtype : @pdfannot.Subtype) {
    Unknown("") => ()
    _ => fail("expected missing subtype fallback")
  }
}

///|
test "read_annotation covers border styles and dash array" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annots : Array[@pdf.PdfObject] = [
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
      ("/Rect", rect),
      ("/BS", Dictionary([("/S", Name(@pdf.PdfName::of_string("/B")))])),
    ]),
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
      ("/Rect", rect),
      ("/BS", Dictionary([("/S", Name(@pdf.PdfName::of_string("/X")))])),
    ]),
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
      ("/Rect", rect),
      (
        "/Border",
        Array([Real(1.0), Real(2.0), Real(3.0), Array([Integer(4), Integer(5)])]),
      ),
    ]),
  ]
  let nums = annots.map(fn(annot) { pdf.addobj(annot) })
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array(nums.map(fn(n) { Indirect(n) }))),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let parsed = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page)
  assert_eq(parsed.length(), 3)
  match (parsed[0].border.style : @pdfannot.Style) {
    Beveled => ()
    _ => fail("expected beveled style")
  }
  match (parsed[1].border.style : @pdfannot.Style) {
    NoStyle => ()
    _ => fail("expected default style")
  }
  assert_eq(parsed[2].border.dasharray.length(), 2)
  assert_eq(parsed[2].border.dasharray[0], 4)
  assert_eq(parsed[2].border.dasharray[1], 5)
}

///|
test "add_annotation merges existing annots and extras" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let existing : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
    ("/Rect", rect),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: Dictionary([("/Annots", Array([existing]))]),
  }
  let base_annot = @pdfannot.Annotation::new(@pdfannot.Subtype::FreeText)
  let annot : @pdfannot.Annotation = {
    subtype: base_annot.subtype,
    annot_contents: base_annot.annot_contents,
    subject: base_annot.subject,
    rectangle: base_annot.rectangle,
    border: base_annot.border,
    colour: base_annot.colour,
    annotrest: Dictionary([("/Foo", Integer(9))]),
  }
  let updated = @pdfannot.PdfAnnot::new(pdf).add_annotation(page, annot)
  match (pdf.lookup_direct("/Annots", updated.rest) : @pdf.PdfObject?) {
    Some(Array([first, second])) => {
      match (pdf.lookup_direct("/Subtype", first) : @pdf.PdfObject?) {
        Some(Name(n)) if n.equal_string_bytes("/FreeText") => ()
        _ => fail("expected freetext subtype")
      }
      match (pdf.lookup_direct("/Foo", first) : @pdf.PdfObject?) {
        Some(Integer(9)) => ()
        _ => fail("expected extra field")
      }
      match (pdf.lookup_direct("/Subtype", second) : @pdf.PdfObject?) {
        Some(Name(n)) if n.equal_string_bytes("/Text") => ()
        _ => fail("expected existing annotation")
      }
    }
    _ => fail("expected annotations array")
  }
}

///|
test "annotations_of_page errors on non-dictionary annots" {
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: Dictionary([("/Annots", Array([Integer(1)]))]),
  }
  let pdf = @pdf.Pdf::empty()
  assert_is_err(try? @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page))
}

///|
test "transform_annotations leaves non-array quadpoints" {
  let pdf = @pdf.Pdf::empty()
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Link"))),
    ("/Rect", Array([Real(0.0), Real(0.0), Real(10.0), Real(20.0)])),
    ("/QuadPoints", Name(@pdf.PdfName::of_string("/Bad"))),
  ])
  let objnum = pdf.addobj(annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let tr = @pdftransform.TransformMatrix::translate(5.0, 5.0)
  @pdfe.with_silenced_logs(fn() {
    @pdfannot.PdfAnnot::new(pdf).transform_annotations(tr, rest)
  })
  let updated = pdf.lookup_obj(objnum)
  match (pdf.lookup_direct("/QuadPoints", updated) : @pdf.PdfObject?) {
    Some(Name(n)) if n.equal_string_bytes("/Bad") => ()
    _ => fail("expected non-array quadpoints")
  }
}

///|
test "read_annotation covers remaining subtypes" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let subtype_names : Array[String] = [
    "/Square", "/Circle", "/Polygon", "/PolyLine", "/StrikeOut", "/Caret", "/Ink",
    "/FileAttachment", "/Sound", "/Movie", "/Widget", "/Screen", "/PrinterMark",
    "/TrapNet", "/Watermark", "/3D",
  ]
  let nums = subtype_names.map(fn(name) {
    pdf.addobj(
      Dictionary([
        ("/Subtype", Name(@pdf.PdfName::of_string(name))),
        ("/Rect", rect),
      ]),
    )
  })
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array(nums.map(fn(n) { Indirect(n) }))),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let parsed = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page)
  assert_eq(parsed.length(), subtype_names.length())
  match (parsed[0].subtype : @pdfannot.Subtype) {
    Square => ()
    _ => fail("expected Square")
  }
  match (parsed[1].subtype : @pdfannot.Subtype) {
    Circle => ()
    _ => fail("expected Circle")
  }
  match (parsed[2].subtype : @pdfannot.Subtype) {
    Polygon => ()
    _ => fail("expected Polygon")
  }
  match (parsed[3].subtype : @pdfannot.Subtype) {
    PolyLine => ()
    _ => fail("expected PolyLine")
  }
  match (parsed[4].subtype : @pdfannot.Subtype) {
    StrikeOut => ()
    _ => fail("expected StrikeOut")
  }
  match (parsed[5].subtype : @pdfannot.Subtype) {
    Caret => ()
    _ => fail("expected Caret")
  }
  match (parsed[6].subtype : @pdfannot.Subtype) {
    Ink => ()
    _ => fail("expected Ink")
  }
  match (parsed[7].subtype : @pdfannot.Subtype) {
    FileAttachment => ()
    _ => fail("expected FileAttachment")
  }
  match (parsed[8].subtype : @pdfannot.Subtype) {
    Sound => ()
    _ => fail("expected Sound")
  }
  match (parsed[9].subtype : @pdfannot.Subtype) {
    Movie => ()
    _ => fail("expected Movie")
  }
  match (parsed[10].subtype : @pdfannot.Subtype) {
    Widget => ()
    _ => fail("expected Widget")
  }
  match (parsed[11].subtype : @pdfannot.Subtype) {
    Screen => ()
    _ => fail("expected Screen")
  }
  match (parsed[12].subtype : @pdfannot.Subtype) {
    PrinterMark => ()
    _ => fail("expected PrinterMark")
  }
  match (parsed[13].subtype : @pdfannot.Subtype) {
    TrapNet => ()
    _ => fail("expected TrapNet")
  }
  match (parsed[14].subtype : @pdfannot.Subtype) {
    Watermark => ()
    _ => fail("expected Watermark")
  }
  match (parsed[15].subtype : @pdfannot.Subtype) {
    ThreeDee => ()
    _ => fail("expected ThreeDee")
  }
}

///|
test "read_annotation handles inset style and non-name /S" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let annots : Array[@pdf.PdfObject] = [
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
      ("/Rect", rect),
      ("/BS", Dictionary([("/S", Name(@pdf.PdfName::of_string("/I")))])),
    ]),
    Dictionary([
      ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
      ("/Rect", rect),
      ("/BS", Dictionary([("/S", Integer(1))])),
    ]),
  ]
  let nums = annots.map(fn(annot) { pdf.addobj(annot) })
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array(nums.map(fn(n) { Indirect(n) }))),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  let parsed = @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page)
  match (parsed[0].border.style : @pdfannot.Style) {
    Inset => ()
    _ => fail("expected inset style")
  }
  match (parsed[1].border.style : @pdfannot.Style) {
    NoStyle => ()
    _ => fail("expected default style")
  }
}

///|
test "read_annotation errors on popup stream and add_annotation requires dictionary rest" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Popup"))),
    ("/Rect", rect),
  ])
  let stream_ref = Ref::new((dict, @pdf.Stream::Got(['x'.to_int().to_byte()])))
  let stream_obj = @pdf.PdfObject::Stream(stream_ref)
  let objnum = pdf.addobj(stream_obj)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let base = @pdfpage.Page::custom(rect)
  let page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest,
  }
  assert_is_err(try? @pdfannot.PdfAnnot::new(pdf).annotations_of_page(page))
  let bad_page : @pdfpage.Page = {
    content: base.content,
    mediabox: base.mediabox,
    resources: base.resources,
    rotate: base.rotate,
    rest: Integer(1),
  }
  let annot = @pdfannot.Annotation::new(@pdfannot.Subtype::Text)
  assert_is_err(
    try? @pdfannot.PdfAnnot::new(pdf).add_annotation(bad_page, annot),
  )
}

///|
test "add_annotation covers remaining subtype variants" {
  let pdf = @pdf.Pdf::empty()
  let rect : @pdf.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(10.0),
    Real(10.0),
  ])
  let page = @pdfpage.Page::custom(rect)
  let variants : Array[(@pdfannot.Subtype, String)] = [
    (@pdfannot.Subtype::FreeText, "/FreeText"),
    (@pdfannot.Subtype::Line, "/Line"),
    (@pdfannot.Subtype::Square, "/Square"),
    (@pdfannot.Subtype::Circle, "/Circle"),
    (@pdfannot.Subtype::Polygon, "/Polygon"),
    (@pdfannot.Subtype::PolyLine, "/PolyLine"),
    (@pdfannot.Subtype::Highlight, "/Highlight"),
    (@pdfannot.Subtype::Underline, "/Underline"),
    (@pdfannot.Subtype::Squiggly, "/Squiggly"),
    (@pdfannot.Subtype::StrikeOut, "/StrikeOut"),
    (@pdfannot.Subtype::Stamp, "/Stamp"),
    (@pdfannot.Subtype::Caret, "/Caret"),
    (@pdfannot.Subtype::Ink, "/Ink"),
    (@pdfannot.Subtype::FileAttachment, "/FileAttachment"),
    (@pdfannot.Subtype::Sound, "/Sound"),
    (@pdfannot.Subtype::Movie, "/Movie"),
    (@pdfannot.Subtype::Widget, "/Widget"),
    (@pdfannot.Subtype::Screen, "/Screen"),
    (@pdfannot.Subtype::PrinterMark, "/PrinterMark"),
    (@pdfannot.Subtype::TrapNet, "/TrapNet"),
    (@pdfannot.Subtype::Watermark, "/Watermark"),
    (@pdfannot.Subtype::ThreeDee, "/3D"),
    (
      @pdfannot.Subtype::Popup(
        @pdfannot.Annotation::new(@pdfannot.Subtype::Text),
      ),
      "/Popup",
    ),
    (@pdfannot.Subtype::Unknown("x"), "/Unknown"),
  ]
  for pair in variants {
    let (subtype, expected) = pair
    let updated = @pdfannot.PdfAnnot::new(pdf).add_annotation(
      page,
      @pdfannot.Annotation::new(subtype),
    )
    match (pdf.lookup_direct("/Annots", updated.rest) : @pdf.PdfObject?) {
      Some(Array([first, ..])) =>
        match (pdf.lookup_direct("/Subtype", first) : @pdf.PdfObject?) {
          Some(Name(name)) => assert_eq(name.to_string_bytes(), expected)
          _ => fail("expected /Subtype")
        }
      _ => fail("expected /Annots")
    }
  }
}

///|
test "transform_annotations leaves missing keys untouched" {
  let pdf = @pdf.Pdf::empty()
  let annot_dict : @pdf.PdfObject = Dictionary([
    ("/Subtype", Name(@pdf.PdfName::of_string("/Text"))),
  ])
  let objnum = pdf.addobj(annot_dict)
  let rest : @pdf.PdfObject = Dictionary([
    ("/Annots", Array([Indirect(objnum)])),
  ])
  let tr = @pdftransform.TransformMatrix::translate(10.0, 20.0)
  @pdfannot.PdfAnnot::new(pdf).transform_annotations(tr, rest)
  let updated = pdf.lookup_obj(objnum)
  match (pdf.lookup_direct("/Rect", updated) : @pdf.PdfObject?) {
    None => ()
    _ => fail("expected no /Rect")
  }
  match (pdf.lookup_direct("/QuadPoints", updated) : @pdf.PdfObject?) {
    None => ()
    _ => fail("expected no /QuadPoints")
  }
  match (pdf.lookup_direct("/L", updated) : @pdf.PdfObject?) {
    None => ()
    _ => fail("expected no /L")
  }
}
