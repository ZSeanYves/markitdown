///|
struct DebugCliOptions {
  output_kind : @cor.DebugOutputKind
  with_ir : Bool
  with_metadata_summary : Bool
  with_normalization : Bool
}

///|
struct DebugParseResult {
  doc : @cor.Document
  format : String
  document_properties : @cor.MetadataDocumentProperties?
  xlsx_workbook : @xlsx.XlsxWorkbookModel?
  xlsx_profile : @xlsx.XlsxProfileReport?
  epub_inspect : @epubpkg.EpubInspectReport?
  zip_inspect : @zipconv.ZipInspectReport?
  zip_profile : @zipconv.ZipProfileReport?
  pdf_model : @pdfmodel.PdfDocumentModel?
  pdf_sections : Array[@cor.DebugSection]?
  temp_root : String?
}

///|
struct LayoutAssistEvalRow {
  sample_id : String
  split : String
  file : String
  page_count : Int
  feature_count : Int
  prediction_count : Int
  provider : String
  mode : String
  label_counts : Map[String, Int]
  reason_counts : Map[String, Int]
  predictions_truncated : Bool
  warning_count : Int
}

///|
async fn cmd_debug_inspect(input : String, opts : DebugCliOptions) -> Unit {
  match build_debug_report(input, opts) {
    Ok(report) => println(@cor.render_debug_report(report, opts.output_kind))
    Err(msg) => exit_error(msg)
  }
}

///|
async fn cmd_debug_layout_assist_eval(
  opts : DebugCliOptions,
  split : String?,
) -> Unit {
  match render_layout_assist_eval(opts.output_kind, split) {
    Ok(rendered) => println(rendered)
    Err(msg) => exit_error(msg)
  }
}

///|
fn cmd_debug_providers(
  opts : DebugCliOptions,
  include_ocr : Bool,
  include_layout_assist : Bool,
  probe : Bool,
) -> Unit {
  if !include_ocr && !include_layout_assist {
    exit_error(
      "debug providers requires at least one target: --ocr or --layout-assist",
    )
    return
  }

  let rendered = render_provider_listing(
    opts.output_kind,
    include_ocr,
    include_layout_assist,
    probe,
  )
  println(rendered)
}

///|
async fn cmd_debug_legacy_pdf(
  scope : String,
  input : String,
  output : String?,
  with_metadata : Bool,
) -> Unit {
  let format = detect_input_format(input)
  if format != "pdf" {
    exit_error("legacy PDF debug mode only supports .pdf input: " + input)
    return
  }

  println(
    "warning: legacy PDF debug mode is deprecated; use debug <input> or debug --json <input>",
  )
  println(
    "warning: legacy scope \"" +
    scope +
    "\" now maps to unified debug inspect output",
  )

  let opts : DebugCliOptions = {
    output_kind: @cor.DebugOutputKind::HumanReadable,
    with_ir: false,
    with_metadata_summary: true,
    with_normalization: true,
  }

  match build_debug_report(input, opts) {
    Ok(report) =>
      println(
        @cor.render_debug_report(report, @cor.DebugOutputKind::HumanReadable),
      )
    Err(msg) => {
      exit_error(msg)
      return
    }
  }

  let resolved_output = @clisup.resolve_output_path(input, output)
  let output_root_opt = match resolved_output {
    Some(path) => Some(@clisup.dirname_of_path(path))
    None => None
  }
  let parse_out_dir = output_root_opt.unwrap_or("")

  if output_root_opt is Some(out_root) {
    @clisup.ensure_dir_tree(out_root) catch {
      e => {
        exit_error("create output dir failed: " + e.to_string())
        return
      }
    }
  }

  let doc = @pdfconv.parse_pdf(
    input,
    parse_out_dir,
    6,
    None,
    false,
    false,
    false,
  ) catch {
    e => {
      exit_error("parse failed: " + e.to_string())
      return
    }
  }

  match
    @clisup.write_document_output(input, "pdf", doc, output, with_metadata) {
    Ok(_) => ()
    Err(msg) => exit_error(msg)
  }
}

///|
fn render_provider_listing(
  output_kind : @cor.DebugOutputKind,
  include_ocr : Bool,
  include_layout_assist : Bool,
  probe : Bool,
) -> String {
  let layout_infos = if include_layout_assist {
    @pdfdebug.list_layout_assist_providers()
  } else {
    []
  }

  match output_kind {
    @cor.DebugOutputKind::Json =>
      render_provider_listing_json(
        layout_infos, include_ocr, include_layout_assist, probe,
      )
    _ =>
      render_provider_listing_text(
        layout_infos, include_ocr, include_layout_assist, probe,
      )
  }
}

///|
fn render_provider_listing_json(
  layout_infos : Array[@pdfdebug.LayoutAssistProviderInfo],
  include_ocr : Bool,
  include_layout_assist : Bool,
  probe : Bool,
) -> String {
  let fields : Array[String] = [
    @cor.json_string("kind") + ": " + @cor.json_string("provider_listing"),
    @cor.json_string("probe_requested") + ": " + @cor.bool_json(probe),
    @cor.json_string("include_ocr") + ": " + @cor.bool_json(include_ocr),
    @cor.json_string("include_layout_assist") +
    ": " +
    @cor.bool_json(include_layout_assist),
  ]

  if include_ocr {
    fields.push(
      @cor.json_string("ocr_status") +
      ": " +
      @cor.object_json([
        @cor.json_string("state") + ": " + @cor.json_string("rebuilding"),
        @cor.json_string("probe_requested") + ": " + @cor.bool_json(probe),
        @cor.json_string("message") +
        ": " +
        @cor.json_string(
          "OCR provider execution has been retired while the OCRPageModel pipeline is rebuilt.",
        ),
      ]),
    )
  }

  if include_layout_assist {
    let items : Array[String] = []
    for info in layout_infos {
      items.push(render_layout_provider_json(info))
    }
    fields.push(
      @cor.json_string("layout_assist_providers") +
      ": " +
      @cor.array_json(items),
    )
  }

  @cor.object_json(fields)
}

///|
fn render_provider_listing_text(
  layout_infos : Array[@pdfdebug.LayoutAssistProviderInfo],
  include_ocr : Bool,
  include_layout_assist : Bool,
  probe : Bool,
) -> String {
  let lines : Array[String] = [
    "provider listing",
    "probe_requested=" + probe.to_string(),
  ]

  if include_ocr {
    lines.push("")
    lines.push("[ocr]")
    lines.push("state=rebuilding")
    lines.push("probe_requested=" + probe.to_string())
    lines.push(
      "message=OCR provider execution has been retired while the OCRPageModel pipeline is rebuilt.",
    )
  }

  if include_layout_assist {
    lines.push("")
    lines.push("[layout-assist]")
    for info in layout_infos {
      lines.push(render_layout_provider_text(info))
    }
  }

  lines.join("\n")
}

///|
async fn render_layout_assist_eval(
  output_kind : @cor.DebugOutputKind,
  split : String?,
) -> Result[String, String] {
  let rows = collect_layout_assist_eval_rows(split) catch {
    e => return Err("layout-assist eval failed: " + e.to_string())
  }
  match output_kind {
    @cor.DebugOutputKind::Json =>
      Ok(render_layout_assist_eval_json(rows, split))
    _ => Ok(render_layout_assist_eval_text(rows, split))
  }
}

///|
async fn collect_layout_assist_eval_rows(
  split : String?,
) -> Array[LayoutAssistEvalRow] {
  let manifest_path = resolve_layout_assist_eval_manifest_path()
  if !@fs.path_exists(manifest_path) {
    fail("layout-assist eval manifest not found: " + manifest_path)
  }
  let text = @fs.read_file_to_string(manifest_path, encoding="utf8") catch {
    e => fail("read layout-assist eval manifest failed: " + e.to_string())
  }
  let rows : Array[LayoutAssistEvalRow] = []
  let want_split = split.map(fn(s) { s.trim().to_lower() })
  let raw_lines = text.split("\n")
  let lines : Array[String] = []
  for raw in raw_lines {
    let line = raw.replace(old="\r", new="").to_owned()
    if line != "" {
      lines.push(line)
    }
  }
  for i = 1; i < lines.length(); i = i + 1 {
    let raw = lines[i].trim_end().to_owned()
    if raw.trim() == "" {
      continue
    }
    let cols = split_layout_assist_tsv_line(raw)
    if cols.length() < 7 {
      continue
    }
    let sample_id = cols[0].trim().to_owned()
    let pdf_path = cols[1].trim().to_owned()
    let row_split = cols[3].trim().to_owned()
    let normalized_split = row_split.to_lower()
    match want_split {
      Some(expected) =>
        if expected.to_owned() != "" && normalized_split != expected.to_owned() {
          continue
        }
      None => ()
    }
    let resolved = resolve_layout_assist_sample_path(pdf_path)
    let model = match
      @pdfapi.extract_document_model(resolved, @pdfapi.default_pdf_config()) {
      Ok(doc) => doc
      Err(e) =>
        fail(
          "layout-assist eval pdf extract failed for " +
          sample_id +
          ": " +
          e.to_string(),
        )
    }
    let summary = @pdfdebug.build_pdf_layout_assist_summary(model, 6)
    let provider = choose_layout_assist_eval_provider(summary)
    let mode = choose_layout_assist_eval_mode(summary)
    rows.push({
      sample_id,
      split: row_split,
      file: pdf_path,
      page_count: model.page_count,
      feature_count: summary.feature_count,
      prediction_count: summary.prediction_count,
      provider,
      mode,
      label_counts: summary.label_counts,
      reason_counts: summary.reason_counts,
      predictions_truncated: summary.prediction_count > 12,
      warning_count: summary.warning_count,
    })
  }
  rows
}

///|
fn render_layout_assist_eval_json(
  rows : Array[LayoutAssistEvalRow],
  split : String?,
) -> String {
  let fields : Array[String] = [
    @cor.json_string("kind") + ": " + @cor.json_string("layout_assist_eval"),
    @cor.json_string("split") + ": " + @cor.json_string_opt(split),
  ]
  let summary = layout_assist_eval_summary_json(rows)
  fields.push(@cor.json_string("summary") + ": " + summary)
  let items : Array[String] = []
  for row in rows {
    items.push(layout_assist_eval_row_json(row))
  }
  fields.push(@cor.json_string("rows") + ": " + @cor.array_json(items))
  @cor.object_json(fields)
}

