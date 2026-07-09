///|
fn markdown_group_key(block : @dmd.MarkdownBlock) -> String {
  match block.kind {
    @dmd.MarkdownBlockKind::ListItem =>
      if markdown_list_is_ordered(block.raw_text) {
        "list:ordered"
      } else {
        "list:unordered"
      }
    @dmd.MarkdownBlockKind::BlockQuote => "blockquote"
    _ => "single:" + markdown_block_kind_name(block.kind)
  }
}

///|
fn markdown_lowered_blocks_for_mode(
  scanned : @dmd.MarkdownDocument,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  block_stream_mode : Bool,
) -> Array[@core.CoreBlock] {
  let lowering_mode = if block_stream_mode {
    MarkdownLoweringMode::BlockStreamingLight
  } else {
    MarkdownLoweringMode::DomAstLight
  }
  let lowered = markdown_blocks_from_scanned_document(
    scanned, source, diagnostics, lowering_mode,
  )
  let (blocks, report) = markdown_annotate_paths_and_report(lowered)
  markdown_apply_block_report_metrics(diagnostics, report, blocks.length())
  if block_stream_mode {
    diagnostics.degraded_features.push("markdown_block_stream_light_lowering")
    diagnostics.same_mode_degradation.push(
      "markdown_block_stream_literal_preservation",
    )
    diagnostics.fallback_trace.push(
      "markdown block streaming -> same-mode light lowering",
    )
    diagnostics.metrics.set("markdown_lowering_mode", "block_stream_light")
  } else {
    diagnostics.metrics.set("markdown_lowering_mode", "dom_ast_light")
  }
  diagnostics.metrics.set(
    "degraded_feature_count",
    diagnostics.degraded_features.length().to_string(),
  )
  diagnostics.metrics.set(
    "fallback_count",
    diagnostics.fallback_trace.length().to_string(),
  )
  diagnostics.metrics.set(
    "warning_count",
    diagnostics.warnings.length().to_string(),
  )
  diagnostics.metrics.set(
    "error_count",
    diagnostics.errors.length().to_string(),
  )
  diagnostics.metrics.set(
    "issue_count",
    (diagnostics.warnings.length() + diagnostics.errors.length()).to_string(),
  )
  diagnostics.metrics.set("resource_limit_hit", "false")
  diagnostics.metrics.set("block_limit_reached", "false")
  blocks
}

///|
priv struct MarkdownInlineParseResult {
  rich_inlines : Array[@core.CoreInline]?
  unsafe_link_count : Int
}

///|
priv enum MarkdownLoweringItem {
  Scanned(@dmd.MarkdownBlock)
  FootnoteDefinition(@dmd.MarkdownBlock, Array[@dmd.MarkdownBlock])
}

///|
priv enum MarkdownLoweringMode {
  DomAstLight
  BlockStreamingLight
} derive(Eq)

///|
fn markdown_blocks_from_scanned_document(
  scanned : @dmd.MarkdownDocument,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  lowering_mode : MarkdownLoweringMode,
  base_source_ref? : @core.SourceRef? = None,
) -> Array[@core.CoreBlock] {
  let blocks : Array[@core.CoreBlock] = []
  let image_asset_index : Ref[Int] = { val: 0 }
  let defined_footnotes = if lowering_mode ==
    MarkdownLoweringMode::BlockStreamingLight &&
    !markdown_blocks_may_define_footnotes(scanned.blocks) {
    Map([])
  } else {
    markdown_collect_defined_footnotes(scanned.blocks)
  }
  match scanned.frontmatter {
    Some(value) => {
      blocks.push(markdown_frontmatter_block(value, source, base_source_ref~))
      diagnostics.metrics.set(
        "frontmatter_kind",
        markdown_frontmatter_kind_name(value.kind),
      )
      diagnostics.metrics.set(
        "frontmatter_closed",
        @fshared.bool_string(value.closed),
      )
      if !value.closed {
        diagnostics.degraded_features.push("markdown_frontmatter_unclosed")
      }
    }
    None => {
      diagnostics.metrics.set("frontmatter_kind", "none")
      diagnostics.metrics.set("frontmatter_closed", "false")
    }
  }
  if lowering_mode == MarkdownLoweringMode::BlockStreamingLight {
    let block_groups = markdown_group_scanned_blocks(scanned.blocks)
    for group in block_groups {
      for
        block in markdown_scanned_group_to_core_blocks_next(
          group,
          source,
          diagnostics,
          image_asset_index,
          defined_footnotes,
          lowering_mode,
          base_source_ref~,
        ) {
        blocks.push(block)
      }
    }
  } else {
    let lowered_items = markdown_prepare_lowering_items(
      scanned.blocks,
      defined_footnotes,
    )
    let block_groups = group_markdown_lowering_items(lowered_items)
    for group in block_groups {
      for
        block in markdown_group_to_core_blocks_next(
          group,
          source,
          diagnostics,
          image_asset_index,
          defined_footnotes,
          lowering_mode,
          base_source_ref~,
        ) {
        blocks.push(block)
      }
    }
  }
  blocks
}

///|
fn markdown_collect_defined_footnotes(
  blocks : Array[@dmd.MarkdownBlock],
) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map([])
  for block in blocks {
    for label in markdown_footnote_definition_labels(block.raw_text) {
      out.set(label, true)
    }
  }
  out
}

///|
fn markdown_blocks_may_define_footnotes(
  blocks : Array[@dmd.MarkdownBlock],
) -> Bool {
  for block in blocks {
    if block.raw_text.contains("[^") && block.raw_text.contains("]:") {
      return true
    }
  }
  false
}

