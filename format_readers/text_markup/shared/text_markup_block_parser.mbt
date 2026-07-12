///|
fn text_markup_semantic_counts_as_quote(block : TextMarkupBlock) -> Bool {
  match block.meta.get("semantic_kind") {
    Some("quote") => true
    Some("admonition") => true
    Some("environment") => true
    _ =>
      block.meta.contains("quote_kind") ||
      block.meta
      .get("directive_kind")
      .map(kind => {
        let lowered = kind.to_lower()
        lowered == "note" ||
        lowered == "warning" ||
        lowered == "tip" ||
        lowered == "important" ||
        lowered == "caution" ||
        lowered == "attention" ||
        lowered == "danger" ||
        lowered == "error" ||
        lowered == "hint" ||
        lowered == "admonition"
      })
      .unwrap_or(false)
  }
}

///|
fn parse_markup_document(
  text : String,
  format : TextMarkupFormat,
) -> TextMarkupDocument {
  let normalized = normalize_markup_text(text)
  let lines : Array[String] = if normalized.length() >= 1_048_576 {
    Array::new(capacity=normalized.length() / 24)
  } else {
    []
  }
  for line in normalized.split("\n") {
    lines.push(line.to_owned())
  }
  let context = make_markup_parse_context(lines, format)
  let blocks : Array[TextMarkupBlock] = Array::new(capacity=lines.length() / 2)
  let block_cache : Map[String, Array[CachedMarkupBlock]] = Map([])
  let cache_enabled = lines.length() >= 4096
  let mut i = 0
  while i < lines.length() {
    if cache_enabled {
      match find_cached_markup_block(block_cache, lines, i) {
        Some((block, next)) => {
          blocks.push(block)
          i = next
          continue
        }
        None => ()
      }
    }
    match classify_markup_line(context, i) {
      MarkupLineClass::Blank(next) => i = next
      MarkupLineClass::Block(block, next) => {
        blocks.push(block)
        if cache_enabled &&
          !(format == TextMarkupFormat::Tex &&
          block.kind == TextMarkupBlockKind::ListItem) {
          cache_markup_block(block_cache, lines, i, next, block)
        }
        i = next
      }
      MarkupLineClass::ParagraphLine(line_text) => {
        let para_lines : Array[String] = [line_text]
        let start = i + 1
        i += 1
        while i < lines.length() {
          match classify_markup_line(context, i) {
            MarkupLineClass::ParagraphLine(next_line) => {
              para_lines.push(next_line)
              i += 1
            }
            _ => break
          }
        }
        let block = {
          kind: TextMarkupBlockKind::Paragraph,
          text: para_lines.join(" "),
          level: 0,
          ordered: false,
          line_start: start,
          line_end: i,
          meta: Map([]),
        }
        blocks.push(block)
        if cache_enabled {
          cache_markup_block(block_cache, lines, start - 1, i, block)
        }
      }
    }
  }
  { format, blocks }
}

///|
priv struct CachedMarkupBlock {
  source_lines : Array[String]
  block : TextMarkupBlock
  origin_index : Int
}

///|
fn cache_markup_block(
  cache : Map[String, Array[CachedMarkupBlock]],
  lines : Array[String],
  start : Int,
  next : Int,
  block : TextMarkupBlock,
) -> Unit {
  if next <= start || lines[start] == "" {
    return
  }
  let source_lines = lines[start:next].to_owned()
  let entries = cache.get(lines[start]).unwrap_or([])
  entries.push({ source_lines, block, origin_index: start })
  cache.set(lines[start], entries)
}

///|
fn find_cached_markup_block(
  cache : Map[String, Array[CachedMarkupBlock]],
  lines : Array[String],
  start : Int,
) -> (TextMarkupBlock, Int)? {
  let entries = match cache.get(lines[start]) {
    Some(value) => value
    None => return None
  }
  for entry in entries {
    if start + entry.source_lines.length() > lines.length() {
      continue
    }
    if entry.source_lines.length() == 1 {
      let delta = start - entry.origin_index
      return Some(
        (
          {
            ..entry.block,
            line_start: entry.block.line_start + delta,
            line_end: entry.block.line_end + delta,
          },
          start + 1,
        ),
      )
    }
    let mut matches = true
    for offset in 0..<entry.source_lines.length() {
      if lines[start + offset] != entry.source_lines[offset] {
        matches = false
        break
      }
    }
    if matches {
      let delta = start - entry.origin_index
      return Some(
        (
          {
            ..entry.block,
            line_start: entry.block.line_start + delta,
            line_end: entry.block.line_end + delta,
          },
          start + entry.source_lines.length(),
        ),
      )
    }
  }
  None
}

///|
priv struct MarkupParseContext {
  lines : Array[String]
  format : TextMarkupFormat
  trimmed_semantic_lines : Array[String]?
  tex_item_ordered_before_line : Array[Bool]
}

///|
fn make_markup_parse_context(
  lines : Array[String],
  format : TextMarkupFormat,
) -> MarkupParseContext {
  let semantic_lines = if format == TextMarkupFormat::Tex {
    build_markup_semantic_lines(lines, format)
  } else {
    lines
  }
  let trimmed_semantic_lines = if format == TextMarkupFormat::Tex {
    Some(build_trimmed_markup_lines(semantic_lines))
  } else {
    None
  }
  let tex_item_ordered_before_line = build_tex_item_ordered_before_line(
    trimmed_semantic_lines.unwrap_or([]),
    format,
  )
  { lines, format, trimmed_semantic_lines, tex_item_ordered_before_line }
}

///|
fn build_markup_semantic_lines(
  lines : Array[String],
  format : TextMarkupFormat,
) -> Array[String] {
  let semantic_lines : Array[String] = Array::new(capacity=lines.length())
  let cache : Map[String, String] = Map([])
  for line in lines {
    match cache.get(line) {
      Some(value) => semantic_lines.push(value)
      None => {
        let value = markup_semantic_line(line, format)
        cache.set(line, value)
        semantic_lines.push(value)
      }
    }
  }
  semantic_lines
}

///|
fn build_trimmed_markup_lines(lines : Array[String]) -> Array[String] {
  let trimmed : Array[String] = Array::new(capacity=lines.length())
  let cache : Map[String, String] = Map([])
  for line in lines {
    match cache.get(line) {
      Some(value) => trimmed.push(value)
      None => {
        let value = line.trim().to_owned()
        cache.set(line, value)
        trimmed.push(value)
      }
    }
  }
  trimmed
}

///|
fn markup_trimmed_line(context : MarkupParseContext, index : Int) -> String {
  match context.trimmed_semantic_lines {
    Some(lines) => lines[index]
    None => context.lines[index].trim().to_owned()
  }
}

///|
fn build_tex_item_ordered_before_line(
  semantic_lines : Array[String],
  format : TextMarkupFormat,
) -> Array[Bool] {
  let states : Array[Bool] = if format == TextMarkupFormat::Tex {
    Array::new(capacity=semantic_lines.length())
  } else {
    []
  }
  if format != TextMarkupFormat::Tex {
    return states
  }
  let stack : Array[Bool] = []
  for semantic_line in semantic_lines {
    states.push(tex_list_stack_top_is_enumerate(stack))
    match semantic_line {
      "\\begin{itemize}" => stack.push(false)
      "\\begin{enumerate}" => stack.push(true)
      "\\end{itemize}" => if stack.length() > 0 { ignore(stack.pop()) }
      "\\end{enumerate}" => if stack.length() > 0 { ignore(stack.pop()) }
      _ => ()
    }
  }
  states
}

