///|
/// One physical UTF-8 source line. Newline bytes are consumed but omitted
/// from `text`; `line_no` is one-based.
pub struct SourceTextLine {
  text : String
  line_no : Int32
  truncated : Bool
  // Whole logical line after the selected optional-prefix policy, not just
  // its retained text. Blank uses String::trim's pinned default ASCII set.
  is_blank : Bool
}

///|
/// Pull reader for physical lines over a bounded source cursor.
pub struct SourceTextLineReader {
  next : async () -> Result[SourceTextLine?, String] noraise
  input_error : () -> String?
  close : () -> Unit
  // True only after observed successful EOF when the selected split semantics
  // leave a final empty field. Early close/error/cancellation never claim EOF.
  eof_has_empty_line : () -> Bool
}

///|
/// Open a bounded UTF-8 physical-line reader without collecting the source.
pub async fn open_source_text_line_reader(
  source : @input.InputSource,
  max_bytes? : Int64,
  max_line_chars~ : Int32 = 4 * 1024 * 1024,
  split_cr~ : Bool = true,
  skip_leading_bom~ : Bool = true,
  blank_prefix~ : Array[Char] = [],
) -> Result[SourceTextLineReader, String] noraise {
  if max_line_chars <= 0 {
    return Err("text line limit must be positive")
  }
  let blank_prefix_snapshot = blank_prefix.copy()
  let chunks = match open_source_text_chunk_reader(source, max_bytes?) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let chunk = Ref("")
  let chunk_index = Ref(0)
  let line = Ref(StringBuilder())
  let line_chars = Ref(0)
  let line_no = Ref(1)
  let line_truncated = Ref(false)
  let line_nonblank = Ref(false)
  let blank_prefix_index = Ref(0)
  // Classification alone may ignore each optional character once, in order.
  // It never removes content from text or retains an omitted scalar suffix.
  let pending_cr = Ref(false)
  let eof = Ref(false)
  let saw_content = Ref(false)
  let skip_bom = Ref(skip_leading_bom)
  let closed = Ref(false)
  let final_empty_pending = Ref(true)
  let eof_has_empty_line = Ref(false)
  let close = fn() {
    if !closed.val {
      closed.val = true
      chunk.val = ""
      chunk_index.val = 0
      line.val = StringBuilder()
      line_chars.val = 0
      line_truncated.val = false
      line_nonblank.val = false
      blank_prefix_index.val = 0
      pending_cr.val = false
      eof.val = true
      saw_content.val = false
      (chunks.close)()
    }
  }
  let emit = fn(terminated : Bool) -> SourceTextLine {
    let value = {
      text: line.val.to_string(),
      line_no: line_no.val,
      truncated: line_truncated.val,
      is_blank: !line_nonblank.val,
    }
    line.val = StringBuilder()
    line_chars.val = 0
    line_truncated.val = false
    line_nonblank.val = false
    blank_prefix_index.val = 0
    line_no.val += 1
    final_empty_pending.val = terminated
    value
  }
  Ok({
    input_error: chunks.input_error,
    close,
    eof_has_empty_line: fn() { eof_has_empty_line.val },
    next: async fn() -> Result[SourceTextLine?, String] noraise {
      if closed.val {
        return Ok(None)
      }
      while true {
        if chunk_index.val >= chunk.val.length() && !eof.val {
          match (chunks.next)() {
            Ok(Some(value)) => {
              chunk.val = value.text
              chunk_index.val = 0
              continue
            }
            Ok(None) => eof.val = true
            Err(message) => {
              close()
              return Err(message)
            }
          }
        }
        if chunk_index.val >= chunk.val.length() {
          if pending_cr.val {
            pending_cr.val = false
            return Ok(Some(emit(true)))
          }
          if saw_content.val && (line_chars.val > 0 || line_truncated.val) {
            return Ok(Some(emit(false)))
          }
          eof_has_empty_line.val = final_empty_pending.val
          close()
          return Ok(None)
        }
        let previous_index = chunk_index.val
        let (ch, next_index) = match
          source_text_scalar_at(chunk.val, previous_index) {
          Ok(value) => value
          Err(message) => {
            @input.record_input_failure(source, message)
            close()
            return Err(message)
          }
        }
        chunk_index.val = next_index
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
            return Ok(Some(emit(true)))
          }
          chunk_index.val = previous_index
          return Ok(Some(emit(true)))
        }
        if split_cr && ch == '\r' {
          pending_cr.val = true
          continue
        }
        if ch == '\n' {
          return Ok(Some(emit(true)))
        }
        if !line_nonblank.val {
          let mut ignored = false
          while blank_prefix_index.val < blank_prefix_snapshot.length() {
            let prefix = blank_prefix_snapshot[blank_prefix_index.val]
            blank_prefix_index.val += 1
            if ch == prefix {
              ignored = true
              break
            }
          }
          if !ignored && !(ch is ('\t' | '\n' | '\r' | ' ')) {
            line_nonblank.val = true
          }
        }
        let width = if ch.to_int() > 0xFFFF { 2 } else { 1 }
        if !line_truncated.val && line_chars.val + width <= max_line_chars {
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
  line_start : Int32
  line_end : Int32
  truncated : Bool
}

///|
/// Pull reader for blank-line-delimited text records.
pub struct SourceTextBlockReader {
  next : async () -> Result[SourceTextBlock?, String] noraise
  close : () -> Unit
}

///|
/// Open a bounded block reader. It retains only the current record.
pub async fn open_source_text_block_reader(
  source : @input.InputSource,
  max_bytes? : Int64,
  max_line_chars~ : Int32 = 4 * 1024 * 1024,
  max_block_lines~ : Int32 = 100000,
) -> Result[SourceTextBlockReader, String] noraise {
  let lines = match
    open_source_text_line_reader(source, max_bytes?, max_line_chars~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let current : Array[String] = []
  let start = Ref(0)
  let finish = Ref(0)
  let truncated = Ref(false)
  let eof = Ref(false)
  let closed = Ref(false)
  let close = fn() {
    if !closed.val {
      closed.val = true
      current.clear()
      current.shrink_to_fit()
      start.val = 0
      finish.val = 0
      truncated.val = false
      eof.val = true
      (lines.close)()
    }
  }
  Ok({
    close,
    next: async fn() -> Result[SourceTextBlock?, String] noraise {
      if closed.val {
        return Ok(None)
      }
      while true {
        if eof.val {
          if current.length() == 0 {
            close()
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
          Err(message) => {
            close()
            return Err(message)
          }
        }
      }
      Ok(None)
    },
  })
}
