///|
fn zip_test_root() -> String raise {
  let root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
  let out = root + "/zip-tests"
  ensure_dir_tree(out)
  out
}

///|
fn cleanup_temp_dir(path : String) -> Unit {
  ignore(try? remove_dir_recursive(path))
}

///|
fn assert_opt_string_eq(
  actual : String?,
  expected : String?,
  message : String,
) -> Unit raise {
  if actual != expected {
    fail(message)
  }
}

///|
test "zip remap_subdoc_assets rewrites paths and asset origins" {
  let root = zip_test_root()
  let out_dir = root + "/remap_subdoc_assets"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let entry_out_dir = out_dir + "/entry"
  let archive_out_dir = out_dir + "/archive"
  ensure_dir_tree(entry_out_dir + "/assets")
  ensure_dir_tree(archive_out_dir)

  @fs.write_string_to_file(
    entry_out_dir + "/assets/image01.png",
    "docx-image",
    encoding="utf8",
  ) catch {
    e => fail("write image01 failed: " + e.to_string())
  }
  @fs.write_string_to_file(
    entry_out_dir + "/assets/image02.jpg",
    "legacy-image",
    encoding="utf8",
  ) catch {
    e => fail("write image02 failed: " + e.to_string())
  }

  let doc = @cor.new_document()
  @cor.push(
    doc,
    @cor.Block::ImageBlock({
      path: "assets/image01.png",
      alt_text: Some("Figure alt text"),
      title: Some("Figure title text"),
      caption: Some("Figure caption"),
      origin: None,
    }),
  )
  @cor.push(doc, @cor.Block::Image("legacy", "assets/image02.jpg"))
  @cor.set_asset_origin(doc, "assets/image01.png", {
    source_name: Some("report.docx"),
    page: None,
    slide: None,
    sheet: None,
    origin_id: Some("docx-asset-1"),
    nearby_caption: Some("Figure caption"),
    object_ref: None,
    relationship_id: Some("rId4"),
    source_path: Some("word/media/image1.png"),
    row_index: None,
    column_index: None,
    key_path: None,
  })

  let remapped = remap_subdoc_assets(
    doc, "docs_report.docx", entry_out_dir, archive_out_dir, "bundle.zip", "docs/report.docx",
  )

  match remapped.blocks.val[0] {
    @cor.Block::ImageBlock(img) => {
      assert_eq(img.path, "assets/archive/docs_report.docx/image01.png")
      assert_opt_string_eq(
        img.caption,
        Some("Figure caption"),
        "expected image caption to be preserved across asset remap",
      )
    }
    _ => fail("expected first block to remain an image block")
  }
  match remapped.blocks.val[1] {
    @cor.Block::Image(_alt, path) =>
      assert_eq(path, "assets/archive/docs_report.docx/image02.jpg")
    _ => fail("expected second block to remain a legacy image block")
  }

  match
    remapped.asset_origins.val.get(
      "assets/archive/docs_report.docx/image01.png",
    ) {
    Some(origin) => {
      assert_opt_string_eq(
        origin.source_name,
        Some("bundle.zip"),
        "expected synthesized legacy source_name to be rewritten to zip file",
      )
      assert_opt_string_eq(
        origin.relationship_id,
        Some("rId4"),
        "expected docx zip asset relationship_id to be preserved",
      )
      assert_opt_string_eq(
        origin.source_path,
        Some("docs/report.docx"),
        "expected docx zip asset source_path to point at archive entry path",
      )
      assert_opt_string_eq(
        origin.key_path,
        Some("docs/report.docx"),
        "expected docx zip asset key_path to point at archive entry path",
      )
      assert_opt_string_eq(
        origin.origin_id,
        Some("zip:docs/report.docx:docx-asset-1"),
        "expected docx zip asset origin_id to be namespaced with entry path",
      )
    }
    None => fail("expected remapped asset origin for image01")
  }
  match
    remapped.asset_origins.val.get(
      "assets/archive/docs_report.docx/image02.jpg",
    ) {
    Some(origin) => {
      assert_opt_string_eq(
        origin.source_name,
        Some("bundle.zip"),
        "expected synthesized legacy source_name to be rewritten to zip file",
      )
      assert_opt_string_eq(
        origin.source_path,
        Some("docs/report.docx"),
        "expected synthesized legacy source_path to point at zip entry path",
      )
      if origin.key_path != Some("docs/report.docx") {
        fail("expected synthesized legacy key_path to point at zip entry path")
      }
      if origin.origin_id !=
        Some("zip:docs/report.docx:assets/archive/docs_report.docx/image02.jpg") {
        fail(
          "expected synthesized legacy origin_id to use namespaced asset path",
        )
      }
    }
    None => fail("expected synthesized asset origin for legacy image")
  }

  if !@fs.path_exists(
      archive_out_dir + "/assets/archive/docs_report.docx/image01.png",
    ) {
    fail("expected copied archive asset for image01")
  }
  if !@fs.path_exists(
      archive_out_dir + "/assets/archive/docs_report.docx/image02.jpg",
    ) {
    fail("expected copied archive asset for image02")
  }
}

