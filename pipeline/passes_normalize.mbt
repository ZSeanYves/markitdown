///|
pub fn normalize_text_pass() -> IRPass {
  {
    name: "NormalizeTextPass",
    run: fn(
      _context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(normalize_text_input(input))
    },
  }
}

///|
pub fn normalize_whitespace_pass() -> IRPass {
  {
    name: "NormalizeWhitespacePass",
    run: fn(
      _context : PassContext,
      input : @core.IRInput,
    ) -> Result[@core.IRInput, PassError] {
      Ok(normalize_whitespace_input(input))
    },
  }
}

///|
fn normalize_block_text(block : @core.CoreBlock) -> @core.CoreBlock {
  let next = @core.block_with_children(
    { ..block, text: block.text.trim().to_owned() },
    block.children.map(child => normalize_block_text(child)),
  )
  next
}

///|
fn normalize_block_whitespace(block : @core.CoreBlock) -> @core.CoreBlock {
  let next_text = match block.kind {
    @core.BlockKind::Code
    | @core.BlockKind::Raw
    | @core.BlockKind::BlockQuote
    | @core.BlockKind::TableCell => block.text
    _ => collapse_whitespace(block.text)
  }
  let next = @core.block_with_children(
    { ..block, text: next_text },
    block.children.map(child => normalize_block_whitespace(child)),
  )
  next
}

///|
fn normalize_text_input(input : @core.IRInput) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) =>
      @core.IRInput::Document(
        @core.document_with_blocks(
          document,
          document.blocks.map(block => normalize_block_text(block)),
        ),
      )
    @core.IRInput::BlockStream(blocks) =>
      @core.IRInput::BlockStream(
        blocks.map(block => normalize_block_text(block)),
      )
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}

///|
fn normalize_whitespace_input(input : @core.IRInput) -> @core.IRInput {
  match input {
    @core.IRInput::Document(document) =>
      @core.IRInput::Document(
        @core.document_with_blocks(
          document,
          document.blocks.map(block => normalize_block_whitespace(block)),
        ),
      )
    @core.IRInput::BlockStream(blocks) =>
      @core.IRInput::BlockStream(
        blocks.map(block => normalize_block_whitespace(block)),
      )
    @core.IRInput::EventStream(events) => @core.IRInput::EventStream(events)
  }
}

///|
fn collapse_whitespace(text : String) -> String {
  let out : Array[Char] = []
  let mut prev_space = false
  for ch in text.to_array() {
    let is_space = ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r'
    if is_space {
      if !prev_space {
        out.push(' ')
      }
    } else {
      out.push(ch)
    }
    prev_space = is_space
  }
  String::from_array(out).trim().to_owned()
}

///|
