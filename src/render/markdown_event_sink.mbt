///|
/// Incremental Markdown writer for line-oriented parser streams.
///
/// The writer keeps only the current paragraph state. It is intentionally
/// narrower than the array renderer: callers must select it only for a parser
/// whose event contract is `TextLine`/`BlankLine`.
pub struct MarkdownEventSink {
  push : (@core.CoreEvent) -> Result[Unit, String]
  finish : () -> Result[Unit, String]
}

///|
/// Open a line-event Markdown writer backed by a caller-owned sink callback.
pub fn open_markdown_line_event_sink(
  write : (String) -> Result[Unit, String],
) -> MarkdownEventSink {
  let wrote_paragraph = Ref(false)
  let paragraph_open = Ref(false)
  {
    push: fn(event) {
      match event.kind {
        TextLine => {
          let line = StringBuilder::new()
          if !paragraph_open.val {
            if wrote_paragraph.val {
              line.write_string("\n\n")
            }
            paragraph_open.val = true
            wrote_paragraph.val = true
          } else {
            line.write_char(' ')
          }
          write_escaped_markdown_inline_text_to(
            line,
            event.text.trim().to_owned(),
          )
          write(line.to_string())
        }
        BlankLine => {
          paragraph_open.val = false
          Ok(())
        }
        StartBlock(Raw) => {
          let line = StringBuilder::new()
          if wrote_paragraph.val {
            line.write_string("\n\n")
          }
          line.write_string("```raw\n")
          line.write_string(event.text)
          line.write_string("\n```")
          wrote_paragraph.val = true
          paragraph_open.val = false
          write(line.to_string())
        }
        _ => Ok(())
      }
    },
    finish: fn() { Ok(()) },
  }
}

///|
/// Open the compact subtitle-record writer used by streaming SRT/VTT parsers.
pub fn open_markdown_subtitle_event_sink(
  write : (String) -> Result[Unit, String],
) -> MarkdownEventSink {
  let wrote_any = Ref(false)
  let in_quote = Ref(false)
  let heading = Ref("")
  let paragraph = Ref("")
  {
    push: fn(event) {
      match event.kind {
        StartBlock(BlockQuote) => {
          if event.text == "" {
            in_quote.val = true
            heading.val = ""
            paragraph.val = ""
            return Ok(())
          }
          let out = StringBuilder::new()
          if wrote_any.val {
            out.write_string("\n\n")
          }
          write_markdown_subtitle_record_v2_to(
            out,
            event.text,
            event.source_ref,
            include_identifier=false,
          )
          wrote_any.val = true
          write(out.to_string())
        }
        StartBlock(Heading) => {
          if in_quote.val {
            heading.val = event.text
          }
          Ok(())
        }
        StartBlock(Paragraph) => {
          if in_quote.val {
            paragraph.val = event.text
          }
          Ok(())
        }
        EndBlock(BlockQuote) => {
          if !in_quote.val {
            return Ok(())
          }
          let out = StringBuilder::new()
          if wrote_any.val {
            out.write_string("\n\n")
          }
          write_markdown_subtitle_cue_to(out, heading.val, paragraph.val)
          in_quote.val = false
          wrote_any.val = true
          write(out.to_string())
        }
        StartBlock(Raw) => {
          let out = StringBuilder::new()
          if wrote_any.val {
            out.write_string("\n\n")
          }
          let info = match event.source_ref {
            Some(source_ref) =>
              source_ref.extra
              .get("ir_block_attr_info")
              .unwrap_or(source_ref.format.unwrap_or("text"))
            None => "text"
          }
          let fence = safe_code_fence(event.text)
          out.write_string(fence)
          out.write_string(info)
          out.write_char('\n')
          out.write_string(event.text)
          out.write_char('\n')
          out.write_string(fence)
          wrote_any.val = true
          write(out.to_string())
        }
        _ => Ok(())
      }
    },
    finish: fn() {
      if !in_quote.val {
        return Ok(())
      }
      let out = StringBuilder::new()
      if wrote_any.val {
        out.write_string("\n\n")
      }
      write_markdown_subtitle_cue_to(out, heading.val, paragraph.val)
      in_quote.val = false
      write(out.to_string())
    },
  }
}

///|
/// Open a row/cell Markdown writer. Only one table row is retained; the first
/// row determines the stable Markdown width used by parser-side two-pass
/// streams such as CSV and JSONL.
pub fn open_markdown_table_event_sink(
  write : (String) -> Result[Unit, String],
) -> MarkdownEventSink {
  let row : Array[String] = []
  let width = Ref(0)
  let wrote_table = Ref(false)
  let wrote_any = Ref(false)
  let flush_row = fn() -> Result[Unit, String] {
    if row.length() == 0 {
      return Ok(())
    }
    if width.val == 0 {
      width.val = row.length()
    }
    let out = StringBuilder::new()
    if wrote_table.val {
      out.write_char('\n')
    }
    write_markdown_table_row_from_values(out, row, width.val)
    if !wrote_table.val {
      out.write_char('\n')
      write_markdown_table_separator(out, width.val)
    }
    row.clear()
    wrote_table.val = true
    wrote_any.val = true
    write(out.to_string())
  }
  {
    push: fn(event) {
      match event.kind {
        Cell => {
          row.push(event.text)
          Ok(())
        }
        RowBreak => flush_row()
        StartBlock(Code) | StartBlock(Raw) => {
          match flush_row() {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          let out = StringBuilder::new()
          if wrote_any.val {
            out.write_string("\n\n")
          }
          let info = match event.source_ref {
            Some(source_ref) =>
              source_ref.extra
              .get("ir_block_attr_info")
              .unwrap_or(source_ref.format.unwrap_or("text"))
            None => "text"
          }
          let fence = safe_code_fence(event.text)
          out.write_string(fence)
          out.write_string(info)
          out.write_char('\n')
          out.write_string(event.text)
          out.write_char('\n')
          out.write_string(fence)
          wrote_any.val = true
          write(out.to_string())
        }
        Text => {
          match flush_row() {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          if event.text.trim() == "" {
            return Ok(())
          }
          let out = StringBuilder::new()
          if wrote_any.val {
            out.write_string("\n\n")
          }
          write_escaped_markdown_inline_text_to(out, event.text)
          wrote_any.val = true
          write(out.to_string())
        }
        _ => Ok(())
      }
    },
    finish: fn() { flush_row() },
  }
}
