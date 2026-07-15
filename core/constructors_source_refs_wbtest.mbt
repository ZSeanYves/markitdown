///|
test "source reference builders preserve every location family" {
  let source_ref = empty_source_ref()
    |> source_ref_with_lines(Some("file"), Some("txt"), Some(1), Some(2))
    |> source_ref_with_bytes(Some("file"), Some("txt"), Some(10), Some(20))
    |> source_ref_with_time_range(
      Some("file"),
      Some("srt"),
      Some("00:01"),
      Some("00:02"),
    )
    |> source_ref_with_json_pointer(Some("file"), Some("json"), Some("/a"))
    |> source_ref_with_yaml_path(Some("file"), Some("yaml"), Some("a.b"))
    |> source_ref_with_html_path(Some("file"), Some("html"), Some("body/p"))
    |> source_ref_with_markdown_path(
      Some("file"),
      Some("markdown"),
      Some("Title"),
    )
    |> source_ref_with_container_entry(
      Some("archive"),
      Some("zip"),
      Some("archive.zip"),
      Some("entry"),
      Some(1),
      Some("txt"),
      Some("inner"),
    )
    |> source_ref_with_cell_range(Some("sheet"), Some("xlsx"), Some("A1:B2"))
    |> source_ref_with_office_fields(
      Some("office"),
      Some("pptx"),
      Some("slide1.xml"),
      Some("Sheet1"),
      Some("A1"),
      Some(2),
      Some("shape"),
      Some("rId1"),
    )
    |> source_ref_with_extra("key", "value")
  assert_true(source_ref.line_start == Some(1))
  assert_true(source_ref.byte_end == Some(20))
  assert_true(source_ref.time_start == Some("00:01"))
  assert_true(source_ref.json_pointer == Some("/a"))
  assert_true(source_ref.yaml_path == Some("a.b"))
  assert_true(source_ref.html_path == Some("body/p"))
  assert_true(source_ref.markdown_path == Some("Title"))
  assert_true(source_ref.container_path == Some("archive.zip"))
  assert_true(source_ref.entry_index == Some(1))
  assert_true(source_ref.slide == Some(2))
  assert_true(source_ref.relationship_id == Some("rId1"))
  assert_true(source_ref.extra.get("key") == Some("value"))
}

///|
test "container entry names cover kinds and security findings" {
  let kinds : Array[(ContainerEntryKind, String)] = [
    (Document, "document"),
    (Asset, "asset"),
    (Metadata, "metadata"),
    (Directory, "directory"),
    (Unsupported, "unsupported"),
    (Unsafe, "unsafe"),
  ]
  for entry in kinds {
    assert_eq(container_entry_kind_name(entry.0), entry.1)
  }
  let findings : Array[(ContainerSecurityFinding, String)] = [
    (PathTraversal, "path_traversal"),
    (AbsolutePath, "absolute_path"),
    (EncryptedEntry, "encrypted_entry"),
    (UnsupportedCompression, "unsupported_compression"),
    (CompressionRatioLimit, "compression_ratio_limit"),
    (DuplicateNormalizedPath, "duplicate_normalized_path"),
    (NestedArchive, "nested_archive"),
    (ExternalReference, "external_reference"),
    (ResourceLimitHit, "resource_limit_hit"),
  ]
  for entry in findings {
    assert_eq(container_security_finding_name(entry.0), entry.1)
  }
  let container = make_container_entry(
    "../unsafe",
    Unsafe,
    normalized_path=Some("unsafe"),
    entry_index=Some(1),
    detected_format=Some("txt"),
    compressed_size=Some(1),
    uncompressed_size=Some(1000),
    is_encrypted=true,
    security_findings=[PathTraversal],
  )
  assert_true(container.is_encrypted)
  assert_eq(container.security_findings.length(), 1)
}

