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