///|
fn render_layout_assist_eval_text(
  rows : Array[LayoutAssistEvalRow],
  split : String?,
) -> String {
  let lines : Array[String] = ["layout assist eval"]
  lines.push("split=" + split.unwrap_or("all"))
  lines.push("sample_count=" + rows.length().to_string())
  lines.push("summary=" + layout_assist_eval_summary_line(rows))
  for row in rows {
    lines.push("")
    lines.push(
      "- " + row.sample_id + " split=" + row.split + " file=" + row.file,
    )
    lines.push(
      "  provider=" +
      row.provider +
      " mode=" +
      row.mode +
      " pages=" +
      row.page_count.to_string() +
      " feature_count=" +
      row.feature_count.to_string() +
      " prediction_count=" +
      row.prediction_count.to_string() +
      " warning_count=" +
      row.warning_count.to_string(),
    )
    lines.push(
      "  label_counts=" + render_string_int_map_inline(row.label_counts),
    )
    lines.push(
      "  top_reasons=" +
      render_top_string_int_entries_inline(row.reason_counts, 3),
    )
  }
  lines.join("\n")
}

///|
fn layout_assist_eval_summary_json(rows : Array[LayoutAssistEvalRow]) -> String {
  let label_counts = Map([])
  let reason_counts = Map([])
  let mut sample_count = 0
  let mut zero_prediction_count = 0
  let mut warning_count = 0
  let mut total_features = 0
  let mut total_predictions = 0
  let files_with_predictions : Array[String] = []
  let files_without_predictions : Array[String] = []
  for row in rows {
    sample_count += 1
    total_features += row.feature_count
    total_predictions += row.prediction_count
    warning_count += row.warning_count
    if row.prediction_count == 0 {
      zero_prediction_count += 1
      files_without_predictions.push(row.sample_id)
    } else {
      files_with_predictions.push(row.sample_id)
    }
    for entry in sorted_layout_eval_map_entries(row.label_counts) {
      bump_count_by(label_counts, entry.0, entry.1)
    }
    for entry in sorted_layout_eval_map_entries(row.reason_counts) {
      bump_count_by(reason_counts, entry.0, entry.1)
    }
  }
  @cor.object_json([
    @cor.json_string("sample_count") + ": " + sample_count.to_string(),
    @cor.json_string("total_features") + ": " + total_features.to_string(),
    @cor.json_string("total_predictions") + ": " + total_predictions.to_string(),
    @cor.json_string("zero_prediction_count") +
    ": " +
    zero_prediction_count.to_string(),
    @cor.json_string("warning_count") + ": " + warning_count.to_string(),
    @cor.json_string("label_counts") +
    ": " +
    @cor.string_int_kv_json(sorted_layout_eval_map_entries(label_counts)),
    @cor.json_string("top_reasons") +
    ": " +
    @cor.string_int_kv_json(
      take_first_string_int_entries(
        sorted_layout_eval_map_entries_by_count(reason_counts),
        5,
      ),
    ),
    @cor.json_string("files_with_predictions") +
    ": " +
    @cor.string_array_json(files_with_predictions),
    @cor.json_string("zero_prediction_files") +
    ": " +
    @cor.string_array_json(files_without_predictions),
  ])
}

///|
fn layout_assist_eval_summary_line(rows : Array[LayoutAssistEvalRow]) -> String {
  let sample_count = rows.length()
  let mut total_features = 0
  let mut total_predictions = 0
  let mut zero_prediction_count = 0
  for row in rows {
    total_features += row.feature_count
    total_predictions += row.prediction_count
    if row.prediction_count == 0 {
      zero_prediction_count += 1
    }
  }
  "features=" +
  total_features.to_string() +
  " predictions=" +
  total_predictions.to_string() +
  " zero_prediction_files=" +
  zero_prediction_count.to_string() +
  "/" +
  sample_count.to_string()
}

///|
fn layout_assist_eval_row_json(row : LayoutAssistEvalRow) -> String {
  @cor.object_json([
    @cor.json_string("sample_id") + ": " + @cor.json_string(row.sample_id),
    @cor.json_string("split") + ": " + @cor.json_string(row.split),
    @cor.json_string("file") + ": " + @cor.json_string(row.file),
    @cor.json_string("page_count") + ": " + row.page_count.to_string(),
    @cor.json_string("feature_count") + ": " + row.feature_count.to_string(),
    @cor.json_string("prediction_count") +
    ": " +
    row.prediction_count.to_string(),
    @cor.json_string("provider") + ": " + @cor.json_string(row.provider),
    @cor.json_string("mode") + ": " + @cor.json_string(row.mode),
    @cor.json_string("label_counts") +
    ": " +
    @cor.string_int_kv_json(sorted_layout_eval_map_entries(row.label_counts)),
    @cor.json_string("top_reasons") +
    ": " +
    @cor.string_int_kv_json(
      take_first_string_int_entries(
        sorted_layout_eval_map_entries_by_count(row.reason_counts),
        5,
      ),
    ),
    @cor.json_string("predictions_truncated") +
    ": " +
    @cor.bool_json(row.predictions_truncated),
    @cor.json_string("warning_count") + ": " + row.warning_count.to_string(),
  ])
}

///|
fn choose_layout_assist_eval_provider(
  summary : @pdfdebug.LayoutAssistSummary,
) -> String {
  if summary.predictions.length() > 0 {
    return summary.predictions[0].provider
  }
  for info in summary.providers {
    if info.name == "heuristic-layout-assist" {
      return info.name
    }
  }
  summary.providers[0].name
}

///|
fn choose_layout_assist_eval_mode(
  summary : @pdfdebug.LayoutAssistSummary,
) -> String {
  if summary.predictions.length() > 0 {
    return layout_assist_mode_name(summary.predictions[0].mode)
  }
  for info in summary.providers {
    if info.name == "heuristic-layout-assist" {
      return layout_assist_mode_name(info.mode)
    }
  }
  layout_assist_mode_name(summary.providers[0].mode)
}

///|
fn resolve_layout_assist_eval_manifest_path() -> String {
  let quality_lab_root = match @sys.get_env_var("MARKITDOWN_QUALITY_LAB") {
    Some(root) =>
      if root.trim() != "" {
        Some(trim_trailing_slash(root.trim().to_owned()))
      } else {
        None
      }
    None => None
  }
  match quality_lab_root {
    Some(root) => {
      let path = root + "/pdf_model_training/manifest.tsv"
      if @fs.path_exists(path) {
        return path
      }
    }
    None => ()
  }
  let repo_local_lab = "markitdown-quality-lab/pdf_model_training/manifest.tsv"
  if @fs.path_exists(repo_local_lab) {
    return repo_local_lab
  }
  let repo_tracked = "debug/testdata/layout_assist_eval/manifest.tsv"
  if @fs.path_exists(repo_tracked) {
    return repo_tracked
  }
  let sibling_lab = "../markitdown-quality-lab/pdf_model_training/manifest.tsv"
  if @fs.path_exists(sibling_lab) {
    return sibling_lab
  }
  repo_tracked
}

///|
fn resolve_layout_assist_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }
  let quality_corpus_root = match
    @sys.get_env_var("MARKITDOWN_QUALITY_CORPUS") {
    Some(root) =>
      if root.trim() != "" {
        Some(trim_trailing_slash(root.trim().to_owned()))
      } else {
        None
      }
    None => None
  }
  if path.has_prefix(".external/quality_corpus/") {
    let suffix = path[25:].to_owned()
    match quality_corpus_root {
      Some(root) => {
        let candidate = root + "/" + suffix
        if @fs.path_exists(candidate) {
          return candidate
        }
      }
      None => ()
    }
    match @sys.get_env_var("MARKITDOWN_QUALITY_LAB") {
      Some(root) =>
        if root.trim() != "" {
          let candidate = trim_trailing_slash(root.trim().to_owned()) +
            "/external_quality/" +
            suffix
          if @fs.path_exists(candidate) {
            return candidate
          }
        }
      None => ()
    }
    let repo_local_candidate = "markitdown-quality-lab/external_quality/" + suffix
    if @fs.path_exists(repo_local_candidate) {
      return repo_local_candidate
    }
    let sibling_candidate = "../markitdown-quality-lab/external_quality/" + suffix
    if @fs.path_exists(sibling_candidate) {
      return sibling_candidate
    }
  }
  if path.has_prefix(".external/layout_model/") {
    let suffix = path[23:].to_owned()
    let quality_lab_layout_root = match
      @sys.get_env_var("MARKITDOWN_LAYOUT_LAB") {
      Some(root) =>
        if root.trim() != "" {
          Some(trim_trailing_slash(root.trim().to_owned()))
        } else {
          None
        }
      None =>
        match @sys.get_env_var("MARKITDOWN_QUALITY_LAB") {
          Some(root) =>
            if root.trim() != "" {
              Some(
                trim_trailing_slash(root.trim().to_owned()) +
                "/pdf_model_training",
              )
            } else {
              None
            }
          None => None
        }
    }
    let mapped = map_layout_lab_legacy_suffix(suffix)
    match quality_lab_layout_root {
      Some(root) => {
        let candidate = root + "/" + mapped
        if @fs.path_exists(candidate) {
          return candidate
        }
      }
      None => ()
    }
    let repo_local_candidate = "markitdown-quality-lab/pdf_model_training/" +
      mapped
    if @fs.path_exists(repo_local_candidate) {
      return repo_local_candidate
    }
    let sibling_candidate = "../markitdown-quality-lab/pdf_model_training/" +
      mapped
    if @fs.path_exists(sibling_candidate) {
      return sibling_candidate
    }
  }
  let fallback = "../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }
  fail("layout-assist eval sample not found: " + path)
}

///|
fn map_layout_lab_legacy_suffix(suffix : String) -> String {
  if suffix.has_prefix("datasets/") {
    return suffix
  }
  if suffix.has_prefix("labels/") {
    return suffix
  }
  if suffix.has_prefix("models/") {
    return suffix
  }
  if suffix.has_prefix("features/") {
    return "local_eval/" + suffix
  }
  if suffix.has_prefix("eval/") {
    return "local_eval/" + suffix
  }
  if suffix.has_prefix("eval_") {
    return "reports/" + suffix
  }
  "reports/" + suffix
}

