///|
priv enum MarkdownChunkKind {
  Paragraph
  CodeBlock
}

///|
fn conservative_markdown_blocks(text : String) -> Array[@cor.Block] {
  let normalized = text
    .replace(old="\r\n", new="\n")
    .replace(old="\r", new="\n")
  let lines : Array[String] = normalized
    .split("\n")
    .map(fn(line) { line.to_owned() })
    .iter()
    .collect()

  let out : Array[@cor.Block] = []
  let count = lines.length()
  let mut i = 0

  match consume_frontmatter_block(lines, 0) {
    Some((next, block)) => {
      out.push(block)
      i = next
    }
    None => ()
  }

  while i < count {
    while i < count && lines[i].trim() == "" {
      i += 1
    }
    if i >= count {
      break
    }

    let trimmed = lines[i].trim().to_owned()
    match fence_marker(trimmed) {
      Some((fence_char, fence_len)) => {
        let (next, chunk) = consume_fenced_block(
          lines, i, fence_char, fence_len,
        )
        out.push(chunk_to_block(MarkdownChunkKind::CodeBlock, chunk))
        i = next
      }
      None => {
        let (next, chunk) = consume_raw_block(lines, i)
        out.push(chunk_to_block(MarkdownChunkKind::Paragraph, chunk))
        i = next
      }
    }
  }

  out
}

///|
fn consume_frontmatter_block(
  lines : Array[String],
  start : Int,
) -> (Int, @cor.Block)? {
  if start != 0 || lines.length() == 0 {
    return None
  }

  let marker = lines[0]
  if !(marker == "---" || marker == "+++") {
    return None
  }

  let chunk : Array[String] = [marker]
  let mut i = 1
  while i < lines.length() {
    chunk.push(lines[i])
    if lines[i] == marker {
      i += 1
      while i < lines.length() && lines[i].trim() == "" {
        i += 1
      }
      return Some((i, chunk_to_block(MarkdownChunkKind::Paragraph, chunk)))
    }
    i += 1
  }

  None
}

///|
fn consume_fenced_block(
  lines : Array[String],
  start : Int,
  fence_char : Char,
  fence_len : Int,
) -> (Int, Array[String]) {
  let chunk : Array[String] = []
  let mut i = start

  while i < lines.length() {
    let line = lines[i]
    chunk.push(line)
    if i > start &&
      is_fence_close(line.trim().to_owned(), fence_char, fence_len) {
      return (i + 1, chunk)
    }
    i += 1
  }

  (lines.length(), chunk)
}

///|
fn consume_raw_block(
  lines : Array[String],
  start : Int,
) -> (Int, Array[String]) {
  let chunk : Array[String] = []
  let mut i = start

  while i < lines.length() {
    let trimmed = lines[i].trim().to_owned()
    if trimmed == "" {
      break
    }
    if i > start {
      match fence_marker(trimmed) {
        Some(_) => break
        None => ()
      }
    }
    chunk.push(lines[i])
    i += 1
  }

  (i, chunk)
}

///|
fn chunk_to_block(
  kind : MarkdownChunkKind,
  lines : Array[String],
) -> @cor.Block {
  let text = lines.join("\n")
  match kind {
    MarkdownChunkKind::Paragraph => @cor.Block::Paragraph(text)
    MarkdownChunkKind::CodeBlock => @cor.Block::CodeBlock(text)
  }
}

///|
fn fence_marker(line : String) -> (Char, Int)? {
  let chars = line.to_array()
  if chars.length() < 3 {
    return None
  }

  let ch = chars[0]
  if !(ch == '`' || ch == '~') {
    return None
  }

  let mut i = 0
  while i < chars.length() && chars[i] == ch {
    i += 1
  }

  if i < 3 {
    return None
  }

  Some((ch, i))
}

///|
fn is_fence_close(line : String, fence_char : Char, fence_len : Int) -> Bool {
  let chars = line.to_array()
  if chars.length() < fence_len {
    return false
  }

  let mut i = 0
  while i < chars.length() && chars[i] == fence_char {
    i += 1
  }

  i >= fence_len && line[i:].trim() == ""
}
