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
/// 递归删除目录；目录不存在时直接返回。
fn remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
/// 重新创建一个干净目录。
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  @fs.create_dir(path)
}

///|
/// defer 用的清理函数：吞掉删除错误，保证自己不 raise。
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
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
fn first_image_block(doc : @cor.Document) -> @cor.ImageData? {
  for b in doc.blocks.val {
    match b {
      @cor.Block::ImageBlock(img) => return Some(img)
      _ => ()
    }
  }
  None
}

///|
fn assert_asset_origin_has_min_source(
  doc : @cor.Document,
  path : String,
) -> Unit raise {
  match doc.asset_origins.val.get(path) {
    None => fail("missing asset origin for path: " + path)
    Some(origin) =>
      match origin.source_name {
        Some(_) => ()
        None => fail("asset origin source_name should be present: " + path)
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
test "origin_metadata/html_docx_minimal_closure" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/html_docx_minimal_closure"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/html")
  ensure_dir(out_dir + "/docx")

  let html_doc = @html.parse_html(
    resolve_sample_path("samples/assets/html/html_img_single.html"),
    out_dir + "/html",
    6,
  )
  assert_block_origin_alignment(html_doc)
  assert_doc_level_origins(html_doc)
  assert_image_assets_are_indexed(html_doc)
  match first_image_block(html_doc) {
    Some(img) => {
      assert_eq(img.alt_text, Some("single"))
      assert_eq(img.title, None)
      assert_eq(img.caption, None)
      assert_eq(img.origin, None)
      assert_asset_origin_has_min_source(html_doc, img.path)
    }
    None => fail("expected one html image block")
  }

  let docx_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/golden.docx"),
    out_dir + "/docx",
    6,
  )
  assert_block_origin_alignment(docx_doc)
  assert_doc_level_origins(docx_doc)
  assert_image_assets_are_indexed(docx_doc)
}

///|
test "image_context/html_alt_title_figcaption" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/image_context_html_alt_title_figcaption"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/html-context")

  let html_alt_doc = @html.parse_html(
    resolve_sample_path("samples/metadata/html/html_img_alt_basic.html"),
    out_dir + "/html-context",
    6,
  )
  match first_image_block(html_alt_doc) {
    Some(img) => {
      assert_eq(img.alt_text, Some("red diagram"))
      assert_eq(img.title, None)
      assert_eq(img.caption, None)
      assert_eq(img.origin, None)
      match html_alt_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => assert_eq(asset_origin.nearby_caption, None)
        None => fail("html alt sample asset origin should exist")
      }
    }
    None => fail("expected one html image block for alt sample")
  }

  let html_title_doc = @html.parse_html(
    resolve_sample_path("samples/metadata/html/html_img_title_basic.html"),
    out_dir + "/html-context",
    6,
  )
  match first_image_block(html_title_doc) {
    Some(img) => {
      assert_eq(img.alt_text, Some("red diagram"))
      assert_eq(img.title, Some("Figure title text"))
      assert_eq(img.caption, None)
      assert_eq(img.origin, None)
      assert_asset_origin_has_min_source(html_title_doc, img.path)
    }
    None => fail("expected one html image block for title sample")
  }

  let html_fig_doc = @html.parse_html(
    resolve_sample_path("samples/metadata/html/html_figure_figcaption_basic.html"),
    out_dir + "/html-context",
    6,
  )
  match first_image_block(html_fig_doc) {
    Some(img) => {
      assert_eq(img.alt_text, Some("figure image"))
      assert_eq(img.title, Some("Figure title"))
      assert_eq(img.caption, Some("Figure caption text."))
      assert_eq(img.origin, None)
      match html_fig_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) =>
          assert_eq(asset_origin.nearby_caption, Some("Figure caption text."))
        None => fail("html figure sample asset origin should exist")
      }
    }
    None => fail("expected one html image block for figure sample")
  }

  let html_missing_alt_doc = @html.parse_html(
    resolve_sample_path("samples/metadata/html/html_img_missing_alt_negative.html"),
    out_dir + "/html-context",
    6,
  )
  match first_image_block(html_missing_alt_doc) {
    Some(img) => {
      assert_eq(img.alt_text, None)
      assert_eq(img.title, None)
      assert_eq(img.caption, None)
      assert_asset_origin_has_min_source(html_missing_alt_doc, img.path)
    }
    None => fail("expected one html image block for missing-alt sample")
  }
}

