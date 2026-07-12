///|
test "subtitle inline lowering preserves meaning and unknown tags" {
  let srt = lower_subtitle_inline_markup(
    "<b>Bold</b> <i>italic</i> <font color=red>red</font> &amp; <future>x</future>",
  )
  assert_eq(srt.0, "**Bold** *italic* red & <future>x</future>")
  assert_true(srt.1)
  let vtt = lower_subtitle_inline_markup(
    "<v Ada><c.notice>Hello</c></v> <ruby>漢<rt>kan</rt></ruby> <00:01.000>",
  )
  assert_eq(vtt.0, "Ada: Hello 漢 (kan) ")
  assert_true(vtt.1)
  assert_true(lower_subtitle_inline_markup("plain").1 == false)
}
