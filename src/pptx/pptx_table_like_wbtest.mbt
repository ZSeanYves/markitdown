///|
fn mk_layout_shape(
  text : String,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> LayoutShape {
  let xml = @utf8.encode("<a:t>" + text + "</a:t>")
  let sp : SlideShape = { xml, x, y, w, h, is_title: false, is_body: true }
  {
    shape: sp,
    right: x + w,
    bottom: y + h,
    center_x: x + w / 2,
    center_y: y + h / 2,
  }
}

///|
test "pptx grid-like region detects strong 2x2 table" {
  let shapes = [
    mk_layout_shape("A1", 100, 100, 120, 80),
    mk_layout_shape("A2", 260, 100, 120, 80),
    mk_layout_shape("B1", 100, 220, 120, 80),
    mk_layout_shape("B2", 260, 220, 120, 80),
  ]

  assert_eq(shapes_form_grid_like_region(shapes), true)
}

///|
test "pptx grid-like region rejects one-dimensional row" {
  let shapes = [
    mk_layout_shape("Card 1", 100, 100, 120, 80),
    mk_layout_shape("Card 2", 260, 100, 120, 80),
    mk_layout_shape("Card 3", 420, 100, 120, 80),
    mk_layout_shape("Card 4", 580, 100, 120, 80),
  ]

  assert_eq(shapes_form_grid_like_region(shapes), false)
}
