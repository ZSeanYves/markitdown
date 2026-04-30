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
fn recreate_clean_dir(path : String) -> Unit raise {
  if @fs.path_exists(path) {
    remove_dir_recursive(path)
  }
  @fs.create_dir(path)
}

///|
fn test_tmp_root() -> String {
  ".tmp"
}

///|
fn docx_test_out_dir(name : String) -> String raise {
  ensure_dir_tree(test_tmp_root())
  let root = test_tmp_root() + "/docx"
  ensure_dir(root)
  let dir = root + "/" + name
  recreate_clean_dir(dir)
  dir
}

///|
fn write_profile_report(
  path : String,
  counters : DocxProfilingCounters,
  total_elapsed_ms : UInt64,
  styles_elapsed_ms : UInt64,
  numbering_elapsed_ms : UInt64,
  scan_elapsed_ms : UInt64,
) -> Unit raise {
  let report = "total_elapsed_ms=" +
    total_elapsed_ms.to_string() +
    "\n" +
    "styles_elapsed_ms=" +
    styles_elapsed_ms.to_string() +
    "\n" +
    "numbering_elapsed_ms=" +
    numbering_elapsed_ms.to_string() +
    "\n" +
    "scan_elapsed_ms=" +
    scan_elapsed_ms.to_string() +
    "\n" +
    "paragraphs_seen=" +
    counters.paragraphs_seen.val.to_string() +
    "\n" +
    "hyperlink_nodes_seen=" +
    counters.hyperlink_nodes_seen.val.to_string() +
    "\n" +
    "collect_wt_inlines_calls=" +
    counters.collect_wt_inlines_calls.val.to_string() +
    "\n" +
    "collect_wt_text_calls=" +
    counters.collect_wt_text_calls.val.to_string() +
    "\n" +
    "collect_wt_text_total_input_len=" +
    counters.collect_wt_text_total_input_len.val.to_string() +
    "\n" +
    "hyperlink_target_lookup_calls=" +
    counters.hyperlink_target_lookup_calls.val.to_string() +
    "\n" +
    "relationship_context_read_count=" +
    counters.relationship_context_read_count.val.to_string() +
    "\n" +
    "xml_attr_lookup_calls=" +
    counters.xml_attr_lookup_calls.val.to_string() +
    "\n" +
    "xml_tag_scan_calls=" +
    counters.xml_tag_scan_calls.val.to_string() +
    "\n" +
    "xml_tag_scan_total_search_len=" +
    counters.xml_tag_scan_total_search_len.val.to_string() +
    "\n" +
    "slice_to_string_calls=" +
    counters.slice_to_string_calls.val.to_string() +
    "\n" +
    "styles_read_count=" +
    counters.styles_read_count.val.to_string() +
    "\n" +
    "styles_parse_calls=" +
    counters.styles_parse_calls.val.to_string() +
    "\n" +
    "styles_xml_len=" +
    counters.styles_xml_len.val.to_string() +
    "\n" +
    "style_nodes_seen=" +
    counters.style_nodes_seen.val.to_string() +
    "\n" +
    "style_lookup_calls=" +
    counters.style_lookup_calls.val.to_string() +
    "\n" +
    "style_lookup_misses=" +
    counters.style_lookup_misses.val.to_string() +
    "\n" +
    "styles_tag_scan_calls=" +
    counters.styles_tag_scan_calls.val.to_string() +
    "\n" +
    "styles_tag_scan_total_search_len=" +
    counters.styles_tag_scan_total_search_len.val.to_string() +
    "\n" +
    "styles_elapsed_ms_counter=" +
    counters.styles_elapsed_ms.val.to_string() +
    "\n" +
    "document_has_pstyle=" +
    counters.document_has_pstyle.val.to_string() +
    "\n" +
    "document_has_numpr=" +
    counters.document_has_numpr.val.to_string() +
    "\n"
  @fs.write_string_to_file(path, report, encoding="utf8") catch {
    e => fail("write profile report failed: " + e.to_string())
  }
}

