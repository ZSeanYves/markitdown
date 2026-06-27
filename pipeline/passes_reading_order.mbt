///|
pub fn merge_text_line_pass() -> IRPass {
  {
    name: "MergeTextLinePass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(merge_text_line_input(context, input))
    },
  }
}

///|
pub fn resolve_reading_order_pass() -> IRPass {
  {
    name: "ResolveReadingOrderPass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(resolve_reading_order_input(context, input))
    },
  }
}

///|
pub fn remove_header_footer_pass() -> IRPass {
  {
    name: "RemoveHeaderFooterPass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(remove_header_footer_input(context, input))
    },
  }
}

///|
fn merge_text_line_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let merged : Array[@core.CoreBlock] = []
  let mut pending : @core.CoreBlock? = None
  for block in blocks {
    let next_block = @core.block_with_children(
      block,
      merge_text_line_blocks(block.children),
    )
    if pending is Some(current) &&
      paragraph_blocks_should_merge(current, next_block) {
      pending = Some(merge_paragraph_blocks(current, next_block))
      continue
    }
    match pending {
      Some(current) => merged.push(current)
      None => ()
    }
    pending = if paragraph_merge_candidate(next_block) {
      Some(next_block)
    } else {
      None
    }
    if !paragraph_merge_candidate(next_block) {
      merged.push(next_block)
    }
  }
  match pending {
    Some(current) => merged.push(current)
    None => ()
  }
  merged
}

///|
fn resolve_reading_order_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let ordered : Array[@core.CoreBlock] = []
  for block in blocks {
    ordered.push(
      @core.block_with_children(
        block,
        resolve_reading_order_blocks(block.children),
      ),
    )
  }
  if ordered.length() <= 1 {
    return ordered
  }
  let hinted_blocks : Array[(Int, @core.CoreBlock)] = []
  for index in 0..<ordered.length() {
    if block_has_explicit_reading_order_hint(ordered[index]) {
      hinted_blocks.push((index, ordered[index]))
    }
  }
  if hinted_blocks.length() < 2 {
    return ordered
  }
  let reordered : Array[@core.CoreBlock] = ordered.copy()
  let mut start = 0
  while start < hinted_blocks.length() {
    let boundary = block_reading_order_boundary_key(hinted_blocks[start].1)
    let mut end = start + 1
    while end < hinted_blocks.length() &&
          block_reading_order_boundary_key(hinted_blocks[end].1) == boundary {
      end += 1
    }
    let group_indexes : Array[Int] = []
    let local_group : Array[(Int, @core.CoreBlock)] = []
    for index in start..<end {
      local_group.push(hinted_blocks[index])
      group_indexes.push(hinted_blocks[index].0)
    }
    group_indexes.sort()
    local_group.sort_by(fn(left, right) {
      let compared = compare_blocks_by_reading_order(left.1, right.1)
      if compared != 0 {
        compared
      } else if left.0 < right.0 {
        -1
      } else if left.0 > right.0 {
        1
      } else {
        0
      }
    })
    for index in 0..<local_group.length() {
      reordered[group_indexes[index]] = local_group[index].1
    }
    start = end
  }
  reordered
}

///|
fn remove_header_footer_blocks(
  blocks : Array[@core.CoreBlock],
  cleanup_enabled : Bool,
  debug : Bool,
) -> (Array[@core.CoreBlock], Int) {
  let kept : Array[@core.CoreBlock] = []
  let mut removed = 0
  for block in blocks {
    let next_children = remove_header_footer_blocks(
      block.children,
      cleanup_enabled,
      debug,
    )
    let next = @core.block_with_children(block, next_children.0)
    removed += next_children.1
    if block_is_header_footer_candidate(next) {
      if cleanup_enabled && !debug {
        removed += 1
        continue
      }
      if debug {
        next.attrs.set("header_footer_candidate", "true")
      }
    }
    kept.push(next)
  }
  (kept, removed)
}

///|
fn paragraph_merge_candidate(block : @core.CoreBlock) -> Bool {
  block.kind == @core.BlockKind::Paragraph && block.children.length() == 0
}

///|
fn paragraph_blocks_should_merge(
  left : @core.CoreBlock,
  right : @core.CoreBlock,
) -> Bool {
  if !paragraph_merge_candidate(left) || !paragraph_merge_candidate(right) {
    return false
  }
  let left_ref = left.source_ref.unwrap_or(@core.empty_source_ref())
  let right_ref = right.source_ref.unwrap_or(@core.empty_source_ref())
  if left_ref.page != right_ref.page ||
    left_ref.slide != right_ref.slide ||
    left_ref.sheet != right_ref.sheet {
    return false
  }
  if left_ref.format != Some("pdf") || right_ref.format != Some("pdf") {
    return false
  }
  let left_group = pdf_merge_group_key(left_ref)
  let right_group = pdf_merge_group_key(right_ref)
  if left_group is None || right_group is None {
    return false
  }
  if left_ref.extra.get("reading_order_index") !=
    right_ref.extra.get("reading_order_index") {
    return false
  }
  if left_group != right_group {
    return false
  }
  if block_is_header_footer_candidate(left) ||
    block_is_header_footer_candidate(right) {
    return false
  }
  true
}

