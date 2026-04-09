///|
/// temporary local debug switch for PDF extractor selection
const PDF_EXTRACT_DEBUG = false

///|
priv struct PdfSelectDecision {
  selected : PdfBackendResult?
  accepted : Bool
  attempted : Array[PdfBackendResult]
}

///|
fn select_pdf_backend_result(
  results : Array[PdfBackendResult],
) -> PdfSelectDecision {
  let successful : Array[PdfBackendResult] = []
  for r in results {
    if r.exit_status == 0 {
      successful.push(r)
    }
  }

  if successful.length() == 0 {
    return { selected: None, accepted: false, attempted: results }
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
    debug_print_selected(
      best.backend_name,
      best.quality.map(fn(q) { q.score }).unwrap_or(0),
    )
    return { selected: Some(best), accepted: true, attempted: results }
  }

  let best_degraded = pick_best_backend_by_score(degraded)
  debug_print_selected(
    best_degraded.backend_name,
    best_degraded.quality.map(fn(q) { q.score }).unwrap_or(0),
  )
  { selected: Some(best_degraded), accepted: false, attempted: results }
}

///|
fn pick_best_backend_by_score(
  cands : Array[PdfBackendResult],
) -> PdfBackendResult {
  let first = cands[0]
  let mut best = first
  let mut best_score = first.quality.map(fn(q) { q.score }).unwrap_or(-999999)

  for i in 1..<cands.length() {
    let cand = cands[i]
    let sc = cand.quality.map(fn(q) { q.score }).unwrap_or(-999999)

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
fn debug_print_selected(label : String, score : Int) -> Unit {
  if !PDF_EXTRACT_DEBUG {
    return
  }
  println("[pdf-debug] selected=" + label + " score=" + score.to_string())
}

///|
fn debug_print_backend_result(r : PdfBackendResult) -> Unit {
  if !PDF_EXTRACT_DEBUG {
    return
  }

  let status = r.exit_status.to_string()
  let qscore = r.quality.map(fn(q) { q.score.to_string() }).unwrap_or("n/a")
  println(
    "[pdf-debug] backend=" +
    r.backend_name +
    " status=" +
    status +
    " score=" +
    qscore,
  )

  match r.quality {
    Some(q) =>
      println(
        "[pdf-debug] quality: empty=" +
        q.effectively_empty.to_string() +
        " low_signal=" +
        q.low_signal.to_string() +
        " fragmented=" +
        q.fragmented.to_string() +
        " ocr_garbage=" +
        q.ocr_garbage.to_string(),
      )
    None => ()
  }
}
