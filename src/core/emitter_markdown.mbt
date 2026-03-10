///|
pub fn emit_markdown(doc : Document) -> String {
  let mut out = ""
  let blocks = doc.blocks.val

  for b in blocks {
    match b {
      Heading(level, text) => {
        let lvl = if level < 1 { 1 } else if level > 6 { 6 } else { level }
        let t = trim_string(text)
        if t != "" {
          out = out + "#".repeat(lvl) + " " + t + "\n\n"
        }
      }
      Paragraph(text) => {
        let t = text
          .replace(old="\r\n", new="\n")
          .replace(old="\r", new="\n")
          .trim()
          .to_string()

        if t != "" {
          let lines : Array[String] = t
            .split("\n")
            .map(fn(x) { trim_string(x.to_string()) })
            .filter(fn(x) { x != "" })
            .iter()
            .collect()

          let body = if lines.length() == 0 { "" } else { lines.join("<br>") }

          if body != "" {
            out = out + body + "\n\n"
          }
        }
      }
      ListItem(ordered, level, text) => {
        let t = trim_string(text)
        if t != "" {
          let lvl = if level < 0 { 0 } else { level }
          let indent = "  ".repeat(lvl)
          let marker = if ordered { "1. " } else { "- " }
          out = out + indent + marker + t + "\n"
        }
      }
      BlockQuote(text) => {
        let t = text
          .replace(old="\r\n", new="\n")
          .replace(old="\r", new="\n")
          .trim()
          .to_string()

        if t != "" {
          for sv in t.split("\n") {
            let line = sv.to_string()
            out = out + "> " + line + "\n"
          }
          out = out + "\n"
        }
      }
      CodeBlock(text) => {
        let t = text
          .replace(old="\r\n", new="\n")
          .replace(old="\r", new="\n")
          .trim()
          .to_string()

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

  String::from_array(cs[:end].to_array()) + "\n"
}