///|
fn markdown_group_scanned_blocks(
  blocks : Array[@dmd.MarkdownBlock],
) -> Array[Array[@dmd.MarkdownBlock]] {
  let groups : Array[Array[@dmd.MarkdownBlock]] = []
  let current : Array[@dmd.MarkdownBlock] = []
  let mut current_key = ""

  fn flush_group(
    groups : Array[Array[@dmd.MarkdownBlock]],
    current : Array[@dmd.MarkdownBlock],
    current_key : String,
  ) -> String {
    if current.length() == 0 {
      return current_key
    }
    let snapshot : Array[@dmd.MarkdownBlock] = []
    snapshot.append(current[:])
    groups.push(snapshot)
    current.clear()
    ""
  }

  for block in blocks {
    if block.kind == @dmd.MarkdownBlockKind::BlankLine {
      current_key = flush_group(groups, current, current_key)
      continue
    }
    let next_key = markdown_group_key(block)
    if current.length() > 0 && next_key != current_key {
      current_key = flush_group(groups, current, current_key)
    }
    current.push(block)
    current_key = next_key
  }
  ignore(flush_group(groups, current, current_key))
  groups
}

///|
fn markdown_scanned_group_to_core_blocks_next(
  group : Array[@dmd.MarkdownBlock],
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  image_asset_index : Ref[Int],
  defined_footnotes : Map[String, Bool],
  lowering_mode : MarkdownLoweringMode,
  base_source_ref? : @core.SourceRef? = None,
) -> Array[@core.CoreBlock] {
  if group.length() == 0 {
    return []
  }
  let first_block = group[0]
  match first_block.kind {
    @dmd.MarkdownBlockKind::ListItem =>
      [
        markdown_list_group_to_block_next(
          group,
          source,
          diagnostics,
          image_asset_index,
          lowering_mode,
          base_source_ref~,
        ),
      ]
    @dmd.MarkdownBlockKind::BlockQuote =>
      [
        markdown_blockquote_group_to_block_next(
          group,
          source,
          diagnostics,
          image_asset_index,
          lowering_mode,
          base_source_ref~,
        ),
      ]
    @dmd.MarkdownBlockKind::HtmlBlockCandidate =>
      [
        markdown_html_group_to_block_next(
          group,
          source,
          diagnostics,
          lowering_mode,
          base_source_ref~,
        ),
      ]
    @dmd.MarkdownBlockKind::TableLikeRow =>
      [
        markdown_table_group_to_block_next(
          group,
          source,
          diagnostics,
          lowering_mode,
          base_source_ref~,
        ),
      ]
    _ =>
      [
        markdown_single_block_to_core_block_next(
          first_block,
          source,
          diagnostics,
          image_asset_index,
          defined_footnotes,
          lowering_mode,
          base_source_ref~,
        ),
      ]
  }
}

///|
fn markdown_prepare_lowering_items(
  blocks : Array[@dmd.MarkdownBlock],
  _defined_footnotes : Map[String, Bool],
) -> Array[MarkdownLoweringItem] {
  let out : Array[MarkdownLoweringItem] = []
  let mut i = 0
  while i < blocks.length() {
    let block = blocks[i]
    match markdown_footnote_definition_head(block) {
      Some(_) => {
        let continuation : Array[@dmd.MarkdownBlock] = []
        let mut j = i + 1
        while j < blocks.length() {
          let next = blocks[j]
          if next.kind == @dmd.MarkdownBlockKind::BlankLine {
            match markdown_next_non_blank_block_index(blocks, j + 1) {
              Some(next_index) =>
                if markdown_block_belongs_to_footnote_definition(
                    blocks[next_index],
                  ) {
                  while j < next_index {
                    continuation.push(blocks[j])
                    j += 1
                  }
                  continue
                } else {
                  break
                }
              None => break
            }
          }
          if markdown_block_belongs_to_footnote_definition(next) {
            continuation.push(next)
            j += 1
          } else {
            break
          }
        }
        out.push(MarkdownLoweringItem::FootnoteDefinition(block, continuation))
        i = j
      }
      None => {
        out.push(MarkdownLoweringItem::Scanned(block))
        i += 1
      }
    }
  }
  out
}

///|
fn group_markdown_lowering_items(
  items : Array[MarkdownLoweringItem],
) -> Array[Array[MarkdownLoweringItem]] {
  let groups : Array[Array[MarkdownLoweringItem]] = []
  let current : Array[MarkdownLoweringItem] = []
  let mut current_key = ""

  fn flush_group(
    groups : Array[Array[MarkdownLoweringItem]],
    current : Array[MarkdownLoweringItem],
    current_key : String,
  ) -> String {
    if current.length() == 0 {
      return current_key
    }
    let snapshot : Array[MarkdownLoweringItem] = []
    snapshot.append(current[:])
    groups.push(snapshot)
    current.clear()
    ""
  }

  for item in items {
    if markdown_lowering_item_is_blank(item) {
      current_key = flush_group(groups, current, current_key)
      continue
    }
    let next_key = markdown_lowering_item_group_key(item)
    if current.length() > 0 && next_key != current_key {
      current_key = flush_group(groups, current, current_key)
    }
    current.push(item)
    current_key = next_key
  }
  ignore(flush_group(groups, current, current_key))
  groups
}

///|
fn markdown_lowering_item_is_blank(item : MarkdownLoweringItem) -> Bool {
  match item {
    MarkdownLoweringItem::Scanned(block) =>
      block.kind == @dmd.MarkdownBlockKind::BlankLine
    MarkdownLoweringItem::FootnoteDefinition(_, _) => false
  }
}

///|
fn markdown_lowering_item_group_key(item : MarkdownLoweringItem) -> String {
  match item {
    MarkdownLoweringItem::FootnoteDefinition(_, _) => "footnote_definition"
    MarkdownLoweringItem::Scanned(block) => markdown_group_key(block)
  }
}