///|
test "zip remap_subdoc_assets namespaces duplicate asset names per entry" {
  let root = zip_test_root()
  let out_dir = root + "/remap_duplicate_names"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let archive_out_dir = out_dir + "/archive"
  ensure_dir_tree(archive_out_dir)

  fn build_image_doc(path : String) -> @cor.Document {
    let doc = @cor.new_document()
    @cor.push(
      doc,
      @cor.Block::ImageBlock({
        path,
        alt_text: Some("image"),
        title: None,
        caption: None,
        origin: None,
      }),
    )
    @cor.set_asset_origin(doc, path, {
      source_name: Some("entry.docx"),
      page: None,
      slide: None,
      sheet: None,
      origin_id: Some("asset-1"),
      nearby_caption: None,
      object_ref: None,
      relationship_id: Some("rId1"),
      source_path: Some("word/media/image1.png"),
      row_index: None,
      column_index: None,
      key_path: None,
    })
    doc
  }

  let first_entry_out = out_dir + "/first"
  let second_entry_out = out_dir + "/second"
  ensure_dir_tree(first_entry_out + "/assets")
  ensure_dir_tree(second_entry_out + "/assets")
  @fs.write_string_to_file(
    first_entry_out + "/assets/image01.png",
    "first",
    encoding="utf8",
  ) catch {
    e => fail("write first asset failed: " + e.to_string())
  }
  @fs.write_string_to_file(
    second_entry_out + "/assets/image01.png",
    "second",
    encoding="utf8",
  ) catch {
    e => fail("write second asset failed: " + e.to_string())
  }

  ignore(
    remap_subdoc_assets(
      build_image_doc("assets/image01.png"),
      "docs_report.docx",
      first_entry_out,
      archive_out_dir,
      "bundle.zip",
      "docs/report.docx",
    ),
  )
  ignore(
    remap_subdoc_assets(
      build_image_doc("assets/image01.png"),
      "slides_overview.pptx",
      second_entry_out,
      archive_out_dir,
      "bundle.zip",
      "slides/overview.pptx",
    ),
  )

  let first_bytes = @fs.read_file_to_bytes(
    archive_out_dir + "/assets/archive/docs_report.docx/image01.png",
  ) catch {
    e => fail("read first copied asset failed: " + e.to_string())
  }
  let second_bytes = @fs.read_file_to_bytes(
    archive_out_dir + "/assets/archive/slides_overview.pptx/image01.png",
  ) catch {
    e => fail("read second copied asset failed: " + e.to_string())
  }

  if first_bytes == second_bytes {
    fail("expected namespaced archive assets to keep distinct contents")
  }
}