///|
fn tex_list_stack_top_is_enumerate(stack : Array[Bool]) -> Bool {
  if stack.length() == 0 {
    return false
  }
  stack[stack.length() - 1]
}

///|
priv enum MarkupLineClass {
  Blank(Int)
  ParagraphLine(String)
  Block(TextMarkupBlock, Int)
}

///|
fn classify_markup_line(
  context : MarkupParseContext,
  index : Int,
) -> MarkupLineClass {
  let trimmed = markup_trimmed_line(context, index)
  if trimmed == "" {
    return MarkupLineClass::Blank(index + 1)
  }
  if !text_markup_line_can_start_block(context, index, trimmed) {
    return MarkupLineClass::ParagraphLine(trimmed)
  }
  match detect_heading(context.lines, index, context.format) {
    Some((block, next)) => return MarkupLineClass::Block(block, next)
    None => ()
  }
  match detect_block_quote(context.lines, index, context.format) {
    Some((block, next)) => return MarkupLineClass::Block(block, next)
    None => ()
  }
  match detect_code_block(context.lines, index, context.format) {
    Some((block, next)) => return MarkupLineClass::Block(block, next)
    None => ()
  }
  match detect_structured_semantic_block(context.lines, index, context.format) {
    Some((block, next)) => return MarkupLineClass::Block(block, next)
    None => ()
  }
  match detect_list_item(context, index) {
    Some((block, next)) => return MarkupLineClass::Block(block, next)
    None => ()
  }
  match detect_table_block(context.lines, index, context.format) {
    Some((block, next)) => return MarkupLineClass::Block(block, next)
    None => ()
  }
  match detect_raw_boundary(context.lines, index, context.format) {
    Some((block, next)) => return MarkupLineClass::Block(block, next)
    None => ()
  }
  MarkupLineClass::ParagraphLine(trimmed)
}

///|
fn text_markup_line_can_start_block(
  context : MarkupParseContext,
  index : Int,
  trimmed : String,
) -> Bool {
  if trimmed == "" {
    return false
  }
  let first = trimmed[0]
  match context.format {
    TextMarkupFormat::Tex =>
      first == '\\' ||
      first == '%' ||
      first == '[' ||
      first == '{' ||
      first == ']' ||
      first == '}'
    TextMarkupFormat::Asciidoc =>
      first == '=' ||
      first == '[' ||
      first == ':' ||
      first == '|' ||
      first == '.' ||
      first == '-' ||
      first == '*' ||
      first == '+' ||
      first == '`' ||
      first == '/' ||
      first == 'N' ||
      first == 'T' ||
      first == 'W' ||
      first == 'I' ||
      first == 'C' ||
      first == 'i'
    TextMarkupFormat::Rst =>
      rst_line_may_start_block(context.lines, index, trimmed)
  }
}

///|
fn rst_line_may_start_block(
  lines : Array[String],
  index : Int,
  trimmed : String,
) -> Bool {
  let first = trimmed[0]
  if first == '.' ||
    first == ':' ||
    first == '-' ||
    first == '+' ||
    first == '*' ||
    first == '=' ||
    first == '|' ||
    first == '_' ||
    (first >= '0' && first <= '9') ||
    trimmed.has_suffix("::") ||
    lines[index].has_prefix(" ") ||
    lines[index].has_prefix("\t") {
    return true
  }
  if index + 1 >= lines.length() {
    return false
  }
  let next = lines[index + 1]
  let next_trimmed = next.trim().to_owned()
  (next.has_prefix("  ") || next.has_prefix("\t")) ||
  (next_trimmed != "" && rst_underline_heading(next_trimmed))
}

///|
fn detect_structured_semantic_block(
  lines : Array[String],
  index : Int,
  format : TextMarkupFormat,
) -> (TextMarkupBlock, Int)? {
  match format {
    TextMarkupFormat::Rst =>
      match detect_rst_note_definition(lines, index) {
        Some(block) => Some(block)
        None =>
          match detect_rst_field_list(lines, index) {
            Some(block) => Some(block)
            None =>
              match detect_rst_definition_list(lines, index) {
                Some(block) => Some(block)
                None =>
                  match detect_rst_include_directive(lines, index) {
                    Some(block) => Some(block)
                    None => detect_rst_directive_block(lines, index)
                  }
              }
          }
      }
    TextMarkupFormat::Asciidoc =>
      match detect_asciidoc_attribute_table(lines, index) {
        Some(block) => Some(block)
        None =>
          match detect_asciidoc_image_block(lines, index) {
            Some(block) => Some(block)
            None =>
              match detect_asciidoc_include_directive(lines, index) {
                Some(block) => Some(block)
                None =>
                  match detect_asciidoc_block_admonition(lines, index) {
                    Some(block) => Some(block)
                    None =>
                      match detect_asciidoc_source_block(lines, index) {
                        Some(block) => Some(block)
                        None => detect_asciidoc_quote_block(lines, index)
                      }
                  }
              }
          }
      }
    TextMarkupFormat::Tex =>
      match detect_tex_metadata_table(lines, index) {
        Some(block) => Some(block)
        None =>
          match detect_tex_include_directive(lines, index) {
            Some(block) => Some(block)
            None => detect_tex_environment_block(lines, index)
          }
      }
  }
}

///|
fn detect_asciidoc_image_block(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  if !trimmed.has_prefix("image::") || !trimmed.has_suffix("]") {
    return None
  }
  let open = match trimmed.find("[") {
    Some(value) => value
    None => return None
  }
  let target = trimmed["image::".length():open].trim().to_owned()
  if target == "" || target.contains("{") || target.contains("}") {
    return None
  }
  let options = trimmed[open + 1:trimmed.length() - 1].to_owned()
  let alt = match options.find(",") {
    Some(value) => options[:value].trim().to_owned()
    None => options.trim().to_owned()
  }
  Some(
    (
      {
        kind: TextMarkupBlockKind::Semantic,
        text: if alt == "" {
          target
        } else {
          alt
        },
        level: 0,
        ordered: false,
        line_start: index + 1,
        line_end: index + 1,
        meta: Map([
          ("semantic_kind", "image"),
          ("image_target", target),
          ("image_alt", if alt == "" { "image" } else { alt }),
        ]),
      },
      index + 1,
    ),
  )
}

///|
fn markup_semantic_line(line : String, format : TextMarkupFormat) -> String {
  match format {
    TextMarkupFormat::Tex => tex_strip_trailing_comment(line)
    _ => line
  }
}

