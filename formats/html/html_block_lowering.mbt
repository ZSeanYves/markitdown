///|
fn html_lowering_map_push_inline_fact(
  map : Map[String, Array[@dhtml.HtmlInlineFact]],
  key : String,
  value : @dhtml.HtmlInlineFact,
) -> Unit {
  match map.get(key) {
    Some(existing) => existing.push(value)
    None => map.set(key, [value])
  }
}

///|
fn html_lowering_index_item_count(index : HtmlLoweringIndex) -> Int {
  index.block_by_key.length() +
  index.inline_by_key.length() +
  index.skipped_block_keys.length()
}

///|
fn html_collect_top_level_blocks(
  semantic : @dhtml.HtmlSemanticDocument,
  index : HtmlLoweringIndex,
) -> Array[@dhtml.HtmlBlockFact] {
  let out : Array[@dhtml.HtmlBlockFact] = []
  let scope_root = html_selected_scope_root_key(semantic)
  for block in semantic.blocks {
    if html_block_should_skip(index, block) {
      continue
    }
    if scope_root == Some(block.source_key) {
      continue
    }
    let is_top = match scope_root {
      Some(root_key) => block.parent_source_key == Some(root_key)
      None => block.parent_source_key is None
    }
    if is_top {
      out.push(block)
    }
  }
  out.sort_by(fn(a, b) { a.source_order.compare(b.source_order) })
  out
}

///|
fn html_block_should_skip(
  index : HtmlLoweringIndex,
  block : @dhtml.HtmlBlockFact,
) -> Bool {
  index.skipped_block_keys.contains(block.source_key)
}

///|
fn html_selected_scope_root_key(
  semantic : @dhtml.HtmlSemanticDocument,
) -> String? {
  for scope in semantic.scope {
    if scope.selected_content_root_key is Some(_) {
      return scope.selected_content_root_key
    }
  }
  None
}

///|
fn html_mark_skipped_blocks(
  semantic : @dhtml.HtmlSemanticDocument,
  block_by_key : Map[String, @dhtml.HtmlBlockFact],
  skipped : Map[String, Bool],
  nav_spans : Array[@dhtml.HtmlSourceSpan],
) -> Unit {
  let nav_context_by_block_key : Map[String, Bool] = Map([])
  for unsupported in semantic.unsupported {
    skipped.set(unsupported.source_key, true)
  }
  for block in semantic.blocks {
    let parent_in_nav_context = match block.parent_source_key {
      Some(parent_key) =>
        nav_context_by_block_key.get(parent_key).unwrap_or(false)
      None => false
    }
    let in_nav_context = parent_in_nav_context || block.tag_name == "nav"
    if in_nav_context {
      nav_context_by_block_key.set(block.source_key, true)
    }
    if html_block_span_in_nav_span(block.span, nav_spans) ||
      parent_in_nav_context {
      skipped.set(block.source_key, true)
    }
  }
  for noise in semantic.noise_candidates {
    match noise.block_source_key {
      Some(key) =>
        if html_noise_should_skip(noise) {
          skipped.set(key, true)
          html_mark_block_subtree(block_by_key, key, skipped)
        }
      None => ()
    }
  }
}

///|
fn html_block_span_in_nav_span(
  span : @dhtml.HtmlSourceSpan,
  nav_spans : Array[@dhtml.HtmlSourceSpan],
) -> Bool {
  for nav_span in nav_spans {
    if span.line_start >= nav_span.line_start &&
      span.line_end <= nav_span.line_end {
      return true
    }
  }
  false
}

///|
fn html_noise_should_skip(noise : @dhtml.HtmlNoiseCandidateFact) -> Bool {
  if noise.tag_name == "nav" {
    return true
  }
  for reason in noise.reasons {
    match reason {
      @dhtml.HtmlNoiseCandidateReason::NavLike
      | @dhtml.HtmlNoiseCandidateReason::FooterLike
      | @dhtml.HtmlNoiseCandidateReason::Hiddenish
      | @dhtml.HtmlNoiseCandidateReason::ScriptStyleTemplate => return true
      _ => ()
    }
  }
  false
}

