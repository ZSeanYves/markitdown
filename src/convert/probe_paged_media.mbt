///|
fn pdf_preflight_probe(
  source : @input.InputSource,
  options : ConvertOptions,
) -> ProbeOutcome {
  let prepared_source = match @sourceio.read_source_bytes(source) {
    Ok(payload) => payload.prepared_source
    Err(_) =>
      return probe_outcome("pdf", ["probe_failed"], source, probe_failures=[
        make_probe_failure("pdf", "probe_failed"),
      ])
  }
  let native = @dpdfnative.extract_pdf_native_document(prepared_source)
  match native {
    Ok(document) => {
      let mut native_text_pages = 0
      let mut scanned_pages = 0
      for page in document.pages {
        let mut span_count = 0
        for block in page.text_blocks {
          for line in block.lines {
            span_count += line.spans.length()
          }
        }
        if span_count > 0 {
          native_text_pages += 1
        } else {
          scanned_pages += 1
        }
      }
      let signals = [
        make_probe_signal(PageCount, document.pages.length()),
        make_probe_signal(NativeTextPageCount, native_text_pages),
        make_probe_signal(
          ScannedPageCount,
          scanned_pages,
          note=Some(convert_mode_name(options.mode)),
        ),
      ]
      let summary = [
        "convert_mode=" + convert_mode_name(options.mode),
        "native_text_pages=" + native_text_pages.to_string(),
        "scanned_pages=" + scanned_pages.to_string(),
      ]
      probe_outcome("pdf", summary, prepared_source, probe_signals=signals, probe_artifacts=[
        PdfNativeDocument(document),
      ])
    }
    Err(_error) => {
      let signals = [
        make_probe_signal(
          PageCount,
          0,
          note=Some(convert_mode_name(options.mode)),
        ),
      ]
      let summary = [
        "convert_mode=" + convert_mode_name(options.mode),
        "native_probe=failed",
      ]
      probe_outcome("pdf", summary, prepared_source, probe_signals=signals, probe_failures=[
        make_probe_failure("pdf", "native_probe_failed"),
      ])
    }
  }
}