///|
test "docx hyperlink profiling captures hot path counters" {
  let out_dir = docx_test_out_dir("link_many_performance_guard")
  let counter : Ref[Int] = { val: 0 }
  let profile : DocxProfilingCounters = {
    paragraphs_seen: { val: 0 },
    hyperlink_nodes_seen: { val: 0 },
    collect_wt_inlines_calls: { val: 0 },
    collect_wt_text_calls: { val: 0 },
    collect_wt_text_total_input_len: { val: 0 },
    hyperlink_target_lookup_calls: { val: 0 },
    relationship_context_read_count: { val: 0 },
    xml_attr_lookup_calls: { val: 0 },
    xml_tag_scan_calls: { val: 0 },
    xml_tag_scan_total_search_len: { val: 0 },
    slice_to_string_calls: { val: 0 },
    styles_read_count: { val: 0 },
    styles_parse_calls: { val: 0 },
    styles_xml_len: { val: 0 },
    style_nodes_seen: { val: 0 },
    style_lookup_calls: { val: 0 },
    style_lookup_misses: { val: 0 },
    styles_tag_scan_calls: { val: 0 },
    styles_tag_scan_total_search_len: { val: 0 },
    styles_elapsed_ms: { val: 0 },
    document_has_pstyle: { val: false },
    document_has_numpr: { val: false },
  }
  let prev_profile = current_docx_profile.val
  let prev_enabled = docx_profile_enabled.val
  current_docx_profile.val = profile
  docx_profile_enabled.val = true
  defer {
    current_docx_profile.val = prev_profile
    docx_profile_enabled.val = prev_enabled
  }
  let started = @env.now()
  let path = resolve_sample_path(
    "samples/main_process/docx/docx_link_many_performance_guard.docx",
  )
  let pkg = open_docx(path)
  let doc_xml = pkg.read_text_required("word/document.xml")
  let document_features = scan_docx_document_features(doc_xml)
  let rel_ctx = pkg.read_document_relationship_context(Some(counter))
  let asset_by_target = build_docx_asset_path_map(rel_ctx, out_dir)
  let styles_started = @env.now()
  let styles = pkg.load_styles_for_document(document_features)
  let styles_elapsed_ms = @env.now() - styles_started
  let numbering_started = @env.now()
  let numbering = pkg.load_numbering()
  let numbering_elapsed_ms = @env.now() - numbering_started
  pkg.extract_media_by_relationships(
    rel_ctx,
    asset_by_target,
    out_dir + "/assets",
  )
  reset_docx_scan_profile_counters()
  let scan_started = @env.now()
  let doc = scan_document(
    doc_xml,
    rel_ctx,
    asset_by_target,
    styles,
    numbering,
    6,
    @cor.basename(path),
  )
  let scan_elapsed_ms = @env.now() - scan_started
  let total_elapsed_ms = @env.now() - started

  assert_eq(counter.val, 1)
  assert_eq(profile.relationship_context_read_count.val, 1)
  assert_eq(profile.hyperlink_nodes_seen.val, 80)
  assert_eq(profile.hyperlink_target_lookup_calls.val, 80)
  assert_eq(profile.collect_wt_text_calls.val, 0)
  assert_false(profile.document_has_pstyle.val)
  assert_eq(profile.styles_read_count.val, 0)
  assert_eq(profile.styles_parse_calls.val, 0)
  assert_eq(profile.styles_xml_len.val, 0)
  assert_eq(profile.style_nodes_seen.val, 0)
  assert_eq(profile.styles_tag_scan_calls.val, 0)
  assert_true(styles_elapsed_ms < 100)
  assert_true(profile.xml_tag_scan_total_search_len.val < 1_200_000)
  write_profile_report(
    test_tmp_root() + "/docx/link_many_profile.txt",
    profile,
    total_elapsed_ms,
    styles_elapsed_ms,
    numbering_elapsed_ms,
    scan_elapsed_ms,
  )

  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("[Link 001](https://example.com/001)"))
  assert_true(markdown.contains("[Link 080](https://example.com/080)"))
}