///|
fn detect_heading(
  lines : Array[String],
  index : Int,
  format : TextMarkupFormat,
) -> (TextMarkupBlock, Int)? {
  let line = lines[index].trim().to_owned()
  if line == "" {
    return None
  }
  match format {
    TextMarkupFormat::Asciidoc =>
      if line.has_prefix("=") {
        let mut level = 0
        for ch in line {
          if ch == '=' {
            level += 1
          } else {
            break
          }
        }
        if level >= line.length() {
          return None
        }
        let body = line[level:].trim().to_owned()
        if body == "" {
          return None
        }
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Heading,
              text: body,
              level,
              ordered: false,
              line_start: index + 1,
              line_end: index + 1,
              meta: Map([]),
            },
            index + 1,
          ),
        )
      }
    TextMarkupFormat::Tex =>
      match tex_heading_level(line) {
        Some((level, text)) =>
          return Some(
            (
              {
                kind: TextMarkupBlockKind::Heading,
                text,
                level,
                ordered: false,
                line_start: index + 1,
                line_end: index + 1,
                meta: Map([]),
              },
              index + 1,
            ),
          )
        None => ()
      }
    TextMarkupFormat::Rst => {
      if index + 2 < lines.length() {
        let title = lines[index + 1].trim().to_owned()
        let underline = lines[index + 2].trim().to_owned()
        if rst_underline_heading(line) && title != "" && underline == line {
          return Some(
            (
              {
                kind: TextMarkupBlockKind::Heading,
                text: title,
                level: rst_heading_level(line),
                ordered: false,
                line_start: index + 1,
                line_end: index + 3,
                meta: Map([]),
              },
              index + 3,
            ),
          )
        }
      }
      if index + 1 < lines.length() {
        let underline = lines[index + 1].trim().to_owned()
        if rst_underline_heading(underline) {
          return Some(
            (
              {
                kind: TextMarkupBlockKind::Heading,
                text: line,
                level: rst_heading_level(underline),
                ordered: false,
                line_start: index + 1,
                line_end: index + 2,
                meta: Map([]),
              },
              index + 2,
            ),
          )
        }
      }
    }
  }
  None
}

///|
fn detect_code_block(
  lines : Array[String],
  index : Int,
  format : TextMarkupFormat,
) -> (TextMarkupBlock, Int)? {
  let line = lines[index]
  let trimmed = line.trim().to_owned()
  match format {
    TextMarkupFormat::Asciidoc =>
      if trimmed == "----" || trimmed == "```" {
        let start = index + 1
        let body : Array[String] = []
        let mut i = index + 1
        while i < lines.length() && lines[i].trim() != trimmed {
          body.push(lines[i])
          i += 1
        }
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Code,
              text: body.join("\n"),
              level: 0,
              ordered: false,
              line_start: start,
              line_end: if i < lines.length() {
                i + 1
              } else {
                i
              },
              meta: Map([]),
            },
            if i < lines.length() {
              i + 1
            } else {
              i
            },
          ),
        )
      }
    TextMarkupFormat::Rst =>
      if trimmed == "::" || trimmed.has_suffix("::") {
        if trimmed.has_prefix(".. ") {
          return None
        }
        let start = index + 2
        let body : Array[String] = []
        let mut i = index + 1
        while i < lines.length() &&
              (
                lines[i].has_prefix("  ") ||
                lines[i].has_prefix("    ") ||
                lines[i].trim() == ""
              ) {
          if lines[i].trim() != "" {
            body.push(lines[i].trim().to_owned())
          }
          i += 1
        }
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Code,
              text: body.join("\n"),
              level: 0,
              ordered: false,
              line_start: start,
              line_end: i,
              meta: Map([]),
            },
            i,
          ),
        )
      }
    TextMarkupFormat::Tex =>
      if trimmed == "\\begin{verbatim}" || trimmed == "\\begin{lstlisting}" {
        let end_marker = if trimmed == "\\begin{verbatim}" {
          "\\end{verbatim}"
        } else {
          "\\end{lstlisting}"
        }
        let start = index + 2
        let body : Array[String] = []
        let mut i = index + 1
        while i < lines.length() && lines[i].trim() != end_marker {
          body.push(lines[i])
          i += 1
        }
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Code,
              text: body.join("\n"),
              level: 0,
              ordered: false,
              line_start: start,
              line_end: if i < lines.length() {
                i + 1
              } else {
                i
              },
              meta: Map([]),
            },
            if i < lines.length() {
              i + 1
            } else {
              i
            },
          ),
        )
      }
  }
  None
}

///|
fn detect_list_item(
  context : MarkupParseContext,
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = markup_trimmed_line(context, index)
  match context.format {
    TextMarkupFormat::Tex =>
      match detect_tex_item(context, index) {
        Some(block) => return Some(block)
        None => ()
      }
    TextMarkupFormat::Asciidoc =>
      if trimmed.has_prefix(". ") {
        return Some(
          (
            {
              kind: TextMarkupBlockKind::ListItem,
              text: trimmed[2:].trim().to_owned(),
              level: 0,
              ordered: true,
              line_start: index + 1,
              line_end: index + 1,
              meta: Map([("list_kind", "asciidoc_ordered_marker")]),
            },
            index + 1,
          ),
        )
      }
    _ => ()
  }
  if trimmed.has_prefix("- ") ||
    trimmed.has_prefix("* ") ||
    trimmed.has_prefix("+ ") {
    return Some(
      (
        {
          kind: TextMarkupBlockKind::ListItem,
          text: trimmed[2:].trim().to_owned(),
          level: 0,
          ordered: false,
          line_start: index + 1,
          line_end: index + 1,
          meta: Map([]),
        },
        index + 1,
      ),
    )
  }
  match ordered_list_tail(trimmed) {
    Some(tail) =>
      return Some(
        (
          {
            kind: TextMarkupBlockKind::ListItem,
            text: tail,
            level: 0,
            ordered: true,
            line_start: index + 1,
            line_end: index + 1,
            meta: Map([]),
          },
          index + 1,
        ),
      )
    None => ()
  }
  None
}

///|
fn detect_table_block(
  lines : Array[String],
  index : Int,
  format : TextMarkupFormat,
) -> (TextMarkupBlock, Int)? {
  match format {
    TextMarkupFormat::Rst =>
      if rst_table_border(lines[index].trim().to_owned()) {
        let body : Array[String] = []
        let mut i = index
        while i < lines.length() && lines[i].trim() != "" {
          body.push(lines[i])
          i += 1
        }
        if body.length() >= 2 {
          return Some(
            (
              {
                kind: TextMarkupBlockKind::Table,
                text: body.join("\n"),
                level: 0,
                ordered: false,
                line_start: index + 1,
                line_end: i,
                meta: Map([]),
              },
              i,
            ),
          )
        }
      }
    TextMarkupFormat::Asciidoc =>
      if lines[index].trim().to_owned() == "|===" {
        let body : Array[String] = []
        let mut i = index + 1
        while i < lines.length() && lines[i].trim().to_owned() != "|===" {
          body.push(lines[i])
          i += 1
        }
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Table,
              text: body.join("\n"),
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: if i < lines.length() {
                i + 1
              } else {
                i
              },
              meta: Map([]),
            },
            if i < lines.length() {
              i + 1
            } else {
              i
            },
          ),
        )
      }
    TextMarkupFormat::Tex =>
      if lines[index].trim().to_owned() == "\\begin{tabular}" ||
        lines[index].trim().to_owned().has_prefix("\\begin{tabular}{") {
        let body : Array[String] = []
        let mut i = index + 1
        while i < lines.length() &&
              lines[i].trim().to_owned() != "\\end{tabular}" {
          body.push(lines[i])
          i += 1
        }
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Table,
              text: body.join("\n"),
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: if i < lines.length() {
                i + 1
              } else {
                i
              },
              meta: Map([]),
            },
            if i < lines.length() {
              i + 1
            } else {
              i
            },
          ),
        )
      }
  }
  None
}

