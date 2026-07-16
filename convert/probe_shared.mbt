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
      CharCount => "chars"
      LineCount => "lines"
      BlockCount => "blocks"
      ListItemCount => "list_items"
      NodeCount => "nodes"
      MaxDepth => "depth"
      RowCount => "rows"
      ColCount => "cols"
      CellCount => "cells"
      CellEstimate => "estimated_cells"
      OutputCount => "outputs"
      AttachmentCount => "attachments"
      AssetCount => "assets"
      EntryCount => "entries"
      PageCount => "pages"
      SlideCount => "slides"
      SheetCount => "sheets"
      ScalarCount => "scalars"
      ObjectCount => "objects"
      ArrayCount => "arrays"
      HiddenRowCount => "hidden_rows"
      HiddenSheetCount => "hidden_sheets"
      CoveredCellCount => "covered_cells"
      NoteCount => "notes"
      CommentCount => "comments"
      ScannedPageCount => "scanned_pages"
      NativeTextPageCount => "native_text_pages"
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