///|
fn trim_trailing_slash(path : String) -> String {
  if path.length() > 1 && path[path.length() - 1] == '/' {
    path[:path.length() - 1].to_owned()
  } else {
    path
  }
}

///|
fn bump_count_by(counts : Map[String, Int], key : String, delta : Int) -> Unit {
  let prev = counts.get(key).unwrap_or(0)
  counts.set(key, prev + delta)
}

///|
fn sorted_layout_eval_map_entries(
  counts : Map[String, Int],
) -> Array[(String, Int)] {
  let keys : Array[String] = []
  for k in counts {
    keys.push(k.0)
  }
  keys.sort()
  let out : Array[(String, Int)] = []
  for key in keys {
    out.push((key, counts.get(key).unwrap_or(0)))
  }
  out
}

///|
fn sorted_layout_eval_map_entries_by_count(
  counts : Map[String, Int],
) -> Array[(String, Int)] {
  let out = sorted_layout_eval_map_entries(counts)
  for i = 0; i < out.length(); i = i + 1 {
    for j = i + 1; j < out.length(); j = j + 1 {
      let a = out[i]
      let b = out[j]
      if b.1 > a.1 || (b.1 == a.1 && b.0 < a.0) {
        out[i] = b
        out[j] = a
      }
    }
  }
  out
}

///|
fn take_first_string_int_entries(
  entries : Array[(String, Int)],
  limit : Int,
) -> Array[(String, Int)] {
  let out : Array[(String, Int)] = []
  let capped = if entries.length() < limit { entries.length() } else { limit }
  for i = 0; i < capped; i = i + 1 {
    out.push(entries[i])
  }
  out
}

///|
fn render_string_int_map_inline(counts : Map[String, Int]) -> String {
  let parts : Array[String] = []
  for entry in sorted_layout_eval_map_entries(counts) {
    parts.push(entry.0 + "=" + entry.1.to_string())
  }
  if parts.length() == 0 {
    "{}"
  } else {
    "{" + parts.join(", ") + "}"
  }
}

///|
fn render_top_string_int_entries_inline(
  counts : Map[String, Int],
  limit : Int,
) -> String {
  let parts : Array[String] = []
  for
    entry in take_first_string_int_entries(
      sorted_layout_eval_map_entries_by_count(counts),
      limit,
    ) {
    parts.push(entry.0 + "=" + entry.1.to_string())
  }
  if parts.length() == 0 {
    "[]"
  } else {
    "[" + parts.join(", ") + "]"
  }
}

///|
fn split_layout_assist_tsv_line(line : String) -> Array[String] {
  let cols : Array[String] = []
  for part in line.split("\t") {
    cols.push(part.to_owned())
  }
  cols
}

///|
fn render_layout_provider_json(
  info : @pdfdebug.LayoutAssistProviderInfo,
) -> String {
  @cor.object_json([
    @cor.json_string("name") + ": " + @cor.json_string(info.name),
    @cor.json_string("mode") +
    ": " +
    @cor.json_string(layout_assist_mode_name(info.mode)),
    @cor.json_string("version") + ": " + @cor.json_string_opt(info.version),
    @cor.json_string("available") + ": " + @cor.bool_json(info.available),
  ])
}

///|
fn render_layout_provider_text(
  info : @pdfdebug.LayoutAssistProviderInfo,
) -> String {
  "- " +
  info.name +
  " mode=" +
  layout_assist_mode_name(info.mode) +
  " available=" +
  info.available.to_string() +
  " version=" +
  info.version.unwrap_or("")
}

///|
fn layout_assist_mode_name(mode : @pdfdebug.LayoutAssistMode) -> String {
  match mode {
    @pdfdebug.LayoutAssistMode::ReportOnly => "report_only"
    @pdfdebug.LayoutAssistMode::Advisory => "advisory"
    @pdfdebug.LayoutAssistMode::GatedNormal => "gated_normal"
  }
}

///|
async fn build_debug_report(
  input : String,
  opts : DebugCliOptions,
) -> Result[@cor.DebugReport, String] {
  if !@fs.path_exists(input) {
    return Err("debug inspect input not found: " + input)
  }

  let format = detect_input_format(input)
  if format == "unknown" {
    return Err("unsupported input format for debug inspect: " + input)
  }

  let parsed = parse_for_debug(input, format) catch {
    e => return Err("debug inspect parse failed: " + e.to_string())
  }
  defer cleanup_debug_temp_root(parsed.temp_root)

  let source_name = @cor.basename(input)
  let report = @cor.new_debug_report(source_name, format, "debug.inspect")
  report.summary = "debug inspect completed without writing markdown or metadata sidecars"

  let route = dispatcher_route_name(format)
  @cor.debug_report_add_section(
    report,
    @cor.debug_section(
      "format",
      "standard",
      true,
      Some("detected format and converter route"),
      @cor.object_json([
        @cor.json_string("detected_format") + ": " + @cor.json_string(format),
        @cor.json_string("dispatcher_route") + ": " + @cor.json_string(route),
        @cor.json_string("converter") + ": " + @cor.json_string(route),
      ]),
    ),
  )

  @cor.debug_report_add_section(
    report,
    debug_document_section(parsed, source_name),
  )
  @cor.debug_report_add_section(report, debug_structure_section(parsed.doc))
  @cor.debug_report_add_section(report, debug_assets_section(parsed.doc))
  @cor.debug_report_add_section(
    report,
    debug_metadata_section(
      parsed.doc,
      parsed.document_properties,
      opts.with_metadata_summary,
    ),
  )

  if opts.with_ir {
    @cor.debug_report_add_section(report, debug_ir_section(parsed.doc))
  }

  if opts.with_normalization || format == "pdf" {
    @cor.debug_report_add_section(
      report,
      debug_normalization_section(parsed, opts.with_normalization),
    )
  }

  for section in debug_format_specific_sections(parsed) {
    @cor.debug_report_add_section(report, section)
  }

  if parsed.doc.passthrough_markdown.val is Some(_) {
    @cor.debug_report_add_warning(
      report, "passthrough_markdown present; debug structure is derived from preserved source context",
    )
  }

  Ok(report)
}

///|
async fn parse_for_debug(input : String, format : String) -> DebugParseResult {
  let temp_root = if format_requires_debug_out_dir(format) {
    Some(debug_temp_root_for_input(input))
  } else {
    None
  }
  match temp_root {
    Some(root) => debug_recreate_clean_dir(root)
    None => ()
  }

  let out_dir = temp_root.unwrap_or("")
  let document_properties = read_document_properties(input, format)

  match format {
    "xlsx" => {
      let workbook = @xlsx.inspect_xlsx_with_profile(input)
      let wb = workbook.0
      let profile = workbook.1
      let doc = @xlsx.parse_xlsx(input, out_dir, 6)
      {
        doc,
        format,
        document_properties,
        xlsx_workbook: Some(wb),
        xlsx_profile: profile,
        epub_inspect: None,
        zip_inspect: None,
        zip_profile: None,
        pdf_model: None,
        pdf_sections: None,
        temp_root,
      }
    }
    "epub" => {
      let inspect = @epubconv.inspect_epub(input)
      let doc = @epubconv.parse_epub(input, out_dir, 6)
      {
        doc,
        format,
        document_properties,
        xlsx_workbook: None,
        xlsx_profile: None,
        epub_inspect: Some(inspect),
        zip_inspect: None,
        zip_profile: None,
        pdf_model: None,
        pdf_sections: None,
        temp_root,
      }
    }
    "zip" => {
      let inspect = @zipconv.inspect_zip(input)
      let profiled = @zipconv.parse_zip_with_profile(input, out_dir, 6)
      {
        doc: profiled.0,
        format,
        document_properties,
        xlsx_workbook: None,
        xlsx_profile: None,
        epub_inspect: None,
        zip_inspect: Some(inspect),
        zip_profile: profiled.1,
        pdf_model: None,
        pdf_sections: None,
        temp_root,
      }
    }
    "pdf" => {
      let model = match
        @pdfapi.extract_document_model(input, @pdfapi.default_pdf_config()) {
        Ok(doc) => doc
        Err(e) => raise @cor.AppError("pdf inspect failed: " + e.to_string())
      }
      let pdf_sections = @pdfdebug.build_pdf_debug_sections(model, 6)
      let opts : @conv.ConvertOptions = {
        out_dir: None,
        max_heading: Some(6),
        pdf_enhance_mode: None,
        pdf_extract_debug: false,
        pdf_dump_selected_raw: false,
        pdf_pipeline_debug: false,
      }
      let doc = match @conv.parse_to_ir(input, opts) {
        Ok(v) => v
        Err(e) => raise @cor.AppError(e.to_string())
      }
      {
        doc,
        format,
        document_properties,
        xlsx_workbook: None,
        xlsx_profile: None,
        epub_inspect: None,
        zip_inspect: None,
        zip_profile: None,
        pdf_model: Some(model),
        pdf_sections: Some(pdf_sections),
        temp_root,
      }
    }
    _ => {
      let opts : @conv.ConvertOptions = {
        out_dir: temp_root,
        max_heading: Some(6),
        pdf_enhance_mode: None,
        pdf_extract_debug: false,
        pdf_dump_selected_raw: false,
        pdf_pipeline_debug: false,
      }
      let doc = match @conv.parse_to_ir(input, opts) {
        Ok(v) => v
        Err(e) => raise @cor.AppError(e.to_string())
      }
      {
        doc,
        format,
        document_properties,
        xlsx_workbook: None,
        xlsx_profile: None,
        epub_inspect: None,
        zip_inspect: None,
        zip_profile: None,
        pdf_model: None,
        pdf_sections: None,
        temp_root,
      }
    }
  }
}

///|
fn debug_document_section(
  parsed : DebugParseResult,
  source_name : String,
) -> @cor.DebugSection {
  let props = parsed.document_properties
  let fields : Array[String] = [
    @cor.json_string("source_name") + ": " + @cor.json_string(source_name),
    @cor.json_string("page_count") +
    ": " +
    int_opt_json(page_count_for_debug(parsed)),
    @cor.json_string("slide_count") +
    ": " +
    int_opt_json(slide_count_for_debug(parsed)),
    @cor.json_string("sheet_count") +
    ": " +
    int_opt_json(sheet_count_for_debug(parsed)),
    @cor.json_string("entry_count") +
    ": " +
    int_opt_json(entry_count_for_debug(parsed)),
    @cor.json_string("chapter_count") +
    ": " +
    int_opt_json(chapter_count_for_debug(parsed)),
    @cor.json_string("document_properties_available") +
    ": " +
    @cor.bool_json(props is Some(_)),
  ]
  match props {
    Some(docprops) =>
      fields.push(
        @cor.json_string("document_properties") +
        ": " +
        metadata_document_properties_json(docprops),
      )
    None => ()
  }
  @cor.debug_section(
    "document",
    "standard",
    true,
    Some("top-level document properties and coarse counts"),
    @cor.object_json(fields),
  )
}