///|
fn html_mark_block_subtree(
  block_by_key : Map[String, @dhtml.HtmlBlockFact],
  root_key : String,
  skipped : Map[String, Bool],
) -> Unit {
  match block_by_key.get(root_key) {
    Some(root) =>
      for child_key in root.children {
        skipped.set(child_key, true)
        html_mark_block_subtree(block_by_key, child_key, skipped)
      }
    None => ()
  }
}

///|
fn html_blocks_for_block(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  match block.kind {
    @dhtml.HtmlBlockKind::Heading(level) =>
      html_heading_blocks(state, semantic, source, block, level, index)
    @dhtml.HtmlBlockKind::Paragraph =>
      html_paragraph_blocks_for_block(state, semantic, source, block, index)
    @dhtml.HtmlBlockKind::List(_) =>
      html_list_container_blocks(
        state, semantic, source, block, dom_blocks, index,
      )
    @dhtml.HtmlBlockKind::ListItem =>
      html_list_item_blocks(state, semantic, source, block, dom_blocks, index)
    @dhtml.HtmlBlockKind::Table =>
      html_table_blocks(state, semantic, source, block, index)
    @dhtml.HtmlBlockKind::BlockQuote =>
      html_blockquote_blocks(state, semantic, source, block, dom_blocks, index)
    @dhtml.HtmlBlockKind::Pre =>
      html_code_blocks(semantic, source, block, index)
    @dhtml.HtmlBlockKind::CodeBlock =>
      html_code_blocks(semantic, source, block, index)
    @dhtml.HtmlBlockKind::Figure =>
      html_figure_blocks(state, semantic, source, block, index)
    @dhtml.HtmlBlockKind::HorizontalRule =>
      [html_horizontal_rule_block(source, block)]
    @dhtml.HtmlBlockKind::UnknownBlock =>
      html_unknown_container_blocks(
        state, semantic, source, block, dom_blocks, index,
      )
    @dhtml.HtmlBlockKind::FigCaption
    | @dhtml.HtmlBlockKind::TableRow
    | @dhtml.HtmlBlockKind::TableCell(_)
    | @dhtml.HtmlBlockKind::UnsupportedBlock => []
  }
}

///|
fn html_heading_blocks(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  level : Int,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  let inlines = html_inlines_for_block(
    state,
    semantic,
    source,
    block.source_key,
    index,
  )
  let text = html_render_plain_inlines(inlines).trim().to_owned()
  if text == "" {
    return []
  }
  let heading = @core.make_block(
    @core.BlockKind::Heading,
    text,
    source_ref=html_block_source_ref(source, block),
  )
  heading.attrs.set("level", @parser_common.clamp_int(level, 1, 6).to_string())
  heading.attrs.set("literal", "true")
  heading.attrs.set("render_inline_escape_mode", "minimal")
  [@core.block_with_rich_inlines(heading, Some(inlines))]
}

///|
fn html_paragraph_blocks_for_block(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  let inlines = html_inlines_for_paragraph(
    state,
    semantic,
    source,
    block.source_key,
    index,
  )
  html_paragraph_inlines_to_blocks(
    inlines,
    html_block_source_ref(source, block),
  )
}

///|
fn html_list_container_blocks(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  let list = @core.make_block(
    @core.BlockKind::List,
    "",
    source_ref=html_block_source_ref(source, block),
  )
  match html_list_for_block(index, block.source_key) {
    Some(fact) =>
      list.attrs.set(
        "ordered",
        @parser_common.bool_string(fact.kind == @dhtml.HtmlListKind::Ordered),
      )
    None => ()
  }
  let trailing_blocks : Array[@core.CoreBlock] = []
  for child_key in block.children {
    match html_block_by_key(index, child_key) {
      Some(child) =>
        if child.kind == @dhtml.HtmlBlockKind::ListItem {
          let item_blocks = html_list_item_blocks(
            state, semantic, source, child, dom_blocks, index,
          )
          if item_blocks.length() > 0 &&
            item_blocks[0].kind == @core.BlockKind::ListItem {
            list.children.push(item_blocks[0])
            if item_blocks.length() > 1 {
              for extra in item_blocks[1:] {
                trailing_blocks.push(extra)
              }
            }
          }
        }
      None => ()
    }
  }
  if list.children.length() == 0 {
    []
  } else {
    let out : Array[@core.CoreBlock] = [list]
    out.append(trailing_blocks[:])
    out
  }
}

