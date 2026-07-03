///|
pub fn tex_parser() -> @parser.Parser {
  @parser.make_parser(
    "tex_parser",
    @parser.ParserMode::DomAstModel,
    @fshared.text_markup_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      @fshared.parse_text_markup_result(source, context, tex_hooks())
    },
  )
}

///|
fn tex_hooks() -> @fshared.TextMarkupHooks {
  @fshared.make_text_markup_hooks(
    "tex_parser",
    "tex",
    @dmark.TextMarkupFormat::Tex,
    fn(text : String) { @dmark.parse_tex_document(text) },
    text_markup_semantic_quote_text,
    text_markup_semantic_raw_block,
  )
}

///|
fn text_markup_semantic_quote_text(
  block : @dmark.TextMarkupBlock,
  _format_name : String,
) -> String {
  match block.meta.get("quote_label") {
    Some(label) =>
      if block.text.trim() == "" {
        label
      } else {
        text_markup_display_label(label.replace_all(old="_", new=" ")) +
        "\n" +
        block.text
      }
    None => block.text
  }
}

///|
fn text_markup_semantic_raw_block(
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
            @dmark.TextMarkupFormat::Tex,
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
      let label = text_markup_display_label(kind.replace_all(old="_", new=" "))
      let text = if block.text.trim() == "" || block.text.trim() == kind.trim() {
        "Environment: " + label
      } else {
        "Environment: " + label + "\n" + block.text
      }
      return Some(
        @core.block_with_attr(
          @fshared.text_markup_block_with_inlines(
            @core.make_block(@core.BlockKind::Paragraph, text, source_ref~),
            text,
            @dmark.TextMarkupFormat::Tex,
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
