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
