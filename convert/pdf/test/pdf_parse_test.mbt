///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise {
  let trimmed = path.trim()
  if trimmed == "" {
    return
  }

  let chars = trimmed.to_array()
  let mut current = if chars.length() > 0 && chars[0] == '/' { "/" } else { "" }
  let part : Array[Char] = []

  fn flush(part : Array[Char], current : String) -> String raise {
    if part.length() == 0 {
      return current
    }

    let segment = String::from_array(part)
    part.clear()
    let next = if current == "" || current == "/" {
      current + segment
    } else {
      current + "/" + segment
    }
    ensure_dir(next)
    next
  }

  for ch in chars {
    if ch == '/' {
      current = flush(part, current)
    } else {
      part.push(ch)
    }
  }

  ignore(flush(part, current))
}

///|
fn test_tmp_root() -> String {
  match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
}

///|
fn link_test_page(
  text : String,
  rect : @mbtpdf_core.PdfObject,
) -> @pdfpage.Page raise {
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(10.0, 20.0),
    @pdfops.Op::OpTj(text),
    @pdfops.Op::OpET,
  ]
  let stream = @pdfops.Op::stream_of_ops(ops)
  let font : @mbtpdf_core.PdfObject = Dictionary([
    ("/Type", Name(@mbtpdf_core.PdfName::of_string("/Font"))),
    ("/Subtype", Name(@mbtpdf_core.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@mbtpdf_core.PdfName::of_string("/Times-Roman"))),
  ])
  {
    content: [stream],
    mediabox: rect,
    cropbox: None,
    resources: Dictionary([("/Font", Dictionary([("/F0", font)]))]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
}

///|
async fn write_uri_link_pdf(path : String) -> Unit {
  let pdf0 = @mbtpdf_core.Pdf::empty()
  let rect : @mbtpdf_core.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(400.0),
    Real(200.0),
  ])
  let page = link_test_page("Visit the example website for details.", rect)
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let refs = pdf.page_reference_numbers()
  let annot : @mbtpdf_core.PdfObject = Dictionary([
    ("/Subtype", Name(@mbtpdf_core.PdfName::of_string("/Link"))),
    ("/Rect", Array([Real(9.0), Real(9.0), Real(275.0), Real(30.0)])),
    ("/Contents", String("Visit the example website for details.")),
    (
      "/A",
      Dictionary([
        ("/S", Name(@mbtpdf_core.PdfName::of_string("/URI"))),
        ("/URI", String("https://example.com")),
      ]),
    ),
  ])
  let annot_num = pdf.addobj(annot)
  let page_obj = pdf.lookup_obj(refs[0])
  let updated_page = page_obj.add_entry("/Annots", Array([Indirect(annot_num)]))
  pdf.addobj_given_num((refs[0], updated_page))
  @mbtpdf.write_file(pdf, path)
}

///|
async fn write_internal_dest_pdf(path : String) -> Unit {
  let pdf0 = @mbtpdf_core.Pdf::empty()
  let rect : @mbtpdf_core.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(400.0),
    Real(200.0),
  ])
  let page = link_test_page("See chapter one for background context.", rect)
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let refs = pdf.page_reference_numbers()
  let annot : @mbtpdf_core.PdfObject = Dictionary([
    ("/Subtype", Name(@mbtpdf_core.PdfName::of_string("/Link"))),
    ("/Rect", Array([Real(9.0), Real(9.0), Real(275.0), Real(30.0)])),
    (
      "/Dest",
      Array([
        Indirect(refs[0]),
        Name(@mbtpdf_core.PdfName::of_string("/XYZ")),
        Real(0.0),
        Real(200.0),
        Real(1.0),
      ]),
    ),
  ])
  let annot_num = pdf.addobj(annot)
  let page_obj = pdf.lookup_obj(refs[0])
  let updated_page = page_obj.add_entry("/Annots", Array([Indirect(annot_num)]))
  pdf.addobj_given_num((refs[0], updated_page))
  @mbtpdf.write_file(pdf, path)
}

///|
fn create_pdf_fixture(name : String) -> String raise {
  let dir = test_tmp_root() + "/convert_pdf"
  ensure_dir_tree(dir)
  dir + "/" + name
}

///|
async test "convert/pdf smoke parses text_simple" {
  let input = resolve_sample_path("samples/main_process/pdf/text_simple.pdf")
  let doc = @pdf.parse_pdf(input, "", 6, None, false, false, false)

  if doc.blocks.val.length() == 0 {
    fail("pdf parse should produce at least one block")
  }

  let markdown = @cor.emit_markdown(doc)
  if !markdown.contains("English") {
    fail("pdf markdown should contain English text")
  }
}

///|
async test "convert/pdf emits rich paragraph link for high-confidence URI link" {
  let input = create_pdf_fixture("uri_link.pdf")
  write_uri_link_pdf(input)
  let doc = @pdf.parse_pdf(input, "", 6, None, false, false, false)

  if doc.blocks.val.length() == 0 {
    fail("pdf parse should produce a block for uri link pdf")
  }

  match doc.blocks.val[0] {
    @cor.Block::RichParagraph(inlines) =>
      match inlines {
        [
          @cor.Inline::Link(
            "Visit the example website for details.",
            "https://example.com"
          ),
        ] => ()
        _ => fail("expected single Inline::Link in RichParagraph")
      }
    _ => fail("expected RichParagraph for matched URI link")
  }

  let markdown = @cor.emit_markdown(doc)
  if !markdown.contains(
      "[Visit the example website for details.](https://example.com)",
    ) {
    fail("pdf markdown should contain emitted uri link")
  }
}

///|
async test "convert/pdf keeps internal dest pdf as plain paragraph" {
  let input = create_pdf_fixture("internal_dest.pdf")
  write_internal_dest_pdf(input)
  let doc = @pdf.parse_pdf(input, "", 6, None, false, false, false)

  if doc.blocks.val.length() == 0 {
    fail("pdf parse should produce a block for internal dest pdf")
  }

  match doc.blocks.val[0] {
    @cor.Block::Paragraph(text) =>
      if text != "See chapter one for background context." {
        fail("expected plain paragraph text for internal dest pdf")
      }
    _ => fail("expected plain Paragraph for internal dest")
  }

  let markdown = @cor.emit_markdown(doc)
  if markdown.contains("](") {
    fail("internal dest pdf should not emit markdown link")
  }
}