///|
fn detect_block_quote(
  lines : Array[String],
  index : Int,
  format : TextMarkupFormat,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  match format {
    TextMarkupFormat::Rst =>
      if trimmed.has_prefix(".. ") && trimmed.contains("::") {
        match trimmed[3:].split_once("::") {
          Some((name_raw, value_raw)) => {
            let directive = name_raw.trim().to_owned()
            if rst_directive_is_blockquote(directive) {
              let inline_value = value_raw.trim().to_owned()
              let lowered = directive.to_lower()
              let body : Array[String] = []
              if inline_value != "" && lowered != "admonition" {
                body.push(inline_value)
              }
              let mut i = index + 1
              while i < lines.length() &&
                    (
                      lines[i].has_prefix("  ") ||
                      lines[i].has_prefix("    ") ||
                      lines[i].trim() == ""
                    ) {
                if lines[i].trim() != "" {
                  body.push(lines[i].trim().to_owned())
                }
                i += 1
              }
              let quote_label = if lowered == "admonition" && inline_value != "" {
                inline_value
              } else {
                directive
              }
              return Some(
                (
                  {
                    kind: TextMarkupBlockKind::BlockQuote,
                    text: body.join("\n"),
                    level: 0,
                    ordered: false,
                    line_start: index + 1,
                    line_end: i,
                    meta: Map([
                      ("quote_kind", "rst_admonition"),
                      ("quote_label", quote_label),
                      ("directive_kind", directive),
                      ("directive_family", "rst"),
                      ("degraded_feature", "admonition_boundary"),
                    ]),
                  },
                  i,
                ),
              )
            }
          }
          None => ()
        }
      }
    TextMarkupFormat::Asciidoc =>
      if trimmed == "NOTE:" ||
        trimmed == "TIP:" ||
        trimmed == "WARNING:" ||
        trimmed == "IMPORTANT:" ||
        trimmed == "CAUTION:" ||
        trimmed.has_prefix("NOTE: ") ||
        trimmed.has_prefix("TIP: ") ||
        trimmed.has_prefix("WARNING: ") ||
        trimmed.has_prefix("IMPORTANT: ") ||
        trimmed.has_prefix("CAUTION: ") {
        return Some(
          (
            {
              kind: TextMarkupBlockKind::BlockQuote,
              text: trimmed,
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: index + 1,
              meta: Map([
                ("quote_kind", "asciidoc_admonition"),
                ("degraded_feature", "admonition_boundary"),
              ]),
            },
            index + 1,
          ),
        )
      }
    TextMarkupFormat::Tex =>
      if trimmed == "\\begin{quote}" ||
        trimmed == "\\begin{quotation}" ||
        trimmed == "\\begin{verse}" {
        let end_marker = if trimmed == "\\begin{verse}" {
          "\\end{verse}"
        } else if trimmed == "\\begin{quotation}" {
          "\\end{quotation}"
        } else {
          "\\end{quote}"
        }
        let body : Array[String] = []
        let mut i = index + 1
        while i < lines.length() && lines[i].trim().to_owned() != end_marker {
          body.push(lines[i])
          i += 1
        }
        return Some(
          (
            {
              kind: TextMarkupBlockKind::BlockQuote,
              text: body.join("\n"),
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: if i < lines.length() {
                i + 1
              } else {
                i
              },
              meta: Map([
                (
                  "quote_kind",
                  if trimmed == "\\begin{verse}" {
                    "tex_verse_environment"
                  } else {
                    "tex_quote_environment"
                  },
                ),
                (
                  "degraded_feature",
                  if trimmed == "\\begin{verse}" {
                    "verse_environment"
                  } else {
                    "quote_environment"
                  },
                ),
              ]),
            },
            if i < lines.length() {
              i + 1
            } else {
              i
            },
          ),
        )
      }
  }
  None
}

///|
fn detect_raw_boundary(
  lines : Array[String],
  index : Int,
  format : TextMarkupFormat,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  match format {
    TextMarkupFormat::Asciidoc => {
      if trimmed.has_prefix("[") && trimmed.has_suffix("]") {
        let meta : Map[String, String] = Map([
          ("degraded_feature", "directive_boundary"),
        ])
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Raw,
              text: lines[index],
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: index + 1,
              meta,
            },
            index + 1,
          ),
        )
      }
      if asciidoc_is_block_delimiter(trimmed) {
        let meta : Map[String, String] = Map([
          ("degraded_feature", "block_delimiter_boundary"),
        ])
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Raw,
              text: lines[index],
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: index + 1,
              meta,
            },
            index + 1,
          ),
        )
      }
      if asciidoc_is_preprocessor_directive(trimmed) {
        let meta : Map[String, String] = Map([
          ("degraded_feature", "preprocessor_boundary"),
        ])
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Raw,
              text: lines[index],
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: index + 1,
              meta,
            },
            index + 1,
          ),
        )
      }
    }
    TextMarkupFormat::Rst =>
      if trimmed.has_prefix(".. ") {
        if trimmed.contains("::") {
          return None
        }
        let meta : Map[String, String] = Map([
          ("degraded_feature", "directive_boundary"),
        ])
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Raw,
              text: lines[index],
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: index + 1,
              meta,
            },
            index + 1,
          ),
        )
      }
    TextMarkupFormat::Tex =>
      if trimmed.has_prefix("\\begin{") ||
        trimmed.has_prefix("\\end{") ||
        trimmed.has_prefix("\\newcommand") ||
        trimmed.has_prefix("\\input{") ||
        trimmed.has_prefix("\\include{") {
        let meta : Map[String, String] = Map([
          ("degraded_feature", "environment_or_macro_boundary"),
        ])
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Raw,
              text: lines[index],
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: index + 1,
              meta,
            },
            index + 1,
          ),
        )
      }
  }
  None
}

///|
fn detect_rst_field_list(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let rows : Array[(String, String)] = []
  let mut i = index
  while i < lines.length() {
    let trimmed = lines[i].trim().to_owned()
    if trimmed == "" {
      break
    }
    if rst_is_field_line(trimmed) {
      let parsed = rst_parse_field_pairs(trimmed)
      if parsed.length() == 0 {
        break
      }
      for pair in parsed {
        rows.push(pair)
      }
      i += 1
      continue
    }
    if is_indented_markup_line(lines[i]) && rows.length() > 0 {
      let last = rows[rows.length() - 1]
      rows[rows.length() - 1] = (
        last.0,
        (last.1 + " " + trimmed).trim().to_owned(),
      )
      i += 1
      continue
    }
    break
  }
  if rows.length() == 0 {
    return None
  }
  Some(
    (
      {
        kind: TextMarkupBlockKind::Table,
        text: synthetic_pipe_table("Field", "Value", rows),
        level: 0,
        ordered: false,
        line_start: index + 1,
        line_end: i,
        meta: Map([("synthetic_table", "rst_field_list")]),
      },
      i,
    ),
  )
}

