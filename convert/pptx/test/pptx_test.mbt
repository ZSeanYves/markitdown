///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
test "pptx baseline samples keep existing body extraction stable" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path("samples/main_process/pptx/pptx_simple.pptx"),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## Slide 1"))
  assert_true(markdown.contains("PPTX MVP 测试"))
  assert_true(markdown.contains("- 项目符号 1"))
  assert_true(markdown.contains("## Slide 2"))
  assert_true(markdown.contains("第二页标题：Data Overview"))
}

///|
test "pptx notes are emitted under owning slide" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_speaker_notes_basic.pptx",
    ),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("### Speaker Notes"))
  assert_true(markdown.contains("本页核心信息"))
  assert_true(markdown.contains("第二页备注"))
  assert_true(markdown.contains("最后页备注"))
}

///|
test "pptx hidden slides are preserved with marker" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_hidden_slide_basic.pptx",
    ),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## Slide 1"))
  assert_true(markdown.contains("## Slide 2 (hidden)"))
  assert_true(markdown.contains("### First"))
}

///|
test "pptx explicit tables emit RichTable when present" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_explicit_table_basic.pptx",
    ),
    "",
    6,
  )
  let mut saw_table = false
  for block in doc.blocks.val {
    match block {
      @cor.Block::RichTable(table) => {
        saw_table = true
        assert_eq(table.header_rows, 1)
        assert_eq(table.rows[0], ["Quarter", "Revenue", "Profit"])
      }
      _ => ()
    }
  }
  if !saw_table {
    fail("pptx explicit table sample should emit RichTable")
  }
}

///|
test "pptx grouped text sample preserves nested grouped text in stable order" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_small_grouped_notes.pptx",
    ),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("## Slide 1"))
  assert_true(markdown.contains("### Highlights"))
  assert_true(markdown.contains("Item A"))
  assert_true(markdown.contains("Item B"))
  assert_true(markdown.contains("Item C"))
  assert_true(markdown.contains("Main paragraph"))
  assert_true(markdown.contains("Item A\n\nItem B\n\nItem C\n\nMain paragraph"))
}

///|
test "pptx footer page number sample keeps body text and drops page number noise" {
  let doc = @pptx.parse_pptx(
    resolve_sample_path(
      "samples/main_process/pptx/pptx_footer_page_number.pptx",
    ),
    "",
    6,
  )
  let markdown = @cor.emit_markdown(doc)
  assert_true(markdown.contains("### Report Summary"))
  assert_true(markdown.contains("Main content"))
  assert_true(!markdown.contains("\n\n1\n\n"))
}
