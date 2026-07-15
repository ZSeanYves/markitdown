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
      Blank(next) => i = next
      Block(block, next) => {
        blocks.push(block)
        if cache_enabled && !(format == Tex && block.kind == ListItem) {
          cache_markup_block(block_cache, lines, i, next, block)
        }
        i = next
      }
      ParagraphLine(line_text) => {
        let para_lines : Array[String] = [line_text]
        let start = i + 1
        i += 1
        while i < lines.length() {
          match classify_markup_line(context, i) {
            ParagraphLine(next_line) => {
              para_lines.push(next_line)
              i += 1
            }
            _ => break
          }
        }
        let block = {
          kind: Paragraph,
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
  let semantic_lines = if format == Tex {
    build_markup_semantic_lines(lines, format)
  } else {
    lines
  }
  let trimmed_semantic_lines = if format == Tex {
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
  let states : Array[Bool] = if format == Tex {
    Array::new(capacity=semantic_lines.length())
  } else {
    []
  }
  if format != Tex {
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
    return Blank(index + 1)
  }
  if !text_markup_line_can_start_block(context, index, trimmed) {
    return ParagraphLine(trimmed)
  }
  match detect_heading(context.lines, index, context.format) {
    Some((block, next)) => return Block(block, next)
    None => ()
  }
  match detect_block_quote(context.lines, index, context.format) {
    Some((block, next)) => return Block(block, next)
    None => ()
  }
  match detect_code_block(context.lines, index, context.format) {
    Some((block, next)) => return Block(block, next)
    None => ()
  }
  match detect_structured_semantic_block(context.lines, index, context.format) {
    Some((block, next)) => return Block(block, next)
    None => ()
  }
  match detect_list_item(context, index) {
    Some((block, next)) => return Block(block, next)
    None => ()
  }
  match detect_table_block(context.lines, index, context.format) {
    Some((block, next)) => return Block(block, next)
    None => ()
  }
  match detect_raw_boundary(context.lines, index, context.format) {
    Some((block, next)) => return Block(block, next)
    None => ()
  }
  ParagraphLine(trimmed)
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
    Tex =>
      first == '\\' ||
      first == '%' ||
      first == '[' ||
      first == '{' ||
      first == ']' ||
      first == '}'
    Asciidoc =>
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
    Rst => rst_line_may_start_block(context.lines, index, trimmed)
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
    Rst =>
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
    Asciidoc =>
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
    Tex =>
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
        kind: Semantic,
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
    Tex => tex_strip_trailing_comment(line)
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
    Asciidoc =>
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
              kind: Heading,
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
    Tex =>
      match tex_heading_level(line) {
        Some((level, text)) =>
          return Some(
            (
              {
                kind: Heading,
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
    Rst => {
      if index + 2 < lines.length() {
        let title = lines[index + 1].trim().to_owned()
        let underline = lines[index + 2].trim().to_owned()
        if rst_underline_heading(line) && title != "" && underline == line {
          return Some(
            (
              {
                kind: Heading,
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
                kind: Heading,
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
    Asciidoc =>
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
              kind: Code,
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
    Rst =>
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
              kind: Code,
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
    Tex =>
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
              kind: Code,
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
    Tex =>
      match detect_tex_item(context, index) {
        Some(block) => return Some(block)
        None => ()
      }
    Asciidoc =>
      if trimmed.has_prefix(". ") {
        return Some(
          (
            {
              kind: ListItem,
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
          kind: ListItem,
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
            kind: ListItem,
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
    Rst =>
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
                kind: Table,
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
    Asciidoc =>
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
              kind: Table,
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
    Tex =>
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
              kind: Table,
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
    Rst =>
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
                    kind: BlockQuote,
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
    Asciidoc =>
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
              kind: BlockQuote,
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
    Tex =>
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
              kind: BlockQuote,
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
