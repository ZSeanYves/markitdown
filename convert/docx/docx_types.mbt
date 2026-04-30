///|
priv enum ListKind {
  Bullet
  Ordered
}

///|
priv struct ParagraphListInfo {
  num_id : Int
  ilvl : Int
}

///|
priv struct DocxNumbering {
  num_to_abs : Map[Int, Int]
  fmt_by_abs_ilvl : Map[String, String]
}

///|
priv struct DocxStyles {
  heading_by_style : Map[String, Int]
  name_by_style : Map[String, String]
}

///|
priv struct DocxRelationshipContext {
  document_relationships : Array[@ox.OoxmlRelationship]
  targets_by_rid : Map[String, String]
  hyperlink_targets_by_rid : Map[String, String]
}

///|
priv struct DocxDocumentFeatures {
  has_pstyle : Bool
  has_numpr : Bool
}

///|
priv struct DocxInlineScanResult {
  inlines : Array[@cor.Inline]
  text : String
}

///|
priv struct DocxImageContext {
  asset_path : String
  alt_text : String?
  title : String?
}

///|
priv struct DocxProfilingCounters {
  paragraphs_seen : Ref[Int]
  hyperlink_nodes_seen : Ref[Int]
  collect_wt_inlines_calls : Ref[Int]
  collect_wt_text_calls : Ref[Int]
  collect_wt_text_total_input_len : Ref[Int]
  hyperlink_target_lookup_calls : Ref[Int]
  relationship_context_read_count : Ref[Int]
  xml_attr_lookup_calls : Ref[Int]
  xml_tag_scan_calls : Ref[Int]
  xml_tag_scan_total_search_len : Ref[Int]
  slice_to_string_calls : Ref[Int]
  styles_read_count : Ref[Int]
  styles_parse_calls : Ref[Int]
  styles_xml_len : Ref[Int]
  style_nodes_seen : Ref[Int]
  style_lookup_calls : Ref[Int]
  style_lookup_misses : Ref[Int]
  styles_tag_scan_calls : Ref[Int]
  styles_tag_scan_total_search_len : Ref[Int]
  styles_elapsed_ms : Ref[UInt64]
  document_has_pstyle : Ref[Bool]
  document_has_numpr : Ref[Bool]
}

///|
let current_docx_profile : Ref[DocxProfilingCounters] = {
  val: {
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
  },
}

///|
let docx_profile_enabled : Ref[Bool] = { val: false }

///|
fn profile_paragraph_seen() -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.paragraphs_seen.val += 1
  }
}

///|
fn profile_hyperlink_node_seen() -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.hyperlink_nodes_seen.val += 1
  }
}

///|
fn profile_collect_wt_inlines_call() -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.collect_wt_inlines_calls.val += 1
  }
}

///|
fn profile_collect_wt_text_call(input_len : Int) -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.collect_wt_text_calls.val += 1
    current_docx_profile.val.collect_wt_text_total_input_len.val += input_len
  }
}

///|
fn profile_hyperlink_target_lookup_call() -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.hyperlink_target_lookup_calls.val += 1
  }
}

///|
fn profile_relationship_context_read() -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.relationship_context_read_count.val += 1
  }
}

///|
fn profile_xml_attr_lookup_call() -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.xml_attr_lookup_calls.val += 1
  }
}

///|
fn profile_xml_tag_scan_call(search_len : Int) -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.xml_tag_scan_calls.val += 1
    current_docx_profile.val.xml_tag_scan_total_search_len.val += search_len
  }
}

///|
fn profile_slice_to_string_call() -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.slice_to_string_calls.val += 1
  }
}

///|
fn profile_document_features(has_pstyle : Bool, has_numpr : Bool) -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.document_has_pstyle.val = has_pstyle
    current_docx_profile.val.document_has_numpr.val = has_numpr
  }
}

///|
fn profile_styles_read(xml_len : Int) -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.styles_read_count.val += 1
    current_docx_profile.val.styles_xml_len.val = xml_len
  }
}

///|
fn profile_styles_parse_call() -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.styles_parse_calls.val += 1
  }
}

///|
fn profile_style_node_seen() -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.style_nodes_seen.val += 1
  }
}

///|
fn profile_style_lookup(hit : Bool) -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.style_lookup_calls.val += 1
    if !hit {
      current_docx_profile.val.style_lookup_misses.val += 1
    }
  }
}

///|
fn profile_styles_tag_scan_call(search_len : Int) -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.styles_tag_scan_calls.val += 1
    current_docx_profile.val.styles_tag_scan_total_search_len.val += search_len
  }
}

///|
fn profile_styles_elapsed_ms(elapsed_ms : UInt64) -> Unit {
  if docx_profile_enabled.val {
    current_docx_profile.val.styles_elapsed_ms.val += elapsed_ms
  }
}

///|
fn reset_docx_scan_profile_counters() -> Unit {
  if docx_profile_enabled.val {
    let counters = current_docx_profile.val
    ignore(@env.now())
    counters.paragraphs_seen.val = 0
    counters.hyperlink_nodes_seen.val = 0
    counters.collect_wt_inlines_calls.val = 0
    counters.collect_wt_text_calls.val = 0
    counters.collect_wt_text_total_input_len.val = 0
    counters.hyperlink_target_lookup_calls.val = 0
    counters.xml_attr_lookup_calls.val = 0
    counters.xml_tag_scan_calls.val = 0
    counters.xml_tag_scan_total_search_len.val = 0
    counters.slice_to_string_calls.val = 0
  }
}

///|
fn profiled_slice_to_string(chars : Array[Char], l : Int, r : Int) -> String {
  profile_slice_to_string_call()
  @cor.slice_to_string(chars, l, r)
}
