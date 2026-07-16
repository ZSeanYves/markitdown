///|
pub fn tex_parser() -> @parser.Parser {
  @parser.make_parser(
    "tex_parser",
    DomAstModel,
    @fshared.text_markup_parser_capability(),
    fn(
      source : @input.InputSource,
      context : @parser.ParseContext,
    ) -> Result[@parser.ParseResult, String] {
      @fshared.parse_text_markup_result(
        source,
        context,
        tex_text_markup_hooks(),
      )
    },
  )
}

///|
pub fn tex_text_markup_hooks() -> @fshared.TextMarkupHooks {
  @fshared.make_text_markup_hooks(
    "tex_parser",
    "tex",
    Tex,
    fn(text : String) { @dmark.parse_tex_document(text) },
    text_markup_semantic_quote_text,
    text_markup_semantic_block,
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
            @core.make_block(Paragraph, text, source_ref~),
            text,
            Tex,
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
            @core.make_block(Paragraph, text, source_ref~),
            text,
            Tex,
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
fn text_markup_semantic_block(
  block : @dmark.TextMarkupBlock,
  source_ref : @core.SourceRef,
  _format_name : String,
) -> @core.CoreBlock? {
  match block.meta.get("semantic_kind") {
    Some("image") => {
      let target = block.meta.get("image_target").unwrap_or(block.text)
      let image = @core.make_block(Image, "", source_ref~)
      image.attrs.set("path", target)
      image.attrs.set("src", target)
      image.attrs.set("alt", block.meta.get("image_alt").unwrap_or("image"))
      image.attrs.set("reference_only", "true")
      let lower = target.to_lower()
      if lower.has_prefix("http://") ||
        lower.has_prefix("https://") ||
        lower.has_prefix("data:") {
        image.attrs.set("remote", "true")
      } else if target != "" {
        image.attrs.set(
          "path",
          @fshared.text_markup_asset_output_path("tex", target),
        )
        image.attrs.set("source_path", target)
        image.attrs.set("asset_id", "tex-image-" + block.line_start.to_string())
      }
      Some(image)
    }
    Some("include") => {
      let target = block.meta.get("include_target").unwrap_or(block.text)
      let text = if block.text.has_prefix("include: ") {
        "Include: " + block.text["include: ".length():].to_owned()
      } else {
        "Include: " + target
      }
      let paragraph = @core.make_block(Paragraph, text, source_ref~)
      paragraph.attrs.set("literal", "true")
      paragraph.attrs.set("semantic_label", "Include")
      paragraph.attrs.set("semantic_family", "tex")
      paragraph.attrs.set("semantic_display", "include")
      Some(@fshared.text_markup_block_with_inlines(paragraph, text, Tex))
    }
    Some("environment") => {
      let label = block.meta
        .get("quote_label")
        .unwrap_or(block.meta.get("directive_kind").unwrap_or("environment"))
      let display = text_markup_display_label(
        label.replace_all(old="_", new=" "),
      )
      let body = text_markup_environment_body(block.text, label)
      let text = if body == "" {
        "Environment: " + display
      } else {
        "Environment: " + display + "\n" + body
      }
      let quote = @core.make_block(BlockQuote, text, source_ref~)
      quote.attrs.set("literal", "true")
      quote.attrs.set("semantic_label", "Environment")
      quote.attrs.set("semantic_family", "tex")
      quote.attrs.set("semantic_display", display)
      Some(@fshared.text_markup_block_with_inlines(quote, text, Tex))
    }
    None => None
    Some(_) => None
  }
}

///|
fn text_markup_environment_body(text : String, label : String) -> String {
  let lines = text.split("\n").to_array().map(line => line.to_owned())
  if lines.length() == 0 {
    return ""
  }
  let first = lines[0].trim().to_lower()
  let lowered_label = label.trim().to_lower()
  if first == lowered_label {
    let rest : Array[String] = []
    for i in 1..<lines.length() {
      rest.push(lines[i])
    }
    return rest.join("\n").trim().to_owned()
  }
  text.trim().to_owned()
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