///|
fn debug_structure_section(doc : @cor.Document) -> @cor.DebugSection {
  let stats = collect_block_stats(doc)
  @cor.debug_section(
    "structure",
    "standard",
    true,
    Some("IR block and inline summary"),
    @cor.object_json([
      @cor.json_string("block_count") + ": " + stats.block_count.to_string(),
      @cor.json_string("block_kind_counts") +
      ": " +
      @cor.string_int_kv_json(stats.block_kind_counts),
      @cor.json_string("heading_count") + ": " + stats.heading_count.to_string(),
      @cor.json_string("table_count") + ": " + stats.table_count.to_string(),
      @cor.json_string("image_count") + ": " + stats.image_count.to_string(),
      @cor.json_string("link_count") + ": " + stats.link_count.to_string(),
      @cor.json_string("blank_line_count") +
      ": " +
      stats.blank_line_count.to_string(),
    ]),
  )
}

///|
fn debug_assets_section(doc : @cor.Document) -> @cor.DebugSection {
  let paths = sorted_asset_paths(doc)
  let preview = take_first_strings(paths, 12)
  @cor.debug_section(
    "assets",
    "standard",
    true,
    Some("asset origins derived from conversion without writing sidecars"),
    @cor.object_json([
      @cor.json_string("asset_count") +
      ": " +
      doc.asset_origins.val.length().to_string(),
      @cor.json_string("asset_paths") + ": " + @cor.string_array_json(preview),
      @cor.json_string("paths_truncated") +
      ": " +
      @cor.bool_json(paths.length() > preview.length()),
    ]),
  )
}

///|
fn debug_metadata_section(
  doc : @cor.Document,
  props : @cor.MetadataDocumentProperties?,
  include_origin_summary : Bool,
) -> @cor.DebugSection {
  let origin_summary = if include_origin_summary {
    metadata_origin_summary_json(doc)
  } else {
    @cor.object_json([@cor.json_string("included") + ": false"])
  }
  @cor.debug_section(
    "metadata",
    "standard",
    true,
    Some("metadata sidecar availability and origin summary"),
    @cor.object_json([
      @cor.json_string("document_properties_available") +
      ": " +
      @cor.bool_json(props is Some(_)),
      @cor.json_string("block_origin_count") +
      ": " +
      block_origin_count(doc).to_string(),
      @cor.json_string("asset_origin_count") +
      ": " +
      doc.asset_origins.val.length().to_string(),
      @cor.json_string("origin_summary") + ": " + origin_summary,
    ]),
  )
}

///|
fn debug_ir_section(doc : @cor.Document) -> @cor.DebugSection {
  let items : Array[String] = []
  for i in 0..<doc.blocks.val.length() {
    let block = doc.blocks.val[i]
    let origin = origin_json(doc.block_origins.val[i])
    items.push(
      @cor.object_json([
        @cor.json_string("index") + ": " + i.to_string(),
        @cor.json_string("kind") +
        ": " +
        @cor.json_string(block_kind_name(block)),
        @cor.json_string("preview") +
        ": " +
        @cor.json_string(block_preview(block, 160)),
        @cor.json_string("origin") + ": " + origin,
      ]),
    )
  }
  @cor.debug_section(
    "ir",
    "optional",
    true,
    Some("IR block previews for developer inspection"),
    @cor.array_json(items),
  )
}

///|
fn debug_normalization_section(
  parsed : DebugParseResult,
  explicit_requested : Bool,
) -> @cor.DebugSection {
  match parsed.pdf_model {
    Some(model) => {
      let output_summary = aggregate_pdf_normalization(
        model,
        @cor.NormalizeProfile::PdfText,
      )
      let compare_summary = aggregate_pdf_normalization(
        model,
        @cor.NormalizeProfile::PdfCompareText,
      )
      @cor.debug_section(
        "normalization",
        "standard",
        true,
        Some("PDF text normalization aggregate summary"),
        @cor.object_json([
          @cor.json_string("available") + ": true",
          @cor.json_string("output_profile") +
          ": " +
          @cor.json_string("PdfText"),
          @cor.json_string("comparison_profile") +
          ": " +
          @cor.json_string("PdfCompareText"),
          @cor.json_string("output_summary") +
          ": " +
          text_normalization_summary_json(output_summary),
          @cor.json_string("comparison_summary") +
          ": " +
          text_normalization_summary_json(compare_summary),
        ]),
      )
    }
    None =>
      @cor.debug_section(
        "normalization",
        "standard",
        explicit_requested,
        Some(
          "normalization summary is currently only aggregated for PDF debug inspect",
        ),
        @cor.object_json([
          @cor.json_string("available") + ": false",
          @cor.json_string("reason") +
          ": " +
          @cor.json_string(
            "normalization summary is not yet aggregated for this format",
          ),
        ]),
      )
  }
}

///|
fn debug_format_specific_sections(
  parsed : DebugParseResult,
) -> Array[@cor.DebugSection] {
  match parsed.format {
    "pdf" => parsed.pdf_sections.unwrap_or([])
    "xlsx" =>
      parsed.xlsx_workbook
      .map(fn(wb) { [debug_xlsx_section(wb, parsed.xlsx_profile)] })
      .unwrap_or([])
    "html" => [debug_html_section(parsed.doc)]
    "zip" =>
      parsed.zip_inspect
      .map(fn(report) { [debug_zip_section(report, parsed.zip_profile)] })
      .unwrap_or([])
    "epub" =>
      parsed.epub_inspect
      .map(fn(report) { [debug_epub_section(report)] })
      .unwrap_or([])
    "docx" => [debug_docx_section(parsed.doc)]
    "pptx" => [debug_pptx_section(parsed.doc)]
    _ => []
  }
}

///|
fn debug_xlsx_section(
  workbook : @xlsx.XlsxWorkbookModel,
  profile : @xlsx.XlsxProfileReport?,
) -> @cor.DebugSection {
  let mut merged_ranges = 0
  let mut formula_cells = 0
  let mut table_rows = 0
  let state_counts = Map([])
  let semantic_counts = Map([])
  for sheet in workbook.sheets {
    merged_ranges += sheet.merged_ranges.length()
    table_rows += sheet.table_rows.length()
    bump_string_count(state_counts, xlsx_sheet_state_name(sheet.state))
    for cell in sheet.cells {
      if cell.formula_text is Some(_) {
        formula_cells += 1
      }
      bump_string_count(
        semantic_counts,
        xlsx_semantic_type_name(cell.semantic_type),
      )
    }
  }
  let profile_stage_count = match profile {
    Some(rep) => rep.stages.length()
    None => 0
  }
  @cor.debug_section(
    "format_specific",
    "xlsx",
    true,
    Some("XLSX workbook inspect summary"),
    @cor.object_json([
      @cor.json_string("sheet_count") +
      ": " +
      workbook.sheets.length().to_string(),
      @cor.json_string("uses_date_1904") +
      ": " +
      @cor.bool_json(workbook.uses_date_1904),
      @cor.json_string("sheet_state_counts") +
      ": " +
      map_string_int_json(state_counts),
      @cor.json_string("merged_ranges_count") + ": " + merged_ranges.to_string(),
      @cor.json_string("formula_cells_count") + ": " + formula_cells.to_string(),
      @cor.json_string("table_rows_count") + ": " + table_rows.to_string(),
      @cor.json_string("semantic_type_counts") +
      ": " +
      map_string_int_json(semantic_counts),
      @cor.json_string("profile_stage_count") +
      ": " +
      profile_stage_count.to_string(),
    ]),
  )
}

///|
fn debug_html_section(doc : @cor.Document) -> @cor.DebugSection {
  let stats = collect_block_stats(doc)
  let boundary = html_asset_boundary_summary(doc)
  @cor.debug_section(
    "format_specific",
    "html",
    true,
    Some("HTML structural and asset boundary summary"),
    @cor.object_json([
      @cor.json_string("table_count") + ": " + stats.table_count.to_string(),
      @cor.json_string("link_count") + ": " + stats.link_count.to_string(),
      @cor.json_string("image_count") + ": " + stats.image_count.to_string(),
      @cor.json_string("asset_boundary") + ": " + boundary,
    ]),
  )
}

///|
fn debug_zip_section(
  inspect : @zipconv.ZipInspectReport,
  profile : @zipconv.ZipProfileReport?,
) -> @cor.DebugSection {
  let action_counts = Map([])
  let kind_counts = Map([])
  let format_counts = Map([])
  let mut unsafe_count = 0
  for entry in inspect.entries {
    bump_string_count(action_counts, zip_action_name(entry.action))
    bump_string_count(kind_counts, zip_kind_name(entry.entry_kind))
    match entry.dispatch_format {
      Some(fmt) => bump_string_count(format_counts, fmt)
      None => ()
    }
    if entry.entry_kind == @zipconv.ZipInspectEntryKind::UnsafePath {
      unsafe_count += 1
    }
  }
  let profile_summary_lines = match profile {
    Some(rep) => take_first_strings(rep.summary_lines, 8)
    None => []
  }
  @cor.debug_section(
    "format_specific",
    "zip",
    true,
    Some("ZIP entry inspection summary"),
    @cor.object_json([
      @cor.json_string("entry_count") + ": " + inspect.entry_count.to_string(),
      @cor.json_string("action_counts") +
      ": " +
      map_string_int_json(action_counts),
      @cor.json_string("entry_kind_counts") +
      ": " +
      map_string_int_json(kind_counts),
      @cor.json_string("dispatch_format_counts") +
      ": " +
      map_string_int_json(format_counts),
      @cor.json_string("unsafe_entry_count") + ": " + unsafe_count.to_string(),
      @cor.json_string("profile_summary_lines") +
      ": " +
      @cor.string_array_json(profile_summary_lines),
    ]),
  )
}

