///|
/// HTML MVP parser: html -> IR
pub fn parse_html(
  input_path : String,
  _out_dir : String,
  max_heading : Int,
) -> @cor.Document raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("html: file not found: " + input_path)
  }

  let html0 = @fs.read_file_to_string(input_path, encoding="utf8") catch {
    e => raise @cor.AppError("html: read failed: " + e.to_string())
  }

  let html = strip_script_style(html0)
  let doc = @cor.new_document()
  @cor.push(doc, @cor.Block::Heading(clamp_heading(1, max_heading), "HTML"))

  let blocks = parse_blocks(html, max_heading)
  for b in blocks {
    @cor.push(doc, b)
  }

  doc
}

///|
fn clamp_heading(level : Int, max_h : Int) -> Int {
  if level < 1 {
    1
  } else if level > max_h {
    max_h
  } else {
    level
  }
}

// ---------- parsing ----------

///|
fn parse_blocks(s : String, max_h : Int) -> Array[@cor.Block] raise {
  let out : Array[@cor.Block] = []
  let mut pos = 0
  let n = s.length()

  while pos < n {
    // skip whitespace
    pos = skip_ws(s, pos)

    // headings
    let h = match_heading_open(s, pos)
    match h {
      Some((lvl, open_end)) => {
        let close_tag = "</h" + lvl.to_string() + ">"
        let close0 = find_sub(s, close_tag, open_end)
        match close0 {
          Some(close_pos) => {
            let inner = s[open_end:close_pos].to_string()
            let text = html_text(inner)
            if text.trim() != "" {
              out.push(@cor.Block::Heading(clamp_heading(lvl, max_h), text))
              out.push(@cor.Block::BlankLine)
            }
            pos = close_pos + close_tag.length()
            continue
          }
          None => ()
        }
      }
      None => ()
    }

    // paragraph
    if has_at(s, pos, "<p") {
      let open_end0 = find_sub(s, ">", pos)
      match open_end0 {
        Some(open_end) => {
          let close0 = find_sub(s, "</p>", open_end + 1)
          match close0 {
            Some(close_pos) => {
              let inner = s[open_end + 1:close_pos].to_string()
              let text = html_text(inner)
              if text.trim() != "" {
                out.push(@cor.Block::Paragraph(text))
                out.push(@cor.Block::BlankLine)
              }
              pos = close_pos + 4
              continue
            }
            None => ()
          }
        }
        None => ()
      }
    }

    // list items (very simple)
    if has_at(s, pos, "<li") {
      let open_end0 = find_sub(s, ">", pos)
      match open_end0 {
        Some(open_end) => {
          let close0 = find_sub(s, "</li>", open_end + 1)
          match close0 {
            Some(close_pos) => {
              let inner = s[open_end + 1:close_pos].to_string()
              let text = html_text(inner)
              if text.trim() != "" {
                out.push(@cor.Block::Paragraph("- " + text))
              }
              pos = close_pos + 5
              continue
            }
            None => ()
          }
        }
        None => ()
      }
    }

    // otherwise: move to next tag or end
    let next_tag = find_sub(s, "<", pos)
    match next_tag {
      None => break
      Some(p) =>
        if p == pos {
          // skip one char to avoid infinite loop
          pos = pos + 1
        } else {
          pos = p
        }
    }
  }

  out
}

///|
fn match_heading_open(s : String, pos : Int) -> (Int, Int)? raise {
  // returns (level, content_start_index)
  if pos + 3 >= s.length() {
    return None
  }
  if s[pos:pos + 2] != "<h" {
    return None
  }
  let lvl_ch = s[pos + 2]
  if lvl_ch < '1' || lvl_ch > '6' {
    return None
  }
  let lvl = lvl_ch.to_int() - '0'.to_int()
  let gt0 = find_sub(s, ">", pos)
  match gt0 {
    None => None
    Some(gt) => Some((lvl, gt + 1))
  }
}

// ---------- text helpers ----------

///|
fn html_text(inner : String) -> String raise {
  // replace <br> with newline-ish, strip other tags
  let t0 = inner
    .replace(old="<br>", new="\n")
    .replace(old="<br/>", new="\n")
    .replace(old="<br />", new="\n")
  let t1 = strip_tags(t0)
  html_unescape(t1).replace(old="\n", new=" ").trim().to_string()
}

///|
fn strip_tags(s : String) -> String raise {
  let mut out = ""
  let mut i = 0
  let n = s.length()
  while i < n {
    let lt = find_sub(s, "<", i)
    match lt {
      None => {
        out = out + s[i:].to_string()
        break
      }
      Some(p) => {
        out = out + s[i:p].to_string()
        let gt = find_sub(s, ">", p)
        match gt {
          None => break
          Some(q) => i = q + 1
        }
      }
    }
  }
  out
}

///|
fn html_unescape(s : String) -> String raise {
  let t = s
    .replace(old="&lt;", new="<")
    .replace(old="&gt;", new=">")
    .replace(old="&amp;", new="&")
    .replace(old="&quot;", new="\"")
    .replace(old="&apos;", new="'")
  @cor.decode_numeric_entities(t)
}

// remove <script>..</script> and <style>..</style> blocks (simple)

///|
fn strip_script_style(s : String) -> String raise {
  strip_block(strip_block(s, "script"), "style")
}

///|
fn strip_block(s : String, tag : String) -> String raise {
  let open = "<" + tag
  let close = "</" + tag + ">"
  let mut out = ""
  let mut pos = 0
  while true {
    let i0 = find_sub(s, open, pos)
    match i0 {
      None => {
        out = out + s[pos:].to_string()
        break
      }
      Some(p) => {
        out = out + s[pos:p].to_string()
        let gt0 = find_sub(s, ">", p)
        match gt0 {
          None => break
          Some(gt) => {
            let j0 = find_sub(s, close, gt + 1)
            match j0 {
              None => break
              Some(j) => pos = j + close.length()
            }
          }
        }
      }
    }
  }
  out
}

// ============================
// Utilities
// ============================

///|
fn skip_ws(s : String, i : Int) -> Int {
  let n = s.length()
  let mut j = i
  while j < n {
    let c = s[j]
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      j = j + 1
    } else {
      break
    }
  }
  j
}

///|
fn has_at(s : String, pos : Int, pat : String) -> Bool raise {
  let n = s.length()
  let m = pat.length()
  if pos < 0 || pos + m > n {
    return false
  }
  s[pos:pos + m] == pat
}

///|
fn find_sub(s : String, pat : String, start : Int) -> Int? raise {
  let n = s.length()
  let m = pat.length()
  if m == 0 {
    return Some(start)
  }
  if start < 0 || start > n - m {
    return None
  }
  let last = n - m
  let mut i = start
  while i <= last {
    if s[i:i + m] == pat {
      return Some(i)
    }
    i = i + 1
  }
  None
}