///|
test "core constructors and stable names cover all semantic enums" {
  let block_kinds : Array[BlockKind] = [
    Document,
    Section,
    Heading,
    Paragraph,
    List,
    ListItem,
    Table,
    TableRow,
    TableCell,
    Image,
    Code,
    BlockQuote,
    Raw,
  ]
  for kind in block_kinds {
    assert_true(block_kind_name(kind) != "")
  }
  let signal_types : Array[SignalType] = [
    HeadingCandidate,
    ListCandidate,
    TableCandidate,
    CaptionCandidate,
    HeaderFooterCandidate,
    PageBreak,
    SectionBreak,
    ReadingOrderHint,
    FontSignal,
    StyleSignal,
    LayoutSignal,
    OcrSignal,
    TableContinuationCandidate,
    ArtifactCandidate,
    LanguageHint,
    CodeLanguageHint,
    NoteRef,
    CommentRef,
    RenderHint,
  ]
  for signal_type in signal_types {
    assert_true(signal_type_name(signal_type) != "")
  }
  for kind in [InlineKind::Text, LineBreak, Link, Image, Code] {
    assert_true(inline_kind_name(kind) != "")
  }
  for kind in [AssetKind::Image, Attachment, Link, Embedded, Unknown] {
    assert_true(asset_kind_name(kind) != "")
  }
}

///|
test "core block IDs and value constructors preserve provenance" {
  let first_ref = source_ref_with_lines(
    empty_source_ref(),
    Some("file"),
    Some("txt"),
    Some(1),
    Some(1),
  )
  let second_ref = source_ref_with_lines(
    empty_source_ref(),
    Some("file"),
    Some("txt"),
    Some(2),
    Some(2),
  )
  let first_id = make_block_id(Paragraph, "text", source_ref=Some(first_ref))
  let repeated_id = make_block_id(Paragraph, "text", source_ref=Some(first_ref))
  let second_id = make_block_id(Paragraph, "text", source_ref=Some(second_ref))
  let content_crc = make_block_content_crc(Paragraph, "text")
  assert_eq(first_id, finish_block_id(content_crc, Some(first_ref)))
  assert_eq(second_id, finish_block_id(content_crc, Some(second_ref)))
  assert_eq(first_id, repeated_id)
  assert_true(first_id != second_id)
  let block = make_block(Paragraph, "text", source_ref=first_ref)
    |> block_with_block_id("custom")
    |> block_with_attr("key", "value")
    |> block_with_children([make_block(Raw, "child")])
    |> block_with_rich_inlines(Some([make_inline_text("inline")]))
    |> block_with_signals([make_signal(RenderHint, 80)])
  assert_eq(block.block_id, "custom")
  assert_eq(block.children.length(), 1)
  assert_eq(block.rich_inlines.unwrap().length(), 1)
  assert_eq(block.signals.length(), 1)
  assert_true(
    inline_with_attr(make_inline_code("code"), "lang", "mbt").attrs.get("lang") ==
    Some("mbt"),
  )
  assert_true(make_inline_line_break().kind == LineBreak)
  assert_true(make_inline_text_without_source_ref("plain").source_ref is None)
  assert_true(make_inline_line_break_without_source_ref().source_ref is None)
  assert_true(
    make_inline_link("link", "href", title=Some("title")).href == Some("href"),
  )
  assert_true(make_inline_image("alt", "path").href == Some("path"))
  assert_true(make_asset_ref(Image, "asset").asset_id == "asset")
  let map_entry = make_source_map_entry(
    primary_ref=Some(first_ref),
    confidence=Some(90),
  )
  let source_map = empty_source_map()
    |> source_map_with_document_ref(Some(first_ref))
    |> source_map_add_block_entry(map_entry)
    |> source_map_add_asset_entry(map_entry)
  assert_eq(source_map.block_entries.length(), 1)
  assert_eq(source_map.asset_entries.length(), 1)
  let rendered = make_block_without_source_ref(Paragraph, "plain")
    |> block_with_literal_rendering(minimal_inline_escape=true)
    |> block_with_rendered_markdown("rendered")
  assert_true(block_is_literal(rendered))
  assert_true(block_inline_escape_mode(rendered) == Some("minimal"))
  assert_true(block_rendered_markdown(rendered) == Some("rendered"))
  let compact = make_block_without_source_ref(Paragraph, "compact")
    |> block_with_compact_source_ref(
      make_compact_source_ref("file", "html", 1, 1, 0, 7),
    )
    |> block_with_attr("render_inline_escape_mode", "legacy")
  assert_true(block_inline_escape_mode(compact) == Some("legacy"))
}