///|
fn html_list_item_blocks(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  match dom_blocks.get(block.source_key) {
    Some(element) =>
      return html_list_item_blocks_from_dom(
        state, semantic, source, block, element, dom_blocks, index,
      )
    None => ()
  }
  let source_ref = html_block_source_ref(source, block)
  let ordered = html_list_item_is_ordered(index, block.source_key)
  let child_blocks = html_child_blocks_sorted(index, block.children)
  let inline_segments = html_core_inline_segments_for_block(
    state,
    semantic,
    source,
    block.source_key,
    child_blocks,
    index,
  )
  let primary_child_index = if inline_segments[0].length() > 0 {
    None
  } else {
    html_list_item_primary_child_index(child_blocks)
  }
  let primary_inlines = if inline_segments[0].length() > 0 {
    inline_segments[0]
  } else {
    match primary_child_index {
      Some(child_pos) =>
        html_trim_core_inlines_edges(
          html_inlines_for_paragraph(
            state,
            semantic,
            source,
            child_blocks[child_pos].source_key,
            index,
          ),
        )
      None => []
    }
  }
  let text = html_render_plain_inlines(primary_inlines).trim().to_owned()
  let item = @core.make_block(@core.BlockKind::ListItem, text, source_ref~)
  item.attrs.set("ordered", @parser_common.bool_string(ordered))
  if ordered {
    item.attrs.set("ordered_indent_step", "3")
  }
  item.attrs.set("stable_ordered_marker", "true")
  item.attrs.set("literal", "true")
  item.attrs.set("render_inline_escape_mode", "minimal")
  let mut root = item
  if primary_inlines.length() > 0 {
    root = @core.block_with_rich_inlines(root, Some(primary_inlines))
  }
  let nested_lists : Array[@core.CoreBlock] = []
  let extras : Array[@core.CoreBlock] = []
  for child_pos in 0..<child_blocks.length() {
    let child = child_blocks[child_pos]
    if primary_child_index != Some(child_pos) {
      match child.kind {
        @dhtml.HtmlBlockKind::List(_) =>
          html_append_flattened_blocks(
            nested_lists,
            html_blocks_for_block(
              state, semantic, source, child, dom_blocks, index,
            ),
          )
        @dhtml.HtmlBlockKind::BlockQuote =>
          html_append_flattened_blocks(
            extras,
            html_blockquote_body_blocks(
              state, semantic, source, child, dom_blocks, index,
            ),
          )
        _ =>
          html_append_flattened_blocks(
            extras,
            html_blocks_for_block(
              state, semantic, source, child, dom_blocks, index,
            ),
          )
      }
    }
    if child_pos + 1 < inline_segments.length() &&
      inline_segments[child_pos + 1].length() > 0 {
      html_append_flattened_blocks(
        extras,
        html_core_inline_segment_to_blocks(
          inline_segments[child_pos + 1],
          source_ref,
        ),
      )
    }
  }
  if nested_lists.length() > 0 {
    root = @core.block_with_children(root, nested_lists)
  }
  if text == "" && nested_lists.length() == 0 && extras.length() == 0 {
    return []
  }
  let out : Array[@core.CoreBlock] = [root]
  out.append(extras[:])
  out
}

