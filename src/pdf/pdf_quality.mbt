///|
priv struct PdfTextQuality {
  effectively_empty : Bool
  low_signal : Bool
  fragmented : Bool
  ocr_garbage : Bool
  score : Int
  signal_chars : Int
  total_lines : Int
  nonblank_lines : Int
  short_lines : Int
  suspicious_short_alpha_lines : Int
}

///|
fn is_effectively_empty_pdf_text(text : String) -> Bool {
  let q = analyze_pdf_text_quality(text)
  q.effectively_empty
}

///|
fn analyze_pdf_text_quality(text : String) -> PdfTextQuality {
  let s = normalize_pdf_text_for_quality(text)
  let trimmed = s.trim().to_string()

  if trimmed == "" {
    return {
      effectively_empty: true,
      low_signal: true,
      fragmented: true,
      ocr_garbage: true,
      score: -9999,
      signal_chars: 0,
      total_lines: 0,
      nonblank_lines: 0,
      short_lines: 0,
      suspicious_short_alpha_lines: 0,
    }
  }

  let mut total = 0
  let mut blank = 0
  let mut short = 0
  let mut sum_len = 0
  let mut suspicious_short_alpha = 0
  let mut signal_chars = 0

  for c in trimmed.to_array() {
    if c != ' ' && c != '\t' && c != '\n' && c != '\r' {
      signal_chars += 1
    }
  }

  for sv in s.split("\n") {
    let line = sv.to_string().trim().to_string()
    total += 1
    if line == "" {
      blank += 1
      continue
    }

    let len = line.to_array().length()
    sum_len += len

    if len <= 2 {
      short += 1
    }

    if len >= 1 && len <= 3 && is_all_ascii_letters(line) {
      suspicious_short_alpha += 1
    }
  }

  let nonblank = total - blank
  let avg_len = if nonblank <= 0 { 0 } else { sum_len / nonblank }
  let fragmented = if nonblank <= 0 {
    true
  } else {
    short * 100 >= nonblank * 60 ||
    suspicious_short_alpha * 100 >= nonblank * 25
  }
  let low_signal = signal_chars < 20
  let effectively_empty = trimmed == "" || low_signal
  let ocr_garbage = nonblank > 0 &&
    suspicious_short_alpha * 100 >= nonblank * 35 &&
    avg_len <= 6

  {
    effectively_empty,
    low_signal,
    fragmented,
    ocr_garbage,
    score: avg_len * 10 - blank * 3 - short * 5 - suspicious_short_alpha * 25,
    signal_chars,
    total_lines: total,
    nonblank_lines: nonblank,
    short_lines: short,
    suspicious_short_alpha_lines: suspicious_short_alpha,
  }
}

///|
fn is_quality_failure_for_normal_text(q : PdfTextQuality) -> Bool {
  q.effectively_empty || q.low_signal || q.fragmented || q.ocr_garbage
}

///|
fn normalize_pdf_text_for_quality(text : String) -> String {
  text.replace(old="\r\n", new="\n").replace(old="\r", new="\n")
}

///|
fn is_all_ascii_letters(s : String) -> Bool {
  let t = s.trim().to_string()
  if t == "" {
    return false
  }

  for c in t.to_array() {
    if !((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) {
      return false
    }
  }

  true
}
