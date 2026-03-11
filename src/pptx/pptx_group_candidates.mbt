///|
fn is_small_shape_for_grouping(
  sp : LayoutShape,
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  if slide_w <= 0 || slide_h <= 0 {
    return false
  }

  let w = sp.shape.w
  let h = sp.shape.h

  let narrow = w <= slide_w / 3
  let low = h <= slide_h / 6
  let small_area = w * h <= slide_w * slide_h / 20

  (narrow && low) || small_area
}

///|
fn is_caption_like_shape(
  sp : LayoutShape,
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  if sp.shape.is_title {
    return false
  }

  let text = normalize_shape_text_for_title(sp.shape.xml)
  if text == "" {
    return false
  }

  if is_bullet_like(text) {
    return false
  }

  if ends_like_sentence(text) {
    return false
  }

  let n = text.to_array().length()
  if n > 40 {
    return false
  }

  if slide_h > 0 && sp.shape.y <= slide_h / 5 {
    return false
  }

  if !is_small_shape_for_grouping(sp, slide_w, slide_h) {
    return false
  }

  true
}

///|
fn is_table_like_shape_candidate(
  sp : LayoutShape,
  slide_w : Int,
  slide_h : Int,
) -> Bool {
  let text = normalize_shape_text_for_title(sp.shape.xml)
  let small = is_small_shape_for_grouping(sp, slide_w, slide_h)
  let bullet = is_bullet_like(text)
  let sent = ends_like_sentence(text)
  let n = text.to_array().length()

  let ok = !sp.shape.is_title &&
    text != "" &&
    !bullet &&
    !sent &&
    n <= 30 &&
    small
  if PPTX_SLIDE_DEBUG {
    println(
      "[pptx-table-candidate-check] " +
      text +
      " | small=" +
      small.to_string() +
      " | bullet=" +
      bullet.to_string() +
      " | sent=" +
      sent.to_string() +
      " | len=" +
      n.to_string() +
      " | ok=" +
      ok.to_string(),
    )
  }
  ok
}

///|
fn filter_table_like_candidates(
  shapes : Array[LayoutShape],
) -> Array[LayoutShape] {
  let out : Array[LayoutShape] = []
  let (slide_w, slide_h) = estimate_layout_bounds(shapes)

  for sp in shapes {
    let text = normalize_shape_text_for_title(sp.shape.xml)
    let ok = is_table_like_shape_candidate(sp, slide_w, slide_h)
    if PPTX_SLIDE_DEBUG {
      println(
        "[pptx-table-candidate] " +
        text +
        " | ok=" +
        ok.to_string() +
        " | x=" +
        sp.shape.x.to_string() +
        " | y=" +
        sp.shape.y.to_string() +
        " | w=" +
        sp.shape.w.to_string() +
        " | h=" +
        sp.shape.h.to_string(),
      )
    }
    if ok {
      out.push(sp)
    }
  }

  out
}
