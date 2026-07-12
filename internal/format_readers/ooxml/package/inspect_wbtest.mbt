///|
test "OOXML inspect classifies package XML relationship and path errors" {
  let zip = classify_ooxml_error(@ox.OoxmlError::ZipError("bad zip"))
  assert_true(zip.kind == @ox.OoxmlErrorKind::ZipFailure)
  assert_true(zip.detail == "bad zip" && zip.part_name is None)
  let missing_rels = classify_ooxml_error(
    @ox.OoxmlError::MissingPart("word/_rels/document.xml.rels"),
  )
  assert_true(missing_rels.kind == @ox.OoxmlErrorKind::MissingPart)
  assert_true(missing_rels.rels_part_name == missing_rels.part_name)
  let missing_part = classify_ooxml_error(
    @ox.OoxmlError::MissingPart("word/document.xml"),
  )
  assert_true(missing_part.rels_part_name is None)
  let duplicate = classify_ooxml_error(
    @ox.OoxmlError::InvalidXml(
      "[Content_Types].xml: duplicate content type override: /word/document.xml",
    ),
  )
  assert_true(
    duplicate.kind == @ox.OoxmlErrorKind::DuplicateContentTypeOverride,
  )
  assert_true(duplicate.part_name == Some("[Content_Types].xml"))
  let malformed_types = classify_ooxml_error(
    @ox.OoxmlError::InvalidXml("[Content_Types].xml: missing Types root"),
  )
  assert_true(malformed_types.kind == @ox.OoxmlErrorKind::MalformedContentTypes)
  let malformed_rels = classify_ooxml_error(
    @ox.OoxmlError::InvalidXml(
      "relationships rels_part=\"word/_rels/document.xml.rels\" source=\"word/document.xml\": missing Id",
    ),
  )
  assert_true(malformed_rels.kind == @ox.OoxmlErrorKind::MalformedRelationships)
  assert_true(
    malformed_rels.rels_part_name == Some("word/_rels/document.xml.rels"),
  )
  assert_true(malformed_rels.source_part == Some("word/document.xml"))
  assert_eq(malformed_rels.detail, "missing Id")
  let generic_xml = classify_ooxml_error(
    @ox.OoxmlError::InvalidXml("other malformed XML"),
  )
  assert_true(generic_xml.kind == @ox.OoxmlErrorKind::InvalidXml)
  let unsafe_target = classify_ooxml_error(
    @ox.OoxmlError::InvalidPartPath(
      "unsafe relationship target: source: ../../outside.xml",
    ),
  )
  assert_true(
    unsafe_target.kind == @ox.OoxmlErrorKind::UnsafeRelationshipTarget,
  )
  assert_true(unsafe_target.target == Some("../../outside.xml"))
  let collision = classify_ooxml_error(
    @ox.OoxmlError::InvalidPartPath(
      "normalized part collision: word/document.xml",
    ),
  )
  assert_true(collision.kind == @ox.OoxmlErrorKind::DuplicateNormalizedPart)
  let unsafe_name = classify_ooxml_error(
    @ox.OoxmlError::InvalidPartPath("../outside.xml"),
  )
  assert_true(unsafe_name.kind == @ox.OoxmlErrorKind::UnsafePartName)
  let rel_missing = classify_ooxml_error(
    @ox.OoxmlError::RelationshipNotFound("word/document.xml", "rId9"),
  )
  assert_true(
    rel_missing.kind == @ox.OoxmlErrorKind::RelationshipNotFound &&
    rel_missing.rel_id == Some("rId9"),
  )
}

///|
test "OOXML inspect path helpers normalize safe paths and preserve unsafe input" {
  assert_eq(
    normalize_part_name_soft(" /word/./media/../document.xml "),
    "word/document.xml",
  )
  assert_eq(normalize_source_part("/"), "")
  assert_eq(normalize_source_part("  "), "")
  assert_eq(normalize_source_part("/word/document.xml"), "word/document.xml")
  assert_eq(
    rels_part_name_for_source("document.xml"),
    "_rels/document.xml.rels",
  )
  assert_eq(
    rels_part_name_for_source("word/document.xml"),
    "word/_rels/document.xml.rels",
  )
  assert_true(split_dir_file("document.xml") == ("", "document.xml"))
  assert_true(split_dir_file("word/document.xml") == ("word", "document.xml"))
  assert_eq(normalize_relative_path_soft("a//b/./c"), "a/b/c")
  assert_eq(normalize_relative_path_soft("a/b/../c"), "a/c")
  assert_eq(normalize_relative_path_soft("../outside"), "../outside")
  assert_eq(normalize_relative_path_soft("a/../../outside"), "a/../../outside")
  assert_eq(normalize_relative_path_soft(""), "")
  assert_eq(normalize_relative_path_soft("./"), "./")
}

///|
test "OOXML inspect parsers handle quoted fields targets and search boundaries" {
  assert_true(parse_quoted_field("x key=\"value\" y", "key=") == Some("value"))
  assert_true(parse_quoted_field("missing", "key=") is None)
  assert_true(parse_quoted_field("key=value", "key=") is None)
  assert_true(parse_quoted_field("key=\"unterminated", "key=") is None)
  assert_eq(parse_relationship_detail("prefix: detail"), "detail")
  assert_eq(parse_relationship_detail("plain"), "plain")
  assert_true(parse_relationship_target("source: target") == Some("target"))
  assert_true(parse_relationship_target("source:") is None)
  assert_true(parse_relationship_target("plain") is None)
  assert_eq(find_substring("alpha beta", "beta"), 6)
  assert_eq(find_substring("alpha", ""), 0)
  assert_eq(find_substring("a", "long"), -1)
  assert_eq(find_substring("alpha", "x"), -1)
  assert_eq(find_char_from("alpha", 'p', 0), 2)
  assert_eq(find_char_from("alpha", 'x', 0), -1)
}

///|
test "OOXML inspect summary writers cover empty and populated relationships" {
  assert_eq(target_mode_text(@ox.OoxmlTargetMode::Internal), "Internal")
  assert_eq(target_mode_text(@ox.OoxmlTargetMode::External), "External")
  assert_eq(string_opt(None), "(none)")
  assert_eq(string_opt(Some("")), "(empty)")
  assert_eq(string_opt(Some("value")), "value")
  let empty_out = StringBuilder::new()
  write_relationship_infos(empty_out, [])
  assert_eq(empty_out.to_string(), "  (none)\n")
  let rels = [
    {
      source_part: Some("word/document.xml"),
      rels_part_name: "word/_rels/document.xml.rels",
      id: "rId1",
      rel_type: "image",
      target: "media/image1.png",
      target_mode: @ox.OoxmlTargetMode::Internal,
      resolved_target: "word/media/image1.png",
    },
    {
      source_part: None,
      rels_part_name: "_rels/.rels",
      id: "rId2",
      rel_type: "hyperlink",
      target: "https://example.test",
      target_mode: @ox.OoxmlTargetMode::External,
      resolved_target: "https://example.test",
    },
  ]
  let out = StringBuilder::new()
  write_relationship_infos(out, rels)
  let rendered = out.to_string()
  assert_true(rendered.contains("id=rId1"))
  assert_true(rendered.contains("target_mode=Internal"))
  assert_true(rendered.contains("target_mode=External"))
  let refs_out = StringBuilder::new()
  write_asset_refs_inline(refs_out, [])
  assert_eq(refs_out.to_string(), "[]")
}
