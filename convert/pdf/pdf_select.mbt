///|
priv struct PdfSelectDecision {
  selected : PdfBackendResult?
  accepted : Bool
  attempted : Array[PdfBackendResult]
}

///|
fn select_pdf_backend_result(
  results : Array[PdfBackendResult],
  debug? : Bool = false,
) -> PdfSelectDecision {
  let successful : Array[PdfBackendResult] = []
  for r in results {
    if r.exit_status == 0 {
      successful.push(r)
    }
  }

  if successful.length() == 0 {
    let decision = { selected: None, accepted: false, attempted: results }
    debug_print_backend_decision(decision, debug~)
    return decision
  }

  let acceptable : Array[PdfBackendResult] = []
  let degraded : Array[PdfBackendResult] = []

  for r in successful {
    match r.quality {
      Some(q) =>
        if is_quality_failure_for_normal_text(q) {
          degraded.push(r)
        } else {
          acceptable.push(r)
        }
      None => degraded.push(r)
    }
  }

  if acceptable.length() > 0 {
    let best = pick_best_backend_by_score(acceptable)
    let decision = { selected: Some(best), accepted: true, attempted: results }
    debug_print_backend_decision(decision, debug~)
    return decision
  }

  let best_degraded = pick_best_backend_by_score(degraded)
  let decision = {
    selected: Some(best_degraded),
    accepted: false,
    attempted: results,
  }
  debug_print_backend_decision(decision, debug~)
  decision
}

///|
fn pick_best_backend_by_score(
  cands : Array[PdfBackendResult],
) -> PdfBackendResult {
  let first = cands[0]
  let mut best = first
  let mut best_score = backend_selection_score(first)

  for i in 1..<cands.length() {
    let cand = cands[i]
    let sc = backend_selection_score(cand)

    if cand.backend_name == "pdftotext-default" {
      if sc >= best_score - 10 {
        best = cand
        best_score = sc
      }
      continue
    }

    if best.backend_name == "pdftotext-default" {
      if sc >= best_score + 20 {
        best = cand
        best_score = sc
      }
    } else if sc > best_score {
      best = cand
      best_score = sc
    }
  }

  best
}

///|
fn backend_selection_score(r : PdfBackendResult) -> Int {
  let base = r.quality.map(fn(q) { q.score }).unwrap_or(-999999)
  let clipped = count_suspicious_clipped_label_lines(r.text)
  let hard_trunc = count_hard_truncated_label_lines(r.text)
  // conservative pseudo two-column negative guard:
  // prefer extractors with fewer clipped LEFT/RIGHT labeled lines.
  // hard truncation (e.g. sentence tail clipped to "... righ") gets stronger penalty.
  base - clipped * 40 - hard_trunc * 140
}

///|
fn count_suspicious_clipped_label_lines(text : String) -> Int {
  let mut n = 0
  for sv in text.split("\n") {
    let line = sv.to_string().trim().to_string()
    if is_suspicious_clipped_label_line(line) {
      n += 1
    }
  }
  n
}

///|
fn is_suspicious_clipped_label_line(line : String) -> Bool {
  let t = line.trim().to_string()
  if !looks_like_label_token_line_start(t) {
    return false
  }

  // short label lines may be bullets/titles; do not penalize.
  if t.to_array().length() < 20 {
    return false
  }

  // long label lines in this sample family are sentence-like; if they do not
  // end like a sentence, they are likely clipped by extractor ordering/layout.
  !ends_like_sentence(t)
}

///|
fn count_hard_truncated_label_lines(text : String) -> Int {
  let mut n = 0
  for sv in text.split("\n") {
    let line = sv.to_string().trim().to_string()
    if is_hard_truncated_label_line(line) {
      n += 1
    }
  }
  n
}

///|
fn is_hard_truncated_label_line(line : String) -> Bool {
  let t = line.trim().to_string()
  if !is_suspicious_clipped_label_line(t) {
    return false
  }

  if t.to_array().length() < 32 {
    return false
  }

  let mut words = 0
  for sv in t.split(" ") {
    if sv.to_string().trim().to_string() != "" {
      words += 1
    }
  }
  if words < 6 {
    return false
  }

  match last_char(t) {
    Some(ch) => (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
    None => false
  }
}

///|
fn debug_print_backend_decision(
  decision : PdfSelectDecision,
  debug? : Bool = false,
) -> Unit {
  if !debug {
    return
  }

  let selected_name = decision.selected
    .map(fn(s) { s.backend_name })
    .unwrap_or("")

  for r in decision.attempted {
    let status_ok = r.exit_status == 0
    let text_len = r.text.length()
    let selected = r.backend_name == selected_name
    let clipped = count_suspicious_clipped_label_lines(r.text)
    let hard_trunc = count_hard_truncated_label_lines(r.text)
    let sel_score = backend_selection_score(r)
    match r.quality {
      Some(q) =>
        println(
          "[pdf-debug] backend=" +
          r.backend_name +
          " ok=" +
          status_ok.to_string() +
          " len=" +
          text_len.to_string() +
          " empty=" +
          q.effectively_empty.to_string() +
          " key={score:" +
          q.score.to_string() +
          ",low_signal:" +
          q.low_signal.to_string() +
          ",fragmented:" +
          q.fragmented.to_string() +
          ",short_lines:" +
          q.short_lines.to_string() +
          ",clipped_label:" +
          clipped.to_string() +
          ",hard_trunc_label:" +
          hard_trunc.to_string() +
          ",sel_score:" +
          sel_score.to_string() +
          "} selected=" +
          selected.to_string(),
        )
      None =>
        println(
          "[pdf-debug] backend=" +
          r.backend_name +
          " ok=" +
          status_ok.to_string() +
          " len=" +
          text_len.to_string() +
          " empty=n/a key={score:n/a} selected=" +
          selected.to_string(),
        )
    }

    let label_lines = collect_label_debug_lines(r.text, limit=8)
    if label_lines.length() == 0 {
      println("[pdf-debug]   label-lines=none")
    } else {
      for i in 0..<label_lines.length() {
        println(
          "[pdf-debug]   label-line[" +
          (i + 1).to_string() +
          "]=" +
          label_lines[i],
        )
      }
    }
  }

  match decision.selected {
    Some(sel) =>
      println(
        "[pdf-debug] final=" +
        sel.backend_name +
        " accepted=" +
        decision.accepted.to_string(),
      )
    None =>
      println(
        "[pdf-debug] final=none accepted=" + decision.accepted.to_string(),
      )
  }
}

///|
/// debug-only helper: keep lines that are most useful for pseudo two-column
/// diagnosis (LEFT-/RIGHT- label lines and surrounding mixed label fragments).
fn collect_label_debug_lines(text : String, limit? : Int = 8) -> Array[String] {
  let out : Array[String] = []
  for sv in text.split("\n") {
    if out.length() >= limit {
      break
    }

    let line = sv.to_string().trim().to_string()
    if line == "" {
      continue
    }

    if is_label_debug_candidate(line) {
      out.push(line)
    }
  }
  out
}

///|
fn is_label_debug_candidate(line : String) -> Bool {
  let t = line.trim().to_string()
  if t == "" {
    return false
  }

  if looks_like_label_token_line_start(t) {
    return true
  }

  t.contains("LEFT-") || t.contains("RIGHT-")
}
