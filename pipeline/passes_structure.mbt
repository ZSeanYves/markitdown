///|
pub fn resolve_heading_pass() -> IRPass {
  {
    name: "ResolveHeadingPass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(resolve_heading_input(context, input))
    },
  }
}

///|
pub fn resolve_list_pass() -> IRPass {
  {
    name: "ResolveListPass",
    run: fn(
      context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(resolve_list_input(context, input))
    },
  }
}

///|
fn resolve_heading_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  blocks.map(block => resolve_heading_block(block))
}

///|
fn resolve_heading_block(block : @core.CoreBlock) -> @core.CoreBlock {
  let next_children = resolve_heading_blocks(block.children)
  let next = @core.block_with_children(block, next_children)
  if next.kind == Heading {
    let level = clamp_heading_level(next.attrs.get("level").unwrap_or("1"))
    next.attrs.set("level", level.to_string())
    return next
  }
  if block_heading_candidate(next) {
    let promoted = @core.make_block(
      Heading,
      next.text.trim().to_owned(),
      source_ref=@core.block_source_ref(next).unwrap_or(
        @core.empty_source_ref(),
      ),
    )
    let promoted = @core.block_with_block_id(promoted, next.block_id)
    let promoted = if next.rich_inlines is Some(_) {
      @core.block_with_rich_inlines(promoted, next.rich_inlines)
    } else {
      promoted
    }
    let promoted = @core.block_with_children(promoted, next_children)
    let promoted = @core.block_with_signals(promoted, next.signals)
    let promoted = copy_block_attrs(next, promoted)
    promoted.attrs.set(
      "level",
      clamp_heading_level(heading_candidate_level(next).unwrap_or("1")).to_string(),
    )
    promoted
  } else {
    next
  }
}

///|
fn resolve_list_blocks(
  blocks : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  let resolved : Array[@core.CoreBlock] = []
  let mut i = 0
  while i < blocks.length() {
    let block = resolve_list_block(blocks[i])
    if list_item_candidate(block) {
      let item_group : Array[@core.CoreBlock] = [block]
      let mut j = i + 1
      while j < blocks.length() {
        let next = resolve_list_block(blocks[j])
        if !list_item_candidate(next) {
          break
        }
        item_group.push(next)
        j += 1
      }
      resolved.append(list_item_group_to_blocks(item_group)[:])
      i = j
    } else {
      resolved.push(block)
      i += 1
    }
  }
  resolved
}

///|
fn resolve_list_block(block : @core.CoreBlock) -> @core.CoreBlock {
  if block.kind == List {
    return @core.block_with_children(
      block,
      resolve_list_children_in_container(block.children),
    )
  }
  @core.block_with_children(block, resolve_list_blocks(block.children))
}

///|
fn resolve_list_children_in_container(
  children : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  children.map(child => {
    if child.kind == ListItem {
      @core.block_with_children(child, resolve_list_blocks(child.children))
    } else if child.kind == List {
      @core.block_with_children(
        child,
        resolve_list_children_in_container(child.children),
      )
    } else {
      @core.block_with_children(child, resolve_list_blocks(child.children))
    }
  })
}

///|
fn list_item_group_to_blocks(
  items : Array[@core.CoreBlock],
) -> Array[@core.CoreBlock] {
  if items.length() == 0 {
    return []
  }
  if items.length() == 1 &&
    items[0].kind == ListItem &&
    items[0].children.any(child => child.kind == List) {
    return [items[0]]
  }
  let root : Array[@core.CoreBlock] = []
  let stack : Array[(Int, @core.CoreBlock, @core.CoreBlock)] = []
  for item in items {
    let level = list_item_level(item)
    let ordered = list_item_ordered(item)
    while stack.length() > 0 && level < stack[stack.length() - 1].0 {
      ignore(stack.pop())
    }
    if stack.length() == 0 {
      let list = make_list_container_for_item(item, ordered)
      list.children.push(item)
      root.push(list)
      stack.push((level, list, item))
      continue
    }
    let current = stack[stack.length() - 1]
    if level > current.0 {
      let nested = make_list_container_for_item(item, ordered)
      current.2.children.push(nested)
      nested.children.push(item)
      stack.push((level, nested, item))
      continue
    }
    let current_list = current.1
    let current_ordered = current_list.attrs.get("ordered").unwrap_or("false") ==
      "true"
    if current_ordered != ordered {
      ignore(stack.pop())
      let list = make_list_container_for_item(item, ordered)
      if stack.length() == 0 {
        root.push(list)
      } else {
        stack[stack.length() - 1].2.children.push(list)
      }
      list.children.push(item)
      stack.push((level, list, item))
      continue
    }
    current_list.children.push(item)
    ignore(stack.pop())
    stack.push((level, current_list, item))
  }
  root
}

