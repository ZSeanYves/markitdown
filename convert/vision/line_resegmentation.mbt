///|
pub fn resegment_ocr_page_lines_from_words(page : OcrPageModel) -> OcrPageModel {
  if page.words.length() == 0 {
    return page
  }

  if !all_nonblank_words_have_valid_geometry(page.words) {
    return page_with_resegmentation_warning(
      page, "line resegmentation skipped: missing word geometry",
    )
  }

  let candidate_words = normalized_resegmentable_words(page.words)
  if candidate_words.length() == 0 {
    return page
  }

  {
    page_index: page.page_index,
    width: page.width,
    height: page.height,
    lines: resegment_ocr_words_into_lines(candidate_words),
    words: page.words,
    provider: page.provider,
    source_kind: page.source_kind,
    warnings: page.warnings,
  }
}

///|
pub fn resegment_ocr_words_into_lines(
  words : Array[OcrSignalWord],
) -> Array[OcrSignalLine] {
  let candidate_words = normalized_resegmentable_words(words)
  if candidate_words.length() == 0 {
    return []
  }

  let ordered = candidate_words.copy()
  ordered.sort_by(compare_words_by_center_y_then_x)

  let bands : Array[WordBand] = []
  for word in ordered {
    let band_index = matching_word_band_index(bands, word)
    if band_index >= 0 {
      bands[band_index].words.push(word)
    } else {
      bands.push({ words: [word] })
    }
  }

  let lines : Array[OcrSignalLine] = []
  for band in bands {
    let segments = split_word_band_into_segments(band.words)
    for segment in segments {
      lines.push(make_resegmented_line(segment, lines.length()))
    }
  }

  let sorted = lines.copy()
  sorted.sort_by(compare_resegmented_lines_by_geometry)
  let renumbered : Array[OcrSignalLine] = []
  for line in sorted {
    renumbered.push({
      text: line.text,
      bbox: line.bbox,
      confidence: line.confidence,
      words: line.words,
      line_index: renumbered.length(),
    })
  }
  renumbered
}

///|
priv struct WordBand {
  words : Array[OcrSignalWord]
}

///|
fn all_nonblank_words_have_valid_geometry(words : Array[OcrSignalWord]) -> Bool {
  let mut saw_nonblank = false
  for word in words {
    if word.text.trim() != "" {
      saw_nonblank = true
      if !bbox_is_valid(word.bbox) {
        return false
      }
    }
  }
  saw_nonblank
}

///|
fn normalized_resegmentable_words(
  words : Array[OcrSignalWord],
) -> Array[OcrSignalWord] {
  let out : Array[OcrSignalWord] = []
  for word in words {
    let text = word.text.trim().to_owned()
    if text != "" && bbox_is_valid(word.bbox) {
      out.push({
        text,
        bbox: word.bbox,
        confidence: word.confidence,
        word_index: word.word_index,
      })
    }
  }
  out
}

///|
fn page_with_resegmentation_warning(
  page : OcrPageModel,
  warning : String,
) -> OcrPageModel {
  {
    page_index: page.page_index,
    width: page.width,
    height: page.height,
    lines: page.lines,
    words: page.words,
    provider: page.provider,
    source_kind: page.source_kind,
    warnings: dedupe_resegmentation_warnings(page.warnings + [warning]),
  }
}

///|
fn matching_word_band_index(
  bands : Array[WordBand],
  word : OcrSignalWord,
) -> Int {
  let mut best_index = -1
  let mut best_delta = 1.0 / 0.0
  for i in 0..<bands.length() {
    let band_words = bands[i].words
    if word_fits_band(word, band_words) {
      let delta = reseg_double_abs(
        bbox_center_y(word.bbox) - bbox_center_y(words_bbox_union(band_words)),
      )
      if best_index < 0 || delta < best_delta {
        best_index = i
        best_delta = delta
      }
    }
  }
  best_index
}

///|
fn word_fits_band(
  word : OcrSignalWord,
  band_words : Array[OcrSignalWord],
) -> Bool {
  let band_bbox = words_bbox_union(band_words)
  let band_height = average_word_height(band_words)
  let min_height = reseg_double_min(word.bbox.height, band_height)
  let center_delta = reseg_double_abs(
    bbox_center_y(word.bbox) - bbox_center_y(band_bbox),
  )
  vertical_overlap(word.bbox, band_bbox) >= min_height * 0.25 ||
  center_delta <= resegmentation_max_center_delta(band_height, word.bbox.height)
}

