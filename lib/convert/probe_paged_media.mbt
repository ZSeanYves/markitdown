///|
async fn pdf_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  match @dpdfnative.open_pdf_native_session(source) {
    Ok(session) => {
      let facts = @dpdfnative.pdf_structural_facts(session)
      let signals : Array[ProbeSignal] = []
      if facts.page_count is Some(count) {
        signals.push(make_probe_signal(PageCount, count))
      }
      let summary = [
        "convert_mode=" + convert_mode_name(options.mode),
        "probe_phase=structural",
        "text_classification=deferred",
        "structural_status=" + facts.reason,
      ]
      probe_outcome("pdf", summary, source, probe_signals=signals, probe_artifacts=[
        PdfNativeSession(session),
      ])
    }
    Err(_error) => {
      let summary = [
        "convert_mode=" + convert_mode_name(options.mode),
        "native_probe=failed",
      ]
      probe_outcome("pdf", summary, source, probe_failures=[
        make_probe_failure("pdf", "native_probe_failed"),
      ])
    }
  }
}
