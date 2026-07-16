///|
fn markdown_table_group_to_block_next(
  group : Array[@dmd.MarkdownBlock],
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  lowering_mode : MarkdownLoweringMode,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.CoreBlock {
  let source_ref = markdown_group_source_ref(
    group,
    source,
    "/table[0]",
    base_source_ref~,
  )
  if lowering_mode == BlockStreamingLight {
    diagnostics.same_mode_degradation.push(
      "markdown_block_stream_table_literal_preserved",
    )
    return markdown_literal_block(
      group.map(block => block.raw_text).join("\n"),
      source_ref,
      "markdown_literal",
    )
  }
  let lines = group
    .map(block => block.raw_text.trim().to_owned())
    .filter(line => line != "")
  if lines.length() == 0 {
    return markdown_literal_block("", source_ref, "markdown_table_literal")
  }
  let table = markdown_table_block_from_lines(lines, source_ref)
  if table.children.length() == 0 {
    diagnostics.degraded_features.push("markdown_table_literal_fallback")
    diagnostics.fallback_trace.push(
      "markdown table parse failed -> literal raw block",
    )
    return markdown_literal_block(
      group.map(block => block.raw_text).join("\n"),
      source_ref,
      "markdown_table_literal",
    )
  }
  table
}

///|
fn markdown_table_literal_block(
  block : @dmd.MarkdownBlock,
  source_ref : @core.SourceRef,
  diagnostics : @core.Diagnostics,
  lowering_mode : MarkdownLoweringMode,
) -> @core.CoreBlock {
  if lowering_mode == BlockStreamingLight {
    diagnostics.same_mode_degradation.push(
      "markdown_block_stream_table_literal_preserved",
    )
    return markdown_literal_block(
      block.raw_text,
      source_ref,
      "markdown_literal",
    )
  }
  let lines = block.raw_text
    .split("\n")
    .to_array()
    .map(line => line.trim().to_owned())
    .filter(line => line != "")
  if lines.length() == 0 {
    return markdown_literal_block("", source_ref, "markdown_table_literal")
  }
  let table = markdown_table_block_from_lines(lines, source_ref)
  if table.children.length() == 0 {
    diagnostics.degraded_features.push("markdown_table_literal_fallback")
    diagnostics.fallback_trace.push(
      "markdown table parse failed -> literal raw block",
    )
    return markdown_literal_block(
      block.raw_text,
      source_ref,
      "markdown_table_literal",
    )
  }
  table
}

///|
fn markdown_table_block_from_lines(
  lines : Array[String],
  source_ref : @core.SourceRef,
) -> @core.CoreBlock {
  let table = @core.make_block(Table, "table", source_ref~)
  table.attrs.set("header_rows", "1")
  let rows = lines
    .filter(line => !markdown_table_separator_line(line))
    .map(line => markdown_table_cells(line))
  if rows.length() == 0 {
    return table
  }
  for row_cells in rows {
    let row = @core.make_block(TableRow, row_cells.join(" | "), source_ref~)
    for cell_text in row_cells {
      row.children.push(@core.make_block(TableCell, cell_text, source_ref~))
    }
    table.children.push(row)
  }
  table
}

///|
fn markdown_table_separator_line(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  if trimmed == "" {
    return false
  }
  let chars = trimmed.to_array()
  let mut saw_dash = false
  for ch in chars {
    if ch == '-' {
      saw_dash = true
    } else if ch == '|' || ch == ':' || ch == ' ' || ch == '\t' {
      ()
    } else {
      return false
    }
  }
  saw_dash
}

///|
fn markdown_table_cells(line : String) -> Array[String] {
  let trimmed = line.trim().to_owned()
  let content = if trimmed.has_prefix("|") &&
    trimmed.has_suffix("|") &&
    trimmed.length() >= 2 {
    trimmed[1:trimmed.length() - 1].to_owned()
  } else {
    trimmed
  }
  content.split("|").map(part => part.trim().to_owned()).to_array()
}

///|
fn markdown_paragraph_block(
  block : @dmd.MarkdownBlock,
  source_ref : @core.SourceRef,
  diagnostics : @core.Diagnostics,
  image_asset_index : Ref[Int],
  defined_footnotes : Map[String, Bool],
  lowering_mode : MarkdownLoweringMode,
) -> @core.CoreBlock {
  if lowering_mode == BlockStreamingLight {
    return markdown_block_stream_paragraph_block(
      block, source_ref, diagnostics, defined_footnotes,
    )
  }
  let normalized = if markdown_may_have_footnote_reference(block.raw_text) {
    markdown_normalize_footnote_references(block.raw_text, defined_footnotes)
  } else {
    block.raw_text
  }
  let trimmed = normalized.trim().to_owned()
  if markdown_requires_literal_paragraph(normalized) {
    diagnostics.degraded_features.push("markdown_literal_paragraph_preserved")
    return markdown_literal_block(normalized, source_ref, "markdown_literal")
  }
  if !markdown_may_have_rich_inline_markup(normalized) {
    return @core.make_block(
      Paragraph,
      markdown_plain_paragraph_text(normalized),
      source_ref~,
    )
  }
  match
    markdown_image_block_or_inline(normalized, source_ref, image_asset_index) {
    Some(image_block) => image_block
    None => {
      let paragraph = @core.make_block(
        Paragraph,
        markdown_plain_paragraph_text(normalized),
        source_ref~,
      )
      let inline_result = markdown_parse_rich_inlines(
        trimmed, source_ref, diagnostics, image_asset_index, defined_footnotes,
      )
      let paragraph = match inline_result.rich_inlines {
        Some(inlines) if inlines.length() > 0 =>
          @core.block_with_rich_inlines(paragraph, Some(inlines))
        _ => paragraph
      }
      if inline_result.unsafe_link_count > 0 {
        paragraph.attrs.set(
          "unsafe_link_count",
          inline_result.unsafe_link_count.to_string(),
        )
      }
      paragraph
    }
  }
}

///|
fn markdown_plain_paragraph_text(text : String) -> String {
  let lines = text.split("\n").to_array()
  let out = StringBuilder::new()
  let mut wrote = false
  for line in lines {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    if wrote {
      out.write_char(' ')
    }
    out.write_string(trimmed)
    wrote = true
  }
  out.to_string()
}

///|
fn markdown_block_stream_paragraph_block(
  block : @dmd.MarkdownBlock,
  source_ref : @core.SourceRef,
  diagnostics : @core.Diagnostics,
  defined_footnotes : Map[String, Bool],
) -> @core.CoreBlock {
  let normalized = if markdown_may_have_footnote_reference(block.raw_text) {
    diagnostics.same_mode_degradation.push(
      "markdown_block_stream_footnote_reference_preserved",
    )
    markdown_normalize_footnote_references(block.raw_text, defined_footnotes)
  } else {
    block.raw_text
  }
  if markdown_requires_literal_paragraph(normalized) {
    diagnostics.degraded_features.push("markdown_literal_paragraph_preserved")
    return markdown_literal_block(normalized, source_ref, "markdown_literal")
  }
  if markdown_plain_block_stream_paragraph_candidate(normalized) {
    let paragraph = @core.make_block(
      Paragraph,
      markdown_plain_paragraph_text(normalized),
      source_ref~,
    )
    paragraph.attrs.set("literal", "true")
    paragraph
  } else {
    diagnostics.same_mode_degradation.push(
      "markdown_block_stream_literal_paragraph_preserved",
    )
    markdown_literal_block(normalized, source_ref, "markdown_literal")
  }
}

///|
fn markdown_plain_block_stream_paragraph_candidate(text : String) -> Bool {
  !(text.contains("[") ||
  text.contains("]") ||
  text.contains("!") ||
  text.contains("`") ||
  text.contains("|") ||
  text.contains("<") ||
  text.contains(">"))
}

///|
fn markdown_requires_literal_paragraph(text : String) -> Bool {
  text.contains("<div") || text.contains("<script") || text.contains("<style")
}

///|
fn markdown_image_block_or_inline(
  text : String,
  source_ref : @core.SourceRef,
  image_asset_index : Ref[Int],
) -> @core.CoreBlock? {
  match parse_markdown_image(text) {
    Some((alt, path)) =>
      Some(
        markdown_image_block_from_parts(
          alt, path, source_ref, image_asset_index,
        ),
      )
    None => None
  }
}

///|
fn markdown_image_block_from_parts(
  alt : String,
  path : String,
  source_ref : @core.SourceRef,
  image_asset_index : Ref[Int],
) -> @core.CoreBlock {
  let image = @core.make_block(Image, "", source_ref~)
  image.attrs.set("alt", alt)
  let normalized = markdown_image_output_path(path, image_asset_index)
  image.attrs.set("path", normalized.0)
  image.attrs.set("asset_id", normalized.1)
  match normalized.2 {
    Some(source_path) => image.attrs.set("source_path", source_path)
    None => ()
  }
  if markdown_remote_href(path) {
    image.attrs.set("remote", "true")
  }
  image
}

///|
fn markdown_list_group_to_block_next(
  group : Array[@dmd.MarkdownBlock],
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  image_asset_index : Ref[Int],
  lowering_mode : MarkdownLoweringMode,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.CoreBlock {
  ignore(diagnostics)
  ignore(image_asset_index)
  if lowering_mode == BlockStreamingLight {
    diagnostics.same_mode_degradation.push(
      "markdown_block_stream_list_literal_preserved",
    )
    return markdown_literal_block(
      group.map(block => block.raw_text).join("\n"),
      markdown_group_source_ref(group, source, "/list[0]", base_source_ref~),
      "markdown_literal",
    )
  }
  let source_ref = markdown_group_source_ref(
    group,
    source,
    "/list[0]",
    base_source_ref~,
  )
  let root = @core.make_block(List, "", source_ref~)
  root.attrs.set(
    "ordered",
    @fshared.bool_string(markdown_list_is_ordered(group[0].raw_text)),
  )
  let stack : Array[(Int, @core.CoreBlock, @core.CoreBlock)] = []
  for block in group {
    let indent = markdown_list_indent(block.raw_text)
    let item = @core.make_block(
      ListItem,
      strip_markdown_list_marker(block.raw_text),
      source_ref=markdown_source_ref(block, source, base_source_ref~),
    )
    item.attrs.set(
      "ordered",
      @fshared.bool_string(markdown_list_is_ordered(block.raw_text)),
    )
    while stack.length() > 0 && indent < stack[stack.length() - 1].0 {
      ignore(stack.pop())
    }
    if stack.length() == 0 {
      root.children.push(item)
      stack.push((indent, root, item))
      continue
    }
    let current = stack[stack.length() - 1]
    if indent > current.0 {
      let nested = @core.make_block(
        List,
        "",
        source_ref=item.source_ref.unwrap_or(source_ref),
      )
      nested.attrs.set("ordered", item.attrs.get("ordered").unwrap_or("false"))
      current.2.children.push(nested)
      nested.children.push(item)
      stack.push((indent, nested, item))
    } else {
      current.1.children.push(item)
      ignore(stack.pop())
      stack.push((indent, current.1, item))
    }
  }
  root
}

///|
fn markdown_group_source_ref(
  group : Array[@dmd.MarkdownBlock],
  source : @input.InputSource,
  path : String,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.SourceRef {
  markdown_source_ref_with_path(
    markdown_source_ref_from_lines(
      source,
      group[0].line_start,
      group[group.length() - 1].line_end,
      base_source_ref~,
    ),
    path,
  )
}

///|
fn markdown_list_indent(text : String) -> Int {
  let chars = text.to_array()
  let mut indent = 0
  while indent < chars.length() && chars[indent] == ' ' {
    indent += 1
  }
  indent
}

///|
fn markdown_blockquote_group_to_block_next(
  group : Array[@dmd.MarkdownBlock],
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  image_asset_index : Ref[Int],
  lowering_mode : MarkdownLoweringMode,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.CoreBlock {
  ignore(diagnostics)
  ignore(image_asset_index)
  if lowering_mode == BlockStreamingLight {
    diagnostics.same_mode_degradation.push(
      "markdown_block_stream_blockquote_literal_preserved",
    )
    return markdown_literal_block(
      group.map(block => block.raw_text).join("\n"),
      markdown_group_source_ref(
        group,
        source,
        "/blockquote[0]",
        base_source_ref~,
      ),
      "markdown_literal",
    )
  }
  let source_ref = markdown_group_source_ref(
    group,
    source,
    "/blockquote[0]",
    base_source_ref~,
  )
  let lines : Array[String] = []
  for block in group {
    lines.push(strip_markdown_blockquote(block.raw_text))
  }
  let quote = @core.make_block(BlockQuote, lines.join("\n"), source_ref~)
  quote
}