///|
test "origin_metadata/pptx_xlsx_minimal_closure" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/pptx_xlsx_minimal_closure"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pptx")
  ensure_dir(out_dir + "/xlsx")

  let pptx_doc = @pptx.parse_pptx(
    resolve_sample_path("samples/metadata/pptx/pptx_image_single_caption_like.pptx"),
    out_dir + "/pptx",
    6,
  )
  assert_block_origin_alignment(pptx_doc)
  assert_slide_level_origins(pptx_doc)
  assert_image_assets_are_indexed(pptx_doc)
  match first_image_block(pptx_doc) {
    Some(img) => {
      assert_eq(img.alt_text, Some("slide-1-image-1"))
      assert_eq(img.title, None)
      assert_eq(img.caption, Some("Figure 1. Revenue trend"))
      match img.origin {
        Some(origin) => assert_eq(origin.slide, Some(1))
        None => fail("pptx image origin should exist")
      }
      assert_asset_origin_has_min_source(pptx_doc, img.path)
      match pptx_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) =>
          assert_eq(
            asset_origin.nearby_caption,
            Some("Figure 1. Revenue trend"),
          )
        None => fail("pptx asset origin should exist")
      }
    }
    None => fail("expected one pptx image block")
  }

  let xlsx_doc = @xlsx.parse_xlsx(
    resolve_sample_path("samples/main_process/xlsx/sheet_simple.xlsx"),
    out_dir + "/xlsx",
    6,
  )
  assert_block_origin_alignment(xlsx_doc)
  assert_sheet_level_origins(xlsx_doc)
}

///|
async test "origin_metadata/pdf_minimal_closure" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/pdf_minimal_closure"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pdf")

  let pdf_doc = @pdf.parse_pdf(
    resolve_sample_path("samples/assets/pdf/pdf_image_xobject.pdf"),
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
  match first_image_block(pdf_doc) {
    Some(img) => {
      assert_eq(img.title, None)
      assert_eq(img.caption, None)
      match img.origin {
        Some(origin) => assert_eq(origin.page, Some(1))
        None => fail("pdf image origin should exist")
      }
      assert_asset_origin_has_min_source(pdf_doc, img.path)
    }
    None => fail("expected one pdf image block")
  }
}

///|
test "image_context/pptx_caption_association" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/image_context_pptx_caption_association"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pptx-image-context")

  let doc = @pptx.parse_pptx(
    resolve_sample_path("samples/metadata/pptx/pptx_image_single_caption_like.pptx"),
    out_dir + "/pptx-image-context",
    6,
  )
  match first_image_block(doc) {
    Some(img) => {
      assert_eq(img.caption, Some("Figure 1. Revenue trend"))
      match img.origin {
        Some(origin) => assert_eq(origin.slide, Some(1))
        None => fail("pptx image origin should exist")
      }
      match doc.asset_origins.val.get(img.path) {
        Some(asset_origin) =>
          assert_eq(
            asset_origin.nearby_caption,
            Some("Figure 1. Revenue trend"),
          )
        None => fail("pptx image asset origin should exist")
      }
    }
    None => fail("expected one pptx image block")
  }
}

///|
async test "image_context/pdf_caption_like" {
  let root_dir = "tmp-origin-tests"
  ensure_dir(root_dir)

  let out_dir = root_dir + "/image_context_pdf_caption_like"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  ensure_dir(out_dir + "/pdf-context")

  let single_caption_doc = @pdf.parse_pdf(
    resolve_sample_path("samples/metadata/pdf/pdf_image_single_caption_like.pdf"),
    out_dir + "/pdf-context",
    6,
    None,
    false,
    false,
    false,
  )
  match first_image_block(single_caption_doc) {
    Some(img) => {
      assert_eq(img.caption, Some("Figure 1. PDF caption"))
      match img.origin {
        Some(origin) => assert_eq(origin.page, Some(1))
        None => fail("pdf single-caption image origin should exist")
      }
      match single_caption_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) =>
          assert_eq(asset_origin.nearby_caption, Some("Figure 1. PDF caption"))
        None => fail("pdf single-caption asset origin should exist")
      }
    }
    None => fail("expected one image block for pdf caption sample")
  }

  let no_caption_doc = @pdf.parse_pdf(
    resolve_sample_path("samples/metadata/pdf/pdf_image_no_caption_negative.pdf"),
    out_dir + "/pdf-context",
    6,
    None,
    false,
    false,
    false,
  )
  match first_image_block(no_caption_doc) {
    Some(img) => {
      assert_eq(img.caption, None)
      match img.origin {
        Some(origin) => assert_eq(origin.page, Some(1))
        None => fail("pdf no-caption image origin should exist")
      }
      match no_caption_doc.asset_origins.val.get(img.path) {
        Some(asset_origin) => assert_eq(asset_origin.nearby_caption, None)
        None => fail("pdf no-caption asset origin should exist")
      }
    }
    None => fail("expected one image block for pdf no-caption sample")
  }
}