///|
fn make_list_container_for_item(
  item : @core.CoreBlock,
  ordered : Bool,
) -> @core.CoreBlock {
  let list = @core.make_block(
    List,
    "",
    source_ref=@core.block_source_ref(item).unwrap_or(@core.empty_source_ref()),
  )
  list.attrs.set("ordered", bool_string(ordered))
  list
}

///|
fn block_heading_candidate(block : @core.CoreBlock) -> Bool {
  block.kind == Paragraph && heading_candidate_level(block) is Some(_)
}

///|
fn heading_candidate_level(block : @core.CoreBlock) -> String? {
  match block.attrs.get("heading_level") {
    Some(level) => Some(level)
    None =>
      match block.attrs.get("level") {
        Some(level) if block.attrs.get("heading_candidate") == Some("true") =>
          Some(level)
        _ => heading_signal_level(block.signals)
      }
  }
}

///|
fn heading_signal_level(signals : Array[@core.CoreSignal]) -> String? {
  for signal in signals {
    if signal.signal_type != HeadingCandidate {
      continue
    }
    match signal.payload.get("level") {
      Some(String(level)) => return Some(level)
      Some(Number(level)) => return Some(level)
      _ => ()
    }
  }
  None
}

///|
fn list_item_candidate(block : @core.CoreBlock) -> Bool {
  if block.kind == ListItem {
    return true
  }
  if block.kind != Paragraph {
    return false
  }
  if block.attrs.get("list_item_candidate") == Some("true") {
    return true
  }
  block.signals.any(fn(signal) { signal.signal_type == ListCandidate })
}

///|
fn list_item_level(block : @core.CoreBlock) -> Int {
  let raw = block.attrs.get("level").unwrap_or("0")
  let parsed = @string.parse_int(raw.trim()) catch { _ => 0 }
  if parsed < 0 {
    0
  } else {
    parsed
  }
}

///|
fn list_item_ordered(block : @core.CoreBlock) -> Bool {
  block.attrs.get("ordered").unwrap_or("false") == "true"
}

///|
fn bool_string(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn copy_block_attrs(
  from : @core.CoreBlock,
  to : @core.CoreBlock,
) -> @core.CoreBlock {
  let next = { ..to, style: from.style }
  for entry in from.attrs.to_array() {
    next.attrs.set(entry.0, entry.1)
  }
  next
}

///|
fn heading_block_count(blocks : Array[@core.CoreBlock]) -> Int {
  let mut total = 0
  for block in blocks {
    if block.kind == Heading {
      total += 1
    }
    total += heading_block_count(block.children)
  }
  total
}

///|
fn list_block_count(blocks : Array[@core.CoreBlock]) -> Int {
  let mut total = 0
  for block in blocks {
    if block.kind == List {
      total += 1
    }
    total += list_block_count(block.children)
  }
  total
}

///|
fn clamp_heading_level(raw : String) -> Int {
  let parsed = @string.parse_int(raw.trim()) catch { _ => 1 }
  if parsed < 1 {
    1
  } else if parsed > 6 {
    6
  } else {
    parsed
  }
}

///|
fn resolve_heading_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    Document(document) => {
      let next = @core.document_with_blocks(
        document,
        resolve_heading_blocks(document.blocks),
      )
      next.diagnostics.metrics.set(
        "resolved_heading_count",
        heading_block_count(next.blocks).to_string(),
      )
      Document(next)
    }
    BlockStream(blocks) => {
      let next_blocks = resolve_heading_blocks(blocks)
      context.diagnostics.val.metrics.set(
        "resolved_heading_count",
        heading_block_count(next_blocks).to_string(),
      )
      BlockStream(next_blocks)
    }
    EventStream(events) => EventStream(events)
  }
}

///|
fn resolve_list_input(
  context : PassContext,
  input : @core.IRInput,
) -> @core.IRInput {
  match input {
    Document(document) => {
      let next = @core.document_with_blocks(
        document,
        resolve_list_blocks(document.blocks),
      )
      next.diagnostics.metrics.set(
        "resolved_list_count",
        list_block_count(next.blocks).to_string(),
      )
      Document(next)
    }
    BlockStream(blocks) => {
      let next_blocks = resolve_list_blocks(blocks)
      context.diagnostics.val.metrics.set(
        "resolved_list_count",
        list_block_count(next_blocks).to_string(),
      )
      BlockStream(next_blocks)
    }
    EventStream(events) => EventStream(events)
  }
}
