///|
priv struct PdfSelectDecision {
  selected : PdfBackendResult?
  accepted : Bool
  attempted : Array[PdfBackendResult]
}

///|
fn select_pdf_backend_result(
  results : Array[PdfBackendResult],
  debug~ : Bool = false,
) -> PdfSelectDecision {
  let successful : Array[PdfBackendResult] = []
  for r in results {
    if r.exit_status == 0 {
      successful.push(r)
    }
  }

  if successful.length() == 0 {
    let decision = { selected: None, accepted: false, attempted: results }
    debug_print_backend_decision(decision, debug=debug)
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
    debug_print_backend_decision(decision, debug=debug)
    return decision
  }

  let best_degraded = pick_best_backend_by_score(degraded)
  let decision = {
    selected: Some(best_degraded),
    accepted: false,
    attempted: results,
  }
  debug_print_backend_decision(decision, debug=debug)
  decision
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
fn debug_print_backend_decision(
  decision : PdfSelectDecision,
  debug~ : Bool = false,
) -> Unit {
  if !debug {
    return
  }

  let selected_name = decision.selected.map(fn(s) { s.backend_name }).unwrap_or(
    "",
  )

  for r in decision.attempted {
    let status_ok = r.exit_status == 0
    let text_len = r.text.length()
    let selected = r.backend_name == selected_name
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
