///|
fn assert_deflated(data : Array[Byte]) -> Unit raise {
  assert_true(data.length() > 0)
  assert_eq(data[0].to_int(), 0x78)
}

///|
test "afm data blocks are present" {
  let ctx = PdfAfmData::new()
  assert_deflated(ctx.courier_afm())
  assert_deflated(ctx.courier_bold_afm())
  assert_deflated(ctx.courier_bold_oblique_afm())
  assert_deflated(ctx.courier_oblique_afm())
  assert_deflated(ctx.helvetica_afm())
  assert_deflated(ctx.helvetica_bold_afm())
  assert_deflated(ctx.helvetica_bold_oblique_afm())
  assert_deflated(ctx.helvetica_oblique_afm())
  assert_deflated(ctx.symbol_afm())
  assert_deflated(ctx.times_bold_afm())
  assert_deflated(ctx.times_bold_italic_afm())
  assert_deflated(ctx.times_italic_afm())
  assert_deflated(ctx.times_roman_afm())
  assert_deflated(ctx.zapf_dingbats_afm())
}
