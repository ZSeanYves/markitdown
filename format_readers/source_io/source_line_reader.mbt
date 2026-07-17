///|
/// One physical UTF-8 source line. Newline bytes are consumed but omitted
/// from `text`; `line_no` is one-based.
pub struct SourceTextLine {
  text : String
  line_no : Int
  truncated : Bool
}

///|
/// Pull reader for physical lines over a bounded source cursor.
pub struct SourceTextLineReader {
  next : () -> Result[SourceTextLine?, String]
}

///|
/// Open a bounded UTF-8 physical-line reader without collecting the source.
pub fn open_source_text_line_reader(
  source : @input.InputSource,
  max_bytes? : Int64 = 512L * 1024L * 1024L,
  max_line_chars? : Int = 4 * 1024 * 1024,
) -> Result[SourceTextLineReader, String] {
  if max_line_chars <= 0 {
    return Err("text line limit must be positive")
  }
  let chunks = match open_source_text_chunk_reader(source, max_bytes~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let chunk = Ref("")
  let chunk_index = Ref(0)
  let line = Ref(StringBuilder::new())
  let line_chars = Ref(0)
  let line_no = Ref(1)
  let line_truncated = Ref(false)
  let pending_cr = Ref(false)
  let eof = Ref(false)
  let saw_content = Ref(false)
  let skip_bom = Ref(true)
  let emit = fn() -> SourceTextLine {
    let value = {
      text: line.val.to_string(),
      line_no: line_no.val,
      truncated: line_truncated.val,
    }
    line.val = StringBuilder::new()
    line_chars.val = 0
    line_truncated.val = false
    line_no.val += 1
    value
  }
  Ok({
    next: fn() {
      while true {
        if chunk_index.val >= chunk.val.length() && !eof.val {
          match (chunks.next)() {
            Ok(Some(value)) => {
              chunk.val = value.text
              chunk_index.val = 0
              continue
            }
            Ok(None) => eof.val = true
            Err(message) => return Err(message)
          }
        }
        if chunk_index.val >= chunk.val.length() {
          if pending_cr.val {
            pending_cr.val = false
            return Ok(Some(emit()))
          }
          if saw_content.val && (line_chars.val > 0 || line_truncated.val) {
            return Ok(Some(emit()))
          }
          return Ok(None)
        }
        let ch = chunk.val[chunk_index.val].unsafe_to_char()
        chunk_index.val += 1
        saw_content.val = true
        if skip_bom.val {
          skip_bom.val = false
          if ch == '\u{FEFF}' {
            continue
          }
        }
        if pending_cr.val {
          pending_cr.val = false
          if ch == '\n' {
            return Ok(Some(emit()))
          }
          chunk_index.val -= 1
          return Ok(Some(emit()))
        }
        if ch == '\r' {
          pending_cr.val = true
          continue
        }
        if ch == '\n' {
          return Ok(Some(emit()))
        }
        let width = if ch.to_int() > 0xFFFF { 2 } else { 1 }
        if line_chars.val + width <= max_line_chars {
          line.val.write_char(ch)
          line_chars.val += width
        } else {
          line_truncated.val = true
        }
      }
      Ok(None)
    },
  })
}

///|
/// One blank-line-delimited record with its inclusive source line range.
pub struct SourceTextBlock {
  lines : Array[String]
  line_start : Int
  line_end : Int
  truncated : Bool
}

///|
/// Pull reader for blank-line-delimited text records.
pub struct SourceTextBlockReader {
  next : () -> Result[SourceTextBlock?, String]
}

///|
/// Open a bounded block reader. It retains only the current record.
pub fn open_source_text_block_reader(
  source : @input.InputSource,
  max_bytes? : Int64 = 512L * 1024L * 1024L,
  max_line_chars? : Int = 4 * 1024 * 1024,
  max_block_lines? : Int = 100000,
) -> Result[SourceTextBlockReader, String] {
  let lines = match
    open_source_text_line_reader(source, max_bytes~, max_line_chars~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let current : Array[String] = []
  let start = Ref(0)
  let finish = Ref(0)
  let truncated = Ref(false)
  let eof = Ref(false)
  Ok({
    next: fn() {
      while true {
        if eof.val {
          if current.length() == 0 {
            return Ok(None)
          }
          let block = {
            lines: current.copy(),
            line_start: start.val,
            line_end: finish.val,
            truncated: truncated.val,
          }
          current.clear()
          return Ok(Some(block))
        }
        match (lines.next)() {
          Ok(Some(line)) => {
            if line.text.trim() == "" {
              if current.length() == 0 {
                continue
              }
              let block = {
                lines: current.copy(),
                line_start: start.val,
                line_end: finish.val,
                truncated: truncated.val,
              }
              current.clear()
              truncated.val = false
              return Ok(Some(block))
            }
            if current.length() == 0 {
              start.val = line.line_no
            }
            finish.val = line.line_no
            if current.length() < max_block_lines {
              current.push(line.text)
            } else {
              truncated.val = true
            }
            truncated.val = truncated.val || line.truncated
          }
          Ok(None) => eof.val = true
          Err(message) => return Err(message)
        }
      }
      Ok(None)
    },
  })
}
