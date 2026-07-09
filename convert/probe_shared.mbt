///|
fn probe_outcome(
  summary_format : String,
  summary_parts : Array[String],
  prepared_source : @input.InputSource,
  probe_signals? : Array[ProbeSignal] = [],
  probe_failures? : Array[ProbeFailure] = [],
  probe_artifacts? : Array[RouteProbeArtifact] = [],
) -> ProbeOutcome {
  {
    probe_signals,
    probe_failures,
    summary_format,
    summary_parts,
    prepared_source,
    probe_artifacts,
  }
}

///|
fn probe_summary_line(label : String, value : Int, limit : Int?) -> String {
  match limit {
    Some(limit_value) =>
      label + "=" + value.to_string() + "/limit=" + limit_value.to_string()
    None => label + "=" + value.to_string()
  }
}

///|
fn signal_summary_lines(signals : Array[ProbeSignal]) -> Array[String] {
  let parts : Array[String] = []
  for signal in signals {
    let label = match signal.kind {
      ProbeSignalKind::CharCount => "chars"
      ProbeSignalKind::LineCount => "lines"
      ProbeSignalKind::BlockCount => "blocks"
      ProbeSignalKind::ListItemCount => "list_items"
      ProbeSignalKind::NodeCount => "nodes"
      ProbeSignalKind::MaxDepth => "depth"
      ProbeSignalKind::RowCount => "rows"
      ProbeSignalKind::ColCount => "cols"
      ProbeSignalKind::CellCount => "cells"
      ProbeSignalKind::CellEstimate => "estimated_cells"
      ProbeSignalKind::OutputCount => "outputs"
      ProbeSignalKind::AttachmentCount => "attachments"
      ProbeSignalKind::AssetCount => "assets"
      ProbeSignalKind::EntryCount => "entries"
      ProbeSignalKind::PageCount => "pages"
      ProbeSignalKind::SlideCount => "slides"
      ProbeSignalKind::SheetCount => "sheets"
      ProbeSignalKind::ScalarCount => "scalars"
      ProbeSignalKind::ObjectCount => "objects"
      ProbeSignalKind::ArrayCount => "arrays"
      ProbeSignalKind::HiddenRowCount => "hidden_rows"
      ProbeSignalKind::HiddenSheetCount => "hidden_sheets"
      ProbeSignalKind::CoveredCellCount => "covered_cells"
      ProbeSignalKind::NoteCount => "notes"
      ProbeSignalKind::CommentCount => "comments"
      ProbeSignalKind::ScannedPageCount => "scanned_pages"
      ProbeSignalKind::NativeTextPageCount => "native_text_pages"
    }
    parts.push(probe_summary_line(label, signal.observed, signal.limit))
  }
  parts
}

///|
fn unavailable_probe(
  summary_format : String,
  prepared_source : @input.InputSource,
) -> ProbeOutcome {
  probe_outcome(summary_format, ["unavailable"], prepared_source, probe_failures=[
    make_probe_failure(summary_format, "probe_unavailable"),
  ])
}

///|
fn generic_preflight_probe(
  source : @input.InputSource,
  format : @input.DetectedFormat,
) -> ProbeOutcome {
  probe_outcome(
    @input.detected_format_name(format),
    [@fmeta.route_name(@fmeta.canonical_route_for_format(format))],
    source,
  )
}