///|
fn html_list_item_blocks_from_dom(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  element : @dhtml.HtmlElement,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  let ordered = html_list_item_is_ordered(index, block.source_key)
  let source_ref = html_block_source_ref(source, block)
  let pieces = html_container_child_blocks_from_dom(
    state,
    semantic,
    source,
    block,
    element,
    dom_blocks,
    index,
    flatten_blockquotes=true,
  )
  let nested_lists : Array[@core.CoreBlock] = []
  let extras : Array[@core.CoreBlock] = []
  let mut root_piece_index : Int? = None
  for index in 0..<pieces.length() {
    let piece = pieces[index]
    if piece.kind == @core.BlockKind::List {
      nested_lists.push(piece)
    } else if root_piece_index is None &&
      piece.kind == @core.BlockKind::Paragraph {
      root_piece_index = Some(index)
    } else {
      extras.push(piece)
    }
  }
  let root_text = match root_piece_index {
    Some(index) => pieces[index].text
    None => ""
  }
  let item = @core.make_block(@core.BlockKind::ListItem, root_text, source_ref~)
  item.attrs.set("ordered", @parser_common.bool_string(ordered))
  if ordered {
    item.attrs.set("ordered_indent_step", "3")
  }
  item.attrs.set("stable_ordered_marker", "true")
  item.attrs.set("literal", "true")
  item.attrs.set("render_inline_escape_mode", "minimal")
  let mut root = item
  match root_piece_index {
    Some(index) =>
      match pieces[index].rich_inlines {
        Some(inlines) if inlines.length() > 0 =>
          root = @core.block_with_rich_inlines(root, Some(inlines))
        _ => ()
      }
    None => ()
  }
  if nested_lists.length() > 0 {
    root = @core.block_with_children(root, nested_lists)
  }
  if root_text == "" && nested_lists.length() == 0 && extras.length() == 0 {
    return []
  }
  let out : Array[@core.CoreBlock] = [root]
  out.append(extras[:])
  out
}

///|
fn html_list_item_primary_child_index(
  child_blocks : Array[@dhtml.HtmlBlockFact],
) -> Int? {
  for child_pos in 0..<child_blocks.length() {
    if child_blocks[child_pos].kind == @dhtml.HtmlBlockKind::Paragraph {
      return Some(child_pos)
    }
  }
  None
}

///|
fn html_table_blocks(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  match html_table_to_block(state, semantic, source, block.source_key, index) {
    Some(table) => [table]
    None =>
      if block.text_preview.trim() == "" {
        []
      } else {
        [
          @core.make_block(
            @core.BlockKind::Paragraph,
            block.text_preview.trim().to_owned(),
            source_ref=html_block_source_ref(source, block),
          ),
        ]
      }
  }
}

///|
fn html_blockquote_blocks(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  let body_blocks = html_blockquote_body_blocks(
    state, semantic, source, block, dom_blocks, index,
  )
  if body_blocks.length() == 0 {
    let fallback = html_paragraph_blocks_for_block(
      state, semantic, source, block, index,
    )
    let lines = html_quote_lines_from_blocks(fallback)
    if lines.length() == 0 {
      []
    } else {
      [
        @core.make_block(
          @core.BlockKind::BlockQuote,
          lines.join("\n"),
          source_ref=html_block_source_ref(source, block),
        ),
      ]
    }
  } else {
    let quote = @core.make_block(
      @core.BlockKind::BlockQuote,
      html_quote_lines_from_blocks(body_blocks).join("\n"),
      source_ref=html_block_source_ref(source, block),
    )
    [@core.block_with_children(quote, body_blocks)]
  }
}

///|
fn html_blockquote_body_blocks(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  match dom_blocks.get(block.source_key) {
    Some(element) =>
      return html_container_child_blocks_from_dom(
        state,
        semantic,
        source,
        block,
        element,
        dom_blocks,
        index,
        flatten_blockquotes=true,
      )
    None => ()
  }
  let child_blocks = match html_blockquote_for_block(index, block.source_key) {
    Some(quote) =>
      html_child_blocks_sorted(index, quote.child_block_source_keys)
    None => html_child_blocks_sorted(index, block.children)
  }
  let inline_segments = html_core_inline_segments_for_block(
    state,
    semantic,
    source,
    block.source_key,
    child_blocks,
    index,
  )
  if child_blocks.length() == 0 {
    return html_core_inline_segment_to_blocks(
      inline_segments[0],
      html_block_source_ref(source, block),
    )
  }
  let out : Array[@core.CoreBlock] = []
  for child_pos in 0..<child_blocks.length() {
    if inline_segments[child_pos].length() > 0 {
      html_append_flattened_blocks(
        out,
        html_core_inline_segment_to_blocks(
          inline_segments[child_pos],
          html_block_source_ref(source, block),
        ),
      )
    }
    html_append_flattened_blocks(
      out,
      html_blocks_for_block(
        state,
        semantic,
        source,
        child_blocks[child_pos],
        dom_blocks,
        index,
      ),
    )
  }
  if inline_segments[child_blocks.length()].length() > 0 {
    html_append_flattened_blocks(
      out,
      html_core_inline_segment_to_blocks(
        inline_segments[child_blocks.length()],
        html_block_source_ref(source, block),
      ),
    )
  }
  out
}

