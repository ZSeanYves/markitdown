///|
pub fn rst_parser() -> @parser.Parser {
  @parser.make_parser(
    "rst_parser",
    @parser.ParserMode::DomAstModel,
    @fshared.text_markup_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      @fshared.parse_text_markup_result(source, context, rst_hooks())
    },
  )
}

///|
fn rst_hooks() -> @fshared.TextMarkupHooks {
  @fshared.make_text_markup_hooks(
    "rst_parser",
    "rst",
    @dmark.TextMarkupFormat::Rst,
    fn(text : String) { @dmark.parse_rst_document(text) },
    rst_semantic_quote_text,
    rst_semantic_block,
    rst_semantic_raw_block,
  )
}

///|
fn rst_semantic_quote_text(
  block : @dmark.TextMarkupBlock,
  _format_name : String,
) -> String {
  match block.meta.get("quote_label") {
    Some(label) => {
      let display = text_markup_display_label(rst_strip_directive_label(label))
      if display == "" {
        block.text
      } else if block.text.trim() == "" {
        display
      } else {
        display + "\n" + block.text
      }
    }
    None => block.text
  }
}

///|
fn rst_semantic_raw_block(
  block : @dmark.TextMarkupBlock,
  source_ref : @core.SourceRef,
  _format_name : String,
) -> @core.CoreBlock? {
  match block.meta.get("include_target") {
    Some(target) => {
      let text = if block.text.has_prefix("include: ") {
        "Include: " + block.text["include: ".length():].to_owned()
      } else {
        "Include: " + target
      }
      return Some(
        @core.block_with_attr(
          @fshared.text_markup_block_with_inlines(
            @core.make_block(@core.BlockKind::Paragraph, text, source_ref~),
            text,
            @dmark.TextMarkupFormat::Rst,
          ),
          "literal",
          "true",
        ),
      )
    }
    None => ()
  }
  match block.meta.get("directive_kind") {
    Some(kind) => {
      let display = text_markup_display_label(kind)
      let text = if block.text.trim() == "" || block.text.trim() == kind.trim() {
        "Directive: " + display
      } else {
        "Directive: " + display + "\n" + block.text
      }
      return Some(
        @core.block_with_attr(
          @fshared.text_markup_block_with_inlines(
            @core.make_block(@core.BlockKind::Paragraph, text, source_ref~),
            text,
            @dmark.TextMarkupFormat::Rst,
          ),
          "literal",
          "true",
        ),
      )
    }
    None => None
  }
}

///|
fn rst_semantic_block(
  block : @dmark.TextMarkupBlock,
  source_ref : @core.SourceRef,
  _format_name : String,
) -> @core.CoreBlock? {
  match block.meta.get("semantic_kind") {
    Some("include") => {
      let target = block.meta.get("include_target").unwrap_or(block.text)
      let text = if block.text.has_prefix("include: ") {
        "Include: " + block.text["include: ".length():].to_owned()
      } else {
        "Include: " + target
      }
      let paragraph = @core.make_block(
        @core.BlockKind::Paragraph,
        text,
        source_ref~,
      )
      paragraph.attrs.set("literal", "true")
      paragraph.attrs.set("semantic_label", "Include")
      paragraph.attrs.set("semantic_family", "rst")
      paragraph.attrs.set("semantic_display", "include")
      Some(
        @fshared.text_markup_block_with_inlines(
          paragraph,
          text,
          @dmark.TextMarkupFormat::Rst,
        ),
      )
    }
    Some("directive") => {
      let kind = block.meta.get("directive_kind").unwrap_or("directive")
      let display = text_markup_display_label(kind)
      let text = if block.text.trim() == "" || block.text.trim() == kind.trim() {
        "Directive: " + display
      } else {
        "Directive: " + display + "\n" + block.text
      }
      let paragraph = @core.make_block(
        @core.BlockKind::Paragraph,
        text,
        source_ref~,
      )
      paragraph.attrs.set("literal", "true")
      paragraph.attrs.set("semantic_label", "Directive")
      paragraph.attrs.set("semantic_family", "rst")
      paragraph.attrs.set("semantic_display", display)
      Some(
        @fshared.text_markup_block_with_inlines(
          paragraph,
          text,
          @dmark.TextMarkupFormat::Rst,
        ),
      )
    }
    None => None
    Some(_) => None
  }
}

///|
fn rst_strip_directive_label(label : String) -> String {
  let trimmed = label.trim().to_owned()
  if trimmed.has_prefix(".. ") &&
    trimmed.has_suffix("::") &&
    trimmed.length() > 5 {
    trimmed[3:trimmed.length() - 2].trim().to_owned()
  } else {
    trimmed
  }
}

///|
fn text_markup_display_label(label : String) -> String {
  let trimmed = label.trim().to_owned()
  if trimmed == "" {
    return trimmed
  }
  let split = trimmed.split(" ").to_array().filter(part => part != "")
  if split.length() == 0 {
    return trimmed
  }
  split
  .map(part => {
    if part == "" {
      part
    } else {
      let lower = part.to_lower()
      lower[:1].to_owned().to_upper() + lower[1:].to_owned()
    }
  })
  .join(" ")
}
