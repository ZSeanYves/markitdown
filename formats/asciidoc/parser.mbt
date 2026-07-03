///|
pub fn asciidoc_parser() -> @parser.Parser {
  @parser.make_parser(
    "asciidoc_parser",
    @parser.ParserMode::DomAstModel,
    @fshared.text_markup_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      @fshared.parse_text_markup_result(source, context, asciidoc_hooks())
    },
  )
}

///|
fn asciidoc_hooks() -> @fshared.TextMarkupHooks {
  @fshared.make_text_markup_hooks(
    "asciidoc_parser",
    "asciidoc",
    @dmark.TextMarkupFormat::Asciidoc,
    fn(text : String) { @dmark.parse_asciidoc_document(text) },
    asciidoc_semantic_quote_text,
    asciidoc_semantic_raw_block,
  )
}

///|
fn asciidoc_semantic_quote_text(
  block : @dmark.TextMarkupBlock,
  _format_name : String,
) -> String {
  match block.meta.get("quote_label") {
    Some(label) =>
      if block.text.trim() == "" {
        label
      } else {
        label + "\n" + block.text
      }
    None => block.text
  }
}

///|
fn asciidoc_semantic_raw_block(
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
            @dmark.TextMarkupFormat::Asciidoc,
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
      let text = "Directive: " + kind + "\n" + block.text
      return Some(
        @core.block_with_attr(
          @fshared.text_markup_block_with_inlines(
            @core.make_block(@core.BlockKind::Paragraph, text, source_ref~),
            text,
            @dmark.TextMarkupFormat::Asciidoc,
          ),
          "literal",
          "true",
        ),
      )
    }
    None => None
  }
}