///|
fn detect_rst_note_definition(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  if !trimmed.has_prefix(".. [") {
    return None
  }
  match trimmed.find("]") {
    Some(close) => {
      if close <= 4 {
        return None
      }
      let identifier = trimmed[4:close].trim().to_owned()
      if identifier == "" {
        return None
      }
      let body : Array[String] = []
      let inline = trimmed[close + 1:].trim().to_owned()
      if inline != "" {
        body.push(inline)
      }
      let mut i = index + 1
      while i < lines.length() && is_indented_markup_line(lines[i]) {
        body.push(lines[i].trim().to_owned())
        i += 1
      }
      Some(
        (
          {
            kind: TextMarkupBlockKind::NoteDefinition,
            text: body.join(" "),
            level: 0,
            ordered: false,
            line_start: index + 1,
            line_end: i,
            meta: Map([
              ("note_id", identifier),
              ("semantic_kind", "footnote_or_citation"),
            ]),
          },
          i,
        ),
      )
    }
    None => None
  }
}

///|
fn detect_rst_definition_list(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let term = lines[index].trim().to_owned()
  if !rst_definition_term_candidate(term) ||
    index + 1 >= lines.length() ||
    !is_indented_markup_line(lines[index + 1]) {
    return None
  }
  let body : Array[String] = []
  let mut i = index + 1
  while i < lines.length() {
    let trimmed = lines[i].trim().to_owned()
    if trimmed == "" {
      if i + 1 < lines.length() && is_indented_markup_line(lines[i + 1]) {
        i += 1
        continue
      }
      break
    }
    if !is_indented_markup_line(lines[i]) {
      break
    }
    body.push(trimmed)
    i += 1
  }
  if body.length() == 0 {
    return None
  }
  Some(
    (
      {
        kind: TextMarkupBlockKind::Table,
        text: synthetic_pipe_table("Term", "Definition", [
          (term, body.join(" ")),
        ]),
        level: 0,
        ordered: false,
        line_start: index + 1,
        line_end: i,
        meta: Map([("synthetic_table", "rst_definition_list")]),
      },
      i,
    ),
  )
}

///|
fn detect_rst_directive_block(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  if !trimmed.has_prefix(".. ") || !trimmed.contains("::") {
    return None
  }
  let body = trimmed[3:].trim().to_owned()
  match body.split_once("::") {
    Some((name, value)) => {
      let directive = name.trim().to_owned()
      if directive == "" {
        return None
      }
      let lowered = directive.to_lower()
      let payload : Array[String] = []
      let options : Array[String] = []
      let content : Array[String] = []
      let inline_value = value.trim().to_owned()
      if inline_value != "" {
        payload.push(inline_value)
      }
      let mut i = index + 1
      let mut body_started = false
      while i < lines.length() {
        let next = lines[i]
        if next.trim() == "" {
          if i + 1 < lines.length() && is_indented_markup_line(lines[i + 1]) {
            if body_started {
              content.push("")
            } else {
              body_started = true
            }
            i += 1
            continue
          }
          break
        }
        if !is_indented_markup_line(next) {
          break
        }
        let trimmed_next = next.trim().to_owned()
        payload.push(trimmed_next)
        if !body_started && trimmed_next.has_prefix(":") {
          options.push(trimmed_next)
        } else {
          body_started = true
          content.push(trimmed_next)
        }
        i += 1
      }
      let meta = Map([
        ("directive_kind", directive),
        ("directive_family", "rst"),
      ])
      if (lowered == "image" || lowered == "figure") && inline_value != "" {
        meta.set("semantic_kind", "image")
        meta.set("image_target", inline_value)
        for option in options {
          if option.has_prefix(":alt:") {
            let alt = option[":alt:".length():].trim().to_owned()
            if alt != "" {
              meta.set("image_alt", alt)
            }
          }
        }
      }
      if options.length() > 0 {
        meta.set("directive_options", options.join("\n"))
      }
      let block_kind = if lowered == "image" || lowered == "figure" {
        TextMarkupBlockKind::Semantic
      } else if lowered == "literalinclude" {
        TextMarkupBlockKind::Raw
      } else if rst_directive_is_code(directive) && content.length() > 0 {
        TextMarkupBlockKind::Code
      } else if rst_directive_is_semantic(directive) {
        TextMarkupBlockKind::Semantic
      } else {
        TextMarkupBlockKind::Raw
      }
      let text = match block_kind {
        TextMarkupBlockKind::Code => {
          match rst_directive_language(directive, inline_value, options) {
            Some(language) => meta.set("code_language", language)
            None => ()
          }
          meta.set("degraded_feature", "directive_code_boundary")
          content.join("\n")
        }
        _ =>
          if lowered == "literalinclude" && inline_value != "" {
            meta.set("include_target", inline_value)
            meta.set("degraded_feature", "include_directive_boundary")
            if options.length() == 0 && content.length() == 0 {
              "include: " + inline_value
            } else {
              "include: " + inline_value + "\n" + (options + content).join("\n")
            }
          } else if meta.get("semantic_kind") == Some("image") {
            inline_value
          } else if block_kind == TextMarkupBlockKind::Semantic {
            meta.set("semantic_kind", "directive")
            meta.set("degraded_feature", "directive_semantic_boundary")
            if payload.length() == 0 {
              directive
            } else {
              payload.join("\n")
            }
          } else {
            meta.set("degraded_feature", "directive_semantic_boundary")
            if payload.length() == 0 {
              directive
            } else {
              payload.join("\n")
            }
          }
      }
      Some(
        (
          {
            kind: block_kind,
            text,
            level: 0,
            ordered: false,
            line_start: index + 1,
            line_end: i,
            meta,
          },
          i,
        ),
      )
    }
    None => None
  }
}

///|
fn detect_rst_include_directive(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  if !trimmed.has_prefix(".. include::") {
    return None
  }
  let target = trimmed[".. include::".length():].trim().to_owned()
  if target == "" {
    return None
  }
  let mut i = index + 1
  let options : Array[String] = []
  while i < lines.length() && is_indented_markup_line(lines[i]) {
    let next = lines[i].trim().to_owned()
    if next != "" {
      options.push(next)
    }
    i += 1
  }
  Some(
    (
      {
        kind: TextMarkupBlockKind::Semantic,
        text: if options.length() == 0 {
          "include: " + target
        } else {
          "include: " + target + "\n" + options.join("\n")
        },
        level: 0,
        ordered: false,
        line_start: index + 1,
        line_end: i,
        meta: Map([
          ("directive_kind", "include"),
          ("directive_family", "rst"),
          ("include_target", target),
          ("semantic_kind", "include"),
          ("degraded_feature", "include_directive_boundary"),
        ]),
      },
      i,
    ),
  )
}

///|
fn detect_asciidoc_attribute_table(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  if !asciidoc_is_attribute_entry(lines[index].trim().to_owned()) {
    return None
  }
  let rows : Array[(String, String)] = []
  let mut i = index
  while i < lines.length() {
    let trimmed = lines[i].trim().to_owned()
    if !asciidoc_is_attribute_entry(trimmed) {
      break
    }
    match asciidoc_parse_attribute_entry(trimmed) {
      Some(pair) => rows.push(pair)
      None => break
    }
    i += 1
  }
  if rows.length() == 0 {
    return None
  }
  Some(
    (
      {
        kind: TextMarkupBlockKind::Table,
        text: synthetic_pipe_table("Attribute", "Value", rows),
        level: 0,
        ordered: false,
        line_start: index + 1,
        line_end: i,
        meta: Map([("synthetic_table", "asciidoc_attribute_entries")]),
      },
      i,
    ),
  )
}

