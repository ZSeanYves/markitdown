///|
test "EML parser lowers related HTML CID attachments and nested messages" {
  let eml = [
    "From: Alice <alice@example.test>", "To: Bob <bob@example.test>", "Subject: Complex message",
    "MIME-Version: 1.0", "Content-Type: multipart/related; boundary=outer", "", "--outer",
    "Content-Type: text/html; charset=utf-8", "", "<html><body><h1>Hello</h1><p>Body<img src=\"cid:hero\"></p></body></html>",
    "--outer", "Content-Type: image/png; name=hero.png", "Content-Disposition: inline; filename=hero.png",
    "Content-ID: <hero>", "Content-Transfer-Encoding: base64", "", "aGVsbG8=", "--outer",
    "Content-Type: application/octet-stream; name=data.bin", "Content-Disposition: attachment; filename=data.bin",
    "Content-Transfer-Encoding: base64", "", "AQID", "--outer", "Content-Type: message/rfc822",
    "", "From: nested@example.test", "Subject: Nested", "Content-Type: text/plain",
    "", "Nested body", "--outer--",
  ].join("\r\n")
  let source = @input.input_from_text_with_format(
    eml,
    "complex.eml",
    Some(@input.DetectedFormat::Eml),
  )
  let result = (eml_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Eml),
  ).unwrap()
  assert_true(result.block_stream.unwrap().length() >= 4)
  assert_true(result.assets.length() >= 2)
  assert_true(result.diagnostics.metrics.get("attachment_count") == Some("2"))
  assert_true(result.diagnostics.metrics.get("inline_image_count") == Some("1"))
  assert_true(
    result.diagnostics.metrics.get("nested_message_count") == Some("1"),
  )
  assert_true(result.diagnostics.metrics.get("cid_rewrite_count") is Some(_))
  assert_true(result.diagnostics.metrics.get("selected_body_kind") is Some(_))
  assert_true(result.diagnostics.pass_trace.contains("parse:eml_parser"))
}

///|
test "EML parser rejects malformed multipart and exposes capability limits" {
  let source = @input.input_from_text_with_format(
    "Content-Type: multipart/mixed\n\nbody",
    "broken.eml",
    Some(@input.DetectedFormat::Eml),
  )
  let fallback = (eml_parser().parse)(
    source,
    @parser.new_parse_context(@input.DetectedFormat::Eml),
  ).unwrap()
  assert_eq(fallback.block_stream.unwrap().length(), 1)
  assert_true(fallback.diagnostics.errors.length() == 1)
  assert_true(
    fallback.diagnostics.degraded_features.contains("eml_raw_fenced_fallback"),
  )
  assert_true(
    fallback.diagnostics.metrics.get("syntax_error_count") == Some("1"),
  )
  let capability = eml_parser_capability()
  assert_true(capability.supports_blocks)
  assert_true(capability.produces_images)
  assert_eq(EML_MAX_RECURSIVE_CHILDREN, 64)
  assert_eq(EML_MAX_MATERIALIZED_ASSETS, 64)
}

///|
test "EML parser preserves malformed MIME part with typed recovery diagnostics" {
  let eml = [
    "Content-Type: multipart/mixed; boundary=mix", "", "--mix", "bad header", "",
    "retained raw child", "--mix", "Content-Type: text/plain", "", "valid body",
    "--mix--",
  ].join("\n")
  let result = (eml_parser().parse)(
    @input.input_from_text_with_format(
      eml,
      "recover.eml",
      Some(@input.DetectedFormat::Eml),
    ),
    @parser.new_parse_context(@input.DetectedFormat::Eml),
  ).unwrap()
  let blocks = result.block_stream.unwrap()
  assert_true(blocks.any(block => block.text.contains("retained raw child")))
  assert_true(blocks.any(block => block.text.contains("valid body")))
  assert_true(
    result.diagnostics.degraded_features.contains(
      "eml_malformed_part_recovered",
    ),
  )
  assert_true(
    result.diagnostics.metrics.get("recovered_part_count") == Some("1"),
  )
}

///|
fn eml_wbtest_child_registry() -> @parser.ParserRegistry {
  let registry = @parser.empty_registry()
  let capability = @parser.block_stream_parser_capability(
    @parser.StreamingGranularity::Block,
    false,
    true,
    true,
    true,
    false,
    true,
    false,
  )
  let child = @parser.make_parser(
    "eml_wbtest_child",
    @parser.ParserMode::BlockStreaming,
    capability,
    fn(source, _context) {
      let source_ref = @core.source_ref_with_lines(
        @core.empty_source_ref(),
        Some(source.source_name),
        Some("child"),
        Some(1),
        Some(1),
      )
      let block = @core.make_block(
        @core.BlockKind::Paragraph,
        "child:" + source.source_name,
        source_ref~,
      )
      let diagnostics = @core.empty_diagnostics()
      diagnostics.warnings.push("child warning")
      Ok(
        @parser.parse_result_with_blocks_capability(
          "eml_wbtest_child",
          @parser.ParserMode::BlockStreaming,
          [block],
          diagnostics,
          capability,
        ),
      )
    },
  )
  for
    format in [
      @input.DetectedFormat::Html,
      @input.DetectedFormat::Json,
      @input.DetectedFormat::Xml,
      @input.DetectedFormat::Markdown,
    ] {
    @parser.registry_register(registry, format, child)
  }
  registry
}