///|
fn html_container_child_blocks_from_dom(
  state : HtmlLoweringState,
  semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  element : @dhtml.HtmlElement,
  dom_blocks : Map[String, @dhtml.HtmlElement],
  index : HtmlLoweringIndex,
  flatten_blockquotes? : Bool = false,
) -> Array[@core.CoreBlock] {
  let child_blocks = html_child_blocks_sorted(index, block.children)
  let top_level_inline_facts = html_top_level_inline_facts_for_block(
    index,
    block.source_key,
  )
  let current_inline_facts : Array[@dhtml.HtmlInlineFact] = []
  let out : Array[@core.CoreBlock] = []
  let mut inline_index = 0
  let mut child_index = 0

  fn flush_current_inline_facts(
    out : Array[@core.CoreBlock],
    current_inline_facts : Array[@dhtml.HtmlInlineFact],
    state : HtmlLoweringState,
    semantic : @dhtml.HtmlSemanticDocument,
    source : @input.InputSource,
    block : @dhtml.HtmlBlockFact,
    index : HtmlLoweringIndex,
  ) -> Unit {
    if current_inline_facts.length() == 0 {
      return
    }
    html_append_flattened_blocks(
      out,
      html_inline_segment_to_blocks(
        state,
        semantic,
        source,
        current_inline_facts,
        html_block_source_ref(source, block),
        index,
      ),
    )
    current_inline_facts.clear()
  }

  for child in element.children {
    match child {
      @dhtml.HtmlNode::Element(child_element) =>
        if html_dom_nav_like(child_element) {
          flush_current_inline_facts(
            out, current_inline_facts, state, semantic, source, block, index,
          )
        } else if html_dom_counts_as_block(child_element.tag_name, false) {
          flush_current_inline_facts(
            out, current_inline_facts, state, semantic, source, block, index,
          )
          match
            html_find_matching_child_block(
              child_blocks, child_index, child_element,
            ) {
            Some((matched_index, child_block)) => {
              child_index = matched_index + 1
              let lowered = if flatten_blockquotes &&
                child_block.kind == @dhtml.HtmlBlockKind::BlockQuote {
                html_blockquote_body_blocks(
                  state, semantic, source, child_block, dom_blocks, index,
                )
              } else {
                html_blocks_for_block(
                  state, semantic, source, child_block, dom_blocks, index,
                )
              }
              html_append_flattened_blocks(out, lowered)
            }
            None => ()
          }
        } else {
          inline_index = html_dom_consume_inline_facts_from_node(
            child, top_level_inline_facts, inline_index, current_inline_facts, false,
          )
        }
      _ =>
        inline_index = html_dom_consume_inline_facts_from_node(
          child, top_level_inline_facts, inline_index, current_inline_facts, false,
        )
    }
  }

  while inline_index < top_level_inline_facts.length() {
    current_inline_facts.push(top_level_inline_facts[inline_index])
    inline_index += 1
  }
  flush_current_inline_facts(
    out, current_inline_facts, state, semantic, source, block, index,
  )
  out
}

///|
fn html_find_matching_child_block(
  child_blocks : Array[@dhtml.HtmlBlockFact],
  start : Int,
  element : @dhtml.HtmlElement,
) -> (Int, @dhtml.HtmlBlockFact)? {
  let mut fallback : (Int, @dhtml.HtmlBlockFact)? = None
  for index in start..<child_blocks.length() {
    let block = child_blocks[index]
    if block.tag_name == element.tag_name &&
      block.span.line_start == element.span.line_start &&
      block.span.line_end == element.span.line_end {
      return Some((index, block))
    }
    if fallback is None && block.tag_name == element.tag_name {
      fallback = Some((index, block))
    }
  }
  fallback
}