///|
fn detect_asciidoc_include_directive(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  if !trimmed.has_prefix("include::") {
    return None
  }
  let body = trimmed["include::".length():]
  match body.split_once("[") {
    Some((target_raw, attrs_raw)) =>
      if attrs_raw.has_suffix("]") {
        let target = target_raw.trim().to_owned()
        let attrs = attrs_raw[:attrs_raw.length() - 1].trim().to_owned()
        if target == "" {
          return None
        }
        return Some(
          (
            {
              kind: TextMarkupBlockKind::Semantic,
              text: if attrs == "" {
                "include: " + target
              } else {
                "include: " + target + "\n" + attrs
              },
              level: 0,
              ordered: false,
              line_start: index + 1,
              line_end: index + 1,
              meta: Map([
                ("directive_kind", "include"),
                ("directive_family", "asciidoc"),
                ("include_target", target),
                ("semantic_kind", "include"),
                ("degraded_feature", "include_directive_boundary"),
              ]),
            },
            index + 1,
          ),
        )
      }
    None => ()
  }
  None
}

///|
fn detect_asciidoc_source_block(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  if !trimmed.has_prefix("[") ||
    !trimmed.has_suffix("]") ||
    index + 1 >= lines.length() {
    return None
  }
  let attrs = trimmed[1:trimmed.length() - 1].trim().to_owned()
  let tokens = asciidoc_attribute_tokens(attrs)
  if tokens.length() == 0 || !asciidoc_is_source_block_spec(tokens[0]) {
    return None
  }
  let delimiter = lines[index + 1].trim().to_owned()
  if delimiter != "----" && delimiter != "...." && delimiter != "```" {
    return None
  }
  let body : Array[String] = []
  let mut i = index + 2
  while i < lines.length() && lines[i].trim().to_owned() != delimiter {
    body.push(lines[i])
    i += 1
  }
  let meta = Map([
    ("directive_kind", "source"),
    ("directive_family", "asciidoc"),
    ("code_language", asciidoc_source_language(tokens).unwrap_or("")),
    ("degraded_feature", "source_block_boundary"),
  ])
  Some(
    (
      {
        kind: TextMarkupBlockKind::Code,
        text: body.join("\n"),
        level: 0,
        ordered: false,
        line_start: index + 1,
        line_end: if i < lines.length() {
          i + 1
        } else {
          i
        },
        meta,
      },
      if i < lines.length() {
        i + 1
      } else {
        i
      },
    ),
  )
}

///|
fn detect_asciidoc_quote_block(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  if !trimmed.has_prefix("[") ||
    !trimmed.has_suffix("]") ||
    index + 1 >= lines.length() {
    return None
  }
  let attrs = trimmed[1:trimmed.length() - 1].trim().to_owned()
  let tokens = asciidoc_attribute_tokens(attrs)
  if tokens.length() == 0 {
    return None
  }
  let primary = asciidoc_primary_attribute_token(tokens[0])
  if primary != "quote" && primary != "verse" {
    return None
  }
  let delimiter = lines[index + 1].trim().to_owned()
  if !asciidoc_is_block_delimiter(delimiter) {
    return None
  }
  let body : Array[String] = []
  let mut i = index + 2
  while i < lines.length() && lines[i].trim().to_owned() != delimiter {
    body.push(lines[i])
    i += 1
  }
  let quote_label = if tokens.length() > 1 && tokens[1] != "" {
    primary.to_upper() + " - " + tokens[1]
  } else {
    primary.to_upper()
  }
  Some(
    (
      {
        kind: TextMarkupBlockKind::Semantic,
        text: body.join("\n").trim().to_owned(),
        level: 0,
        ordered: false,
        line_start: index + 1,
        line_end: if i < lines.length() {
          i + 1
        } else {
          i
        },
        meta: Map([
          ("quote_kind", "asciidoc_quote_block"),
          ("quote_label", quote_label),
          ("semantic_kind", "quote"),
          ("degraded_feature", "quote_block_boundary"),
        ]),
      },
      if i < lines.length() {
        i + 1
      } else {
        i
      },
    ),
  )
}

///|
fn detect_asciidoc_block_admonition(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  if !trimmed.has_prefix("[") || !trimmed.has_suffix("]") {
    return None
  }
  let label = trimmed[1:trimmed.length() - 1].trim().to_upper().to_owned()
  if !asciidoc_is_block_admonition_label(label) {
    return None
  }
  if index + 1 >= lines.length() ||
    !asciidoc_is_block_delimiter(lines[index + 1].trim().to_owned()) {
    return None
  }
  let delimiter = lines[index + 1].trim().to_owned()
  let body : Array[String] = []
  let mut i = index + 2
  while i < lines.length() && lines[i].trim().to_owned() != delimiter {
    body.push(lines[i])
    i += 1
  }
  Some(
    (
      {
        kind: TextMarkupBlockKind::Semantic,
        text: body.join("\n").trim().to_owned(),
        level: 0,
        ordered: false,
        line_start: index + 1,
        line_end: if i < lines.length() {
          i + 1
        } else {
          i
        },
        meta: Map([
          ("quote_kind", "asciidoc_admonition_block"),
          ("quote_label", label),
          ("semantic_kind", "admonition"),
          ("degraded_feature", "admonition_block_boundary"),
        ]),
      },
      if i < lines.length() {
        i + 1
      } else {
        i
      },
    ),
  )
}

///|
fn detect_tex_metadata_table(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let rows : Array[(String, String)] = []
  let mut i = index
  while i < lines.length() {
    let trimmed = tex_strip_trailing_comment(lines[i].trim().to_owned())
    if trimmed == "" {
      break
    }
    match tex_parse_metadata_command(trimmed) {
      Some(pair) => {
        rows.push(pair)
        i += 1
      }
      None => break
    }
  }
  if rows.length() == 0 {
    return None
  }
  Some(
    (
      {
        kind: TextMarkupBlockKind::Table,
        text: synthetic_pipe_table("Field", "Value", rows),
        level: 0,
        ordered: false,
        line_start: index + 1,
        line_end: i,
        meta: Map([("synthetic_table", "tex_metadata_commands")]),
      },
      i,
    ),
  )
}

///|
fn detect_tex_include_directive(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = tex_strip_trailing_comment(lines[index].trim().to_owned())
  if trimmed.has_prefix("\\includegraphics") && trimmed.has_suffix("}") {
    let open = match trimmed.find("{") {
      Some(value) => value
      None => return None
    }
    let target = trimmed[open + 1:trimmed.length() - 1].trim().to_owned()
    if target != "" {
      return Some(
        (
          {
            kind: TextMarkupBlockKind::Semantic,
            text: target,
            level: 0,
            ordered: false,
            line_start: index + 1,
            line_end: index + 1,
            meta: Map([
              ("directive_kind", "includegraphics"),
              ("directive_family", "tex"),
              ("semantic_kind", "image"),
              ("image_target", target),
              ("image_alt", "image"),
            ]),
          },
          index + 1,
        ),
      )
    }
  }
  for prefix in ["\\input{", "\\include{"] {
    if trimmed.has_prefix(prefix) && trimmed.has_suffix("}") {
      let target = trimmed[prefix.length():trimmed.length() - 1]
        .trim()
        .to_owned()
      if target == "" {
        return None
      }
      return Some(
        (
          {
            kind: TextMarkupBlockKind::Semantic,
            text: "include: " + target,
            level: 0,
            ordered: false,
            line_start: index + 1,
            line_end: index + 1,
            meta: Map([
              ("directive_kind", "include"),
              ("directive_family", "tex"),
              ("include_target", target),
              ("semantic_kind", "include"),
              ("degraded_feature", "include_directive_boundary"),
            ]),
          },
          index + 1,
        ),
      )
    }
  }
  None
}