///|
fn debug_epub_section(
  inspect : @epubpkg.EpubInspectReport,
) -> @cor.DebugSection {
  let mut warning_spine_items = 0
  let actions = Map([])
  for item in inspect.spine_items {
    bump_string_count(actions, item.action)
    if item.action != "convert" {
      warning_spine_items += 1
    }
  }
  @cor.debug_section(
    "format_specific",
    "epub",
    true,
    Some("EPUB package inspect summary"),
    @cor.object_json([
      @cor.json_string("rootfile_path") +
      ": " +
      @cor.json_string(inspect.rootfile_path),
      @cor.json_string("manifest_count") +
      ": " +
      inspect.manifest_count.to_string(),
      @cor.json_string("spine_count") + ": " + inspect.spine_count.to_string(),
      @cor.json_string("nav_path") +
      ": " +
      @cor.json_string_opt(inspect.nav_path),
      @cor.json_string("cover_path") +
      ": " +
      @cor.json_string_opt(inspect.cover_path),
      @cor.json_string("guide_cover_path") +
      ": " +
      @cor.json_string_opt(inspect.guide_cover_path),
      @cor.json_string("has_encryption") +
      ": " +
      @cor.bool_json(inspect.has_encryption),
      @cor.json_string("spine_action_counts") +
      ": " +
      map_string_int_json(actions),
      @cor.json_string("warning_spine_items") +
      ": " +
      warning_spine_items.to_string(),
    ]),
  )
}

///|
fn debug_docx_section(doc : @cor.Document) -> @cor.DebugSection {
  let stats = collect_block_stats(doc)
  let counts = origin_dimension_counts(doc)
  @cor.debug_section(
    "format_specific",
    "docx",
    true,
    Some("DOCX origin-derived structural summary"),
    @cor.object_json([
      @cor.json_string("paragraph_like_count") +
      ": " +
      paragraph_like_count(doc).to_string(),
      @cor.json_string("table_count") + ": " + stats.table_count.to_string(),
      @cor.json_string("image_count") + ": " + stats.image_count.to_string(),
      @cor.json_string("link_count") + ": " + stats.link_count.to_string(),
      @cor.json_string("origin_object_ref_count") +
      ": " +
      counts.object_ref_count.to_string(),
      @cor.json_string("origin_relationship_id_count") +
      ": " +
      counts.relationship_id_count.to_string(),
      @cor.json_string("key_path_count") +
      ": " +
      counts.key_path_count.to_string(),
    ]),
  )
}

///|
fn debug_pptx_section(doc : @cor.Document) -> @cor.DebugSection {
  let stats = collect_block_stats(doc)
  let hidden_slides = hidden_slide_count(doc)
  let notes = note_block_count(doc)
  let slide_count = distinct_slide_count(doc)
  @cor.debug_section(
    "format_specific",
    "pptx",
    true,
    Some("PPTX slide-derived structural summary"),
    @cor.object_json([
      @cor.json_string("slide_count") + ": " + slide_count.to_string(),
      @cor.json_string("hidden_slide_count") + ": " + hidden_slides.to_string(),
      @cor.json_string("note_block_count") + ": " + notes.to_string(),
      @cor.json_string("image_count") + ": " + stats.image_count.to_string(),
      @cor.json_string("table_count") + ": " + stats.table_count.to_string(),
      @cor.json_string("link_count") + ": " + stats.link_count.to_string(),
    ]),
  )
}

///|
struct BlockStats {
  block_count : Int
  heading_count : Int
  table_count : Int
  image_count : Int
  link_count : Int
  blank_line_count : Int
  block_kind_counts : Array[(String, Int)]
}

///|
fn collect_block_stats(doc : @cor.Document) -> BlockStats {
  let counts = Map([])
  let mut heading_count = 0
  let mut table_count = 0
  let mut image_count = 0
  let mut link_count = 0
  let mut blank_line_count = 0

  for block in doc.blocks.val {
    let name = block_kind_name(block)
    bump_string_count(counts, name)
    match block {
      @cor.Block::Heading(_, _) | @cor.Block::RichHeading(_, _) =>
        heading_count += 1
      @cor.Block::Table(_) | @cor.Block::RichTable(_) => table_count += 1
      @cor.Block::Image(_, _) | @cor.Block::ImageBlock(_) => image_count += 1
      @cor.Block::BlankLine => blank_line_count += 1
      _ => ()
    }
    link_count += block_link_count(block)
  }

  {
    block_count: doc.blocks.val.length(),
    heading_count,
    table_count,
    image_count,
    link_count,
    blank_line_count,
    block_kind_counts: sorted_map_entries(counts),
  }
}

///|
fn block_kind_name(block : @cor.Block) -> String {
  match block {
    @cor.Block::Heading(_, _) => "Heading"
    @cor.Block::RichHeading(_, _) => "RichHeading"
    @cor.Block::Paragraph(_) => "Paragraph"
    @cor.Block::RichParagraph(_) => "RichParagraph"
    @cor.Block::ListItem(_, _, _) => "ListItem"
    @cor.Block::RichListItem(_, _, _) => "RichListItem"
    @cor.Block::BlockQuote(_) => "BlockQuote"
    @cor.Block::RichBlockQuote(_) => "RichBlockQuote"
    @cor.Block::CodeBlock(_) => "CodeBlock"
    @cor.Block::Table(_) => "Table"
    @cor.Block::RichTable(_) => "RichTable"
    @cor.Block::Image(_, _) => "Image"
    @cor.Block::ImageBlock(_) => "ImageBlock"
    @cor.Block::BlankLine => "BlankLine"
  }
}

///|
fn block_preview(block : @cor.Block, limit : Int) -> String {
  let text = match block {
    @cor.Block::Heading(_, v) => v
    @cor.Block::RichHeading(_, xs) => render_inline_preview(xs)
    @cor.Block::Paragraph(v) => v
    @cor.Block::RichParagraph(xs) => render_inline_preview(xs)
    @cor.Block::ListItem(_, _, v) => v
    @cor.Block::RichListItem(_, _, xs) => render_inline_preview(xs)
    @cor.Block::BlockQuote(v) => v
    @cor.Block::RichBlockQuote(xs) => render_inline_preview(xs)
    @cor.Block::CodeBlock(v) => v
    @cor.Block::Table(rows) => rows_preview(rows)
    @cor.Block::RichTable(table) => rows_preview(table.rows)
    @cor.Block::Image(alt, path) => alt + " -> " + path
    @cor.Block::ImageBlock(img) =>
      img.alt_text.unwrap_or("") +
      " -> " +
      img.path +
      img.caption.map(fn(v) { " (" + v + ")" }).unwrap_or("")
    @cor.Block::BlankLine => ""
  }
  shorten_debug_text(text, limit)
}

///|
fn rows_preview(rows : Array[Array[String]]) -> String {
  if rows.is_empty() {
    return "(empty table)"
  }
  let first = rows[0].join(" | ")
  if rows.length() == 1 {
    first
  } else {
    first + " …"
  }
}

///|
fn render_inline_preview(xs : Array[@cor.Inline]) -> String {
  let out = StringBuilder::new()
  for x in xs {
    match x {
      @cor.Inline::Text(v) => out.write_string(v)
      @cor.Inline::Break => out.write_string("<br>")
      @cor.Inline::Link(text, href) => {
        out.write_string(text)
        out.write_string(" -> ")
        out.write_string(href)
      }
    }
  }
  out.to_string()
}

///|
fn block_link_count(block : @cor.Block) -> Int {
  match block {
    @cor.Block::RichHeading(_, xs) => inline_link_count(xs)
    @cor.Block::RichParagraph(xs) => inline_link_count(xs)
    @cor.Block::RichListItem(_, _, xs) => inline_link_count(xs)
    @cor.Block::RichBlockQuote(xs) => inline_link_count(xs)
    _ => 0
  }
}

///|
fn inline_link_count(xs : Array[@cor.Inline]) -> Int {
  let mut count = 0
  for x in xs {
    match x {
      @cor.Inline::Link(_, _) => count += 1
      _ => ()
    }
  }
  count
}

///|
struct OriginDimensionCounts {
  object_ref_count : Int
  relationship_id_count : Int
  key_path_count : Int
}

///|
fn origin_dimension_counts(doc : @cor.Document) -> OriginDimensionCounts {
  let mut object_ref_count = 0
  let mut relationship_id_count = 0
  let mut key_path_count = 0
  for origin in doc.block_origins.val {
    match origin {
      Some(v) => {
        if v.object_ref is Some(_) {
          object_ref_count += 1
        }
        if v.relationship_id is Some(_) {
          relationship_id_count += 1
        }
        if v.key_path is Some(_) {
          key_path_count += 1
        }
      }
      None => ()
    }
  }
  { object_ref_count, relationship_id_count, key_path_count }
}