///|
test "EML parser recursively dispatches typed MIME children and absorbs diagnostics" {
  let eml = [
    "From: sender@example.test", "Subject: Typed children", "MIME-Version: 1.0",
    "Content-Type: multipart/mixed; boundary=typed", "", "--typed", "Content-Type: text/html; charset=utf-8",
    "", "<p>html child</p>", "--typed", "Content-Type: application/json", "", "{\"kind\":\"json\"}",
    "--typed", "Content-Type: application/xml", "", "<root>xml</root>", "--typed",
    "Content-Type: text/markdown", "", "# markdown", "--typed--",
  ].join("\r\n")
  let result = (eml_parser_with_registry(eml_wbtest_child_registry).parse)(
    @input.input_from_text_with_format(
      eml,
      "typed.eml",
      Some(@input.DetectedFormat::Eml),
    ),
    @parser.new_parse_context(@input.DetectedFormat::Eml),
  ).unwrap()
  let blocks = result.block_stream.unwrap()
  assert_true(blocks.any(block => block.text.contains("typed.eml.html")))
  assert_true(blocks.any(block => block.text.contains("typed.eml.json")))
  assert_true(blocks.any(block => block.text.contains("typed.eml.xml")))
  assert_true(blocks.any(block => block.text.contains("typed.eml.markdown")))
  assert_true(result.diagnostics.warnings.length() >= 4)
  assert_true(
    result.diagnostics.metrics.get("recursive_attachment_dispatch_count") ==
    Some("3"),
  )
}

///|
test "EML lowering preserves typed fallback unknown parts and recursion budget" {
  let eml = [
    "From: sender@example.test", "Subject: Fallback children", "MIME-Version: 1.0",
    "Content-Type: multipart/mixed; boundary=fallback", "", "--fallback", "Content-Type: text/plain",
    "", "", "--fallback", "Content-Type: text/html", "", "<div class='broken", "--fallback",
    "Content-Type: application/json", "", "{broken", "--fallback", "Content-Type: application/problem+json",
    "", "{\"ok\":true}", "--fallback", "Content-Type: application/problem+xml", "",
    "<root/>", "--fallback", "Content-Type: application/x-unknown", "", "opaque",
    "--fallback--",
  ].join("\r\n")
  let message = @deml.parse_eml_message(eml)
  let source = @input.input_from_text_with_format(
    eml,
    "fallback.eml",
    Some(@input.DetectedFormat::Eml),
  )
  let context = @parser.new_parse_context(@input.DetectedFormat::Eml)
  let diagnostics = @core.empty_diagnostics()
  let document = @core.empty_document_ir()
  let registry = @parser.empty_registry()
  assert_true(message.children.length() >= 5)
  let limited = lower_eml_part(
    message.children[0],
    source,
    context,
    registry,
    diagnostics,
    document,
    [],
    EML_MAX_RECURSIVE_CHILDREN,
  )
  assert_eq(limited.length(), 2)
  assert_true(limited[1].text.contains("recursive child limit"))

  let lowered : Array[@core.CoreBlock] = []
  for part in message.children {
    lowered.append(
      lower_eml_part(
        part,
        source,
        context,
        registry,
        diagnostics,
        document,
        [],
        0,
      )[:],
    )
  }
  assert_true(lowered.any(block => block.text.contains("opaque")))
  assert_true(lowered.any(block => block.kind == @core.BlockKind::Code))
  assert_true(
    diagnostics.degraded_features.contains("eml_recursive_child_limit"),
  )
}

