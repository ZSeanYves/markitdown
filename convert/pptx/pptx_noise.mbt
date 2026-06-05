///|
/// conservative noise filtering for PPTX layout shapes:
/// - page numbers
/// - tiny edge/corner labels
/// - short footer/copyright/url/date-like texts
///
/// this file only handles single-slide heuristics for now.
fn filter_noise_shapes(shapes : Array[LayoutShape]) -> Array[LayoutShape] {
  let out : Array[LayoutShape] = []
  let (slide_w, slide_h) = estimate_slide_bounds(shapes)

  for sp in shapes {
    if !is_noise_candidate(sp, slide_w, slide_h) {
      out.push(sp)
    }
  }

  out
}

///|
fn is_noise_candidate(sp : LayoutShape, slide_w : Int, slide_h : Int) -> Bool {
  let text = normalize_shape_text(sp.shape.xml)
  if text == "" {
    return true
  }

  let _edge = is_edge_shape(sp, slide_w, slide_h)
  let corner = is_corner_shape(sp, slide_w, slide_h)
  let small = is_small_shape(sp, slide_w, slide_h)
  let near_bottom = is_bottom_edge_shape(sp, slide_h)
  if looks_like_page_number_text(text) && near_bottom && small {
    //("[pptx-noise] drop explicit page-like: " + text)
    return true
  }

  if is_small_plain_page_number(sp, slide_w, slide_h, text) {
    //println("[pptx-noise] drop plain page number: " + text)
    return true
  }

  if looks_like_corner_label_text(text) && corner && small {
    return true
  }

  false
}

///|
/// estimate slide bounds from shape geometry.
/// this is only used for relative edge/corner heuristics.
fn estimate_slide_bounds(shapes : Array[LayoutShape]) -> (Int, Int) {
  if shapes.length() == 0 {
    return (0, 0)
  }

  let mut max_right = 0
  let mut max_bottom = 0

  for sp in shapes {
    if sp.right > max_right {
      max_right = sp.right
    }
    if sp.bottom > max_bottom {
      max_bottom = sp.bottom
    }
  }

  (max_right, max_bottom)
}

///|
fn is_edge_shape(sp : LayoutShape, slide_w : Int, slide_h : Int) -> Bool {
  if slide_w <= 0 || slide_h <= 0 {
    return false
  }

  let left_margin = slide_w / 12
  let right_margin = slide_w / 12
  let top_margin = slide_h / 10
  let bottom_margin = slide_h / 10

  let near_left = sp.shape.x <= left_margin
  let near_right = sp.right >= slide_w - right_margin
  let near_top = sp.shape.y <= top_margin
  let near_bottom = sp.bottom >= slide_h - bottom_margin

  near_left || near_right || near_top || near_bottom
}

///|
fn is_corner_shape(sp : LayoutShape, slide_w : Int, slide_h : Int) -> Bool {
  if slide_w <= 0 || slide_h <= 0 {
    return false
  }

  let left_margin = slide_w / 8
  let right_margin = slide_w / 8
  let top_margin = slide_h / 8
  let bottom_margin = slide_h / 8

  let near_left = sp.shape.x <= left_margin
  let near_right = sp.right >= slide_w - right_margin
  let near_top = sp.shape.y <= top_margin
  let near_bottom = sp.bottom >= slide_h - bottom_margin

  (near_left && near_top) ||
  (near_right && near_top) ||
  (near_left && near_bottom) ||
  (near_right && near_bottom)
}

///|
fn is_small_shape(sp : LayoutShape, slide_w : Int, slide_h : Int) -> Bool {
  if slide_w <= 0 || slide_h <= 0 {
    return false
  }

  let w = sp.shape.w
  let h = sp.shape.h

  let narrow = w <= slide_w / 5
  let low = h <= slide_h / 8
  let tiny_area = w * h <= slide_w * slide_h / 40

  (narrow && low) || tiny_area
}

///|
fn looks_like_page_number_text(s : String) -> Bool {
  let t = normalize_noise_text(s)
  if t == "" {
    return false
  }

  let lower = ascii_lower(t)

  lower.has_prefix("page ") ||
  lower.has_prefix("p. ") ||
  lower.has_prefix("p ") ||
  lower.has_prefix("slide ") ||
  looks_like_page_x_of_y(t)
}

///|
fn looks_like_page_x_of_y(s : String) -> Bool {
  let t = normalize_noise_text(s)
  if t == "" {
    return false
  }

  let slash = find_first_slash(t)
  match slash {
    None => false
    Some(pos) => {
      if pos <= 0 || pos >= t.length() - 1 {
        return false
      }
      let left = t[:pos].trim().to_owned()
      let right = t[pos + 1:].trim().to_owned()
      is_all_digits(left) && is_all_digits(right)
    }
  }
}

///|
fn normalize_shape_text(xml : Bytes) -> String {
  let t = extract_text_runs(xml, 0, xml.length())
  normalize_noise_text(t)
}

///|
fn normalize_noise_text(s : String) -> String {
  normalize_slide_text(s)
}

///|
fn is_all_digits(s : String) -> Bool {
  let t = s.trim().to_owned()
  if t == "" {
    return false
  }

  for c in t.to_array() {
    if !(c >= '0' && c <= '9') {
      return false
    }
  }
  true
}

///|
fn find_first_slash(s : String) -> Int? {
  let cs = s.to_array()
  for i in 0..<cs.length() {
    if cs[i] == '/' {
      return Some(i)
    }
  }
  None
}

///|
/// ASCII-only lowercasing is enough for footer keywords.
fn ascii_lower(s : String) -> String {
  let mut out = ""
  for c in s.to_array() {
    let code = c.to_int()
    if code >= 'A'.to_int() && code <= 'Z'.to_int() {
      let lower = Int::to_char(code + 32)
      match lower {
        Some(v) => out = out + v.to_string()
        None => out = out + c.to_string()
      }
    } else {
      out = out + c.to_string()
    }
  }
  out
}

///|
fn is_bottom_edge_shape(sp : LayoutShape, slide_h : Int) -> Bool {
  if slide_h <= 0 {
    return false
  }

  let bottom_margin = slide_h / 10
  sp.bottom >= slide_h - bottom_margin
}

///|
fn looks_like_corner_label_text(s : String) -> Bool {
  let t = ascii_lower(normalize_noise_text(s))
  t == "draft" || t == "internal" || t == "confidential"
}

///|
fn is_small_plain_page_number(
  sp : LayoutShape,
  slide_w : Int,
  slide_h : Int,
  text : String,
) -> Bool {
  let t = normalize_noise_text(text)
  if !is_all_digits(t) {
    return false
  }

  let n = parse_nonneg_int(t)
  if n <= 0 || n > 30 {
    return false
  }

  if !is_small_shape(sp, slide_w, slide_h) {
    return false
  }

  if !is_bottom_edge_shape(sp, slide_h) {
    return false
  }

  if !is_corner_shape(sp, slide_w, slide_h) {
    return false
  }

  true
}
