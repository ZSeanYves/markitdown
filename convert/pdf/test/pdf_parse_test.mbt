///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  if path.has_prefix(".external/quality_corpus/pdf_external/pdfjs/") {
    let name = path.split("/").last().unwrap_or("").to_owned()
    if name != "" {
      let repo_tracked = "doc_parse/pdf/testdata/pdfjs/" + name
      if @fs.path_exists(repo_tracked) {
        return repo_tracked
      }
      let repo_tracked_fallback = "../../" + repo_tracked
      if @fs.path_exists(repo_tracked_fallback) {
        return repo_tracked_fallback
      }
    }
  }

  if path.has_prefix(".external/quality_corpus/") {
    let suffix = path[25:].to_owned()
    let repo_local_lab = "markitdown-quality-lab/external_quality/" + suffix
    if @fs.path_exists(repo_local_lab) {
      return repo_local_lab
    }
    let sibling_lab = "../markitdown-quality-lab/external_quality/" + suffix
    if @fs.path_exists(sibling_lab) {
      return sibling_lab
    }
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
fn read_utf8_text(path : String) -> String raise {
  @fs.read_file_to_string(path, encoding="utf8") catch {
    e => fail("read sample failed: " + e.to_string())
  }
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
fn write_convert_pdf_test_fixture(
  path : String,
  pdf : @mbtpdf_core.Pdf,
) -> Unit raise {
  let (output, buffer) = @pdfio.Output::of_bytes(2048)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    preserve_objstm=true,
    generate_objstm=false,
    compress_objstm=true,
    None,
    true,
    pdf,
    output,
  )
  @fs.write_bytes_to_file(path, Bytes::from_array(output.extract_bytes(buffer)))
}

///|
fn test_tmp_root() -> String {
  match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
}

///|
fn count_occurrences(text : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }

  let haystack = text.to_array()
  let pattern = needle.to_array()
  if pattern.length() > haystack.length() {
    return 0
  }

  let mut count = 0
  let mut i = 0
  while i + pattern.length() <= haystack.length() {
    let mut matched = true
    let mut j = 0
    while j < pattern.length() {
      if haystack[i + j] != pattern[j] {
        matched = false
        break
      }
      j = j + 1
    }
    if matched {
      count = count + 1
      i = i + pattern.length()
    } else {
      i = i + 1
    }
  }
  count
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
fn write_uri_link_pdf(path : String) -> Unit raise {
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
  write_convert_pdf_test_fixture(path, pdf)
}

///|
fn write_wrapped_uri_link_pdf(path : String) -> Unit raise {
  let pdf0 = @mbtpdf_core.Pdf::empty()
  let rect : @mbtpdf_core.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(400.0),
    Real(200.0),
  ])
  let ops : Array[@pdfops.Op] = [
    @pdfops.Op::OpBT,
    @pdfops.Op::OpTf("/F0", 12.0),
    @pdfops.Op::OpTd(10.0, 40.0),
    @pdfops.Op::OpTj("Visit the example website"),
    @pdfops.Op::OpTd(0.0, -14.0),
    @pdfops.Op::OpTj("for details."),
    @pdfops.Op::OpET,
  ]
  let stream = @pdfops.Op::stream_of_ops(ops)
  let font : @mbtpdf_core.PdfObject = Dictionary([
    ("/Type", Name(@mbtpdf_core.PdfName::of_string("/Font"))),
    ("/Subtype", Name(@mbtpdf_core.PdfName::of_string("/Type1"))),
    ("/BaseFont", Name(@mbtpdf_core.PdfName::of_string("/Times-Roman"))),
  ])
  let page : @pdfpage.Page = {
    content: [stream],
    mediabox: rect,
    cropbox: None,
    resources: Dictionary([("/Font", Dictionary([("/F0", font)]))]),
    rotate: @pdfpage.Rotation::Rotate0,
    rest: Dictionary([]),
  }
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let refs = pdf.page_reference_numbers()
  let annot : @mbtpdf_core.PdfObject = Dictionary([
    ("/Subtype", Name(@mbtpdf_core.PdfName::of_string("/Link"))),
    ("/Rect", Array([Real(9.0), Real(25.0), Real(180.0), Real(55.0)])),
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
  write_convert_pdf_test_fixture(path, pdf)
}

///|
fn write_internal_dest_pdf(path : String) -> Unit raise {
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
  write_convert_pdf_test_fixture(path, pdf)
}

///|
fn write_named_destination_collision_pdf(path : String) -> Unit raise {
  let pdf0 = @mbtpdf_core.Pdf::empty()
  let rect : @mbtpdf_core.PdfObject = Array([
    Real(0.0),
    Real(0.0),
    Real(400.0),
    Real(200.0),
  ])
  let page = link_test_page("Named destination links.", rect)
  let (pdf1, pageroot) = @pdfpage.PdfPageDoc::new(pdf0).add_pagetree([page])
  let pdf = @pdfpage.PdfPageDoc::new(pdf1).add_root(pageroot, [])
  let refs = pdf.page_reference_numbers()

  let foo_dest : @mbtpdf_core.PdfObject = Array([
    Indirect(refs[0]),
    Name(@mbtpdf_core.PdfName::of_string("/Fit")),
  ])
  let bar_dest : @mbtpdf_core.PdfObject = Array([
    Indirect(refs[0]),
    Name(@mbtpdf_core.PdfName::of_string("/Fit")),
  ])
  let dest_tree : @mbtpdf_core.PdfObject = Dictionary([
    ("/Names", Array([String("foo"), foo_dest, String("bar"), bar_dest])),
  ])
  let dest_tree_num = pdf.addobj(dest_tree)
  let rootnum = pdf.root
  let root = pdf.lookup_obj(rootnum)
  let names : @mbtpdf_core.PdfObject = match pdf.lookup_direct("/Names", root) {
    Some(obj) => obj
    None => Dictionary([])
  }
  let updated_names = names.add_entry("/Dests", Indirect(dest_tree_num))
  let updated_root = root.add_entry("/Names", updated_names)
  pdf.addobj_given_num((rootnum, updated_root))
  pdf.trailerdict = pdf.trailerdict.add_entry("/Root", Indirect(rootnum))

  let foo_annot : @mbtpdf_core.PdfObject = Dictionary([
    ("/Subtype", Name(@mbtpdf_core.PdfName::of_string("/Link"))),
    ("/Rect", Array([Real(9.0), Real(9.0), Real(120.0), Real(30.0)])),
    ("/Dest", String("foo")),
  ])
  let bar_annot : @mbtpdf_core.PdfObject = Dictionary([
    ("/Subtype", Name(@mbtpdf_core.PdfName::of_string("/Link"))),
    ("/Rect", Array([Real(9.0), Real(35.0), Real(120.0), Real(56.0)])),
    ("/Dest", String("bar")),
  ])
  let foo_annot_num = pdf.addobj(foo_annot)
  let bar_annot_num = pdf.addobj(bar_annot)
  let page_obj = pdf.lookup_obj(refs[0])
  let updated_page = page_obj.add_entry(
    "/Annots",
    Array([Indirect(foo_annot_num), Indirect(bar_annot_num)]),
  )
  pdf.addobj_given_num((refs[0], updated_page))
  write_convert_pdf_test_fixture(path, pdf)
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
async test "convert/pdf merges hardwrapped sample markdown conservatively" {
  let hardwrap_en_input = resolve_sample_path(
    "samples/main_process/pdf/hardwrap_en.pdf",
  )
  let hardwrap_en_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/pdf/expected/hardwrap_en.md"),
  )
  let hardwrap_en_doc = @pdf.parse_pdf(
    hardwrap_en_input,
    "",
    6,
    None,
    false,
    false,
    false,
  )
  if @cor.emit_markdown(hardwrap_en_doc) != hardwrap_en_expected {
    fail("unexpected markdown for hardwrap_en.pdf")
  }

  let hardwrap_zh_input = resolve_sample_path(
    "samples/main_process/pdf/hardwrap_zh.pdf",
  )
  let hardwrap_zh_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/pdf/expected/hardwrap_zh.md"),
  )
  let hardwrap_zh_doc = @pdf.parse_pdf(
    hardwrap_zh_input,
    "",
    6,
    None,
    false,
    false,
    false,
  )
  if @cor.emit_markdown(hardwrap_zh_doc) != hardwrap_zh_expected {
    fail("unexpected markdown for hardwrap_zh.pdf")
  }

  let text_hardwrap_input = resolve_sample_path(
    "samples/main_process/pdf/text_hardwrap.pdf",
  )
  let text_hardwrap_expected = read_utf8_text(
    resolve_sample_path("samples/main_process/pdf/expected/text_hardwrap.md"),
  )
  let text_hardwrap_doc = @pdf.parse_pdf(
    text_hardwrap_input,
    "",
    6,
    None,
    false,
    false,
    false,
  )
  if @cor.emit_markdown(text_hardwrap_doc) != text_hardwrap_expected {
    fail("unexpected markdown for text_hardwrap.pdf")
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
async test "convert/pdf emits rich paragraph link for wrapped URI link" {
  let input = create_pdf_fixture("uri_link_wrapped.pdf")
  write_wrapped_uri_link_pdf(input)
  let doc = @pdf.parse_pdf(input, "", 6, None, false, false, false)

  if doc.blocks.val.length() == 0 {
    fail("pdf parse should produce a block for wrapped uri link pdf")
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
        _ => fail("expected wrapped paragraph to become single Inline::Link")
      }
    _ => fail("expected RichParagraph for wrapped URI link")
  }

  let markdown = @cor.emit_markdown(doc)
  if !markdown.contains(
      "[Visit the example website for details.](https://example.com)",
    ) {
    fail("wrapped uri link markdown should contain emitted uri link")
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
async test "convert/pdf keeps distinct named destinations when they resolve to the same page" {
  let input = create_pdf_fixture("named_dest_collision.pdf")
  write_named_destination_collision_pdf(input)
  let doc = @pdf.parse_pdf(input, "", 6, None, false, false, false)

  let actual = doc.blocks.val.map(fn(block) {
    match block {
      @cor.Block::Heading(level, text) => "H" + level.to_string() + ":" + text
      @cor.Block::Paragraph(text) => "P:" + text
      @cor.Block::RichParagraph(_) => "RICH"
      _ => "OTHER"
    }
  })
  let expected = [
    "P:Named destination links.", "H2:Annotations", "P:Link (page 1): destination foo -> page 1",
    "P:Link (page 1): destination bar -> page 1",
  ]
  if actual.length() != expected.length() {
    fail(
      "expected " +
      expected.length().to_string() +
      " blocks, got " +
      actual.length().to_string(),
    )
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail(
        "named-destination parse mismatch at " +
        i.to_string() +
        ": expected `" +
        expected[i] +
        "`, got `" +
        actual[i] +
        "`",
      )
    }
  }
}

///|
async test "convert/pdf attaches high-confidence same-page image caption" {
  let out_dir = create_pdf_out_dir("caption_positive")
  let doc = @pdf.parse_pdf(
    resolve_sample_path(
      "samples/main_process/pdf/metadata/pdf_image_single_caption_like.pdf",
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
      "samples/main_process/pdf/metadata/pdf_image_no_caption_negative.pdf",
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
fn write_simple_table_pdf(path : String) -> Unit raise {
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
  write_convert_pdf_test_fixture(path, pdf)
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
      assert_true(table.rows[0] == ["Product", "Region", "Status"])
      assert_true(table.rows[1] == ["Alpha", "East", "Open"])
      assert_true(table.rows[2] == ["Beta", "West", "Closed"])
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
    @inspect.extract_document_inspect_dump(input, @api.default_pdf_config()) {
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
fn write_headerless_numeric_table_pdf(path : String) -> Unit raise {
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
  write_convert_pdf_test_fixture(path, pdf)
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
        assert_true(table.rows[0] == ["Alpha", "12", "4.5%"])
      }
      _ => ()
    }
  }
  if !saw_table {
    fail("expected headerless numeric table to emit RichTable")
  }
}

///|
async test "convert/pdf appends real pdfjs text widget forms with normalized multiline values" {
  let input = resolve_sample_path(
    "doc_parse/pdf/testdata/pdfjs/annotation-text-widget.pdf",
  )
  let doc = @pdf.parse_pdf(input, "", 6, None, false, false, false)
  let markdown = @cor.emit_markdown(doc)

  if !markdown.contains("## Forms") {
    fail("expected text widget sample to append a Forms section")
  }
  if !markdown.contains(
      "Text (page 1): Single line, unlimited length — Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    ) {
    fail("expected first text widget value to be preserved in markdown")
  }
  if !markdown.contains(
      "Text (page 1): Single line, combs — abcdefghijklmnopqrstuvwxyz",
    ) {
    fail("expected comb text widget value to be preserved in markdown")
  }
  if !markdown.contains(
      "Text (page 1): Multiline — Lorem ipsum dolor sit amet, consectetur adipiscing elit. / Aliquam vitae felis ac lectus bibendum ultricies quis non diam. / Morbi id porttitor quam, a iaculis dui. / Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. / Nulla consectetur, ligula in tincidunt placerat, velit augue consectetur orci, / sed mattis libero nunc ut massa. / Etiam facilisis tempus interdum.",
    ) {
    fail(
      "expected multiline text widget value to normalize HTML/CR line breaks",
    )
  }
  if markdown.contains("<br>") || markdown.contains("\r") {
    fail("expected multiline text widget markdown to strip raw HTML/CR breaks")
  }
}

///|
async test "convert/pdf keeps printable hidden annotations but suppresses hidden no-view widgets" {
  let hidden_print_input = resolve_sample_path(
    "doc_parse/pdf/testdata/pdfjs/annotation_hidden_print.pdf",
  )
  let hidden_print_doc = @pdf.parse_pdf(
    hidden_print_input,
    "",
    6,
    None,
    false,
    false,
    false,
  )
  let hidden_print_markdown = @cor.emit_markdown(hidden_print_doc)

  if !hidden_print_markdown.contains("## Annotations") ||
    !hidden_print_markdown.contains("Ink (page 1): Pencil") {
    fail(
      "expected hidden-print sample to keep printable annotation appendix, got: " +
      hidden_print_markdown,
    )
  }
  if hidden_print_markdown.contains("## Forms") {
    fail(
      "expected hidden-print sample to avoid forms appendix leakage, got: " +
      hidden_print_markdown,
    )
  }

  let hidden_noview_input = resolve_sample_path(
    "doc_parse/pdf/testdata/pdfjs/annotation_hidden_noview.pdf",
  )
  let hidden_noview_doc = @pdf.parse_pdf(
    hidden_noview_input,
    "",
    6,
    None,
    false,
    false,
    false,
  )
  let hidden_noview_markdown = @cor.emit_markdown(hidden_noview_doc)

  if hidden_noview_markdown.contains("## Forms") ||
    hidden_noview_markdown.contains("## Annotations") ||
    hidden_noview_markdown.contains("World") ||
    hidden_noview_markdown.contains("Text1") ||
    hidden_noview_markdown.contains("Text2") {
    fail(
      "expected hidden-no-view sample to suppress widget/annotation visibility output, got: " +
      hidden_noview_markdown,
    )
  }
}

///|
async test "convert/pdf keeps pdfjs non-widget annotations without appearance streams" {
  let input = resolve_sample_path(
    "doc_parse/pdf/testdata/pdfjs/annotation-squiggly-without-appearance.pdf",
  )
  let doc = @pdf.parse_pdf(input, "", 6, None, false, false, false)
  let markdown = @cor.emit_markdown(doc)

  if !markdown.contains("# Squiggly (without appearance stream)") ||
    !markdown.contains("## Annotations") ||
    !markdown.contains("Squiggly (page 1): Squiggly content") {
    fail(
      "expected without-appearance squiggly sample to keep readable annotation output, got: " +
      markdown,
    )
  }
}

///|
async test "convert/pdf deduplicates appendix notes for pdfjs square-circle without appearance sample" {
  let without_input = resolve_sample_path(
    "doc_parse/pdf/testdata/pdfjs/annotation-square-circle-without-appearance.pdf",
  )
  let without_doc = @pdf.parse_pdf(
    without_input,
    "",
    6,
    None,
    false,
    false,
    false,
  )
  let without_markdown = @cor.emit_markdown(without_doc)

  let without_square_count = count_occurrences(
    without_markdown, "Square (page 1): Square content",
  )
  let without_circle_count = count_occurrences(
    without_markdown, "Circle (page 1): Circle content",
  )

  if without_square_count != 1 || without_circle_count != 1 {
    fail(
      "expected without-appearance square/circle appendix notes to deduplicate to one each; square=" +
      without_square_count.to_string() +
      ", circle=" +
      without_circle_count.to_string() +
      ", markdown=" +
      without_markdown,
    )
  }

  let normal_input = resolve_sample_path(
    "doc_parse/pdf/testdata/pdfjs/annotation-square-circle.pdf",
  )
  let normal_doc = @pdf.parse_pdf(
    normal_input,
    "",
    6,
    None,
    false,
    false,
    false,
  )
  let normal_markdown = @cor.emit_markdown(normal_doc)

  let normal_square_count = count_occurrences(
    normal_markdown, "Square (page 1): Rectangle — Square content",
  )
  let normal_circle_count = count_occurrences(
    normal_markdown, "Circle (page 1): Oval — Circle content",
  )

  if normal_square_count != 1 || normal_circle_count != 1 {
    fail(
      "expected normal square/circle appearance sample to remain one note each; square=" +
      normal_square_count.to_string() +
      ", circle=" +
      normal_circle_count.to_string() +
      ", markdown=" +
      normal_markdown,
    )
  }
}