///|
test "EML MIME asset and text utility policy covers supported boundary mappings" {
  for
    format in [
      @input.DetectedFormat::Txt,
      @input.DetectedFormat::Markdown,
      @input.DetectedFormat::Json,
      @input.DetectedFormat::Xml,
      @input.DetectedFormat::Yaml,
      @input.DetectedFormat::Toml,
      @input.DetectedFormat::Html,
      @input.DetectedFormat::Eml,
      @input.DetectedFormat::Ipynb,
    ] {
    assert_true(eml_detected_format_prefers_text_payload(format))
  }
  assert_true(
    !eml_detected_format_prefers_text_payload(@input.DetectedFormat::Pdf),
  )
  let extension_cases = [
    ("image/png", ".png"),
    ("image/jpeg", ".jpg"),
    ("image/gif", ".gif"),
    ("image/svg+xml", ".svg"),
    ("application/json", ".json"),
    ("application/xml", ".xml"),
    ("text/xml", ".xml"),
    ("application/x-ipynb+json", ".ipynb"),
    ("text/html", ".html"),
    ("text/markdown", ".md"),
    ("application/toml", ".toml"),
    ("application/octet-stream", ".bin"),
  ]
  for item in extension_cases {
    assert_eq(eml_attachment_ext(item.0), item.1)
  }
  let info_cases = [
    ("application/problem+json", "json"),
    ("application/json", "json"),
    ("application/problem+xml", "xml"),
    ("application/xml", "xml"),
    ("text/xml", "xml"),
    ("text/html", "html"),
    ("text/markdown", "markdown"),
    ("text/plain", "text"),
    ("application/pdf", "application/pdf"),
  ]
  for item in info_cases {
    assert_eq(eml_info_string_for_mime(item.0), item.1)
  }
  assert_eq(eml_slug(" /A strange--PART/ "), "a-strange-part")
  assert_eq(eml_slug("---"), "part")
  assert_eq(eml_trim_dashes("plain"), "plain")
  assert_eq(eml_trim_dashes("--trim--"), "trim")
  assert_eq(eml_asset_ext(Some("asset.JPEG"), None), ".jpeg")
  assert_eq(eml_asset_ext(Some("asset"), Some("image/png")), ".asset")
  assert_eq(eml_asset_ext(None, Some("image/png")), ".png")
  assert_true(eml_base64_body_within_inline_limit(" YW Jj\r\n", 4))
  assert_true(!eml_base64_body_within_inline_limit("YWJjZA==", 4))
  assert_true(
    eml_max_inline_binary_base64_chars() >= EML_MAX_INLINE_BINARY_BYTES,
  )
  assert_true(eml_paragraphs("").length() == 0)
  assert_true(eml_paragraphs("one\r\nline\r\n\r\ntwo") == ["one line", "two"])

  let message = @deml.parse_eml_message(
    [
      "MIME-Version: 1.0", "Content-Type: multipart/mixed; boundary=assets", "",
      "--assets", "Content-Type: image/png; name=inline.png", "Content-Disposition: inline; filename=inline.png",
      "Content-ID: <hero>", "Content-Transfer-Encoding: base64", "", "aGVsbG8=",
      "--assets", "Content-Type: application/octet-stream; name=payload.json", "Content-Disposition: attachment; filename=payload.json",
      "", "{\"ok\":true}", "--assets--",
    ].join("\r\n"),
  )
  let image = message.children[0].attachments[0]
  let named = message.children[1].attachments[0]
  assert_true(eml_attachment_is_inline_image(image))
  assert_true(eml_should_materialize_attachment_asset(image))
  assert_true(
    eml_attachment_detected_format(image) ==
    Some(@input.DetectedFormat::Image(@input.ImageFormat::Png)),
  )
  assert_true(
    eml_attachment_detected_format(named) == Some(@input.DetectedFormat::Json),
  )
}

///|
test "EML multipart alternative selection and nested asset rewrites are deterministic" {
  let eml = [
    "MIME-Version: 1.0", "Content-Type: multipart/mixed; boundary=outer", "", "--outer",
    "Content-Type: multipart/alternative; boundary=alt", "", "--alt", "Content-Type: text/html",
    "", "<p>HTML body</p>", "--alt", "Content-Type: text/plain", "", "Plain body",
    "--alt--", "--outer--",
  ].join("\r\n")
  let message = @deml.parse_eml_message(eml)
  let diagnostics = @core.empty_diagnostics()
  let selected = eml_selected_alternative_children(
    message.children[0],
    diagnostics,
  )
  assert_true(selected.length() == 1)
  assert_true(selected[0].summary.mime_type == "text/plain")
  assert_true(
    diagnostics.metrics.get("selected_body_kind") == Some("text/plain"),
  )

  let owner = message.children[0]
  let document = @core.empty_document_ir()
  let asset0 = @core.make_asset_ref(@core.AssetKind::Image, "old")
  let asset = { ..asset0, path: Some("old.PNG") }
  let rewrites = eml_rewrite_child_assets(
    [asset],
    owner,
    [],
    document,
    diagnostics,
  )
  assert_true(rewrites.length() == 1)
  assert_true(document.assets.length() == 1)
  let image = @core.make_block(@core.BlockKind::Image, "")
  image.attrs.set("asset_id", "old")
  image.attrs.set("path", "old.PNG")
  let parent = @core.make_block(@core.BlockKind::Paragraph, "parent")
  parent.children.push(image)
  let rewritten = eml_rewrite_child_block(parent, rewrites)
  assert_true(
    rewritten.children[0].attrs.get("asset_id") ==
    Some(rewrites[0].new_asset_id),
  )
  assert_true(
    rewritten.children[0].attrs.get("path") == Some(rewrites[0].new_path),
  )
  assert_true(eml_find_asset_rewrite(rewrites, "old", "") is Some(_))
  assert_true(eml_find_asset_rewrite(rewrites, "", "old.PNG") is Some(_))
  assert_true(eml_find_asset_rewrite(rewrites, "missing", "missing") is None)
}
