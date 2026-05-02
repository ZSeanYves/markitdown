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
fn create_pdf_out_dir(name : String) -> String raise {
  let dir = test_tmp_root() + "/convert_pdf/" + name
  ensure_dir_tree(dir)
  dir
}

///|
fn first_image_block(doc : @cor.Document) -> @cor.ImageData? {
  for block in doc.blocks.val {
    match block {
      @cor.Block::ImageBlock(img) => return Some(img)
      _ => ()
    }
  }
  None
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

///|
async test "convert/pdf attaches high-confidence same-page image caption" {
  let out_dir = create_pdf_out_dir("caption_positive")
  let doc = @pdf.parse_pdf(
    resolve_sample_path(
      "samples/metadata/pdf/pdf_image_single_caption_like.pdf",
    ),
    out_dir,
    6,
    None,
    false,
    false,
    false,
  )

  match first_image_block(doc) {
    Some(img) => {
      if img.caption != Some("Figure 1. PDF caption") {
        fail("expected matched pdf image caption to be Figure 1. PDF caption")
      }
      match doc.asset_origins.val.get(img.path) {
        Some(origin) =>
          if origin.nearby_caption != Some("Figure 1. PDF caption") {
            fail(
              "expected nearby_caption to mirror the matched pdf image caption",
            )
          }
        None => fail("expected asset origin for captioned pdf image")
      }
    }
    None => fail("expected one image block for pdf caption sample")
  }
}

///|
async test "convert/pdf rejects ambiguous or missing image caption text" {
  let out_dir = create_pdf_out_dir("caption_negative")
  let doc = @pdf.parse_pdf(
    resolve_sample_path(
      "samples/metadata/pdf/pdf_image_no_caption_negative.pdf",
    ),
    out_dir,
    6,
    None,
    false,
    false,
    false,
  )

  match first_image_block(doc) {
    Some(img) => {
      if img.caption != None {
        fail(
          "expected no matched caption for negative pdf image caption sample",
        )
      }
      match doc.asset_origins.val.get(img.path) {
        Some(origin) =>
          if origin.nearby_caption != None {
            fail(
              "expected no nearby_caption for pdf image without a matched caption",
            )
          }
        None => fail("expected asset origin for no-caption pdf image")
      }
    }
    None => fail("expected one image block for pdf no-caption sample")
  }
}

///|
fn simple_pdf_page_from_ops(
  ops : Array[@pdfops.Op],
  rect : @mbtpdf_core.PdfObject,
) -> @pdfpage.Page raise {
  let stream = @pdfops.Op::stream_of_ops(ops)
  let font : @mbtpdf_core.PdfObject = Dictionary([
    ("/Type", Name(@mbtpdf_core.PdfName::of_string("/Font"))),
    ("/Subtype", Name(@mbtpdf_core.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@mbtpdf_core.PdfName::of_string("/Helvetica"))),
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
async fn write_simple_table_pdf(path : String) -> Unit {
  let rect : @mbtpdf_core.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(400.0),
    Real(240.0),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 180.0),
    @pdfops.Op::OpTj("Product"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(150.0, 180.0),
    @pdfops.Op::OpTj("Region"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(250.0, 180.0),
    @pdfops.Op::OpTj("Status"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 158.0),
    @pdfops.Op::OpTj("Alpha"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(150.0, 158.0),
    @pdfops.Op::OpTj("East"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(250.0, 158.0),
    @pdfops.Op::OpTj("Open"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 136.0),
    @pdfops.Op::OpTj("Beta"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(150.0, 136.0),
    @pdfops.Op::OpTj("West"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(250.0, 136.0),
    @pdfops.Op::OpTj("Closed"),
    @pdfops.Op::OpET,
  ]

  let pdf0 = @mbtpdf_core.Pdf::empty()
  let page = simple_pdf_page_from_ops(ops, rect)
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  @mbtpdf.write_file(pdf, path)
}

///|
async test "convert/pdf emits conservative RichTable for simple aligned table" {
  let input = create_pdf_fixture("simple_table.pdf")
  write_simple_table_pdf(input)
  let doc = @pdf.parse_pdf(input, "", 6, None, false, false, false)

  let tables = doc.blocks.val.filter(fn(block) {
    match block {
      @cor.Block::RichTable(_) => true
      _ => false
    }
  })
  if tables.length() != 1 {
    fail("expected one RichTable block for simple aligned table")
  }

  match tables[0] {
    @cor.Block::RichTable(table) => {
      assert_eq(table.header_rows, 1)
      assert_eq(table.rows[0], ["Product", "Region", "Status"])
      assert_eq(table.rows[1], ["Alpha", "East", "Open"])
      assert_eq(table.rows[2], ["Beta", "West", "Closed"])
    }
    _ => fail("expected RichTable block")
  }

  let markdown = @cor.emit_markdown(doc)
  if !markdown.contains("| Product | Region | Status |") {
    fail("expected markdown table header")
  }
  if !markdown.contains("| Alpha | East | Open |") {
    fail("expected markdown table row")
  }
}

///|
async test "convert/pdf simple table fixture keeps visible table signal in inspect dump" {
  let input = create_pdf_fixture("simple_table.pdf")
  write_simple_table_pdf(input)
  let dump = match
    @api.extract_document_inspect_dump(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_inspect_dump failed: " + e.to_string())
  }

  if !dump.contains("Product") ||
    !dump.contains("Region") ||
    !dump.contains("Status") {
    fail("inspect dump should contain table header texts")
  }
  if !dump.contains("Alpha") || !dump.contains("West") {
    fail("inspect dump should contain body table values")
  }
}

///|
async fn write_headerless_numeric_table_pdf(path : String) -> Unit {
  let rect : @mbtpdf_core.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(400.0),
    Real(240.0),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 180.0),
    @pdfops.Op::OpTj("Alpha"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(180.0, 180.0),
    @pdfops.Op::OpTj("12"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(280.0, 180.0),
    @pdfops.Op::OpTj("4.5%"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 158.0),
    @pdfops.Op::OpTj("Beta"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(180.0, 158.0),
    @pdfops.Op::OpTj("9"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(280.0, 158.0),
    @pdfops.Op::OpTj("3.2%"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(40.0, 136.0),
    @pdfops.Op::OpTj("Gamma"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(180.0, 136.0),
    @pdfops.Op::OpTj("7"),
    @pdfops.Op::OpET,
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(280.0, 136.0),
    @pdfops.Op::OpTj("2.1%"),
    @pdfops.Op::OpET,
  ]

  let pdf0 = @mbtpdf_core.Pdf::empty()
  let page = simple_pdf_page_from_ops(ops, rect)
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  @mbtpdf.write_file(pdf, path)
}

///|
async test "convert/pdf supports headerless numeric table with header_rows=0" {
  let input = create_pdf_fixture("headerless_numeric_table.pdf")
  write_headerless_numeric_table_pdf(input)
  let doc = @pdf.parse_pdf(input, "", 6, None, false, false, false)

  let mut saw_table = false
  for block in doc.blocks.val {
    match block {
      @cor.Block::RichTable(table) => {
        saw_table = true
        assert_eq(table.header_rows, 0)
        assert_eq(table.rows[0], ["Alpha", "12", "4.5%"])
      }
      _ => ()
    }
  }
  if !saw_table {
    fail("expected headerless numeric table to emit RichTable")
  }
}