///|
fn html_dom_consume_inline_facts_from_node(
  node : @dhtml.HtmlNode,
  facts : Array[@dhtml.HtmlInlineFact],
  start : Int,
  out : Array[@dhtml.HtmlInlineFact],
  parent_pre : Bool,
) -> Int {
  match node {
    @dhtml.HtmlNode::Text(_) =>
      if start < facts.length() &&
        facts[start].kind == @dhtml.HtmlInlineKind::Text {
        out.push(facts[start])
        start + 1
      } else {
        start
      }
    @dhtml.HtmlNode::Element(element) =>
      if html_dom_counts_as_block(element.tag_name, parent_pre) {
        start
      } else if html_dom_element_has_top_level_inline_fact(
          element.tag_name,
          parent_pre,
        ) {
        if start < facts.length() {
          out.push(facts[start])
          start + 1
        } else {
          start
        }
      } else {
        let mut next = start
        for child in element.children {
          next = html_dom_consume_inline_facts_from_node(
            child,
            facts,
            next,
            out,
            parent_pre || element.tag_name == "pre",
          )
        }
        next
      }
    _ => start
  }
}

///|
fn html_dom_element_has_top_level_inline_fact(
  tag_name : String,
  parent_pre : Bool,
) -> Bool {
  match tag_name {
    "a"
    | "img"
    | "em"
    | "i"
    | "strong"
    | "b"
    | "br"
    | "span"
    | "small"
    | "mark"
    | "sub"
    | "sup" => true
    "code" => !parent_pre
    "script"
    | "noscript"
    | "style"
    | "iframe"
    | "embed"
    | "object"
    | "svg"
    | "math"
    | "template"
    | "form"
    | "input"
    | "select"
    | "textarea"
    | "button"
    | "video"
    | "audio"
    | "source"
    | "canvas" => true
    _ => false
  }
}

///|
fn html_code_blocks(
  _semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  match html_code_block_for_block(index, block.source_key) {
    Some(code) =>
      if code.code_text.trim() == "" {
        []
      } else {
        let out = @core.make_block(
          @core.BlockKind::Code,
          code.code_text,
          source_ref=html_block_source_ref(source, block),
        )
        match code.language_hint {
          Some(language) if language.trim() != "" =>
            out.attrs.set("info", language.trim().to_owned())
          None => ()
          _ => ()
        }
        [out]
      }
    None => []
  }
}

///|
fn html_figure_blocks(
  state : HtmlLoweringState,
  _semantic : @dhtml.HtmlSemanticDocument,
  source : @input.InputSource,
  block : @dhtml.HtmlBlockFact,
  index : HtmlLoweringIndex,
) -> Array[@core.CoreBlock] {
  match html_figure_for_block(index, block.source_key) {
    Some(figure) =>
      if figure.image_source_keys.length() == 0 {
        []
      } else {
        match html_image_by_key(index, figure.image_source_keys[0]) {
          Some(image) =>
            match html_image_to_asset(state, source, image) {
              Some(asset) => {
                let image_block = html_image_block_from_asset(
                  asset.0,
                  asset.1,
                  image.alt.unwrap_or("image").trim().to_owned(),
                  image.title,
                  figure.caption_text_preview,
                )
                [
                  @core.make_block(
                    @core.BlockKind::Image,
                    image_block.text,
                    source_ref=html_block_source_ref(source, block),
                  )
                  |> with_html_image_attrs(image_block),
                ]
              }
              None => {
                let out : Array[@core.CoreBlock] = []
                if image.kind != @dhtml.HtmlImageKind::Remote {
                  let label = html_image_placeholder_text(
                    image.kind,
                    image.alt.unwrap_or("image").trim().to_owned(),
                  )
                  out.push(
                    @core.make_block(
                      @core.BlockKind::Paragraph,
                      label,
                      source_ref=html_block_source_ref(source, block),
                    ),
                  )
                }
                match figure.caption_text_preview {
                  Some(caption) if caption.trim() != "" =>
                    out.push(
                      @core.make_block(
                        @core.BlockKind::Paragraph,
                        caption.trim().to_owned(),
                        source_ref=html_block_source_ref(source, block),
                      ),
                    )
                  None => ()
                  _ => ()
                }
                out
              }
            }
          None => []
        }
      }
    None => []
  }
}
