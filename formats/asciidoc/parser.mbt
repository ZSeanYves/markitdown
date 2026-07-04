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
    asciidoc_semantic_block,
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

///|
fn asciidoc_semantic_block(
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
      paragraph.attrs.set("semantic_family", "asciidoc")
      paragraph.attrs.set("semantic_display", "include")
      Some(
        @fshared.text_markup_block_with_inlines(
          paragraph,
          text,
          @dmark.TextMarkupFormat::Asciidoc,
        ),
      )
    }
    Some("quote") => {
      let text = asciidoc_semantic_quote_text(block, "asciidoc")
      let quote = @core.make_block(
        @core.BlockKind::BlockQuote,
        text,
        source_ref~,
      )
      quote.attrs.set("literal", "true")
      quote.attrs.set("semantic_label", "Quote")
      quote.attrs.set("semantic_family", "asciidoc")
      quote.attrs.set(
        "semantic_display",
        block.meta.get("quote_label").unwrap_or("QUOTE"),
      )
      Some(
        @fshared.text_markup_block_with_inlines(
          quote,
          text,
          @dmark.TextMarkupFormat::Asciidoc,
        ),
      )
    }
    Some("admonition") => {
      let text = asciidoc_semantic_quote_text(block, "asciidoc")
      let quote = @core.make_block(
        @core.BlockKind::BlockQuote,
        text,
        source_ref~,
      )
      quote.attrs.set("literal", "true")
      quote.attrs.set("semantic_label", "Admonition")
      quote.attrs.set("semantic_family", "asciidoc")
      quote.attrs.set(
        "semantic_display",
        block.meta.get("quote_label").unwrap_or("NOTE"),
      )
      Some(
        @fshared.text_markup_block_with_inlines(
          quote,
          text,
          @dmark.TextMarkupFormat::Asciidoc,
        ),
      )
    }
    None => None
    Some(_) => None
  }
}