///|
fn paragraph_like_count(doc : @cor.Document) -> Int {
  let mut count = 0
  for block in doc.blocks.val {
    match block {
      @cor.Block::Paragraph(_)
      | @cor.Block::RichParagraph(_)
      | @cor.Block::BlockQuote(_)
      | @cor.Block::RichBlockQuote(_)
      | @cor.Block::ListItem(_, _, _)
      | @cor.Block::RichListItem(_, _, _) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn hidden_slide_count(doc : @cor.Document) -> Int {
  let seen = Map([])
  for block in doc.blocks.val {
    match block {
      @cor.Block::Heading(_, text) =>
        if text.contains("(hidden)") {
          seen.set(text, true)
        }
      _ => ()
    }
  }
  seen.length()
}

///|
fn note_block_count(doc : @cor.Document) -> Int {
  let mut count = 0
  for i in 0..<doc.blocks.val.length() {
    let block = doc.blocks.val[i]
    let origin = doc.block_origins.val[i]
    let key_path = match origin {
      Some(v) => v.key_path.unwrap_or("")
      None => ""
    }
    if key_path.contains("notes") {
      match block {
        @cor.Block::Paragraph(_)
        | @cor.Block::RichParagraph(_)
        | @cor.Block::ListItem(_, _, _)
        | @cor.Block::RichListItem(_, _, _) => count += 1
        _ => ()
      }
    }
  }
  count
}

///|
fn distinct_slide_count(doc : @cor.Document) -> Int {
  let seen = Map([])
  for origin in doc.block_origins.val {
    match origin {
      Some(v) =>
        match v.slide {
          Some(slide) => seen.set(slide.to_string(), true)
          None => ()
        }
      None => ()
    }
  }
  seen.length()
}

///|
fn sorted_asset_paths(doc : @cor.Document) -> Array[String] {
  let paths : Array[String] = []
  for entry in doc.asset_origins.val {
    let (path, _) = entry
    paths.push(path)
  }
  paths.sort()
  paths
}

///|
fn metadata_origin_summary_json(doc : @cor.Document) -> String {
  let block_sources = Map([])
  let block_pages = Map([])
  let block_slides = Map([])
  let block_sheets = Map([])
  for origin in doc.block_origins.val {
    match origin {
      Some(v) => {
        match v.source_name {
          Some(name) => bump_string_count(block_sources, name)
          None => ()
        }
        match v.page {
          Some(page) => bump_string_count(block_pages, page.to_string())
          None => ()
        }
        match v.slide {
          Some(slide) => bump_string_count(block_slides, slide.to_string())
          None => ()
        }
        match v.sheet {
          Some(sheet) => bump_string_count(block_sheets, sheet)
          None => ()
        }
      }
      None => ()
    }
  }
  @cor.object_json([
    @cor.json_string("source_names") + ": " + map_string_int_json(block_sources),
    @cor.json_string("pages") + ": " + map_string_int_json(block_pages),
    @cor.json_string("slides") + ": " + map_string_int_json(block_slides),
    @cor.json_string("sheets") + ": " + map_string_int_json(block_sheets),
  ])
}

///|
fn block_origin_count(doc : @cor.Document) -> Int {
  let mut count = 0
  for origin in doc.block_origins.val {
    if origin is Some(_) {
      count += 1
    }
  }
  count
}

///|
fn origin_json(origin : @cor.Origin?) -> String {
  match origin {
    None => "null"
    Some(v) =>
      @cor.object_json([
        @cor.json_string("source_name") +
        ": " +
        @cor.json_string_opt(v.source_name),
        @cor.json_string("page") + ": " + int_opt_json(v.page),
        @cor.json_string("slide") + ": " + int_opt_json(v.slide),
        @cor.json_string("sheet") + ": " + @cor.json_string_opt(v.sheet),
        @cor.json_string("block_index") + ": " + int_opt_json(v.block_index),
        @cor.json_string("line_start") + ": " + int_opt_json(v.line_start),
        @cor.json_string("line_end") + ": " + int_opt_json(v.line_end),
        @cor.json_string("row_index") + ": " + int_opt_json(v.row_index),
        @cor.json_string("column_index") + ": " + int_opt_json(v.column_index),
        @cor.json_string("object_ref") +
        ": " +
        @cor.json_string_opt(v.object_ref),
        @cor.json_string("relationship_id") +
        ": " +
        @cor.json_string_opt(v.relationship_id),
        @cor.json_string("key_path") + ": " + @cor.json_string_opt(v.key_path),
      ])
  }
}

///|
fn metadata_document_properties_json(
  props : @cor.MetadataDocumentProperties,
) -> String {
  @cor.object_json([
    @cor.json_string("title") + ": " + @cor.json_string_opt(props.title),
    @cor.json_string("subject") + ": " + @cor.json_string_opt(props.subject),
    @cor.json_string("creator") + ": " + @cor.json_string_opt(props.creator),
    @cor.json_string("language") + ": " + @cor.json_string_opt(props.language),
    @cor.json_string("identifier") +
    ": " +
    @cor.json_string_opt(props.identifier),
    @cor.json_string("publisher") + ": " + @cor.json_string_opt(props.publisher),
    @cor.json_string("description") +
    ": " +
    @cor.json_string_opt(props.description),
    @cor.json_string("keywords") + ": " + @cor.json_string_opt(props.keywords),
    @cor.json_string("created") + ": " + @cor.json_string_opt(props.created),
    @cor.json_string("modified") + ": " + @cor.json_string_opt(props.modified),
    @cor.json_string("application") +
    ": " +
    @cor.json_string_opt(props.application),
    @cor.json_string("pages") + ": " + @cor.json_string_opt(props.pages),
    @cor.json_string("words") + ": " + @cor.json_string_opt(props.words),
    @cor.json_string("slides") + ": " + @cor.json_string_opt(props.slides),
    @cor.json_string("sheets") + ": " + @cor.json_string_opt(props.sheets),
  ])
}

///|
fn text_normalization_summary_json(
  summary : @cor.TextNormalizationSummary,
) -> String {
  let change_items : Array[String] = []
  for change in summary.changes {
    change_items.push(
      @cor.object_json([
        @cor.json_string("kind") +
        ": " +
        @cor.json_string(normalization_change_kind_name(change.kind)),
        @cor.json_string("count") + ": " + change.count.to_string(),
      ]),
    )
  }

  let stage_items : Array[String] = []
  for stage in summary.stages {
    stage_items.push(
      @cor.object_json([
        @cor.json_string("stage") +
        ": " +
        @cor.json_string(normalization_stage_name(stage.stage)),
        @cor.json_string("changed") + ": " + @cor.bool_json(stage.changed),
        @cor.json_string("total_changes") +
        ": " +
        stage.total_changes.to_string(),
        @cor.json_string("applied") + ": " + @cor.bool_json(stage.applied),
      ]),
    )
  }

  let rule_items : Array[String] = []
  for rule in summary.rules {
    rule_items.push(
      @cor.object_json([
        @cor.json_string("rule") +
        ": " +
        @cor.json_string(normalization_rule_name(rule.rule)),
        @cor.json_string("scope") +
        ": " +
        @cor.json_string(normalization_rule_scope_name(rule.scope)),
        @cor.json_string("changed") + ": " + @cor.bool_json(rule.changed),
        @cor.json_string("total_changes") +
        ": " +
        rule.total_changes.to_string(),
        @cor.json_string("applied") + ": " + @cor.bool_json(rule.applied),
      ]),
    )
  }

  let warning_items : Array[String] = []
  for warning in summary.warnings {
    warning_items.push(
      @cor.object_json([
        @cor.json_string("kind") +
        ": " +
        @cor.json_string(normalization_warning_kind_name(warning.kind)),
        @cor.json_string("message") + ": " + @cor.json_string(warning.message),
      ]),
    )
  }

  @cor.object_json([
    @cor.json_string("total_changes") + ": " + summary.total_changes.to_string(),
    @cor.json_string("changes") + ": " + @cor.array_json(change_items),
    @cor.json_string("rules") + ": " + @cor.array_json(rule_items),
    @cor.json_string("stages") + ": " + @cor.array_json(stage_items),
    @cor.json_string("warnings") + ": " + @cor.array_json(warning_items),
  ])
}

///|
fn aggregate_pdf_normalization(
  model : @pdfmodel.PdfDocumentModel,
  profile : @cor.NormalizeProfile,
) -> @cor.TextNormalizationSummary {
  let aggregate_changes = Map([])
  let aggregate_rules = Map([])
  let aggregate_rule_scopes = Map([])
  let aggregate_stages = Map([])
  let aggregate_warnings = Map([])
  let mut total_changes = 0

  for page in model.pages {
    for block in page.text_blocks {
      let text = @pdfmodel.block_text(block)
      if text.trim() == "" {
        continue
      }
      let result = @cor.normalize_text_with_profile_summary(text, profile)
      let summary = result.summary
      total_changes += summary.total_changes

      for change in summary.changes {
        let key = normalization_change_kind_name(change.kind)
        let prev = aggregate_changes.get(key).unwrap_or(0)
        aggregate_changes.set(key, prev + change.count)
      }

      for rule in summary.rules {
        let key = normalization_rule_name(rule.rule)
        let prev = aggregate_rules.get(key).unwrap_or(0)
        aggregate_rules.set(key, prev + rule.total_changes)
        if !aggregate_rule_scopes.contains(key) {
          aggregate_rule_scopes.set(key, rule.scope)
        }
      }

      for stage in summary.stages {
        let key = normalization_stage_name(stage.stage)
        let prev = aggregate_stages.get(key).unwrap_or(0)
        aggregate_stages.set(key, prev + stage.total_changes)
      }

      for warning in summary.warnings {
        let key = normalization_warning_kind_name(warning.kind) +
          ": " +
          warning.message
        if !aggregate_warnings.contains(key) {
          aggregate_warnings.set(key, warning)
        }
      }
    }
  }

  let changes : Array[@cor.TextNormalizationChange] = []
  for entry in sorted_map_entries(aggregate_changes) {
    let (key, count) = entry
    changes.push({
      kind: normalization_change_kind_from_name(key),
      before: "",
      after: "",
      count,
    })
  }

  let rules : Array[@cor.TextNormalizationRuleSummary] = []
  for entry in sorted_map_entries(aggregate_rules) {
    let (key, count) = entry
    let scope = aggregate_rule_scopes
      .get(key)
      .unwrap_or(@cor.TextNormalizationRuleScope::WhitespaceCleanup)
    rules.push({
      rule: normalization_rule_from_name(key),
      scope,
      changed: count > 0,
      total_changes: count,
      applied: true,
    })
  }

  let stages : Array[@cor.TextNormalizationStageSummary] = []
  for entry in sorted_map_entries(aggregate_stages) {
    let (key, count) = entry
    let stage = normalization_stage_from_name(key)
    stages.push({
      stage,
      changed: count > 0,
      total_changes: count,
      applied: true,
    })
  }

  let warnings : Array[@cor.TextNormalizationWarning] = []
  let warning_keys : Array[String] = []
  for entry in aggregate_warnings {
    let (key, _) = entry
    warning_keys.push(key)
  }
  warning_keys.sort()
  for key in warning_keys {
    match aggregate_warnings.get(key) {
      Some(warning) => warnings.push(warning)
      None => ()
    }
  }

  { total_changes, changes, rules, stages, warnings }
}

///|
fn bump_string_count(counts : Map[String, Int], key : String) -> Unit {
  let prev = counts.get(key).unwrap_or(0)
  counts.set(key, prev + 1)
}

///|
fn sorted_map_entries(counts : Map[String, Int]) -> Array[(String, Int)] {
  let keys : Array[String] = []
  for entry in counts {
    let (key, _) = entry
    keys.push(key)
  }
  keys.sort()
  let out : Array[(String, Int)] = []
  for key in keys {
    out.push((key, counts.get(key).unwrap_or(0)))
  }
  out
}

///|
fn map_string_int_json(counts : Map[String, Int]) -> String {
  @cor.string_int_kv_json(sorted_map_entries(counts))
}

///|
fn take_first_strings(values : Array[String], limit : Int) -> Array[String] {
  if values.length() <= limit {
    return values
  }
  let out : Array[String] = []
  for i in 0..<limit {
    out.push(values[i])
  }
  out
}

///|
fn dispatcher_route_name(format : String) -> String {
  match format {
    "docx" => "convert/docx"
    "pdf" => "convert/pdf"
    "xlsx" => "convert/xlsx"
    "pptx" => "convert/pptx"
    "html" => "convert/html"
    "csv" => "convert/csv"
    "tsv" => "convert/csv"
    "txt" => "convert/txt"
    "xml" => "convert/xml"
    "json" => "convert/json"
    "yaml" => "convert/yaml"
    "yml" => "convert/yaml"
    "markdown" => "convert/markdown"
    "zip" => "convert/zip"
    "epub" => "convert/epub"
    _ => "unknown"
  }
}

///|
fn format_requires_debug_out_dir(format : String) -> Bool {
  format == "docx" ||
  format == "pptx" ||
  format == "html" ||
  format == "zip" ||
  format == "epub"
}

///|
fn debug_temp_root_for_input(input : String) -> String {
  let base_root = match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(path) => if path.trim() == "" { ".tmp" } else { path }
    None => ".tmp"
  }
  base_root +
  "/debug-inspect/" +
  sanitize_debug_path_component(input_stem(input))
}

///|
fn sanitize_debug_path_component(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text {
    if is_debug_path_safe_char(ch) {
      out.write_char(ch)
    } else {
      out.write_char('_')
    }
  }
  let sanitized = out.to_string()
  if sanitized.trim() == "" {
    "input"
  } else {
    sanitized
  }
}

///|
fn is_debug_path_safe_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.'
}

///|
fn cleanup_debug_temp_root(path : String?) -> Unit {
  match path {
    Some(root) => ignore(try? debug_remove_dir_recursive(root))
    None => ()
  }
}

///|
fn debug_remove_dir_recursive(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    return
  }

  for name in @fs.read_dir(path) {
    let child = path + "/" + name
    if @fs.is_dir(child) {
      debug_remove_dir_recursive(child)
    } else if @fs.is_file(child) {
      @fs.remove_file(child)
    }
  }

  @fs.remove_dir(path)
}

