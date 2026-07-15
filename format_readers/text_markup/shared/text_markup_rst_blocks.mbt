///|
fn detect_raw_boundary(
  lines : Array[String],
  index : Int,
  format : TextMarkupFormat,
) -> (TextMarkupBlock, Int)? {
  let trimmed = lines[index].trim().to_owned()
  match format {
    Asciidoc => {
      if trimmed.has_prefix("[") && trimmed.has_suffix("]") {
        let meta : Map[String, String] = Map([
          ("degraded_feature", "directive_boundary"),
        ])
        return Some(
          (
            {
              kind: Raw,
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
              kind: Raw,
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
              kind: Raw,
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
    Rst =>
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
              kind: Raw,
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
    Tex =>
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
              kind: Raw,
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
        kind: Table,
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
            kind: NoteDefinition,
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
        kind: Table,
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
        Raw
      } else if rst_directive_is_code(directive) && content.length() > 0 {
        Code
      } else if rst_directive_is_semantic(directive) {
        Semantic
      } else {
        Raw
      }
      let text = match block_kind {
        Code => {
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
          } else if block_kind == Semantic {
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
        kind: Semantic,
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
