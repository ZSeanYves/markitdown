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
fn assert_block_origin_alignment(doc : @cor.Document) -> Unit raise {
  if doc.blocks.val.length() != doc.block_origins.val.length() {
    fail(
      "block/origin length mismatch: blocks=" +
      doc.blocks.val.length().to_string() +
      " origins=" +
      doc.block_origins.val.length().to_string(),
    )
  }
}

///|
fn assert_image_assets_are_indexed(doc : @cor.Document) -> Unit raise {
  for b in doc.blocks.val {
    match b {
      @cor.Block::Image(_, path) =>
        if !doc.asset_origins.val.contains(path) {
          fail("missing asset origin for image path: " + path)
        }
      @cor.Block::ImageBlock(img) =>
        if !doc.asset_origins.val.contains(img.path) {
          fail("missing asset origin for image path: " + img.path)
        }
      _ => ()
    }
  }
}

///|
fn assert_doc_level_origins(doc : @cor.Document) -> Unit raise {
  for i in 0..<doc.block_origins.val.length() {
    match doc.block_origins.val[i] {
      None => fail("block origin should not be None at index: " + i.to_string())
      Some(origin) => {
        match origin.source_name {
          Some(_) => ()
          None =>
            fail("source_name should be present at index: " + i.to_string())
        }
        match origin.block_index {
          Some(_) => ()
          None =>
            fail("block_index should be present at index: " + i.to_string())
        }
      }
    }
  }
}

///|
fn assert_slide_level_origins(doc : @cor.Document) -> Unit raise {
  let mut has_slide_origin = false
  for i in 0..<doc.block_origins.val.length() {
    match doc.block_origins.val[i] {
      None => fail("block origin should not be None at index: " + i.to_string())
      Some(origin) => {
        match origin.slide {
          Some(_) => has_slide_origin = true
          None => fail("slide should be present at index: " + i.to_string())
        }
        match origin.block_index {
          Some(_) => ()
          None =>
            fail("block_index should be present at index: " + i.to_string())
        }
      }
    }
  }
  if !has_slide_origin {
    fail("expected at least one slide-level origin")
  }
}

///|
fn assert_sheet_level_origins(doc : @cor.Document) -> Unit raise {
  let mut has_sheet_origin = false
  for i in 0..<doc.block_origins.val.length() {
    match doc.block_origins.val[i] {
      None => fail("block origin should not be None at index: " + i.to_string())
      Some(origin) => {
        match origin.sheet {
          Some(_) => has_sheet_origin = true
          None => fail("sheet should be present at index: " + i.to_string())
        }
        match origin.block_index {
          Some(_) => ()
          None =>
            fail("block_index should be present at index: " + i.to_string())
        }
      }
    }
  }
  if !has_sheet_origin {
    fail("expected at least one sheet-level origin")
  }
}

///|
fn assert_page_level_origins(doc : @cor.Document) -> Unit raise {
  let mut has_page_origin = false
  for i in 0..<doc.block_origins.val.length() {
    match doc.block_origins.val[i] {
      None => fail("block origin should not be None at index: " + i.to_string())
      Some(origin) => {
        match origin.page {
          Some(_) => has_page_origin = true
          None => fail("page should be present at index: " + i.to_string())
        }
        match origin.block_index {
          Some(_) => ()
          None =>
            fail("block_index should be present at index: " + i.to_string())
        }
      }
    }
  }
  if !has_page_origin {
    fail("expected at least one page-level origin")
  }
}

///|
test "origin metadata minimal closure for html and docx" {
  let out_dir = "tmp-origin-tests"
  ensure_dir(out_dir)
  ensure_dir(out_dir + "/html")
  ensure_dir(out_dir + "/docx")

  let html_doc = @html.parse_html(
    resolve_sample_path("samples/image/html_img_single.html"),
    out_dir + "/html",
    6,
  )
  assert_block_origin_alignment(html_doc)
  assert_doc_level_origins(html_doc)
  assert_image_assets_are_indexed(html_doc)

  let docx_doc = @doc.parse_docx(
    resolve_sample_path("samples/docx/golden.docx"),
    out_dir + "/docx",
    6,
  )
  assert_block_origin_alignment(docx_doc)
  assert_doc_level_origins(docx_doc)
  assert_image_assets_are_indexed(docx_doc)
}

///|
test "origin metadata minimal closure for pptx and xlsx" {
  let out_dir = "tmp-origin-tests"
  ensure_dir(out_dir)
  ensure_dir(out_dir + "/pptx")
  ensure_dir(out_dir + "/xlsx")

  let pptx_doc = @pptx.parse_pptx(
    resolve_sample_path("samples/image/pptx_image_single.pptx"),
    out_dir + "/pptx",
    6,
  )
  assert_block_origin_alignment(pptx_doc)
  assert_slide_level_origins(pptx_doc)
  assert_image_assets_are_indexed(pptx_doc)

  let xlsx_doc = @xlsx.parse_xlsx(
    resolve_sample_path("samples/xlsx/sheet_simple.xlsx"),
    out_dir + "/xlsx",
    6,
  )
  assert_block_origin_alignment(xlsx_doc)
  assert_sheet_level_origins(xlsx_doc)
}

///|
async test "origin metadata minimal closure for pdf" {
  let out_dir = "tmp-origin-tests"
  ensure_dir(out_dir)
  ensure_dir(out_dir + "/pdf")

  let pdf_doc = @pdf.parse_pdf(
    resolve_sample_path("samples/image/pdf_image_xobject.pdf"),
    out_dir + "/pdf",
    6,
    None,
    false,
    false,
    false,
  )
  assert_block_origin_alignment(pdf_doc)
  assert_page_level_origins(pdf_doc)
  assert_image_assets_are_indexed(pdf_doc)
}