///|
fn markdown_frontmatter_block(
  value : @dmd.MarkdownFrontmatter,
  source : @input.InputSource,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.CoreBlock {
  let source_ref = markdown_source_ref_with_path(
    markdown_source_ref_from_lines(
      source,
      value.line_start,
      value.line_end,
      base_source_ref~,
    ),
    "/frontmatter",
  )
  let block = @core.make_block(@core.BlockKind::Raw, value.content, source_ref~)
  let marker = match value.kind {
    @dmd.MarkdownFrontmatterKind::Toml => "+++"
    _ => "---"
  }
  block.attrs.set("raw_kind", "markdown_frontmatter")
  block.attrs.set("frontmatter_marker", marker)
  block.attrs.set(
    "frontmatter_kind",
    markdown_frontmatter_kind_name(value.kind),
  )
  block.attrs.set("closed", @fshared.bool_string(value.closed))
  block
}

///|
fn markdown_group_to_core_blocks_next(
  group : Array[MarkdownLoweringItem],
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  image_asset_index : Ref[Int],
  defined_footnotes : Map[String, Bool],
  lowering_mode : MarkdownLoweringMode,
  base_source_ref? : @core.SourceRef? = None,
) -> Array[@core.CoreBlock] {
  if group.length() == 0 {
    return []
  }
  let first = group[0]
  match first {
    MarkdownLoweringItem::FootnoteDefinition(_, _) =>
      markdown_footnote_group_to_core_blocks_next(
        group,
        source,
        diagnostics,
        image_asset_index,
        defined_footnotes,
        lowering_mode,
        base_source_ref~,
      )
    MarkdownLoweringItem::Scanned(first_block) => {
      let scanned_group = group.map(item => markdown_lowering_item_block(item))
      match first_block.kind {
        @dmd.MarkdownBlockKind::ListItem =>
          [
            markdown_list_group_to_block_next(
              scanned_group,
              source,
              diagnostics,
              image_asset_index,
              lowering_mode,
              base_source_ref~,
            ),
          ]
        @dmd.MarkdownBlockKind::BlockQuote =>
          [
            markdown_blockquote_group_to_block_next(
              scanned_group,
              source,
              diagnostics,
              image_asset_index,
              lowering_mode,
              base_source_ref~,
            ),
          ]
        @dmd.MarkdownBlockKind::HtmlBlockCandidate =>
          [
            markdown_html_group_to_block_next(
              scanned_group,
              source,
              diagnostics,
              lowering_mode,
              base_source_ref~,
            ),
          ]
        @dmd.MarkdownBlockKind::TableLikeRow =>
          [
            markdown_table_group_to_block_next(
              scanned_group,
              source,
              diagnostics,
              lowering_mode,
              base_source_ref~,
            ),
          ]
        _ =>
          [
            markdown_single_block_to_core_block_next(
              first_block,
              source,
              diagnostics,
              image_asset_index,
              defined_footnotes,
              lowering_mode,
              base_source_ref~,
            ),
          ]
      }
    }
  }
}

///|
fn markdown_lowering_item_block(
  item : MarkdownLoweringItem,
) -> @dmd.MarkdownBlock {
  match item {
    MarkdownLoweringItem::Scanned(block) => block
    MarkdownLoweringItem::FootnoteDefinition(block, _) => block
  }
}

///|
fn markdown_footnote_group_to_core_blocks_next(
  group : Array[MarkdownLoweringItem],
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  image_asset_index : Ref[Int],
  defined_footnotes : Map[String, Bool],
  lowering_mode : MarkdownLoweringMode,
  base_source_ref? : @core.SourceRef? = None,
) -> Array[@core.CoreBlock] {
  ignore(diagnostics)
  ignore(image_asset_index)
  let out : Array[@core.CoreBlock] = []
  for item in group {
    match item {
      MarkdownLoweringItem::FootnoteDefinition(head, continuation) =>
        out.push(
          markdown_footnote_definition_block(
            head,
            continuation,
            source,
            defined_footnotes,
            base_source_ref~,
          ),
        )
      MarkdownLoweringItem::Scanned(block) =>
        out.push(
          markdown_single_block_to_core_block_next(
            block,
            source,
            diagnostics,
            image_asset_index,
            defined_footnotes,
            lowering_mode,
            base_source_ref~,
          ),
        )
    }
  }
  out
}

///|
fn markdown_footnote_definition_block(
  head : @dmd.MarkdownBlock,
  continuation : Array[@dmd.MarkdownBlock],
  source : @input.InputSource,
  defined_footnotes : Map[String, Bool],
  base_source_ref? : @core.SourceRef? = None,
) -> @core.CoreBlock {
  let (label, body) = match markdown_footnote_definition_head(head) {
    Some(value) => value
    None => ("", "")
  }
  let lines = head.raw_text.split("\n").to_array()
  let tail_segments : Array[String] = []
  if lines.length() > 1 {
    tail_segments.push(lines[1:].join("\n"))
  }
  for block in continuation {
    tail_segments.push(block.raw_text)
  }
  let tail = tail_segments.join("\n")
  let text = if body != "" {
    let first_line = "[^" + label + "]: " + body
    if tail == "" {
      first_line
    } else {
      first_line + "\n" + tail
    }
  } else {
    let (inline_body, remaining) = markdown_take_first_footnote_body_line(tail)
    let first_line = match inline_body {
      Some(value) => "[^" + label + "]: " + value
      None => "[^" + label + "]:"
    }
    first_line + remaining
  }
  let normalized = markdown_normalize_footnote_references(
    text, defined_footnotes,
  )
  let last_line = if continuation.length() > 0 {
    continuation[continuation.length() - 1].line_end
  } else {
    head.line_end
  }
  let source_ref = markdown_source_ref_from_lines(
    source,
    head.line_start,
    last_line,
    base_source_ref~,
  )
  markdown_literal_block(normalized, source_ref, "markdown_footnote_definition")
}

///|
fn markdown_single_block_to_core_block_next(
  block : @dmd.MarkdownBlock,
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  image_asset_index : Ref[Int],
  defined_footnotes : Map[String, Bool],
  lowering_mode : MarkdownLoweringMode,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.CoreBlock {
  let source_ref = markdown_source_ref(block, source, base_source_ref~)
  match block.kind {
    @dmd.MarkdownBlockKind::HeadingAtx => {
      let heading = @core.make_block(
        @core.BlockKind::Heading,
        strip_markdown_heading(block.raw_text),
        source_ref~,
      )
      heading.attrs.set(
        "level",
        markdown_heading_level(block.raw_text).to_string(),
      )
      heading
    }
    @dmd.MarkdownBlockKind::HeadingSetext => {
      let heading = @core.make_block(
        @core.BlockKind::Heading,
        strip_setext_heading(block.raw_text),
        source_ref~,
      )
      heading.attrs.set(
        "level",
        markdown_setext_heading_level(block.raw_text).to_string(),
      )
      heading
    }
    @dmd.MarkdownBlockKind::FencedCode => {
      let code = @core.make_block(
        @core.BlockKind::Code,
        strip_fence_block_content(block.raw_text),
        source_ref~,
      )
      match block.fenced_code {
        Some(info) => {
          match info.info_string {
            Some(lang) => code.attrs.set("info", lang.trim().to_owned())
            None => ()
          }
          code.attrs.set("closed", @fshared.bool_string(info.closed))
        }
        None => ()
      }
      code
    }
    @dmd.MarkdownBlockKind::ThematicBreak => {
      let raw = @core.make_block(
        @core.BlockKind::Raw,
        block.raw_text.trim().to_owned(),
        source_ref~,
      )
      raw.attrs.set("raw_kind", "markdown_thematic_break")
      raw
    }
    @dmd.MarkdownBlockKind::HtmlBlockCandidate =>
      markdown_html_literal_block(block, source_ref, diagnostics, lowering_mode)
    @dmd.MarkdownBlockKind::TableLikeRow =>
      markdown_table_literal_block(
        block, source_ref, diagnostics, lowering_mode,
      )
    @dmd.MarkdownBlockKind::ParagraphLike =>
      markdown_paragraph_block(
        block, source_ref, diagnostics, image_asset_index, defined_footnotes, lowering_mode,
      )
    @dmd.MarkdownBlockKind::Other =>
      markdown_literal_block(block.raw_text, source_ref, "markdown_literal")
    _ => markdown_literal_block(block.raw_text, source_ref, "markdown_literal")
  }
}

///|
fn markdown_literal_block(
  text : String,
  source_ref : @core.SourceRef,
  raw_kind : String,
) -> @core.CoreBlock {
  let block = @core.make_block(@core.BlockKind::Raw, text, source_ref~)
  block.attrs.set("raw_kind", raw_kind)
  block
}

///|
fn markdown_html_group_to_block_next(
  group : Array[@dmd.MarkdownBlock],
  source : @input.InputSource,
  diagnostics : @core.Diagnostics,
  lowering_mode : MarkdownLoweringMode,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.CoreBlock {
  let source_ref = markdown_group_source_ref(
    group,
    source,
    "/markdown_html_literal[0]",
    base_source_ref~,
  )
  let text = group.map(block => block.raw_text).join("\n")
  if lowering_mode == MarkdownLoweringMode::BlockStreamingLight {
    diagnostics.same_mode_degradation.push(
      "markdown_block_stream_html_literal_preserved",
    )
    return markdown_literal_block(text, source_ref, "markdown_literal")
  }
  let raw = markdown_literal_block(text, source_ref, "markdown_html_literal")
  if markdown_html_contains_unsafe_tag(text) {
    diagnostics.warnings.push("unsafe raw html preserved as literal text")
    diagnostics.degraded_features.push("markdown_raw_html_unsafe_literal")
    diagnostics.fallback_trace.push(
      "markdown raw html unsafe -> typed literal raw block",
    )
    raw.attrs.set("unsafe_html", "true")
  }
  raw
}

///|
fn markdown_html_literal_block(
  block : @dmd.MarkdownBlock,
  source_ref : @core.SourceRef,
  diagnostics : @core.Diagnostics,
  lowering_mode : MarkdownLoweringMode,
) -> @core.CoreBlock {
  if lowering_mode == MarkdownLoweringMode::BlockStreamingLight {
    diagnostics.same_mode_degradation.push(
      "markdown_block_stream_html_literal_preserved",
    )
    return markdown_literal_block(
      block.raw_text,
      source_ref,
      "markdown_literal",
    )
  }
  let raw = markdown_literal_block(
    block.raw_text,
    source_ref,
    "markdown_html_literal",
  )
  if markdown_html_contains_unsafe_tag(block.raw_text) {
    diagnostics.warnings.push("unsafe raw html preserved as literal text")
    diagnostics.degraded_features.push("markdown_raw_html_unsafe_literal")
    diagnostics.fallback_trace.push(
      "markdown raw html unsafe -> typed literal raw block",
    )
    raw.attrs.set("unsafe_html", "true")
  }
  raw
}

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
  if lowering_mode == MarkdownLoweringMode::BlockStreamingLight {
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
  if lowering_mode == MarkdownLoweringMode::BlockStreamingLight {
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
  let table = @core.make_block(@core.BlockKind::Table, "table", source_ref~)
  table.attrs.set("header_rows", "1")
  let rows = lines
    .filter(line => !markdown_table_separator_line(line))
    .map(line => markdown_table_cells(line))
  if rows.length() == 0 {
    return table
  }
  for row_cells in rows {
    let row = @core.make_block(
      @core.BlockKind::TableRow,
      row_cells.join(" | "),
      source_ref~,
    )
    for cell_text in row_cells {
      row.children.push(
        @core.make_block(@core.BlockKind::TableCell, cell_text, source_ref~),
      )
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
  if lowering_mode == MarkdownLoweringMode::BlockStreamingLight {
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
      @core.BlockKind::Paragraph,
      markdown_plain_paragraph_text(normalized),
      source_ref~,
    )
  }
  match
    markdown_image_block_or_inline(normalized, source_ref, image_asset_index) {
    Some(image_block) => image_block
    None => {
      let paragraph = @core.make_block(
        @core.BlockKind::Paragraph,
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
      @core.BlockKind::Paragraph,
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
  let image = @core.make_block(@core.BlockKind::Image, "", source_ref~)
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
  if lowering_mode == MarkdownLoweringMode::BlockStreamingLight {
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
  let root = @core.make_block(@core.BlockKind::List, "", source_ref~)
  root.attrs.set(
    "ordered",
    @fshared.bool_string(markdown_list_is_ordered(group[0].raw_text)),
  )
  let stack : Array[(Int, @core.CoreBlock, @core.CoreBlock)] = []
  for block in group {
    let indent = markdown_list_indent(block.raw_text)
    let item = @core.make_block(
      @core.BlockKind::ListItem,
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
        @core.BlockKind::List,
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
  if lowering_mode == MarkdownLoweringMode::BlockStreamingLight {
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
  let quote = @core.make_block(
    @core.BlockKind::BlockQuote,
    lines.join("\n"),
    source_ref~,
  )
  quote
}

///|
fn markdown_parse_rich_inlines(
  text : String,
  source_ref : @core.SourceRef,
  diagnostics : @core.Diagnostics,
  image_asset_index : Ref[Int],
  defined_footnotes : Map[String, Bool],
) -> MarkdownInlineParseResult {
  let out : Array[@core.CoreInline] = []
  let unsafe_link_count : Ref[Int] = { val: 0 }
  let chars = text.to_array()
  let mut i = 0
  let mut cursor = 0
  while i < chars.length() {
    if chars[i] == '!' && i + 1 < chars.length() && chars[i + 1] == '[' {
      match markdown_find_inline_link(chars, i + 1) {
        Some((label_end, path_start, path_end)) => {
          if cursor < i {
            out.push(
              @core.make_inline_text(text[cursor:i].to_owned(), source_ref~),
            )
          }
          let alt = text[i + 2:label_end].to_owned()
          let path = text[path_start + 1:path_end].to_owned()
          let normalized = markdown_image_output_path(path, image_asset_index)
          let inline = @core.make_inline_image(alt, normalized.0, source_ref~)
          out.push(inline)
          cursor = path_end + 1
          i = cursor
          continue
        }
        None => ()
      }
    }
    if chars[i] == '[' {
      match markdown_find_footnote_reference(chars, i) {
        Some((label_end, label)) => {
          if cursor < i {
            out.push(
              @core.make_inline_text(text[cursor:i].to_owned(), source_ref~),
            )
          }
          if defined_footnotes.contains(label) {
            let marker = text[i:label_end + 1].to_owned()
            let inline = @core.make_inline_text(marker, source_ref~)
            let inline = @core.inline_with_attr(
              inline, "annotation_role", "note_ref",
            )
            let inline = @core.inline_with_attr(
              inline, "annotation_kind", "footnote",
            )
            let inline = @core.inline_with_attr(inline, "annotation_id", label)
            let inline = @core.inline_with_attr(
              inline, "annotation_marker", marker,
            )
            out.push(@core.inline_with_attr(inline, "render_literal", "true"))
          } else {
            out.push(@core.make_inline_text("^" + label, source_ref~))
          }
          cursor = label_end + 1
          i = cursor
          continue
        }
        None => ()
      }
      match markdown_find_inline_link(chars, i) {
        Some((label_end, path_start, path_end)) => {
          if cursor < i {
            out.push(
              @core.make_inline_text(text[cursor:i].to_owned(), source_ref~),
            )
          }
          let label = text[i + 1:label_end].to_owned()
          let href = text[path_start + 1:path_end].to_owned()
          let safe_href = markdown_safe_href(href)
          match safe_href {
            Some(value) =>
              out.push(@core.make_inline_link(label, value, source_ref~))
            None => {
              diagnostics.warnings.push("unsafe markdown link href dropped")
              diagnostics.degraded_features.push(
                "markdown_unsafe_link_text_only",
              )
              diagnostics.fallback_trace.push(
                "markdown unsafe link -> keep text, drop href",
              )
              out.push(@core.make_inline_text(label, source_ref~))
              unsafe_link_count.val += 1
            }
          }
          cursor = path_end + 1
          i = cursor
          continue
        }
        None => ()
      }
    }
    if chars[i] == '`' {
      match markdown_find_inline_code_end(chars, i) {
        Some(end) => {
          if cursor < i {
            out.push(
              @core.make_inline_text(text[cursor:i].to_owned(), source_ref~),
            )
          }
          out.push(
            @core.make_inline_code(text[i + 1:end].to_owned(), source_ref~),
          )
          cursor = end + 1
          i = cursor
          continue
        }
        None => ()
      }
    }
    i += 1
  }
  if cursor < text.length() {
    out.push(@core.make_inline_text(text[cursor:].to_owned(), source_ref~))
  }
  let rich_inlines = if markdown_inline_is_plain_text_only(out) &&
    unsafe_link_count.val == 0 {
    None
  } else {
    Some(out)
  }
  { rich_inlines, unsafe_link_count: unsafe_link_count.val }
}

///|
fn markdown_inline_is_plain_text_only(
  inlines : Array[@core.CoreInline],
) -> Bool {
  if inlines.length() == 0 {
    return true
  }
  for inline in inlines {
    if inline.kind != @core.InlineKind::Text {
      return false
    }
    if inline.attrs.length() > 0 {
      return false
    }
  }
  true
}

///|
fn markdown_footnote_definition_labels(text : String) -> Array[String] {
  let out : Array[String] = []
  for line in text.split("\n").to_array() {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("[^") {
      match markdown_parse_footnote_definition_line(trimmed) {
        Some((label, _)) => out.push(label)
        None => ()
      }
    }
  }
  out
}

///|
fn markdown_footnote_definition_head(
  block : @dmd.MarkdownBlock,
) -> (String, String)? {
  let lines = block.raw_text.split("\n").to_array()
  if lines.length() == 0 {
    return None
  }
  markdown_parse_footnote_definition_line(lines[0].trim().to_owned())
}

///|
fn markdown_parse_footnote_definition_line(line : String) -> (String, String)? {
  if !line.has_prefix("[^") {
    return None
  }
  let chars = line.to_array()
  let mut i = 2
  let label : Array[Char] = []
  while i < chars.length() {
    if chars[i] == ']' {
      if label.length() == 0 || i + 1 >= chars.length() || chars[i + 1] != ':' {
        return None
      }
      let body = if i + 2 < line.length() {
        line[i + 2:].trim().to_owned()
      } else {
        ""
      }
      return Some((String::from_array(label), body))
    }
    if chars[i] == '\n' || chars[i] == '[' {
      return None
    }
    label.push(chars[i])
    i += 1
  }
  None
}

///|
fn markdown_next_non_blank_block_index(
  blocks : Array[@dmd.MarkdownBlock],
  start : Int,
) -> Int? {
  let mut i = start
  while i < blocks.length() {
    if blocks[i].kind != @dmd.MarkdownBlockKind::BlankLine {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn markdown_block_belongs_to_footnote_definition(
  block : @dmd.MarkdownBlock,
) -> Bool {
  match block.kind {
    @dmd.MarkdownBlockKind::ListItem =>
      markdown_list_indent(block.raw_text) >= 4
    @dmd.MarkdownBlockKind::BlockQuote => block.raw_text.has_prefix("    ")
    @dmd.MarkdownBlockKind::ParagraphLike =>
      block.raw_text.has_prefix("    ") ||
      (
        block.raw_text.contains("\n") &&
        !block.raw_text.trim().to_owned().has_prefix("[^")
      )
    _ => false
  }
}

///|
fn markdown_take_first_footnote_body_line(tail : String) -> (String?, String) {
  let lines = tail.split("\n").to_array()
  let mut i = 0
  while i < lines.length() {
    let line = lines[i].to_owned()
    if line.trim() == "" {
      i += 1
      continue
    }
    let body = markdown_strip_footnote_body_indent(line)
    let remainder_lines : Array[String] = []
    if i + 1 < lines.length() {
      let mut j = i + 1
      while j < lines.length() {
        remainder_lines.push(lines[j].to_owned())
        j += 1
      }
    }
    let remainder = if remainder_lines.length() == 0 {
      ""
    } else {
      "\n" + remainder_lines.join("\n")
    }
    return (Some(body), remainder)
  }
  (None, "")
}

///|
fn markdown_strip_footnote_body_indent(line : String) -> String {
  if line.has_prefix("    ") {
    line[4:].trim().to_owned()
  } else if line.has_prefix("\t") {
    line[1:].trim().to_owned()
  } else {
    line.trim().to_owned()
  }
}

///|
fn markdown_normalize_footnote_references(
  text : String,
  defined_footnotes : Map[String, Bool],
) -> String {
  if !markdown_may_have_footnote_reference(text) {
    return text
  }
  let chars = text.to_array()
  let out = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '[' {
      match markdown_find_footnote_reference(chars, i) {
        Some((label_end, label)) => {
          let is_definition = label_end + 1 < chars.length() &&
            chars[label_end + 1] == ':'
          if defined_footnotes.contains(label) || is_definition {
            out.write_string(text[i:label_end + 1].to_owned())
          } else {
            out.write_char('^')
            out.write_string(label)
          }
          i = label_end + 1
          continue
        }
        None => ()
      }
    }
    out.write_char(chars[i])
    i += 1
  }
  out.to_string()
}

///|
fn markdown_may_have_footnote_reference(text : String) -> Bool {
  text.contains("[^")
}

///|
fn markdown_may_have_rich_inline_markup(text : String) -> Bool {
  text.contains("[") || text.contains("!") || text.contains("`")
}

///|
fn markdown_find_footnote_reference(
  chars : Array[Char],
  start : Int,
) -> (Int, String)? {
  if start + 3 >= chars.length() ||
    chars[start] != '[' ||
    chars[start + 1] != '^' {
    return None
  }
  let mut i = start + 2
  let label : Array[Char] = []
  while i < chars.length() {
    if chars[i] == ']' {
      if label.length() == 0 {
        return None
      }
      return Some((i, String::from_array(label)))
    }
    if chars[i] == '\n' || chars[i] == '[' {
      return None
    }
    label.push(chars[i])
    i += 1
  }
  None
}

///|
fn markdown_find_inline_link(
  chars : Array[Char],
  start : Int,
) -> (Int, Int, Int)? {
  let mut label_end : Int? = None
  let mut path_start : Int? = None
  let mut i = start
  while i < chars.length() {
    if chars[i] == ']' {
      label_end = Some(i)
      if i + 1 < chars.length() && chars[i + 1] == '(' {
        path_start = Some(i + 1)
        break
      }
      return None
    }
    i += 1
  }
  match (label_end, path_start) {
    (Some(end), Some(path_open)) => {
      let mut j = path_open + 1
      let mut depth = 0
      while j < chars.length() {
        if chars[j] == '(' {
          depth += 1
        } else if chars[j] == ')' {
          if depth == 0 {
            return Some((end, path_open, j))
          }
          depth -= 1
        }
        j += 1
      }
      None
    }
    _ => None
  }
}

///|
fn markdown_find_inline_code_end(chars : Array[Char], start : Int) -> Int? {
  let mut i = start + 1
  while i < chars.length() {
    if chars[i] == '`' {
      return Some(i)
    }
    i += 1
  }
  None
}

///|
fn markdown_safe_href(href : String) -> String? {
  let trimmed = href.trim().to_owned()
  let lowered = trimmed.to_lower()
  if lowered.has_prefix("javascript:") ||
    lowered.has_prefix("vbscript:") ||
    lowered.has_prefix("data:") ||
    lowered.has_prefix("file:") {
    None
  } else {
    Some(trimmed)
  }
}

///|
fn markdown_remote_href(href : String) -> Bool {
  let lowered = href.trim().to_owned().to_lower()
  lowered.has_prefix("http://") || lowered.has_prefix("https://")
}

///|
fn markdown_image_output_path(
  path : String,
  image_asset_index : Ref[Int],
) -> (String, String, String?) {
  let trimmed = path.trim().to_owned()
  if markdown_remote_href(trimmed) || !markdown_safe_local_image_src(trimmed) {
    image_asset_index.val += 1
    return (
      trimmed,
      "markdown-image-" + image_asset_index.val.to_string(),
      None,
    )
  }
  let src = markdown_strip_query_and_hash(trimmed)
  image_asset_index.val += 1
  (
    "assets/image" +
    markdown_two_digit(image_asset_index.val) +
    "." +
    markdown_image_ext_from_src(src),
    "markdown-image-" + image_asset_index.val.to_string(),
    Some(src),
  )
}

///|
fn markdown_safe_local_image_src(src : String) -> Bool {
  if src == "" ||
    src.has_prefix("/") ||
    src.has_prefix("\\") ||
    src.contains("..") ||
    src.contains(":") {
    return false
  }
  true
}

///|
fn markdown_strip_query_and_hash(src : String) -> String {
  let chars = src.to_array()
  let mut end = chars.length()
  for i in 0..<chars.length() {
    if chars[i] == '?' || chars[i] == '#' {
      end = i
      break
    }
  }
  src[:end].to_owned()
}

///|
fn markdown_image_ext_from_src(src : String) -> String {
  let trimmed = src.trim().to_owned().to_lower()
  let chars = trimmed.to_array()
  let mut last_dot = -1
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = i
    }
  }
  if last_dot >= 0 && last_dot + 1 < trimmed.length() {
    trimmed[last_dot + 1:].to_owned()
  } else {
    "png"
  }
}

///|
fn markdown_two_digit(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn markdown_html_contains_unsafe_tag(text : String) -> Bool {
  let lowered = text.to_lower()
  lowered.contains("<script") || lowered.contains("<style")
}

///|
fn markdown_source_ref_with_path(
  source_ref : @core.SourceRef,
  markdown_path : String,
) -> @core.SourceRef {
  @core.source_ref_with_markdown_path(
    source_ref,
    source_ref.file_id,
    source_ref.format,
    Some(markdown_path),
  )
}

///|
fn markdown_source_ref_from_lines(
  source : @input.InputSource,
  line_start : Int,
  line_end : Int,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.SourceRef {
  match base_source_ref {
    Some(base) =>
      @core.source_ref_with_lines(
        base,
        base.file_id,
        base.format,
        Some(line_start),
        Some(line_end),
      )
    None =>
      @core.source_ref_with_lines(
        @core.empty_source_ref(),
        Some(source.source_name),
        Some("markdown"),
        Some(line_start),
        Some(line_end),
      )
  }
}

///|
fn markdown_annotate_paths_and_report(
  blocks : Array[@core.CoreBlock],
) -> (Array[@core.CoreBlock], MarkdownBlockReport) {
  let heading_index : Ref[Int] = { val: 0 }
  let paragraph_index : Ref[Int] = { val: 0 }
  let list_index : Ref[Int] = { val: 0 }
  let table_index : Ref[Int] = { val: 0 }
  let code_index : Ref[Int] = { val: 0 }
  let quote_index : Ref[Int] = { val: 0 }
  let raw_index : Ref[Int] = { val: 0 }
  let report = markdown_new_block_report_accumulator()
  (
    blocks.map(block => {
      markdown_annotate_single_block_path(
        block, heading_index, paragraph_index, list_index, table_index, code_index,
        quote_index, raw_index, "/", report, 0,
      )
    }),
    markdown_block_report_from_accumulator(report),
  )
}

///|
fn markdown_annotate_single_block_path(
  block : @core.CoreBlock,
  heading_index : Ref[Int],
  paragraph_index : Ref[Int],
  list_index : Ref[Int],
  table_index : Ref[Int],
  code_index : Ref[Int],
  quote_index : Ref[Int],
  raw_index : Ref[Int],
  prefix : String,
  report : MarkdownBlockReportAccumulator,
  list_depth : Int,
) -> @core.CoreBlock {
  let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
  let path = if source_ref.markdown_path is Some(_) {
    source_ref.markdown_path.unwrap_or("/")
  } else {
    markdown_generated_path_for_block(
      block, heading_index, paragraph_index, list_index, table_index, code_index,
      quote_index, raw_index, prefix,
    )
  }
  let next_source_ref = @core.source_ref_with_markdown_path(
    source_ref,
    source_ref.file_id,
    source_ref.format,
    Some(path),
  )
  markdown_accumulate_single_block_report(block, report, list_depth)
  let children = if block.children.length() > 0 {
    let child_prefix = path
    let out : Array[@core.CoreBlock] = []
    for i in 0..<block.children.length() {
      let child = block.children[i]
      let child_ref = child.source_ref.unwrap_or(@core.empty_source_ref())
      let child_path = child_prefix + "/item[" + i.to_string() + "]"
      let child_source_ref = @core.source_ref_with_markdown_path(
        child_ref,
        child_ref.file_id,
        child_ref.format,
        Some(child_path),
      )
      let annotated_child = markdown_annotate_single_block_path(
        { ..child, source_ref: Some(child_source_ref) },
        heading_index,
        paragraph_index,
        list_index,
        table_index,
        code_index,
        quote_index,
        raw_index,
        child_path + "/",
        report,
        if block.kind == @core.BlockKind::List {
          list_depth + 1
        } else {
          list_depth
        },
      )
      out.push(annotated_child)
    }
    out
  } else {
    block.children
  }
  { ..block, source_ref: Some(next_source_ref), children }
}

///|
fn markdown_generated_path_for_block(
  block : @core.CoreBlock,
  heading_index : Ref[Int],
  paragraph_index : Ref[Int],
  list_index : Ref[Int],
  table_index : Ref[Int],
  code_index : Ref[Int],
  quote_index : Ref[Int],
  raw_index : Ref[Int],
  prefix : String,
) -> String {
  match block.kind {
    @core.BlockKind::Heading => {
      let index = heading_index.val
      heading_index.val += 1
      prefix + "heading[" + index.to_string() + "]"
    }
    @core.BlockKind::Paragraph => {
      let index = paragraph_index.val
      paragraph_index.val += 1
      prefix + "paragraph[" + index.to_string() + "]"
    }
    @core.BlockKind::List => {
      let index = list_index.val
      list_index.val += 1
      prefix + "list[" + index.to_string() + "]"
    }
    @core.BlockKind::Table => {
      let index = table_index.val
      table_index.val += 1
      prefix + "table[" + index.to_string() + "]"
    }
    @core.BlockKind::Code => {
      let index = code_index.val
      code_index.val += 1
      prefix + "code[" + index.to_string() + "]"
    }
    @core.BlockKind::BlockQuote => {
      let index = quote_index.val
      quote_index.val += 1
      prefix + "blockquote[" + index.to_string() + "]"
    }
    @core.BlockKind::Raw => {
      let existing = block.attrs.get("raw_kind").unwrap_or("raw")
      let index = raw_index.val
      raw_index.val += 1
      prefix + existing + "[" + index.to_string() + "]"
    }
    @core.BlockKind::Image => {
      let index = paragraph_index.val
      paragraph_index.val += 1
      prefix + "image[" + index.to_string() + "]"
    }
    _ => prefix + "block[0]"
  }
}

///|
fn markdown_source_ref(
  block : @dmd.MarkdownBlock,
  source : @input.InputSource,
  base_source_ref? : @core.SourceRef? = None,
) -> @core.SourceRef {
  markdown_source_ref_from_lines(
    source,
    block.line_start,
    block.line_end,
    base_source_ref~,
  )
}

///|
fn markdown_heading_level(text : String) -> Int {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  let mut level = 0
  while level < chars.length() && chars[level] == '#' {
    level += 1
  }
  @fshared.clamp_int(level, 1, 6)
}

///|
fn markdown_setext_heading_level(text : String) -> Int {
  let lines = text.split("\n").to_array()
  if lines.length() < 2 {
    return 1
  }
  let underline = lines[1].trim().to_owned()
  if underline.has_prefix("=") {
    1
  } else {
    2
  }
}

///|
fn markdown_list_is_ordered(text : String) -> Bool {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  let mut saw_digit = false
  for ch in chars {
    if ch >= '0' && ch <= '9' {
      saw_digit = true
      continue
    }
    if (ch == '.' || ch == ')') && saw_digit {
      return true
    }
    return false
  }
  false
}

///|
fn parse_markdown_image(text : String) -> (String, String)? {
  let trimmed = text.trim().to_owned()
  if !trimmed.has_prefix("![") || !trimmed.has_suffix(")") {
    return None
  }
  let chars = trimmed.to_array()
  let mut alt_end : Int? = None
  let mut path_start : Int? = None
  for i in 0..<chars.length() {
    if chars[i] == ']' && alt_end is None {
      alt_end = Some(i)
    } else if chars[i] == '(' && path_start is None {
      path_start = Some(i)
    }
  }
  match (alt_end, path_start) {
    (Some(alt_index), Some(path_index)) =>
      if path_index > alt_index && alt_index >= 2 {
        Some(
          (
            trimmed[2:alt_index].to_owned(),
            trimmed[path_index + 1:trimmed.length() - 1].to_owned(),
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn markdown_frontmatter_kind_name(
  kind : @dmd.MarkdownFrontmatterKind,
) -> String {
  match kind {
    @dmd.MarkdownFrontmatterKind::Yaml => "yaml"
    @dmd.MarkdownFrontmatterKind::Toml => "toml"
    @dmd.MarkdownFrontmatterKind::Unknown => "unknown"
  }
}

///|
fn strip_fence_block_content(text : String) -> String {
  let lines = text.split("\n").to_array()
  if lines.length() < 2 {
    return text
  }
  let inner : Array[String] = []
  for i in 1..<lines.length() {
    if i == lines.length() - 1 && lines[i].trim().has_prefix("```") {
      ()
    } else {
      inner.push(lines[i].to_owned())
    }
  }
  inner.join("\n")
}

///|
fn strip_markdown_heading(text : String) -> String {
  let trimmed = text.trim().to_owned()
  let chars = trimmed.to_array()
  let mut i = 0
  while i < chars.length() && chars[i] == '#' {
    i += 1
  }
  trimmed[i:].trim().to_owned()
}

///|
fn strip_setext_heading(text : String) -> String {
  text.split("\n").to_array()[0].trim().to_owned()
}

///|
fn strip_markdown_list_marker(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.has_prefix("- ") ||
    trimmed.has_prefix("* ") ||
    trimmed.has_prefix("+ ") {
    return trimmed[2:].trim().to_owned()
  }
  let chars = trimmed.to_array()
  for i in 0..<chars.length() {
    if chars[i] == '.' || chars[i] == ')' {
      return trimmed[i + 1:].trim().to_owned()
    }
  }
  trimmed
}

///|
fn strip_markdown_blockquote(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed.has_prefix(">") {
    trimmed[1:].trim().to_owned()
  } else {
    trimmed
  }
}
