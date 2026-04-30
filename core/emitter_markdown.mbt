///|
pub fn emit_markdown(doc : Document) -> String {
  match doc.passthrough_markdown.val {
    Some(raw) => return normalize_markdown_tail(raw)
    None => ()
  }

  let mut out = ""
  let blocks = doc.blocks.val

  for i in 0..<blocks.length() {
    let b = blocks[i]
    match b {
      Heading(level, text) => {
        let lvl = if level < 1 { 1 } else if level > 6 { 6 } else { level }
        let t = trim_string(text)
        if t != "" {
          out = out + "#".repeat(lvl) + " " + t + "\n\n"
        }
      }
      RichHeading(level, inlines) => {
        let lvl = if level < 1 { 1 } else if level > 6 { 6 } else { level }
        let t = render_inlines(inlines)
        if t != "" {
          out = out + "#".repeat(lvl) + " " + t + "\n\n"
        }
      }
      Paragraph(text) => {
        let t = text
          .replace(old="\r\n", new="\n")
          .replace(old="\r", new="\n")
          .trim()
          .to_owned()

        if t != "" {
          let lines : Array[String] = t
            .split("\n")
            .map(fn(x) { trim_string(x.to_owned()) })
            .filter(fn(x) { x != "" })
            .iter()
            .collect()

          let body = if lines.length() == 0 { "" } else { lines.join("<br>") }

          if body != "" {
            out = out + body + "\n\n"
          }
        }
      }
      RichParagraph(inlines) => {
        let body = render_inlines(inlines)
        if body != "" {
          out = out + body + "\n\n"
        }
      }
      ListItem(ordered, level, text) => {
        let t = trim_string(text)
        if t != "" {
          let lvl = if level < 0 { 0 } else { level }
          let indent = "  ".repeat(lvl)
          let marker = if ordered { "1. " } else { "- " }
          out = out + indent + marker + t + "\n"

          if i + 1 < blocks.length() {
            match blocks[i + 1] {
              ListItem(_, _, _) => ()
              RichListItem(_, _, _) => ()
              BlankLine => ()
              _ => out = out + "\n"
            }
          }
        }
      }
      RichListItem(ordered, level, inlines) => {
        let t = render_inlines(inlines)
        if t != "" {
          let lvl = if level < 0 { 0 } else { level }
          let indent = "  ".repeat(lvl)
          let marker = if ordered { "1. " } else { "- " }
          out = out + indent + marker + t + "\n"

          if i + 1 < blocks.length() {
            match blocks[i + 1] {
              ListItem(_, _, _) => ()
              RichListItem(_, _, _) => ()
              BlankLine => ()
              _ => out = out + "\n"
            }
          }
        }
      }
      BlockQuote(text) => {
        let t = text
          .replace(old="\r\n", new="\n")
          .replace(old="\r", new="\n")
          .trim()
          .to_owned()

        if t != "" {
          for sv in t.split("\n") {
            let line = sv.to_owned()
            out = out + "> " + line + "\n"
          }
          out = out + "\n"
        }
      }
      RichBlockQuote(inlines) => {
        let t = render_inlines(inlines).trim().to_owned()
        if t != "" {
          out = out + "> " + t + "\n\n"
        }
      }
      CodeBlock(text) => {
        let t = text
          .replace(old="\r\n", new="\n")
          .replace(old="\r", new="\n")
          .trim()
          .to_owned()

        if t != "" {
          out = out + "```\n" + t + "\n```\n\n"
        }
      }
      Image(alt, path) => {
        let a0 = trim_string(alt)
        let a = if a0 == "" { "image" } else { a0 }
        let p = trim_string(path)
        out = out + "![" + a + "](" + p + ")\n\n"
      }
      ImageBlock(img) => {
        let a = img.alt_text.unwrap_or("").trim().to_owned()
        let alt = if a == "" { "image" } else { a }
        let p = trim_string(img.path)
        out = out + "![" + alt + "](" + p + ")\n"
        match img.title {
          Some(t) =>
            if t.trim() != "" {
              out = out + "*" + t.trim().to_owned() + "*\n"
            }
          None => ()
        }
        match img.caption {
          Some(c) =>
            if c.trim() != "" {
              out = out + c.trim().to_owned() + "\n"
            }
          None => ()
        }
        out = out + "\n"
      }
      Table(rows) =>
        if rows.length() > 0 {
          let header = rows[0]
          out = out + "| " + header.map(normalize_cell).join(" | ") + " |\n"
          out = out + "| " + header.map(fn(_) { "---" }).join(" | ") + " |\n"

          for i in 1..<rows.length() {
            let r = rows[i]
            let cells = r
            while cells.length() < header.length() {
              cells.push("")
            }
            out = out + "| " + cells.map(normalize_cell).join(" | ") + " |\n"
          }
          out = out + "\n"
        }
      BlankLine => out = out + "\n"
    }
  }

  normalize_markdown_tail(out)
}

///|
/// normalize final markdown tail:
/// - remove trailing blank lines
/// - keep exactly one trailing newline for non-empty output
fn normalize_markdown_tail(s : String) -> String {
  if s == "" {
    return ""
  }

  let cs = s.to_array()
  let mut end = cs.length()

  while end > 0 {
    let c = cs[end - 1]
    if c == '\n' || c == '\r' {
      end = end - 1
    } else {
      break
    }
  }

  if end == 0 {
    return ""
  }

  String::from_array(cs[:end].to_owned()) + "\n"
}

///|
fn escape_inline_text(s : String) -> String {
  s
  .replace(old="[", new="\\[")
  .replace(old="]", new="\\]")
  .replace(old="(", new="\\(")
  .replace(old=")", new="\\)")
}

///|
fn render_inlines(xs : Array[Inline]) -> String {
  let mut out = ""
  for x in xs {
    match x {
      Text(t) => out = out + t
      Break => out = out + "<br>"
      Link(text, url) => {
        let t0 = text.trim().to_owned()
        let u0 = url.trim().to_owned()
        if t0 == "" || u0 == "" {
          out = out + t0
        } else {
          out = out + "[" + escape_inline_text(t0) + "](" + u0 + ")"
        }
      }
    }
  }
  out.trim().to_owned()
}
