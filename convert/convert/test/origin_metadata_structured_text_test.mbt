///|
/// Structured-text origin regressions split from the all-format suite.
test "origin_metadata/structured_text_block_origins" {
  let root_dir = origin_tmp_root()

  let out_dir = root_dir + "/structured_text_block_origins"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)

  let csv_path = out_dir + "/quoted_newline.csv"
  write_utf8_text(csv_path, "Name,Note\nAlice,\"line1\nline2\"\nBob,ok\n")

  let csv_doc = @csv.parse_csv(csv_path, "", 6)
  let csv_origin = block_origin_at(csv_doc, 0)
  if csv_origin.line_start != Some(1) {
    fail("csv table block should start at line 1")
  }
  if csv_origin.line_end != Some(4) {
    fail("csv table block should end at physical line 4")
  }
  if csv_origin.row_index != Some(1) {
    fail("csv table block should start at row_index=1")
  }
  if csv_origin.column_index != Some(1) {
    fail("csv table block should start at column_index=1")
  }
  if csv_origin.key_path != None {
    fail("csv table block should not set key_path")
  }
  match csv_doc.blocks.val[0] {
    @cor.Block::RichTable(table) =>
      if table.header_rows != 1 {
        fail("csv should keep header_rows=1 explicit table semantics")
      }
    _ => fail("csv should emit RichTable for table semantics")
  }

  let tsv_doc = @csv.parse_tsv(
    resolve_sample_path("samples/main_process/tsv/tsv_basic.tsv"),
    "",
    6,
  )
  let tsv_origin = block_origin_at(tsv_doc, 0)
  if tsv_origin.line_start != Some(1) {
    fail("tsv table block should start at line 1")
  }
  if tsv_origin.line_end != Some(3) {
    fail("tsv table block should end at line 3")
  }
  if tsv_origin.row_index != Some(1) {
    fail("tsv table block should start at row_index=1")
  }
  if tsv_origin.column_index != Some(1) {
    fail("tsv table block should start at column_index=1")
  }
  if tsv_origin.key_path != None {
    fail("tsv table block should not set key_path")
  }
  match tsv_doc.blocks.val[0] {
    @cor.Block::RichTable(table) =>
      if table.header_rows != 1 {
        fail("tsv should keep header_rows=1 explicit table semantics")
      }
    _ => fail("tsv should emit RichTable for table semantics")
  }

  let json_object_doc = @json.parse_json(
    resolve_sample_path("samples/main_process/json/json_object_basic.json"),
    "",
    6,
  )
  if block_origin_at(json_object_doc, 0).key_path != Some("$") {
    fail("json object block should keep root key_path")
  }

  let json_list_doc = @json.parse_json(
    resolve_sample_path(
      "samples/main_process/json/json_array_scalars_list.json",
    ),
    "",
    6,
  )
  for i in 0..<json_list_doc.block_origins.val.length() {
    if block_origin_at(json_list_doc, i).key_path != Some("$") {
      fail("json scalar list item should keep root key_path")
    }
  }

  let yaml_mapping_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_mapping_basic.yaml"),
    "",
    6,
  )
  if block_origin_at(yaml_mapping_doc, 0).key_path != Some("$") {
    fail("yaml mapping block should keep root key_path")
  }

  let yaml_list_doc = @yaml.parse_yaml(
    resolve_sample_path("samples/main_process/yaml/yaml_sequence_scalars.yaml"),
    "",
    6,
  )
  for i in 0..<yaml_list_doc.block_origins.val.length() {
    if block_origin_at(yaml_list_doc, i).key_path != Some("$") {
      fail("yaml scalar list item should keep root key_path")
    }
  }

  let xml_doc = @xml.parse_xml(
    resolve_sample_path("samples/main_process/xml/xml_comments.xml"),
    "",
    6,
  )
  let xml_origin = block_origin_at(xml_doc, 0)
  if xml_origin.line_start != Some(1) {
    fail("xml code block should start at line 1")
  }
  if xml_origin.line_end != Some(5) {
    fail("xml code block should end at physical line 5")
  }
  if xml_origin.key_path != None {
    fail("xml code block should not set key_path")
  }
  if xml_origin.source_name != Some("xml_comments.xml") {
    fail("xml code block should preserve source_name")
  }

  let markdown_code_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_code_fence.md"),
    "",
    6,
  )
  let markdown_code_origin = block_origin_at(markdown_code_doc, 0)
  if markdown_code_origin.line_start != Some(1) {
    fail("markdown code fence block should start at line 1")
  }
  if markdown_code_origin.line_end != Some(5) {
    fail("markdown code fence block should end at line 5")
  }

  let markdown_frontmatter_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_frontmatter_passthrough.markdown",
    ),
    "",
    6,
  )
  if block_origin_at(markdown_frontmatter_doc, 0).line_start != Some(1) {
    fail("markdown frontmatter block should start at line 1")
  }
  if block_origin_at(markdown_frontmatter_doc, 0).line_end != Some(5) {
    fail("markdown frontmatter block should end at line 5")
  }
  if block_origin_at(markdown_frontmatter_doc, 1).line_start != Some(7) {
    fail("markdown frontmatter heading block should start at line 7")
  }
  if block_origin_at(markdown_frontmatter_doc, 1).line_end != Some(7) {
    fail("markdown frontmatter heading block should end at line 7")
  }
  if block_origin_at(markdown_frontmatter_doc, 2).line_start != Some(9) {
    fail("markdown frontmatter trailing paragraph should start at line 9")
  }
  if block_origin_at(markdown_frontmatter_doc, 2).line_end != Some(9) {
    fail("markdown frontmatter trailing paragraph should end at line 9")
  }

  let markdown_no_newline_doc = @md.parse_markdown(
    resolve_sample_path(
      "samples/main_process/markdown/markdown_no_trailing_newline.md",
    ),
    "",
    6,
  )
  let markdown_no_newline_origin = block_origin_at(markdown_no_newline_doc, 0)
  if markdown_no_newline_origin.line_start != Some(1) {
    fail("markdown no-trailing-newline block should start at line 1")
  }
  if markdown_no_newline_origin.line_end != Some(1) {
    fail("markdown no-trailing-newline block should end at line 1")
  }

  let markdown_crlf_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_crlf.md"),
    "",
    6,
  )
  if block_origin_at(markdown_crlf_doc, 0).line_start != Some(1) {
    fail("markdown crlf heading block should start at line 1")
  }
  if block_origin_at(markdown_crlf_doc, 0).line_end != Some(1) {
    fail("markdown crlf heading block should end at line 1")
  }
  if block_origin_at(markdown_crlf_doc, 1).line_start != Some(3) {
    fail("markdown crlf paragraph block should start at line 3")
  }
  if block_origin_at(markdown_crlf_doc, 1).line_end != Some(3) {
    fail("markdown crlf paragraph block should end at line 3")
  }

  let markdown_bom_doc = @md.parse_markdown(
    resolve_sample_path("samples/main_process/markdown/markdown_bom_utf8.md"),
    "",
    6,
  )
  if block_origin_at(markdown_bom_doc, 0).line_start != Some(1) {
    fail("markdown bom heading block should start at line 1")
  }
  if block_origin_at(markdown_bom_doc, 0).line_end != Some(1) {
    fail("markdown bom heading block should end at line 1")
  }
  if block_origin_at(markdown_bom_doc, 1).line_start != Some(3) {
    fail("markdown bom paragraph block should start at line 3")
  }
  if block_origin_at(markdown_bom_doc, 1).line_end != Some(3) {
    fail("markdown bom paragraph block should end at line 3")
  }

  let txt_doc = @txt.parse_txt(
    resolve_sample_path("samples/main_process/txt/txt_paragraphs.txt"),
    "",
    6,
  )
  if txt_doc.blocks.val.length() != 2 {
    fail("txt_paragraphs should emit exactly two paragraph blocks")
  }

  let txt_first = block_origin_at(txt_doc, 0)
  if txt_first.line_start != Some(1) {
    fail("txt first paragraph should start at line 1")
  }
  if txt_first.line_end != Some(2) {
    fail("txt first paragraph should end at line 2")
  }
  if txt_first.key_path != None {
    fail("txt paragraph should not set key_path")
  }

  let txt_second = block_origin_at(txt_doc, 1)
  if txt_second.line_start != Some(4) {
    fail("txt second paragraph should start at line 4")
  }
  if txt_second.line_end != Some(5) {
    fail("txt second paragraph should end at line 5")
  }

  let txt_many_doc = @txt.parse_txt(
    resolve_sample_path("samples/main_process/txt/txt_many_paragraphs.txt"),
    "",
    6,
  )
  if txt_many_doc.blocks.val.length() != 5 {
    fail("txt_many_paragraphs should ignore repeated blank lines")
  }
  let txt_many_last = block_origin_at(txt_many_doc, 4)
  if txt_many_last.line_start != Some(14) {
    fail("txt many-paragraph final block should start at line 14")
  }
  if txt_many_last.line_end != Some(14) {
    fail("txt many-paragraph final block should end at line 14")
  }
}