///|
fn merge_paragraph_blocks(
  left : @core.CoreBlock,
  right : @core.CoreBlock,
) -> @core.CoreBlock {
  let merged_text = merge_text_line_strings(left.text, right.text)
  let next = { ..left, text: merged_text }
  let left_ref = left.source_ref.unwrap_or(@core.empty_source_ref())
  let right_ref = right.source_ref.unwrap_or(@core.empty_source_ref())
  let merged_ref = {
    ..left_ref,
    bbox: merge_source_bbox(left_ref.bbox, right_ref.bbox),
    line_start: min_optional_int(left_ref.line_start, right_ref.line_start),
    line_end: max_optional_int(left_ref.line_end, right_ref.line_end),
  }
  { ..next, source_ref: Some(merged_ref) }
}

///|
fn merge_text_line_strings(left : String, right : String) -> String {
  let lhs = left.trim_end().to_owned()
  let rhs = right.trim_start().to_owned()
  if lhs == "" {
    return rhs
  }
  if rhs == "" {
    return lhs
  }
  if lhs.has_suffix("-") && rhs != "" {
    lhs[:lhs.length() - 1].to_owned() + rhs
  } else {
    lhs + " " + rhs
  }
}

///|
fn merge_source_bbox(left : @core.BBox?, right : @core.BBox?) -> @core.BBox? {
  match (left, right) {
    (Some(lhs), Some(rhs)) =>
      Some({
        x0: if lhs.x0 < rhs.x0 {
          lhs.x0
        } else {
          rhs.x0
        },
        y0: if lhs.y0 < rhs.y0 {
          lhs.y0
        } else {
          rhs.y0
        },
        x1: if lhs.x1 > rhs.x1 {
          lhs.x1
        } else {
          rhs.x1
        },
        y1: if lhs.y1 > rhs.y1 {
          lhs.y1
        } else {
          rhs.y1
        },
      })
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn min_optional_int(left : Int?, right : Int?) -> Int? {
  match (left, right) {
    (Some(lhs), Some(rhs)) => Some(if lhs < rhs { lhs } else { rhs })
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn max_optional_int(left : Int?, right : Int?) -> Int? {
  match (left, right) {
    (Some(lhs), Some(rhs)) => Some(if lhs > rhs { lhs } else { rhs })
    (Some(lhs), None) => Some(lhs)
    (None, Some(rhs)) => Some(rhs)
    (None, None) => None
  }
}

///|
fn compare_blocks_by_reading_order(
  left : @core.CoreBlock,
  right : @core.CoreBlock,
) -> Int {
  let left_ref = left.source_ref.unwrap_or(@core.empty_source_ref())
  let right_ref = right.source_ref.unwrap_or(@core.empty_source_ref())
  let left_rank = block_reading_order_rank(left, left_ref)
  let right_rank = block_reading_order_rank(right, right_ref)
  let rank_order = left_rank.lexical_compare(right_rank)
  if rank_order != 0 {
    return rank_order
  }
  let left_page = left_ref.page.unwrap_or(0)
  let right_page = right_ref.page.unwrap_or(0)
  if left_page < right_page {
    return -1
  } else if left_page > right_page {
    return 1
  }
  let left_slide = left_ref.slide.unwrap_or(0)
  let right_slide = right_ref.slide.unwrap_or(0)
  if left_slide < right_slide {
    return -1
  } else if left_slide > right_slide {
    return 1
  }
  0
}

///|
fn block_reading_order_boundary_key(block : @core.CoreBlock) -> String {
  let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
  source_ref.format.unwrap_or("") +
  "|" +
  source_ref.page.map(i => i.to_string()).unwrap_or("") +
  "|" +
  source_ref.slide.map(i => i.to_string()).unwrap_or("") +
  "|" +
  source_ref.sheet.unwrap_or("") +
  "|" +
  source_ref.entry_path.unwrap_or("")
}

///|
fn block_reading_order_rank(
  block : @core.CoreBlock,
  source_ref : @core.SourceRef,
) -> String {
  match source_ref.extra.get("reading_order_key") {
    Some(value) => "0|" + value
    None =>
      match source_ref.extra.get("reading_order_index") {
        Some(value) => "1|" + left_pad_numeric_string(value, 8)
        None =>
          "9|" +
          block_kind_rank(block.kind) +
          "|" +
          source_ref.page
          .map(i => left_pad_numeric_string(i.to_string(), 8))
          .unwrap_or("00000000") +
          "|" +
          source_ref.slide
          .map(i => left_pad_numeric_string(i.to_string(), 8))
          .unwrap_or("00000000") +
          "|" +
          source_ref.line_start
          .map(i => left_pad_numeric_string(i.to_string(), 8))
          .unwrap_or("00000000")
      }
  }
}

///|
fn left_pad_numeric_string(value : String, width : Int) -> String {
  let trimmed = value.trim().to_owned()
  let negative = trimmed.has_prefix("-")
  let digits = if negative { trimmed[1:].to_owned() } else { trimmed }
  let mut out = digits
  while out.length() < width {
    out = "0" + out
  }
  if negative {
    "-" + out
  } else {
    out
  }
}

///|
fn block_kind_rank(kind : @core.BlockKind) -> String {
  match kind {
    @core.BlockKind::Heading => "00"
    @core.BlockKind::Paragraph => "01"
    @core.BlockKind::List => "02"
    @core.BlockKind::Table => "03"
    @core.BlockKind::Image => "04"
    @core.BlockKind::Code => "05"
    @core.BlockKind::BlockQuote => "06"
    @core.BlockKind::Raw => "07"
    _ => "99"
  }
}

///|
fn block_is_header_footer_candidate(block : @core.CoreBlock) -> Bool {
  if block.attrs.get("header_footer_candidate") == Some("true") {
    return true
  }
  block.signals.any(fn(signal) {
    signal.signal_type == @core.SignalType::HeaderFooterCandidate
  })
}

///|
fn block_has_explicit_reading_order_hint(block : @core.CoreBlock) -> Bool {
  let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
  source_ref.extra.get("reading_order_key") is Some(_) ||
  source_ref.extra.get("reading_order_index") is Some(_)
}

///|
fn pdf_merge_group_key(source_ref : @core.SourceRef) -> String? {
  match source_ref.extra.get("pdf_merge_group") {
    Some(value) if value.trim() != "" => Some(value)
    _ => source_ref.extra.get("pdf_text_block_index")
  }
}

///|
fn merged_text_line_count(
  before : Array[@core.CoreBlock],
  after : Array[@core.CoreBlock],
) -> Int {
  let before_count = paragraph_leaf_count(before)
  let after_count = paragraph_leaf_count(after)
  if before_count > after_count {
    before_count - after_count
  } else {
    0
  }
}

///|
fn paragraph_leaf_count(blocks : Array[@core.CoreBlock]) -> Int {
  let mut total = 0
  for block in blocks {
    if block.kind == @core.BlockKind::Paragraph && block.children.length() == 0 {
      total += 1
    }
    total += paragraph_leaf_count(block.children)
  }
  total
}

///|
fn reading_order_hint_block_count(blocks : Array[@core.CoreBlock]) -> Int {
  let mut total = 0
  for block in blocks {
    let source_ref = block.source_ref.unwrap_or(@core.empty_source_ref())
    if source_ref.extra.get("reading_order_key") is Some(_) ||
      source_ref.extra.get("reading_order_index") is Some(_) {
      total += 1
    }
    total += reading_order_hint_block_count(block.children)
  }
  total
}

///|
fn merge_text_line_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) => {
      let next = @core.document_with_blocks(
        document,
        merge_text_line_blocks(document.blocks),
      )
      next.diagnostics.metrics.set(
        "merged_text_line_count",
        merged_text_line_count(document.blocks, next.blocks).to_string(),
      )
      @core.IRInput::Document(next)
    }
    @core.IRInput::BlockStream(blocks) => {
      let next_blocks = merge_text_line_blocks(blocks)
      context.diagnostics.val.metrics.set(
        "merged_text_line_count",
        merged_text_line_count(blocks, next_blocks).to_string(),
      )
      @core.IRInput::BlockStream(next_blocks)
    }
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}

///|
fn resolve_reading_order_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) => {
      let next = @core.document_with_blocks(
        document,
        resolve_reading_order_blocks(document.blocks),
      )
      next.diagnostics.metrics.set(
        "resolved_reading_order_block_count",
        reading_order_hint_block_count(next.blocks).to_string(),
      )
      @core.IRInput::Document(next)
    }
    @core.IRInput::BlockStream(blocks) => {
      let next_blocks = resolve_reading_order_blocks(blocks)
      context.diagnostics.val.metrics.set(
        "resolved_reading_order_block_count",
        reading_order_hint_block_count(next_blocks).to_string(),
      )
      @core.IRInput::BlockStream(next_blocks)
    }
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}

///|
fn remove_header_footer_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  let debug = @product.debug_mode(context.mode)
  let cleanup_enabled = @product.pdf_cleanup_enabled(context.options)
  match input {
    @core.IRInput::Document(document) => {
      let removal = remove_header_footer_blocks(
        document.blocks,
        cleanup_enabled,
        debug,
      )
      let next = @core.document_with_blocks(document, removal.0)
      next.diagnostics.metrics.set(
        "removed_header_footer_count",
        removal.1.to_string(),
      )
      @core.IRInput::Document(sync_document_to_context(context, next))
    }
    @core.IRInput::BlockStream(blocks) => {
      let removal = remove_header_footer_blocks(blocks, cleanup_enabled, debug)
      context.diagnostics.val.metrics.set(
        "removed_header_footer_count",
        removal.1.to_string(),
      )
      @core.IRInput::BlockStream(removal.0)
    }
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}
