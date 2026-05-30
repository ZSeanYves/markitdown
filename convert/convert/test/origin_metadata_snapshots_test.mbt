///|
/// Metadata sidecar snapshot regressions split from the all-format suite.
async test "metadata_sidecar/structured_text_origin_snapshots" {
  let html_single_out_dir = origin_tmp_root() +
    "/metadata_sidecar_html_img_single"
  recreate_clean_dir(html_single_out_dir)
  defer cleanup_temp_dir(html_single_out_dir)
  ensure_dir(html_single_out_dir + "/html")
  let html_single_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/metadata/html_img_single.html",
    ),
    html_single_out_dir + "/html",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      html_single_doc, "html_img_single.html", "html", "html_img_single.md",
    ),
    "html_img_single.metadata.json",
  )

  let html_figure_out_dir = origin_tmp_root() +
    "/metadata_sidecar_html_figure_figcaption_basic"
  recreate_clean_dir(html_figure_out_dir)
  defer cleanup_temp_dir(html_figure_out_dir)
  ensure_dir(html_figure_out_dir + "/html")
  let html_figure_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/metadata/html_figure_figcaption_basic.html",
    ),
    html_figure_out_dir + "/html",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      html_figure_doc, "html_figure_figcaption_basic.html", "html", "html_figure_figcaption_basic.md",
    ),
    "html_figure_figcaption_basic.metadata.json",
  )

  let html_basic_out_dir = origin_tmp_root() + "/metadata_sidecar_html_basic"
  recreate_clean_dir(html_basic_out_dir)
  defer cleanup_temp_dir(html_basic_out_dir)
  ensure_dir(html_basic_out_dir + "/html")
  let html_basic_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/metadata/html_metadata_basic.html",
    ),
    html_basic_out_dir + "/html",
    6,
  )
  match html_basic_doc.blocks.val[0] {
    @cor.Block::RichHeading(_, _) => ()
    _ => fail("html metadata basic should keep RichHeading block semantics")
  }
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      html_basic_doc, "html_metadata_basic.html", "html", "html_metadata_basic.md",
    ),
    "html_metadata_basic.metadata.json",
  )

  let html_link_image_out_dir = origin_tmp_root() +
    "/metadata_sidecar_html_link_image"
  recreate_clean_dir(html_link_image_out_dir)
  defer cleanup_temp_dir(html_link_image_out_dir)
  ensure_dir(html_link_image_out_dir + "/html")
  let html_link_image_doc = @html.parse_html(
    resolve_sample_path(
      "samples/main_process/html/metadata/html_metadata_link_image.html",
    ),
    html_link_image_out_dir + "/html",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      html_link_image_doc, "html_metadata_link_image.html", "html", "html_metadata_link_image.md",
    ),
    "html_metadata_link_image.metadata.json",
  )

  let xlsx_basic_out_dir = origin_tmp_root() + "/metadata_sidecar_xlsx_basic"
  recreate_clean_dir(xlsx_basic_out_dir)
  defer cleanup_temp_dir(xlsx_basic_out_dir)
  ensure_dir(xlsx_basic_out_dir + "/xlsx")
  let xlsx_basic_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/metadata/xlsx_metadata_basic.xlsx",
    ),
    xlsx_basic_out_dir + "/xlsx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      xlsx_basic_doc,
      "xlsx_metadata_basic.xlsx",
      "xlsx",
      "xlsx_metadata_basic.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/xlsx/metadata/xlsx_metadata_basic.xlsx",
        ),
      ),
    ),
    "xlsx_metadata_basic.metadata.json",
  )

  let xlsx_multi_out_dir = origin_tmp_root() +
    "/metadata_sidecar_xlsx_multi_sheet"
  recreate_clean_dir(xlsx_multi_out_dir)
  defer cleanup_temp_dir(xlsx_multi_out_dir)
  ensure_dir(xlsx_multi_out_dir + "/xlsx")
  let xlsx_multi_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/metadata/xlsx_metadata_multi_sheet.xlsx",
    ),
    xlsx_multi_out_dir + "/xlsx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      xlsx_multi_doc,
      "xlsx_metadata_multi_sheet.xlsx",
      "xlsx",
      "xlsx_metadata_multi_sheet.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/xlsx/metadata/xlsx_metadata_multi_sheet.xlsx",
        ),
      ),
    ),
    "xlsx_metadata_multi_sheet.metadata.json",
  )

  let xlsx_policy_out_dir = origin_tmp_root() +
    "/metadata_sidecar_xlsx_formula_or_merged_policy"
  recreate_clean_dir(xlsx_policy_out_dir)
  defer cleanup_temp_dir(xlsx_policy_out_dir)
  ensure_dir(xlsx_policy_out_dir + "/xlsx")
  let xlsx_policy_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/metadata/xlsx_metadata_formula_or_merged_policy.xlsx",
    ),
    xlsx_policy_out_dir + "/xlsx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      xlsx_policy_doc,
      "xlsx_metadata_formula_or_merged_policy.xlsx",
      "xlsx",
      "xlsx_metadata_formula_or_merged_policy.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/xlsx/metadata/xlsx_metadata_formula_or_merged_policy.xlsx",
        ),
      ),
    ),
    "xlsx_metadata_formula_or_merged_policy.metadata.json",
  )

  let mut saw_xlsx_policy_hints = false
  for block in xlsx_policy_doc.blocks.val {
    match block {
      @cor.Block::RichTable(table) =>
        match table.hints {
          Some(hints) => {
            saw_xlsx_policy_hints = true
            if hints.format != Some("xlsx") {
              fail("expected xlsx format hint in metadata policy sample")
            }
            if hints.sheet_state != Some("visible") {
              fail("expected visible sheet_state in metadata policy sample")
            }
            match hints.merged_ranges {
              Some(ranges) => assert_true(ranges == ["B3:C4"])
              None =>
                fail("xlsx metadata policy sample should expose merged ranges")
            }
            match hints.formula_cells {
              Some(cells) => {
                assert_eq(cells.length(), 1)
                assert_eq(cells[0].reference, "B2")
                assert_eq(cells[0].formula_text, "10+5")
                assert_eq(cells[0].semantic_type, "formula_cached_value")
                if cells[0].policy != Some("cached") {
                  fail("expected cached policy in metadata policy sample")
                }
              }
              None =>
                fail("xlsx metadata policy sample should expose formula cells")
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  assert_true(saw_xlsx_policy_hints)

  let xlsx_formula_states_out_dir = origin_tmp_root() +
    "/metadata_sidecar_xlsx_formula_policy_states"
  recreate_clean_dir(xlsx_formula_states_out_dir)
  defer cleanup_temp_dir(xlsx_formula_states_out_dir)
  ensure_dir(xlsx_formula_states_out_dir + "/xlsx")
  let xlsx_formula_states_doc = @xlsx.parse_xlsx(
    resolve_sample_path(
      "samples/main_process/xlsx/metadata/xlsx_metadata_formula_policy_states.xlsx",
    ),
    xlsx_formula_states_out_dir + "/xlsx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      xlsx_formula_states_doc,
      "xlsx_metadata_formula_policy_states.xlsx",
      "xlsx",
      "xlsx_metadata_formula_policy_states.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/xlsx/metadata/xlsx_metadata_formula_policy_states.xlsx",
        ),
      ),
    ),
    "xlsx_metadata_formula_policy_states.metadata.json",
  )

  let mut saw_xlsx_formula_states = false
  for block in xlsx_formula_states_doc.blocks.val {
    match block {
      @cor.Block::RichTable(table) =>
        match table.hints {
          Some(hints) =>
            match hints.formula_cells {
              Some(cells) => {
                saw_xlsx_formula_states = true
                assert_eq(cells.length(), 4)
                if cells[0].policy != Some("cached") {
                  fail("expected cached policy in XLSX metadata fixture")
                }
                if cells[1].policy != Some("evaluated_missing_cache") {
                  fail(
                    "expected evaluated_missing_cache policy in XLSX metadata fixture",
                  )
                }
                if cells[1].evaluated_value != Some("3") {
                  fail("expected evaluated value 3 in XLSX metadata fixture")
                }
                if cells[2].policy != Some("unsupported_formula") {
                  fail(
                    "expected unsupported_formula policy in XLSX metadata fixture",
                  )
                }
                if cells[3].policy != Some("formula_error") {
                  fail("expected formula_error policy in XLSX metadata fixture")
                }
              }
              None => ()
            }
          None => ()
        }
      _ => ()
    }
  }
  assert_true(saw_xlsx_formula_states)

  let zip_basic_out_dir = origin_tmp_root() + "/metadata_sidecar_zip_basic"
  recreate_clean_dir(zip_basic_out_dir)
  defer cleanup_temp_dir(zip_basic_out_dir)
  let zip_basic_doc = @zipconv.parse_zip(
    resolve_sample_path(
      "samples/main_process/zip/metadata/zip_metadata_basic.zip",
    ),
    zip_basic_out_dir,
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      zip_basic_doc, "zip_metadata_basic.zip", "zip", "zip_metadata_basic.md",
    ),
    "zip_metadata_basic.metadata.json",
  )

  let zip_origins_out_dir = origin_tmp_root() +
    "/metadata_sidecar_zip_entry_origins"
  recreate_clean_dir(zip_origins_out_dir)
  defer cleanup_temp_dir(zip_origins_out_dir)
  let zip_origins_doc = @zipconv.parse_zip(
    resolve_sample_path(
      "samples/main_process/zip/metadata/zip_metadata_entry_origins.zip",
    ),
    zip_origins_out_dir,
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      zip_origins_doc, "zip_metadata_entry_origins.zip", "zip", "zip_metadata_entry_origins.md",
    ),
    "zip_metadata_entry_origins.metadata.json",
  )

  let zip_assets_out_dir = origin_tmp_root() + "/metadata_sidecar_zip_assets"
  recreate_clean_dir(zip_assets_out_dir)
  defer cleanup_temp_dir(zip_assets_out_dir)
  let zip_assets_doc = @zipconv.parse_zip(
    resolve_sample_path(
      "samples/main_process/zip/metadata/zip_metadata_assets.zip",
    ),
    zip_assets_out_dir,
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      zip_assets_doc, "zip_metadata_assets.zip", "zip", "zip_metadata_assets.md",
    ),
    "zip_metadata_assets.metadata.json",
  )
  let zip_inspect = @zipconv.inspect_zip(
    resolve_sample_path(
      "samples/main_process/zip/metadata/zip_metadata_assets.zip",
    ),
  )
  let mut saw_convertable_html = false
  for entry in zip_inspect.entries {
    if entry.normalized_path == Some("site/page.html") {
      saw_convertable_html = true
      if entry.action != @zipconv.ZipInspectAction::Convert {
        fail("zip inspect should mark site/page.html as convertable")
      }
      if entry.dispatch_format != Some("html") {
        fail("zip inspect should classify site/page.html as html")
      }
    }
  }
  if !saw_convertable_html {
    fail("zip inspect should report site/page.html in metadata asset sample")
  }

  let pptx_single_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_image_single_caption_like"
  recreate_clean_dir(pptx_single_out_dir)
  defer cleanup_temp_dir(pptx_single_out_dir)
  ensure_dir(pptx_single_out_dir + "/pptx")
  let pptx_single_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_image_single_caption_like.pptx",
    ),
    pptx_single_out_dir + "/pptx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      pptx_single_doc, "pptx_image_single_caption_like.pptx", "pptx", "pptx_image_single_caption_like.md",
    ),
    "pptx_image_single_caption_like.metadata.json",
  )

  let pptx_alt_title_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_image_alt_title_basic"
  recreate_clean_dir(pptx_alt_title_out_dir)
  defer cleanup_temp_dir(pptx_alt_title_out_dir)
  ensure_dir(pptx_alt_title_out_dir + "/pptx")
  let pptx_alt_title_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_image_alt_title_basic.pptx",
    ),
    pptx_alt_title_out_dir + "/pptx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      pptx_alt_title_doc, "pptx_image_alt_title_basic.pptx", "pptx", "pptx_image_alt_title_basic.md",
    ),
    "pptx_image_alt_title_basic.metadata.json",
  )

  let pptx_no_alt_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_image_no_alt_negative"
  recreate_clean_dir(pptx_no_alt_out_dir)
  defer cleanup_temp_dir(pptx_no_alt_out_dir)
  ensure_dir(pptx_no_alt_out_dir + "/pptx")
  let pptx_no_alt_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_image_no_alt_negative.pptx",
    ),
    pptx_no_alt_out_dir + "/pptx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      pptx_no_alt_doc, "pptx_image_no_alt_negative.pptx", "pptx", "pptx_image_no_alt_negative.md",
    ),
    "pptx_image_no_alt_negative.metadata.json",
  )

  let pptx_table_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_metadata_table_basic"
  recreate_clean_dir(pptx_table_out_dir)
  defer cleanup_temp_dir(pptx_table_out_dir)
  ensure_dir(pptx_table_out_dir + "/pptx")
  // PPTX H2 slice coverage:
  // keep explicit table metadata regression separate from image-only PPTX cases.
  let pptx_table_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_metadata_table_basic.pptx",
    ),
    pptx_table_out_dir + "/pptx",
    6,
  )
  let mut saw_pptx_table = false
  for block in pptx_table_doc.blocks.val {
    match block {
      @cor.Block::RichTable(table) => {
        saw_pptx_table = true
        if table.header_rows != 1 {
          fail("pptx explicit table metadata sample should keep header_rows=1")
        }
      }
      _ => ()
    }
  }
  if !saw_pptx_table {
    fail("pptx explicit table metadata sample should emit RichTable")
  }
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      pptx_table_doc,
      "pptx_metadata_table_basic.pptx",
      "pptx",
      "pptx_metadata_table_basic.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/pptx/metadata/pptx_metadata_table_basic.pptx",
        ),
      ),
    ),
    "pptx_metadata_table_basic.metadata.json",
  )

  let pptx_notes_hidden_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_metadata_notes_hidden"
  recreate_clean_dir(pptx_notes_hidden_out_dir)
  defer cleanup_temp_dir(pptx_notes_hidden_out_dir)
  ensure_dir(pptx_notes_hidden_out_dir + "/pptx")
  // Hidden-slide + speaker-notes coverage is intentionally content-preserving:
  // heading text carries the hidden marker; notes keep existing provenance fields.
  let pptx_notes_hidden_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_metadata_notes_hidden.pptx",
    ),
    pptx_notes_hidden_out_dir + "/pptx",
    6,
  )
  let pptx_notes_hidden_md = @cor.emit_markdown(pptx_notes_hidden_doc)
  if !pptx_notes_hidden_md.contains("## Slide 2 (hidden)") {
    fail(
      "pptx notes+hidden metadata sample should preserve hidden slide marker",
    )
  }
  if !pptx_notes_hidden_md.contains("### Speaker Notes") {
    fail("pptx notes+hidden metadata sample should emit speaker notes heading")
  }
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      pptx_notes_hidden_doc,
      "pptx_metadata_notes_hidden.pptx",
      "pptx",
      "pptx_metadata_notes_hidden.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/pptx/metadata/pptx_metadata_notes_hidden.pptx",
        ),
      ),
    ),
    "pptx_metadata_notes_hidden.metadata.json",
  )

  let pptx_docprops_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_metadata_docprops_rich"
  recreate_clean_dir(pptx_docprops_out_dir)
  defer cleanup_temp_dir(pptx_docprops_out_dir)
  ensure_dir(pptx_docprops_out_dir + "/pptx")
  let pptx_docprops_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_metadata_docprops_rich.pptx",
    ),
    pptx_docprops_out_dir + "/pptx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      pptx_docprops_doc,
      "pptx_metadata_docprops_rich.pptx",
      "pptx",
      "pptx_metadata_docprops_rich.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/pptx/metadata/pptx_metadata_docprops_rich.pptx",
        ),
      ),
    ),
    "pptx_metadata_docprops_rich.metadata.json",
  )

  let pptx_links_images_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_metadata_links_images"
  recreate_clean_dir(pptx_links_images_out_dir)
  defer cleanup_temp_dir(pptx_links_images_out_dir)
  ensure_dir(pptx_links_images_out_dir + "/pptx")
  let pptx_links_images_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_metadata_links_images.pptx",
    ),
    pptx_links_images_out_dir + "/pptx",
    6,
  )
  let pptx_links_images_md = @cor.emit_markdown(pptx_links_images_doc)
  if !pptx_links_images_md.contains(
      "[reference](https://example.com/reference)",
    ) {
    fail("pptx links+images metadata sample should keep hyperlink markdown")
  }
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      pptx_links_images_doc,
      "pptx_metadata_links_images.pptx",
      "pptx",
      "pptx_metadata_links_images.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/pptx/metadata/pptx_metadata_links_images.pptx",
        ),
      ),
    ),
    "pptx_metadata_links_images.metadata.json",
  )

  let pptx_table_grid_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_metadata_table_grid"
  recreate_clean_dir(pptx_table_grid_out_dir)
  defer cleanup_temp_dir(pptx_table_grid_out_dir)
  ensure_dir(pptx_table_grid_out_dir + "/pptx")
  let pptx_table_grid_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_metadata_table_grid.pptx",
    ),
    pptx_table_grid_out_dir + "/pptx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      pptx_table_grid_doc,
      "pptx_metadata_table_grid.pptx",
      "pptx",
      "pptx_metadata_table_grid.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/pptx/metadata/pptx_metadata_table_grid.pptx",
        ),
      ),
    ),
    "pptx_metadata_table_grid.metadata.json",
  )

  let pptx_caption_like_out_dir = origin_tmp_root() +
    "/metadata_sidecar_pptx_metadata_caption_like"
  recreate_clean_dir(pptx_caption_like_out_dir)
  defer cleanup_temp_dir(pptx_caption_like_out_dir)
  ensure_dir(pptx_caption_like_out_dir + "/pptx")
  let pptx_caption_like_doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/metadata/pptx_metadata_caption_like.pptx",
    ),
    pptx_caption_like_out_dir + "/pptx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      pptx_caption_like_doc,
      "pptx_metadata_caption_like.pptx",
      "pptx",
      "pptx_metadata_caption_like.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/pptx/metadata/pptx_metadata_caption_like.pptx",
        ),
      ),
    ),
    "pptx_metadata_caption_like.metadata.json",
  )

  let docx_golden_out_dir = origin_tmp_root() + "/metadata_sidecar_docx_golden"
  recreate_clean_dir(docx_golden_out_dir)
  defer cleanup_temp_dir(docx_golden_out_dir)
  ensure_dir(docx_golden_out_dir + "/docx")
  let docx_golden_doc = @doc.parse_docx(
    resolve_sample_path("samples/main_process/docx/golden.docx"),
    docx_golden_out_dir + "/docx",
    6,
  )
  let docx_table_blocks = docx_golden_doc.blocks.val.filter(fn(block) {
    match block {
      @cor.Block::RichTable(_) => true
      _ => false
    }
  })
  if docx_table_blocks.length() != 1 {
    fail("golden.docx should emit one RichTable block")
  }
  match docx_table_blocks[0] {
    @cor.Block::RichTable(table) =>
      if table.header_rows != 1 {
        fail("docx golden table should keep header_rows=1 explicit semantics")
      }
    _ => fail("golden.docx table block should be RichTable")
  }
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      docx_golden_doc,
      "golden.docx",
      "docx",
      "golden.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path("samples/main_process/docx/golden.docx"),
      ),
    ),
    "golden.metadata.json",
  )
  let docx_json = @cor.emit_metadata_json_with_document_properties(
    docx_golden_doc,
    "golden.docx",
    "docx",
    "golden.md",
    read_ooxml_metadata_document_properties(
      resolve_sample_path("samples/main_process/docx/golden.docx"),
    ),
  )
  if !docx_json.contains("\"header_rows\": 1") {
    fail("docx metadata should expose explicit table header_rows")
  }

  let docx_alt_title_out_dir = origin_tmp_root() +
    "/metadata_sidecar_docx_image_alt_title_basic"
  recreate_clean_dir(docx_alt_title_out_dir)
  defer cleanup_temp_dir(docx_alt_title_out_dir)
  ensure_dir(docx_alt_title_out_dir + "/docx")
  let docx_alt_title_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/metadata/docx_image_alt_title_basic.docx",
    ),
    docx_alt_title_out_dir + "/docx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      docx_alt_title_doc,
      "docx_image_alt_title_basic.docx",
      "docx",
      "docx_image_alt_title_basic.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/docx/metadata/docx_image_alt_title_basic.docx",
        ),
      ),
    ),
    "docx_image_alt_title_basic.metadata.json",
  )

  let docx_no_alt_out_dir = origin_tmp_root() +
    "/metadata_sidecar_docx_image_no_alt_negative"
  recreate_clean_dir(docx_no_alt_out_dir)
  defer cleanup_temp_dir(docx_no_alt_out_dir)
  ensure_dir(docx_no_alt_out_dir + "/docx")
  let docx_no_alt_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/metadata/docx_image_no_alt_negative.docx",
    ),
    docx_no_alt_out_dir + "/docx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      docx_no_alt_doc,
      "docx_image_no_alt_negative.docx",
      "docx",
      "docx_image_no_alt_negative.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/docx/metadata/docx_image_no_alt_negative.docx",
        ),
      ),
    ),
    "docx_image_no_alt_negative.metadata.json",
  )

  let docx_notes_out_dir = origin_tmp_root() + "/metadata_sidecar_docx_notes"
  recreate_clean_dir(docx_notes_out_dir)
  defer cleanup_temp_dir(docx_notes_out_dir)
  ensure_dir(docx_notes_out_dir + "/docx")
  let docx_notes_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/metadata/docx_notes_metadata.docx",
    ),
    docx_notes_out_dir + "/docx",
    6,
  )
  if docx_notes_doc.blocks.val.length() != 4 {
    fail("docx notes metadata sample should emit four body blocks")
  }
  // Keep the structured note IR guard aligned with the metadata sidecar
  // snapshot below.
  if docx_notes_doc.note_definitions.val.length() != 1 {
    fail("docx notes metadata sample should retain one note definition")
  }
  let docx_note = docx_notes_doc.note_definitions.val[0]
  if docx_note.note_id != "1" {
    fail("docx notes metadata sample should preserve footnote id 1")
  }
  if docx_note.blocks.length() != 1 {
    fail("docx notes metadata sample should retain footnote body block")
  }
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      docx_notes_doc,
      "docx_notes_metadata.docx",
      "docx",
      "docx_notes_metadata.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/docx/metadata/docx_notes_metadata.docx",
        ),
      ),
    ),
    "docx_notes_metadata.metadata.json",
  )

  let docx_notes_comments_out_dir = origin_tmp_root() +
    "/metadata_sidecar_docx_notes_comments"
  recreate_clean_dir(docx_notes_comments_out_dir)
  defer cleanup_temp_dir(docx_notes_comments_out_dir)
  ensure_dir(docx_notes_comments_out_dir + "/docx")
  let docx_notes_comments_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/metadata/docx_metadata_notes_comments.docx",
    ),
    docx_notes_comments_out_dir + "/docx",
    6,
  )
  if docx_notes_comments_doc.blocks.val.length() != 4 {
    fail("docx notes/comments metadata sample should emit four body blocks")
  }
  if docx_notes_comments_doc.note_definitions.val.length() != 2 {
    fail(
      "docx notes/comments metadata sample should retain footnote and endnote definitions",
    )
  }
  let docx_footnote = docx_notes_comments_doc.note_definitions.val[0]
  assert_eq(docx_footnote.note_id, "1")
  assert_eq(docx_footnote.marker, "1")
  assert_true(docx_footnote.kind == @cor.NoteKind::Footnote)
  assert_true(
    docx_footnote.source_kind == @cor.NoteSourceKind::DocxFootnoteBody,
  )
  assert_true(docx_footnote.body_status == @cor.NoteBodyStatus::Resolved)
  if docx_footnote.blocks.length() != 1 {
    fail("docx notes/comments metadata sample should retain footnote body")
  }
  match docx_footnote.blocks[0] {
    @cor.Block::Paragraph(text) => assert_eq(text, "Footnote body.")
    _ => fail("docx notes/comments footnote body should be a paragraph")
  }
  let docx_endnote = docx_notes_comments_doc.note_definitions.val[1]
  assert_eq(docx_endnote.note_id, "e1")
  assert_eq(docx_endnote.marker, "e1")
  assert_true(docx_endnote.kind == @cor.NoteKind::Endnote)
  assert_true(docx_endnote.source_kind == @cor.NoteSourceKind::DocxEndnoteBody)
  assert_true(docx_endnote.body_status == @cor.NoteBodyStatus::Resolved)
  if docx_endnote.blocks.length() != 1 {
    fail("docx notes/comments metadata sample should retain endnote body")
  }
  match docx_endnote.blocks[0] {
    @cor.Block::Paragraph(text) => assert_eq(text, "Endnote body.")
    _ => fail("docx notes/comments endnote body should be a paragraph")
  }
  match docx_notes_comments_doc.blocks.val[2] {
    @cor.Block::Heading(_, text) => assert_eq(text, "Comments")
    _ => fail("docx notes/comments sample should retain comments heading")
  }
  match docx_notes_comments_doc.blocks.val[3] {
    @cor.Block::ListItem(_, _, text) => assert_eq(text, "Alice: Comment body.")
    _ => fail("docx notes/comments sample should retain comment body block")
  }
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      docx_notes_comments_doc,
      "docx_metadata_notes_comments.docx",
      "docx",
      "docx_metadata_notes_comments.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/docx/metadata/docx_metadata_notes_comments.docx",
        ),
      ),
    ),
    "docx_metadata_notes_comments.metadata.json",
  )

  let docx_header_footer_out_dir = origin_tmp_root() +
    "/metadata_sidecar_docx_header_footer"
  recreate_clean_dir(docx_header_footer_out_dir)
  defer cleanup_temp_dir(docx_header_footer_out_dir)
  ensure_dir(docx_header_footer_out_dir + "/docx")
  let docx_header_footer_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/metadata/docx_header_footer_metadata.docx",
    ),
    docx_header_footer_out_dir + "/docx",
    6,
  )
  if docx_header_footer_doc.blocks.val.length() != 7 {
    fail("docx header/footer metadata sample should emit seven blocks")
  }
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      docx_header_footer_doc,
      "docx_header_footer_metadata.docx",
      "docx",
      "docx_header_footer_metadata.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/docx/metadata/docx_header_footer_metadata.docx",
        ),
      ),
    ),
    "docx_header_footer_metadata.metadata.json",
  )

  let docx_textbox_out_dir = origin_tmp_root() +
    "/metadata_sidecar_docx_textbox"
  recreate_clean_dir(docx_textbox_out_dir)
  defer cleanup_temp_dir(docx_textbox_out_dir)
  ensure_dir(docx_textbox_out_dir + "/docx")
  let docx_textbox_doc = @doc.parse_docx(
    resolve_sample_path(
      "samples/main_process/docx/metadata/docx_textbox_metadata.docx",
    ),
    docx_textbox_out_dir + "/docx",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      docx_textbox_doc,
      "docx_textbox_metadata.docx",
      "docx",
      "docx_textbox_metadata.md",
      read_ooxml_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/docx/metadata/docx_textbox_metadata.docx",
        ),
      ),
    ),
    "docx_textbox_metadata.metadata.json",
  )

  let csv_doc = @csv.parse_csv(
    resolve_sample_path("samples/main_process/csv/csv_basic.csv"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(csv_doc, "csv_basic.csv", "csv", "csv_basic.md"),
    "csv_basic.metadata.json",
  )
  let csv_metadata_basic_doc = @csv.parse_csv(
    resolve_sample_path(
      "samples/main_process/csv/metadata/csv_metadata_basic.csv",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      csv_metadata_basic_doc, "csv_metadata_basic.csv", "csv", "csv_metadata_basic.md",
    ),
    "csv_metadata_basic.metadata.json",
  )
  let csv_metadata_ragged_doc = @csv.parse_csv(
    resolve_sample_path(
      "samples/main_process/csv/metadata/csv_metadata_ragged_rows.csv",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      csv_metadata_ragged_doc, "csv_metadata_ragged_rows.csv", "csv", "csv_metadata_ragged_rows.md",
    ),
    "csv_metadata_ragged_rows.metadata.json",
  )

  let tsv_doc = @csv.parse_tsv(
    resolve_sample_path("samples/main_process/tsv/tsv_basic.tsv"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(tsv_doc, "tsv_basic.tsv", "tsv", "tsv_basic.md"),
    "tsv_basic.metadata.json",
  )
  let tsv_metadata_basic_doc = @csv.parse_tsv(
    resolve_sample_path(
      "samples/main_process/tsv/metadata/tsv_metadata_basic.tsv",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      tsv_metadata_basic_doc, "tsv_metadata_basic.tsv", "tsv", "tsv_metadata_basic.md",
    ),
    "tsv_metadata_basic.metadata.json",
  )

  let json_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_object_basic.json"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      json_doc, "json_object_basic.json", "json", "json_object_basic.md",
    ),
    "json_object_basic.metadata.json",
  )
  let json_metadata_basic_doc = @json.parse_json(
    resolve_sample_path(
      "samples/main_process/json/metadata/json_metadata_basic.json",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      json_metadata_basic_doc, "json_metadata_basic.json", "json", "json_metadata_basic.md",
    ),
    "json_metadata_basic.metadata.json",
  )
  let json_metadata_table_doc = @json.parse_json(
    resolve_sample_path(
      "samples/main_process/json/metadata/json_metadata_table.json",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      json_metadata_table_doc, "json_metadata_table.json", "json", "json_metadata_table.md",
    ),
    "json_metadata_table.metadata.json",
  )
  let json_metadata_nested_doc = @json.parse_json(
    resolve_sample_path(
      "samples/main_process/json/metadata/json_metadata_nested.json",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      json_metadata_nested_doc, "json_metadata_nested.json", "json", "json_metadata_nested.md",
    ),
    "json_metadata_nested.metadata.json",
  )

  let yaml_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_mapping_basic.yaml"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      yaml_doc, "yaml_mapping_basic.yaml", "yaml", "yaml_mapping_basic.md",
    ),
    "yaml_mapping_basic.metadata.json",
  )

  let xml_basic_doc = @xml.parse_xml(
    resolve_sample_path(
      "samples/main_process/xml/metadata/xml_metadata_basic.xml",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      xml_basic_doc, "xml_metadata_basic.xml", "xml", "xml_metadata_basic.md",
    ),
    "xml_metadata_basic.metadata.json",
  )

  let xml_multiline_doc = @xml.parse_xml(
    resolve_sample_path(
      "samples/main_process/xml/metadata/xml_metadata_multiline.xml",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      xml_multiline_doc, "xml_metadata_multiline.xml", "xml", "xml_metadata_multiline.md",
    ),
    "xml_metadata_multiline.metadata.json",
  )

  let epub_out_dir = origin_tmp_root() + "/metadata_sidecar_epub_metadata_basic"
  recreate_clean_dir(epub_out_dir)
  defer cleanup_temp_dir(epub_out_dir)
  let epub_doc = @epub.parse_epub(
    resolve_sample_path(
      "samples/main_process/epub/metadata/epub_metadata_basic.epub",
    ),
    epub_out_dir,
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      epub_doc,
      "epub_metadata_basic.epub",
      "epub",
      "epub_metadata_basic.md",
      read_epub_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/epub/metadata/epub_metadata_basic.epub",
        ),
      ),
    ),
    "epub_metadata_basic.metadata.json",
  )

  let epub_spine_doc = @epub.parse_epub(
    resolve_sample_path(
      "samples/main_process/epub/metadata/epub_metadata_spine_origins.epub",
    ),
    epub_out_dir,
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      epub_spine_doc,
      "epub_metadata_spine_origins.epub",
      "epub",
      "epub_metadata_spine_origins.md",
      read_epub_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/epub/metadata/epub_metadata_spine_origins.epub",
        ),
      ),
    ),
    "epub_metadata_spine_origins.metadata.json",
  )

  let epub_assets_doc = @epub.parse_epub(
    resolve_sample_path(
      "samples/main_process/epub/metadata/epub_metadata_assets.epub",
    ),
    epub_out_dir,
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      epub_assets_doc,
      "epub_metadata_assets.epub",
      "epub",
      "epub_metadata_assets.md",
      read_epub_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/epub/metadata/epub_metadata_assets.epub",
        ),
      ),
    ),
    "epub_metadata_assets.metadata.json",
  )
  let epub_cover_doc = @epub.parse_epub(
    resolve_sample_path(
      "samples/main_process/epub/metadata/epub_metadata_cover.epub",
    ),
    epub_out_dir,
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      epub_cover_doc,
      "epub_metadata_cover.epub",
      "epub",
      "epub_metadata_cover.md",
      read_epub_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/epub/metadata/epub_metadata_cover.epub",
        ),
      ),
    ),
    "epub_metadata_cover.metadata.json",
  )
  let epub_inspect = @epub.inspect_epub(
    resolve_sample_path("samples/main_process/epub/epub_nav_toc.epub"),
  )
  if epub_inspect.nav_path != Some("OPS/nav.xhtml") {
    fail("epub inspect should expose nav path")
  }
  if epub_inspect.spine_count != 1 {
    fail("epub inspect should expose spine count")
  }

  let epub_warning_doc = @epub.parse_epub(
    resolve_sample_path(
      "samples/main_process/epub/metadata/epub_metadata_warning_block.epub",
    ),
    epub_out_dir,
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json_with_document_properties(
      epub_warning_doc,
      "epub_metadata_warning_block.epub",
      "epub",
      "epub_metadata_warning_block.md",
      read_epub_metadata_document_properties(
        resolve_sample_path(
          "samples/main_process/epub/metadata/epub_metadata_warning_block.epub",
        ),
      ),
    ),
    "epub_metadata_warning_block.metadata.json",
  )

  let markdown_code_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_code_fence.md"),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_code_doc, "markdown_code_fence.md", "markdown", "markdown_code_fence.md",
    ),
    "markdown_code_fence.metadata.json",
  )

  let markdown_frontmatter_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_frontmatter_passthrough.markdown",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_frontmatter_doc, "markdown_frontmatter_passthrough.markdown", "markdown",
      "markdown_frontmatter_passthrough.md",
    ),
    "markdown_frontmatter_passthrough.metadata.json",
  )

  let markdown_no_newline_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_no_trailing_newline.md",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_no_newline_doc, "markdown_no_trailing_newline.md", "markdown", "markdown_no_trailing_newline.md",
    ),
    "markdown_no_trailing_newline.metadata.json",
  )

  let markdown_basic_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/metadata/markdown_metadata_basic.md",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_basic_doc, "markdown_metadata_basic.md", "markdown", "markdown_metadata_basic.md",
    ),
    "markdown_metadata_basic.metadata.json",
  )

  let markdown_multiline_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/metadata/markdown_metadata_heading_or_multiline.md",
    ),
    "",
    6,
  )
  assert_metadata_snapshot(
    @cor.emit_metadata_json(
      markdown_multiline_doc, "markdown_metadata_heading_or_multiline.md", "markdown",
      "markdown_metadata_heading_or_multiline.md",
    ),
    "markdown_metadata_heading_or_multiline.metadata.json",
  )
}