///|
fn split_word_band_into_segments(
  words : Array[OcrSignalWord],
) -> Array[Array[OcrSignalWord]] {
  if words.length() == 0 {
    return []
  }

  let ordered = words.copy()
  ordered.sort_by(compare_words_by_x_then_y)
  let threshold = large_gap_split_threshold(ordered)
  let segments : Array[Array[OcrSignalWord]] = []
  let mut current : Array[OcrSignalWord] = [ordered[0]]

  for i in 1..<ordered.length() {
    let previous_word = current[current.length() - 1]
    let word = ordered[i]
    let gap = word.bbox.x - bbox_right(previous_word.bbox)
    if gap > threshold {
      segments.push(current)
      current = [word]
    } else {
      current.push(word)
    }
  }

  segments.push(current)
  segments
}

///|
fn make_resegmented_line(
  words : Array[OcrSignalWord],
  line_index : Int,
) -> OcrSignalLine {
  let ordered = words.copy()
  ordered.sort_by(compare_words_by_x_then_y)
  let parts : Array[String] = []
  let mut bbox = unknown_bbox()
  let mut confidence_total = 0.0
  let mut confidence_count = 0
  for word in ordered {
    let text = word.text.trim().to_owned()
    if text != "" {
      parts.push(text)
    }
    bbox = bbox_union(bbox, word.bbox)
    if word.confidence >= 0.0 {
      confidence_total = confidence_total + word.confidence
      confidence_count = confidence_count + 1
    }
  }
  {
    text: parts.join(" "),
    bbox,
    confidence: if confidence_count == 0 {
      -1.0
    } else {
      confidence_total / confidence_count.to_double()
    },
    words: ordered,
    line_index,
  }
}

///|
fn words_bbox_union(words : Array[OcrSignalWord]) -> VisionBBox {
  let mut bbox = unknown_bbox()
  for word in words {
    bbox = bbox_union(bbox, word.bbox)
  }
  bbox
}

///|
fn average_word_height(words : Array[OcrSignalWord]) -> Double {
  if words.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  for word in words {
    total = total + word.bbox.height
  }
  total / words.length().to_double()
}

///|
fn large_gap_split_threshold(words : Array[OcrSignalWord]) -> Double {
  reseg_double_max(80.0, average_word_height(words) * 3.0)
}

///|
fn resegmentation_max_center_delta(
  band_height : Double,
  word_height : Double,
) -> Double {
  reseg_double_max(6.0, reseg_double_min(band_height, word_height) * 0.6)
}

///|
fn vertical_overlap(a : VisionBBox, b : VisionBBox) -> Double {
  reseg_double_max(
    0.0,
    reseg_double_min(bbox_bottom(a), bbox_bottom(b)) -
    reseg_double_max(a.y, b.y),
  )
}

///|
fn bbox_center_y(bbox : VisionBBox) -> Double {
  bbox.y + bbox.height / 2.0
}

///|
fn compare_words_by_center_y_then_x(
  a : OcrSignalWord,
  b : OcrSignalWord,
) -> Int {
  let a_center = bbox_center_y(a.bbox)
  let b_center = bbox_center_y(b.bbox)
  if a_center < b_center {
    return -1
  }
  if a_center > b_center {
    return 1
  }
  compare_words_by_x_then_y(a, b)
}

///|
fn compare_words_by_x_then_y(a : OcrSignalWord, b : OcrSignalWord) -> Int {
  if a.bbox.x < b.bbox.x {
    return -1
  }
  if a.bbox.x > b.bbox.x {
    return 1
  }
  if a.bbox.y < b.bbox.y {
    return -1
  }
  if a.bbox.y > b.bbox.y {
    return 1
  }
  a.word_index - b.word_index
}

///|
fn compare_resegmented_lines_by_geometry(
  a : OcrSignalLine,
  b : OcrSignalLine,
) -> Int {
  if a.bbox.y < b.bbox.y {
    return -1
  }
  if a.bbox.y > b.bbox.y {
    return 1
  }
  if a.bbox.x < b.bbox.x {
    return -1
  }
  if a.bbox.x > b.bbox.x {
    return 1
  }
  a.line_index - b.line_index
}

///|
fn dedupe_resegmentation_warnings(warnings : Array[String]) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[String] = []
  for warning in warnings {
    if warning != "" && !seen.contains(warning) {
      seen.set(warning, true)
      out.push(warning)
    }
  }
  out
}

///|
fn reseg_double_abs(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn reseg_double_min(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn reseg_double_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