///|
fn detect_tex_environment_block(
  lines : Array[String],
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = tex_strip_trailing_comment(lines[index].trim().to_owned())
  match tex_parse_begin_environment(trimmed) {
    Some((env, _suffix)) => {
      if env == "" ||
        env == "document" ||
        env == "quote" ||
        env == "quotation" ||
        env == "verse" ||
        env == "verbatim" ||
        env == "lstlisting" ||
        env == "tabular" ||
        env == "itemize" ||
        env == "enumerate" {
        return None
      }
      let end_marker = "\\end{" + env + "}"
      let body : Array[String] = []
      let mut i = index + 1
      while i < lines.length() &&
            tex_strip_trailing_comment(lines[i].trim().to_owned()) != end_marker {
        body.push(lines[i])
        i += 1
      }
      let meta = Map([("directive_kind", env), ("directive_family", "tex")])
      let block_kind = if tex_environment_is_math(env) {
        meta.set("code_language", "tex-math")
        meta.set("degraded_feature", "math_environment_boundary")
        TextMarkupBlockKind::Code
      } else if tex_environment_is_theorem_like(env) {
        meta.set("quote_kind", "tex_semantic_environment")
        meta.set("quote_label", env)
        meta.set("semantic_kind", "environment")
        meta.set("degraded_feature", "environment_semantic_boundary")
        TextMarkupBlockKind::Semantic
      } else {
        meta.set("semantic_kind", "environment")
        meta.set("degraded_feature", "environment_semantic_boundary")
        TextMarkupBlockKind::Semantic
      }
      Some(
        (
          {
            kind: block_kind,
            text: if block_kind == TextMarkupBlockKind::Semantic {
              if body.length() == 0 {
                env
              } else {
                env + "\n" + body.join("\n")
              }
            } else {
              body.join("\n").trim().to_owned()
            },
            level: 0,
            ordered: false,
            line_start: index + 1,
            line_end: if i < lines.length() {
              i + 1
            } else {
              i
            },
            meta,
          },
          if i < lines.length() {
            i + 1
          } else {
            i
          },
        ),
      )
    }
    None => None
  }
}

///|
fn tex_parse_begin_environment(line : String) -> (String, String)? {
  if !line.has_prefix("\\begin{") {
    return None
  }
  let rest = line["\\begin{".length():]
  match rest.split_once("}") {
    Some((env, suffix)) => Some((env.trim().to_owned(), suffix.to_owned()))
    None => None
  }
}

///|
fn detect_tex_item(
  context : MarkupParseContext,
  index : Int,
) -> (TextMarkupBlock, Int)? {
  let trimmed = markup_trimmed_line(context, index)
  if !trimmed.has_prefix("\\item") {
    return None
  }
  let body : Array[String] = []
  let inline = trimmed["\\item".length():].trim().to_owned()
  if inline != "" {
    body.push(inline)
  }
  let mut i = index + 1
  while i < context.lines.length() {
    let next = markup_trimmed_line(context, i)
    if next == "" ||
      next.has_prefix("\\item") ||
      next == "\\end{itemize}" ||
      next == "\\end{enumerate}" {
      break
    }
    if next.has_prefix("\\begin{") || next.has_prefix("\\end{") {
      break
    }
    body.push(next)
    i += 1
  }
  Some(
    (
      {
        kind: TextMarkupBlockKind::ListItem,
        text: body.join(" "),
        level: 0,
        ordered: context.tex_item_ordered_before_line[index],
        line_start: index + 1,
        line_end: i,
        meta: Map([("list_kind", "tex_environment_item")]),
      },
      i,
    ),
  )
}

///|
fn tex_heading_level(line : String) -> (Int, String)? {
  let line = tex_strip_trailing_comment(line.trim().to_owned())
  for
    entry in [
      ("\\section{", 1),
      ("\\subsection{", 2),
      ("\\subsubsection{", 3),
      ("\\paragraph{", 4),
    ] {
    if line.has_prefix(entry.0) && line.has_suffix("}") {
      let body = line[entry.0.length():]
      return Some((entry.1, body[:body.length() - 1].to_owned()))
    }
  }
  None
}

///|
fn tex_strip_trailing_comment(line : String) -> String {
  if !line.contains("%") {
    return line
  }
  let chars = line.to_array()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '%' && (index == 0 || chars[index - 1] != '\\') {
      return line[:index].trim_end().to_owned()
    }
    index += 1
  }
  line
}

///|
fn rst_underline_heading(line : String) -> Bool {
  if line.length() < 3 {
    return false
  }
  let chars = line.to_array()
  let marker = chars[0]
  for ch in chars {
    if ch != marker {
      return false
    }
  }
  true
}

///|
fn rst_table_border(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  trimmed.length() >= 3 &&
  (trimmed.has_prefix("+") || trimmed.has_prefix("=")) &&
  (trimmed.contains("+") || trimmed.contains("="))
}

///|
fn rst_heading_level(line : String) -> Int {
  match line.to_array()[0] {
    '=' => 1
    '-' => 2
    '~' => 3
    '^' => 4
    '"' => 5
    _ => 6
  }
}

///|
fn normalize_markup_text(text : String) -> String {
  if !text.contains("\r") {
    return text
  }
  text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
}

///|
fn count_markup_lines(text : String) -> Int {
  if text == "" {
    return 0
  }
  let mut count = 1
  for ch in text {
    if ch == '\n' {
      count += 1
    }
  }
  count
}

///|
fn all_digits(text : String) -> Bool {
  if text == "" {
    return false
  }
  for ch in text {
    if ch < '0' || ch > '9' {
      return false
    }
  }
  true
}

///|
fn ordered_list_tail(text : String) -> String? {
  match text.split_once(". ") {
    Some((head, tail)) if ordered_marker_token(head.to_owned()) =>
      return Some(tail.to_owned())
    _ => ()
  }
  match text.split_once(") ") {
    Some((head, tail)) => {
      let marker = if head.has_prefix("(") {
        head[1:].to_owned()
      } else {
        head.to_owned()
      }
      if ordered_marker_token(marker) {
        return Some(tail.to_owned())
      }
    }
    None => ()
  }
  None
}

///|
fn ordered_marker_token(text : String) -> Bool {
  let token = text.trim().to_owned()
  if token == "" {
    return false
  }
  if all_digits(token) {
    return true
  }
  let chars = token.to_array()
  if chars.length() == 1 && is_ascii_alpha(chars[0]) {
    return true
  }
  for ch in chars {
    if !roman_marker_char(ch) {
      return false
    }
  }
  true
}

