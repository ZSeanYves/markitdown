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