///|
fn debug_recreate_clean_dir(path : String) -> Unit raise {
  ignore(try? debug_remove_dir_recursive(path))
  debug_ensure_dir_tree(path)
}

///|
fn debug_ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
  let normalized = path.trim().to_owned()
  if normalized == "" || normalized == "." {
    return
  }
  if @fs.path_exists(normalized) {
    return
  }

  let parts = normalized.split("/")
  let mut current = if normalized.has_prefix("/") { "/" } else { "" }
  for raw in parts {
    let part = raw.trim().to_owned()
    if part == "" || part == "." {
      continue
    }

    current = if current == "" || current == "/" {
      if current == "/" {
        "/" + part
      } else {
        part
      }
    } else {
      current + "/" + part
    }

    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
fn int_opt_json(v : Int?) -> String {
  match v {
    Some(value) => value.to_string()
    None => "null"
  }
}

///|
fn page_count_for_debug(parsed : DebugParseResult) -> Int? {
  match parsed.pdf_model {
    Some(model) => Some(model.page_count)
    None =>
      match parsed.document_properties {
        Some(props) =>
          match props.pages {
            Some(text) => Some(parse_positive_int(text))
            None => None
          }
        None => None
      }
  }
}

///|
fn slide_count_for_debug(parsed : DebugParseResult) -> Int? {
  if parsed.format == "pptx" {
    return Some(distinct_slide_count(parsed.doc))
  }
  match parsed.document_properties {
    Some(props) =>
      match props.slides {
        Some(text) => Some(parse_positive_int(text))
        None => None
      }
    None => None
  }
}

///|
fn sheet_count_for_debug(parsed : DebugParseResult) -> Int? {
  match parsed.xlsx_workbook {
    Some(wb) => Some(wb.sheets.length())
    None =>
      match parsed.document_properties {
        Some(props) =>
          match props.sheets {
            Some(text) => Some(parse_positive_int(text))
            None => None
          }
        None => None
      }
  }
}

///|
fn entry_count_for_debug(parsed : DebugParseResult) -> Int? {
  match parsed.zip_inspect {
    Some(report) => Some(report.entry_count)
    None => None
  }
}

///|
fn chapter_count_for_debug(parsed : DebugParseResult) -> Int? {
  match parsed.epub_inspect {
    Some(report) => Some(report.spine_count)
    None => None
  }
}

///|
fn parse_positive_int(text : String) -> Int {
  let trimmed = text.trim()
  if trimmed == "" {
    return 0
  }
  let mut value = 0
  for ch in trimmed {
    if ch < '0' || ch > '9' {
      return 0
    }
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  value
}

///|
fn html_asset_boundary_summary(doc : @cor.Document) -> String {
  let counts = Map([])
  for entry in doc.asset_origins.val {
    let (_, origin) = entry
    let src = origin.source_path.unwrap_or("")
    let kind = if src.has_prefix("http://") || src.has_prefix("https://") {
      "remote"
    } else if src.has_prefix("data:") {
      "data"
    } else if src == "" {
      "unknown"
    } else {
      "local"
    }
    bump_string_count(counts, kind)
  }
  map_string_int_json(counts)
}

///|
fn xlsx_sheet_state_name(state : @xlsx.XlsxSheetState) -> String {
  match state {
    @xlsx.XlsxSheetState::Visible => "Visible"
    @xlsx.XlsxSheetState::Hidden => "Hidden"
    @xlsx.XlsxSheetState::VeryHidden => "VeryHidden"
  }
}

///|
fn xlsx_semantic_type_name(t : @xlsx.XlsxCellSemanticType) -> String {
  match t {
    @xlsx.XlsxCellSemanticType::String => "String"
    @xlsx.XlsxCellSemanticType::Number => "Number"
    @xlsx.XlsxCellSemanticType::Boolean => "Boolean"
    @xlsx.XlsxCellSemanticType::Date => "Date"
    @xlsx.XlsxCellSemanticType::DateTime => "DateTime"
    @xlsx.XlsxCellSemanticType::Time => "Time"
    @xlsx.XlsxCellSemanticType::Blank => "Blank"
    @xlsx.XlsxCellSemanticType::Error => "Error"
    @xlsx.XlsxCellSemanticType::FormulaCachedValue => "FormulaCachedValue"
    @xlsx.XlsxCellSemanticType::FormulaMissingCache => "FormulaMissingCache"
  }
}

///|
fn zip_action_name(action : @zipconv.ZipInspectAction) -> String {
  match action {
    @zipconv.ZipInspectAction::Convert => "Convert"
    @zipconv.ZipInspectAction::Skip => "Skip"
    @zipconv.ZipInspectAction::Warn => "Warn"
    @zipconv.ZipInspectAction::Fail => "Fail"
  }
}

///|
fn zip_kind_name(kind : @zipconv.ZipInspectEntryKind) -> String {
  match kind {
    @zipconv.ZipInspectEntryKind::Supported => "Supported"
    @zipconv.ZipInspectEntryKind::NestedArchive => "NestedArchive"
    @zipconv.ZipInspectEntryKind::Unsupported => "Unsupported"
    @zipconv.ZipInspectEntryKind::Directory => "Directory"
    @zipconv.ZipInspectEntryKind::HiddenMetadata => "HiddenMetadata"
    @zipconv.ZipInspectEntryKind::UnsafePath => "UnsafePath"
    @zipconv.ZipInspectEntryKind::EntryLimitExceeded => "EntryLimitExceeded"
    @zipconv.ZipInspectEntryKind::EntryTooLarge => "EntryTooLarge"
    @zipconv.ZipInspectEntryKind::TotalDecodedLimitExceeded =>
      "TotalDecodedLimitExceeded"
  }
}

///|
fn normalization_stage_name(stage : @cor.TextNormalizationStage) -> String {
  match stage {
    @cor.TextNormalizationStage::ValidateScalarStage => "ValidateScalarStage"
    @cor.TextNormalizationStage::CanonicalUnicodeStage =>
      "CanonicalUnicodeStage"
    @cor.TextNormalizationStage::CompatibilityGlyphStage =>
      "CompatibilityGlyphStage"
    @cor.TextNormalizationStage::WhitespaceStage => "WhitespaceStage"
    @cor.TextNormalizationStage::InvisibleCharStage => "InvisibleCharStage"
    @cor.TextNormalizationStage::SoftHyphenStage => "SoftHyphenStage"
    @cor.TextNormalizationStage::LineEndingStage => "LineEndingStage"
    @cor.TextNormalizationStage::PdfGlyphStage => "PdfGlyphStage"
    @cor.TextNormalizationStage::PdfCompareStage => "PdfCompareStage"
  }
}

///|
fn normalization_stage_from_name(name : String) -> @cor.TextNormalizationStage {
  match name {
    "ValidateScalarStage" => @cor.TextNormalizationStage::ValidateScalarStage
    "CanonicalUnicodeStage" =>
      @cor.TextNormalizationStage::CanonicalUnicodeStage
    "CompatibilityGlyphStage" =>
      @cor.TextNormalizationStage::CompatibilityGlyphStage
    "WhitespaceStage" => @cor.TextNormalizationStage::WhitespaceStage
    "InvisibleCharStage" => @cor.TextNormalizationStage::InvisibleCharStage
    "SoftHyphenStage" => @cor.TextNormalizationStage::SoftHyphenStage
    "LineEndingStage" => @cor.TextNormalizationStage::LineEndingStage
    "PdfGlyphStage" => @cor.TextNormalizationStage::PdfGlyphStage
    _ => @cor.TextNormalizationStage::PdfCompareStage
  }
}

///|
fn normalization_change_kind_name(
  kind : @cor.TextNormalizationChangeKind,
) -> String {
  match kind {
    @cor.TextNormalizationChangeKind::LineEndings => "LineEndings"
    @cor.TextNormalizationChangeKind::Tabs => "Tabs"
    @cor.TextNormalizationChangeKind::Nbsp => "Nbsp"
    @cor.TextNormalizationChangeKind::UnicodeSpaces => "UnicodeSpaces"
    @cor.TextNormalizationChangeKind::SpaceLikeRuns => "SpaceLikeRuns"
    @cor.TextNormalizationChangeKind::ZeroWidth => "ZeroWidth"
    @cor.TextNormalizationChangeKind::SoftHyphen => "SoftHyphen"
    @cor.TextNormalizationChangeKind::Ligatures => "Ligatures"
    @cor.TextNormalizationChangeKind::Quotes => "Quotes"
    @cor.TextNormalizationChangeKind::Dashes => "Dashes"
    @cor.TextNormalizationChangeKind::Fullwidth => "Fullwidth"
    @cor.TextNormalizationChangeKind::CjkPunctuation => "CjkPunctuation"
    @cor.TextNormalizationChangeKind::CjkPunctuationSpacing =>
      "CjkPunctuationSpacing"
    @cor.TextNormalizationChangeKind::AsciiPunctuationSpacing =>
      "AsciiPunctuationSpacing"
    @cor.TextNormalizationChangeKind::BulletMarkerSpacing =>
      "BulletMarkerSpacing"
    @cor.TextNormalizationChangeKind::NumberedMarkerSpacing =>
      "NumberedMarkerSpacing"
    @cor.TextNormalizationChangeKind::Canonical => "Canonical"
    @cor.TextNormalizationChangeKind::Compatibility => "Compatibility"
    @cor.TextNormalizationChangeKind::PdfGlyph => "PdfGlyph"
    @cor.TextNormalizationChangeKind::CjkSpacing => "CjkSpacing"
    @cor.TextNormalizationChangeKind::PdfComparisonWhitespace =>
      "PdfComparisonWhitespace"
  }
}

///|
fn normalization_change_kind_from_name(
  name : String,
) -> @cor.TextNormalizationChangeKind {
  match name {
    "LineEndings" => @cor.TextNormalizationChangeKind::LineEndings
    "Tabs" => @cor.TextNormalizationChangeKind::Tabs
    "Nbsp" => @cor.TextNormalizationChangeKind::Nbsp
    "UnicodeSpaces" => @cor.TextNormalizationChangeKind::UnicodeSpaces
    "SpaceLikeRuns" => @cor.TextNormalizationChangeKind::SpaceLikeRuns
    "ZeroWidth" => @cor.TextNormalizationChangeKind::ZeroWidth
    "SoftHyphen" => @cor.TextNormalizationChangeKind::SoftHyphen
    "Ligatures" => @cor.TextNormalizationChangeKind::Ligatures
    "Quotes" => @cor.TextNormalizationChangeKind::Quotes
    "Dashes" => @cor.TextNormalizationChangeKind::Dashes
    "Fullwidth" => @cor.TextNormalizationChangeKind::Fullwidth
    "CjkPunctuation" => @cor.TextNormalizationChangeKind::CjkPunctuation
    "CjkPunctuationSpacing" =>
      @cor.TextNormalizationChangeKind::CjkPunctuationSpacing
    "AsciiPunctuationSpacing" =>
      @cor.TextNormalizationChangeKind::AsciiPunctuationSpacing
    "BulletMarkerSpacing" =>
      @cor.TextNormalizationChangeKind::BulletMarkerSpacing
    "NumberedMarkerSpacing" =>
      @cor.TextNormalizationChangeKind::NumberedMarkerSpacing
    "Canonical" => @cor.TextNormalizationChangeKind::Canonical
    "Compatibility" => @cor.TextNormalizationChangeKind::Compatibility
    "PdfGlyph" => @cor.TextNormalizationChangeKind::PdfGlyph
    "PdfComparisonWhitespace" =>
      @cor.TextNormalizationChangeKind::PdfComparisonWhitespace
    _ => @cor.TextNormalizationChangeKind::CjkSpacing
  }
}

///|
fn normalization_rule_name(rule : @cor.TextNormalizationRuleId) -> String {
  match rule {
    @cor.TextNormalizationRuleId::NormalizeLineEndings => "NormalizeLineEndings"
    @cor.TextNormalizationRuleId::NormalizeTabs => "NormalizeTabs"
    @cor.TextNormalizationRuleId::CanonicalUnicode => "CanonicalUnicode"
    @cor.TextNormalizationRuleId::ExpandLigatures => "ExpandLigatures"
    @cor.TextNormalizationRuleId::NormalizeQuotes => "NormalizeQuotes"
    @cor.TextNormalizationRuleId::NormalizeDashes => "NormalizeDashes"
    @cor.TextNormalizationRuleId::NormalizeFullwidth => "NormalizeFullwidth"
    @cor.TextNormalizationRuleId::NormalizeCjkPunctuation =>
      "NormalizeCjkPunctuation"
    @cor.TextNormalizationRuleId::NormalizeNbsp => "NormalizeNbsp"
    @cor.TextNormalizationRuleId::NormalizeUnicodeSpaces =>
      "NormalizeUnicodeSpaces"
    @cor.TextNormalizationRuleId::CollapseSpaceLikeRuns =>
      "CollapseSpaceLikeRuns"
    @cor.TextNormalizationRuleId::RemoveSpacesBetweenCjk =>
      "RemoveSpacesBetweenCjk"
    @cor.TextNormalizationRuleId::RemoveSpacesAroundCjkPunctuation =>
      "RemoveSpacesAroundCjkPunctuation"
    @cor.TextNormalizationRuleId::NormalizeAsciiPunctuationSpacing =>
      "NormalizeAsciiPunctuationSpacing"
    @cor.TextNormalizationRuleId::NormalizeBulletMarkerSpacing =>
      "NormalizeBulletMarkerSpacing"
    @cor.TextNormalizationRuleId::NormalizeNumberedMarkerSpacing =>
      "NormalizeNumberedMarkerSpacing"
    @cor.TextNormalizationRuleId::RemoveZeroWidth => "RemoveZeroWidth"
    @cor.TextNormalizationRuleId::RemoveSoftHyphen => "RemoveSoftHyphen"
    @cor.TextNormalizationRuleId::PdfPrivateGlyphFallback =>
      "PdfPrivateGlyphFallback"
    @cor.TextNormalizationRuleId::CollapsePdfComparisonWhitespace =>
      "CollapsePdfComparisonWhitespace"
  }
}

///|
fn normalization_rule_from_name(name : String) -> @cor.TextNormalizationRuleId {
  match name {
    "NormalizeLineEndings" => @cor.TextNormalizationRuleId::NormalizeLineEndings
    "NormalizeTabs" => @cor.TextNormalizationRuleId::NormalizeTabs
    "CanonicalUnicode" => @cor.TextNormalizationRuleId::CanonicalUnicode
    "ExpandLigatures" => @cor.TextNormalizationRuleId::ExpandLigatures
    "NormalizeQuotes" => @cor.TextNormalizationRuleId::NormalizeQuotes
    "NormalizeDashes" => @cor.TextNormalizationRuleId::NormalizeDashes
    "NormalizeFullwidth" => @cor.TextNormalizationRuleId::NormalizeFullwidth
    "NormalizeCjkPunctuation" =>
      @cor.TextNormalizationRuleId::NormalizeCjkPunctuation
    "NormalizeNbsp" => @cor.TextNormalizationRuleId::NormalizeNbsp
    "NormalizeUnicodeSpaces" =>
      @cor.TextNormalizationRuleId::NormalizeUnicodeSpaces
    "CollapseSpaceLikeRuns" =>
      @cor.TextNormalizationRuleId::CollapseSpaceLikeRuns
    "RemoveSpacesBetweenCjk" =>
      @cor.TextNormalizationRuleId::RemoveSpacesBetweenCjk
    "RemoveSpacesAroundCjkPunctuation" =>
      @cor.TextNormalizationRuleId::RemoveSpacesAroundCjkPunctuation
    "NormalizeAsciiPunctuationSpacing" =>
      @cor.TextNormalizationRuleId::NormalizeAsciiPunctuationSpacing
    "NormalizeBulletMarkerSpacing" =>
      @cor.TextNormalizationRuleId::NormalizeBulletMarkerSpacing
    "NormalizeNumberedMarkerSpacing" =>
      @cor.TextNormalizationRuleId::NormalizeNumberedMarkerSpacing
    "RemoveZeroWidth" => @cor.TextNormalizationRuleId::RemoveZeroWidth
    "RemoveSoftHyphen" => @cor.TextNormalizationRuleId::RemoveSoftHyphen
    "PdfPrivateGlyphFallback" =>
      @cor.TextNormalizationRuleId::PdfPrivateGlyphFallback
    _ => @cor.TextNormalizationRuleId::CollapsePdfComparisonWhitespace
  }
}

///|
fn normalization_rule_scope_name(
  scope : @cor.TextNormalizationRuleScope,
) -> String {
  match scope {
    @cor.TextNormalizationRuleScope::CharacterCleanup => "CharacterCleanup"
    @cor.TextNormalizationRuleScope::CanonicalUnicode => "CanonicalUnicode"
    @cor.TextNormalizationRuleScope::CompatibilityGlyph => "CompatibilityGlyph"
    @cor.TextNormalizationRuleScope::WhitespaceCleanup => "WhitespaceCleanup"
    @cor.TextNormalizationRuleScope::PunctuationSpacing => "PunctuationSpacing"
    @cor.TextNormalizationRuleScope::MarkerSpacing => "MarkerSpacing"
    @cor.TextNormalizationRuleScope::CjkSpacing => "CjkSpacing"
    @cor.TextNormalizationRuleScope::PdfCleanup => "PdfCleanup"
    @cor.TextNormalizationRuleScope::CompareOnly => "CompareOnly"
  }
}

///|
fn normalization_warning_kind_name(
  kind : @cor.TextNormalizationWarningKind,
) -> String {
  match kind {
    @cor.TextNormalizationWarningKind::UnsupportedNormalization =>
      "UnsupportedNormalization"
    @cor.TextNormalizationWarningKind::InvalidScalar => "InvalidScalar"
    @cor.TextNormalizationWarningKind::SkippedDueToLiteralContext =>
      "SkippedDueToLiteralContext"
  }
}

///|
fn shorten_debug_text(text : String, limit : Int) -> String {
  if text.length() <= limit {
    text
  } else {
    text[:limit].to_owned() + "..."
  }
}