///|
fn is_ascii_alpha(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn roman_marker_char(ch : Char) -> Bool {
  match ch {
    'i'
    | 'v'
    | 'x'
    | 'l'
    | 'c'
    | 'd'
    | 'm'
    | 'I'
    | 'V'
    | 'X'
    | 'L'
    | 'C'
    | 'D'
    | 'M' => true
    _ => false
  }
}

///|
fn is_indented_markup_line(line : String) -> Bool {
  line.has_prefix("  ") || line.has_prefix("    ") || line.has_prefix("\t")
}

///|
fn rst_is_field_line(line : String) -> Bool {
  if !line.has_prefix(":") {
    return false
  }
  match line[1:].split_once(":") {
    Some((name, _)) => name.trim() != ""
    None => false
  }
}

///|
fn rst_parse_field_pairs(line : String) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  let parts = line.split(" :").to_array()
  for index in 0..<parts.length() {
    let raw = if index == 0 {
      parts[index].to_owned()
    } else {
      ":" + parts[index].to_owned()
    }
    match raw[1:].split_once(":") {
      Some((name, value)) =>
        if name.trim() != "" {
          out.push((name.trim().to_owned(), value.trim().to_owned()))
        }
      None => ()
    }
  }
  out
}

///|
fn rst_definition_term_candidate(term : String) -> Bool {
  if term == "" ||
    term.has_prefix(".. ") ||
    term.has_prefix(":") ||
    term.has_suffix(":") ||
    term.has_suffix(".") ||
    term.has_suffix("!") ||
    term.has_suffix("?") ||
    term.contains("__") ||
    term.contains("`") ||
    term.contains(". ") ||
    rst_underline_heading(term) {
    return false
  }
  let words = term.split(" ").to_array().filter(word => word.trim() != "")
  words.length() > 0 && words.length() <= 6
}

///|
fn synthetic_pipe_table(
  left_header : String,
  right_header : String,
  rows : Array[(String, String)],
) -> String {
  let lines : Array[String] = ["| " + left_header + " | " + right_header + " |"]
  for row in rows {
    lines.push("| " + row.0 + " | " + row.1 + " |")
  }
  lines.join("\n")
}

///|
fn asciidoc_is_attribute_entry(line : String) -> Bool {
  if !line.has_prefix(":") {
    return false
  }
  match line[1:].split_once(":") {
    Some((name, _)) => name.trim() != ""
    None => false
  }
}

///|
fn asciidoc_parse_attribute_entry(line : String) -> (String, String)? {
  match line[1:].split_once(":") {
    Some((name, value)) =>
      if name.trim() == "" {
        None
      } else {
        Some((name.trim().to_owned(), value.trim().to_owned()))
      }
    None => None
  }
}

///|
fn asciidoc_is_preprocessor_directive(line : String) -> Bool {
  line.has_prefix("ifdef::") ||
  line.has_prefix("ifndef::") ||
  line.has_prefix("endif::") ||
  line.has_prefix("ifeval::") ||
  line.has_prefix("include::")
}

///|
fn asciidoc_is_block_delimiter(line : String) -> Bool {
  if line.length() < 4 {
    return false
  }
  let chars = line.to_array()
  let marker = chars[0]
  if marker == ' ' || marker == '\t' {
    return false
  }
  for ch in chars {
    if ch != marker {
      return false
    }
  }
  true
}

///|
fn asciidoc_is_block_admonition_label(line : String) -> Bool {
  line == "NOTE" ||
  line == "TIP" ||
  line == "WARNING" ||
  line == "IMPORTANT" ||
  line == "CAUTION"
}

///|
fn asciidoc_attribute_tokens(attrs : String) -> Array[String] {
  attrs
  .split(",")
  .to_array()
  .map(token => token.trim().to_owned())
  .filter(token => token != "")
}

///|
fn asciidoc_primary_attribute_token(token : String) -> String {
  let base = match token.split_once("%") {
    Some((head, _)) => head.trim().to_owned()
    None => token.trim().to_owned()
  }
  match base.split_once(".") {
    Some((head, _)) => head.trim().to_owned()
    None => base
  }
}

///|
fn asciidoc_is_source_block_spec(token : String) -> Bool {
  let primary = asciidoc_primary_attribute_token(token)
  primary == "source" || primary == "listing"
}

///|
fn asciidoc_source_language(tokens : Array[String]) -> String? {
  let mut index = 1
  while index < tokens.length() {
    let token = tokens[index]
    if token != "" &&
      !token.contains("=") &&
      !token.contains("%") &&
      !token.has_prefix("opts=") {
      return Some(token)
    }
    index += 1
  }
  None
}

///|
fn tex_parse_metadata_command(line : String) -> (String, String)? {
  for
    entry in [
      ("\\title{", "title"),
      ("\\author{", "author"),
      ("\\date{", "date"),
    ] {
    if line.has_prefix(entry.0) && line.has_suffix("}") {
      let body = line[entry.0.length():line.length() - 1].trim().to_owned()
      return Some((entry.1, body))
    }
  }
  None
}

///|
fn rst_directive_is_blockquote(name : String) -> Bool {
  let lowered = name.to_lower()
  lowered == "attention" ||
  lowered == "danger" ||
  lowered == "error" ||
  lowered == "hint" ||
  lowered == "note" ||
  lowered == "warning" ||
  lowered == "tip" ||
  lowered == "important" ||
  lowered == "caution" ||
  lowered == "admonition"
}

///|
fn rst_directive_is_code(name : String) -> Bool {
  let lowered = name.to_lower()
  lowered == "code-block" ||
  lowered == "sourcecode" ||
  lowered == "parsed-literal"
}

///|
fn rst_directive_is_semantic(name : String) -> Bool {
  let lowered = name.to_lower()
  lowered == "image" ||
  lowered == "figure" ||
  lowered == "include" ||
  lowered == "literalinclude" ||
  lowered == "contents" ||
  lowered == "topic" ||
  lowered == "sidebar" ||
  lowered == "rubric" ||
  lowered == "epigraph" ||
  lowered == "highlights" ||
  lowered == "pull-quote" ||
  lowered == "container"
}

///|
fn rst_directive_language(
  directive : String,
  inline_value : String,
  options : Array[String],
) -> String? {
  let lowered = directive.to_lower()
  if (lowered == "code-block" || lowered == "sourcecode") && inline_value != "" {
    return Some(inline_value)
  }
  for option in options {
    if option.has_prefix(":language:") {
      let language = option[":language:".length():].trim().to_owned()
      if language != "" {
        return Some(language)
      }
    }
  }
  None
}

///|
fn tex_environment_is_math(env : String) -> Bool {
  let lowered = env.to_lower()
  lowered == "equation" ||
  lowered == "equation*" ||
  lowered == "align" ||
  lowered == "align*" ||
  lowered == "gather" ||
  lowered == "gather*" ||
  lowered == "multline" ||
  lowered == "multline*" ||
  lowered == "displaymath"
}

///|
fn tex_environment_is_theorem_like(env : String) -> Bool {
  let lowered = env.to_lower()
  lowered == "theorem" ||
  lowered == "lemma" ||
  lowered == "proposition" ||
  lowered == "corollary" ||
  lowered == "definition" ||
  lowered == "remark" ||
  lowered == "example" ||
  lowered == "proof"
}
