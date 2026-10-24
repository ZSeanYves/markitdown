///|
fn dirname_of_path(path : String) -> String {
  let chars = path.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
      last = i
    }
  }
  if last <= 0 {
    "."
  } else {
    path[:last].to_owned()
  }
}

///|
fn ensure_dir_tree(path : String) -> Unit raise @fs.IOError {
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
    if current == "" || current == "/" {
      current = if current == "/" { "/" + part } else { part }
    } else {
      current = current + "/" + part
    }
    if !@fs.path_exists(current) {
      @fs.create_dir(current)
    }
  }
}

///|
fn persist_cli_provenance(
  opts : CliOptions,
  execution : @convert.ConvertExecution,
) -> Unit raise @fs.IOError {
  match opts.provenance_output {
    Some(path) => {
      let parent = dirname_of_path(path)
      ensure_dir_tree(parent)
      @fs.write_string_to_file(
        path,
        cli_provenance_with_stage_timings(execution).stringify(indent=2) + "\n",
        encoding="utf8",
      )
    }
    None => ()
  }
}

///|
fn cli_provenance_with_stage_timings(
  execution : @convert.ConvertExecution,
) -> Json {
  let provenance = @convert.convert_provenance_to_json(execution.provenance)
  match provenance {
    Object(fields) => {
      fields.set(
        "stage_timings_ms",
        convert_stage_timings_json(execution.result.diagnostics.metrics),
      )
      fields.set(
        "budget_usage",
        convert_budget_usage_json(execution.result.diagnostics.metrics),
      )
      provenance
    }
    _ => provenance
  }
}

///|
/// The output meter is sampled after rendering. Keep it in the existing
/// provenance sidecar so its own JSON does not recursively change the measured
/// converted payload. Counter values are decimal Int64 strings like timings.
fn convert_budget_usage_json(metrics : Map[String, String]) -> Json {
  let fields : Map[String, Json] = Map([])
  for key, value in metrics {
    if key.has_prefix("budget_") {
      fields.set(key, Json(value))
    }
  }
  Json::object(fields)
}

///|
fn convert_stage_timings_json(metrics : Map[String, String]) -> Json {
  let fields : Map[String, Json] = Map([])
  for
    entry in [
      ("detect_probe", "timing_detect_probe_ms"),
      ("parse_lower", "timing_parse_lower_ms"),
      ("pipeline", "timing_pipeline_ms"),
      ("render", "timing_render_ms"),
      ("total", "timing_total_ms"),
    ] {
    match metrics.get(entry.1) {
      Some(value) => fields.set(entry.0, Json(value))
      None => ()
    }
  }
  Json::object(fields)
}

///|
async fn run_batch_cli_app(cli_args : Array[String]) -> Int32 {
  let parsed = parse_batch_cli_options(cli_args, 1)
  let (opts, output_dir) = match parsed {
    Ok(value) => value
    Err(msg) => return exit_cli_error(cli_failure(UsageFailure, msg))
  }
  let input_path = opts.input
  let tasks = if fs_is_dir(input_path) {
    collect_batch_input_paths(input_path, input_path)
  } else if @fs.path_exists(input_path) {
    [input_path]
  } else {
    return exit_cli_error(
      cli_failure(DetectionFailure, "batch input path not found: " + input_path),
    )
  }
  ensure_dir_tree(output_dir) catch {
    err =>
      return exit_cli_error(
        cli_failure(
          OutputFailure,
          "create batch output dir failed: " + (err : Error).to_string(),
        ),
      )
  }
  let results : Array[BatchTaskResult] = []
  for task_input in tasks {
    let relative_path = batch_relative_path(input_path, task_input)
    let result = run_single_batch_task(
      opts, output_dir, task_input, relative_path,
    )
    results.push(result)
  }
  let manifest_path = output_dir + "/manifest.json"
  let manifest = Json::object({
    "task_count": Json(results.length()),
    "results": Json(results.map(batch_task_result_to_json)),
  })
  @fs.write_string_to_file(
    manifest_path,
    manifest.stringify(indent=2) + "\n",
    encoding="utf8",
  ) catch {
    err =>
      return exit_cli_error(
        cli_failure(
          OutputFailure,
          "write batch manifest failed: " + (err : Error).to_string(),
        ),
      )
  }
  let mut exit_code = 0
  for result in results {
    match result.failure_kind {
      Some(kind) =>
        exit_code = Int32::max(
          exit_code,
          cli_failure_exit_code(cli_failure(kind, "batch task failed")),
        )
      None => ()
    }
  }
  exit_code
}

///|
fn parse_batch_cli_options(
  args : Array[String],
  start_index : Int32,
) -> Result[(CliOptions, String), String] {
  let mut parsed_index = start_index
  let mut mode = @convert.ConvertMode::Balanced
  if parsed_index < args.length() {
    let first = args[parsed_index].trim().to_owned().to_lower()
    match cli_mode_from_name(first) {
      Some(parsed_mode) => {
        mode = parsed_mode
        parsed_index += 1
      }
      None =>
        if first == "convert" || first == "normal" {
          return Err(removed_batch_mode_message(first))
        }
    }
  }
  let parsed = parse_cli_options_from_index(args, parsed_index, mode~)
  let opts = match parsed {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  if opts.provenance_output is Some(_) {
    return Err("batch does not support --provenance-out; use manifest.json")
  }
  if opts.output is None {
    return Err("batch requires <input> <output_dir>")
  }
  match opts.output {
    Some(output_dir) => Ok(({ ..opts, output: None, }, output_dir))
    None => Err("batch requires <input> <output_dir>")
  }
}

///|
fn collect_batch_input_paths(root : String, path : String) -> Array[String] {
  ignore(root)
  if fs_is_file(path) {
    return [path]
  }
  let collected : Array[String] = []
  for name in fs_read_dir(path) {
    let child = join_dir_path(path, name)
    if fs_is_dir(child) {
      collected.append(collect_batch_input_paths(root, child)[:])
    } else if fs_is_file(child) {
      collected.push(child)
    }
  }
  collected
}

///|
fn batch_relative_path(root_input : String, path : String) -> String {
  if root_input == path {
    return basename_of_path(path)
  }
  if !fs_is_dir(root_input) {
    return basename_of_path(path)
  }
  let prefix = if root_input.has_suffix("/") {
    root_input
  } else {
    root_input + "/"
  }
  if path.has_prefix(prefix) {
    path[prefix.length():].to_owned()
  } else {
    basename_of_path(path)
  }
}

///|
fn fs_is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
fn fs_is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
fn fs_read_dir(path : String) -> Array[String] {
  if !@fs.path_exists(path) {
    return []
  }
  @fs.read_dir(path).to_owned() catch {
    _ => []
  }
}

///|
fn basename_of_path(path : String) -> String {
  let normalized = path.trim().to_owned()
  let chars = normalized.to_array()
  let mut last = -1
  for i in 0..<chars.length() {
    if chars[i] == '/' || chars[i] == '\\' {
      last = i
    }
  }
  if last < 0 {
    normalized
  } else {
    normalized[last + 1:].to_owned()
  }
}

///|
fn batch_output_suffix(output_format : @convert.OutputFormat) -> String {
  match output_format {
    Markdown => ".md"
    Debug => ".debug.json"
    Rag => ".rag.json"
  }
}

///|
fn batch_output_path(
  output_dir : String,
  relative_path : String,
  output_format : @convert.OutputFormat,
) -> String {
  join_dir_path(output_dir, relative_path) + batch_output_suffix(output_format)
}

///|
async fn run_single_batch_task(
  base_opts : CliOptions,
  output_dir : String,
  task_input : String,
  relative_path : String,
) -> BatchTaskResult {
  let requested_format = cli_requested_format_from_input(
    task_input,
    base_opts.explicit_format,
  )
  if !cli_is_supported_format(requested_format) {
    return {
      input_path: task_input,
      relative_path,
      status: Failed,
      detected_format: @input.detected_format_name(requested_format),
      convert_mode: @convert.convert_mode_name(base_opts.convert_mode),
      fidelity_mode: @convert.fidelity_mode_name(
        @convert.fidelity_mode_for_convert_mode(base_opts.convert_mode),
      ),
      output_mode: @convert.output_mode_name(base_opts.output_mode),
      output_path: None,
      selected_route: None,
      parser_mode: None,
      route_reason: None,
      warning_count: 0,
      degraded_features: [],
      error: Some(
        "unsupported format in this build: " +
        path_extension_label(task_input).unwrap_or("unknown"),
      ),
      failure_kind: Some(DetectionFailure),
    }
  }
  let output_path = batch_output_path(
    output_dir,
    relative_path,
    base_opts.output_mode,
  )
  let opts = { ..base_opts, input: task_input, output: Some(output_path), }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_mode,
    opts.explicit_format,
    cli_resource_limits(opts),
    rag_options=opts.rag_options,
  )
  let session = @input.begin_input_session(
    @input.input_from_path(task_input),
    max_bytes=convert_options.limits.max_input_bytes,
  )
  defer @input.end_input_session(session)
  match
    @convert.convert_input_with_provenance(
      session.source,
      convert_options,
      output_assets=ExistingOutputAssets,
    ) {
    Ok(execution) =>
      match
        cli_render_convert_result(
          opts,
          execution.result,
          session.source,
          convert_options.limits,
        ) {
        Ok(_) => {
          @convert.refresh_budget_diagnostics(
            session.source,
            execution.result.diagnostics,
          )
          {
            input_path: task_input,
            relative_path,
            status: Success,
            detected_format: @input.detected_format_name(requested_format),
            convert_mode: @convert.convert_mode_name(
              execution.result.convert_mode,
            ),
            fidelity_mode: @convert.fidelity_mode_name(
              execution.result.fidelity_mode,
            ),
            output_mode: @convert.output_mode_name(execution.result.output_mode),
            output_path: Some(output_path),
            selected_route: Some(execution.provenance.route_plan.selected_route),
            parser_mode: Some(@parser.mode_name(execution.result.parser_mode)),
            route_reason: Some(execution.provenance.route_plan.route_reason),
            warning_count: execution.result.diagnostics.warnings.length(),
            degraded_features: execution.result.diagnostics.degraded_features.copy(),
            error: None,
            failure_kind: None,
          }
        }
        Err(failure) =>
          {
            input_path: task_input,
            relative_path,
            status: Failed,
            detected_format: @input.detected_format_name(requested_format),
            convert_mode: @convert.convert_mode_name(opts.convert_mode),
            fidelity_mode: @convert.fidelity_mode_name(
              @convert.fidelity_mode_for_convert_mode(opts.convert_mode),
            ),
            output_mode: @convert.output_mode_name(opts.output_mode),
            output_path: Some(output_path),
            selected_route: Some(execution.provenance.route_plan.selected_route),
            parser_mode: Some(@parser.mode_name(execution.result.parser_mode)),
            route_reason: Some(execution.provenance.route_plan.route_reason),
            warning_count: execution.result.diagnostics.warnings.length(),
            degraded_features: execution.result.diagnostics.degraded_features.copy(),
            error: Some(failure.message),
            failure_kind: Some(failure.kind),
          }
      }
    Err(err) =>
      {
        input_path: task_input,
        relative_path,
        status: Failed,
        detected_format: @input.detected_format_name(requested_format),
        convert_mode: @convert.convert_mode_name(opts.convert_mode),
        fidelity_mode: @convert.fidelity_mode_name(
          @convert.fidelity_mode_for_convert_mode(opts.convert_mode),
        ),
        output_mode: @convert.output_mode_name(opts.output_mode),
        output_path: None,
        selected_route: None,
        parser_mode: None,
        route_reason: None,
        warning_count: 0,
        degraded_features: [],
        error: Some(cli_convert_error_message(opts, err.to_string())),
        failure_kind: Some(cli_failure_from_convert_error(opts, err).kind),
      }
  }
}

///|
fn path_extension_label(path : String) -> String? {
  let trimmed = path.trim().to_owned().to_lower()
  let chars = trimmed.to_array()
  let mut last_dot : Int32? = None
  for i in 0..<chars.length() {
    if chars[i] == '.' {
      last_dot = Some(i)
    }
  }
  match last_dot {
    Some(index) if index + 1 < trimmed.length() => {
      let label = trimmed[index + 1:].to_owned()
      if label == "" {
        None
      } else {
        Some(label)
      }
    }
    _ => None
  }
}

///|
fn normalize_format_label(label : String) -> String {
  let parsed = @input.parse_detected_format(label)
  if parsed == Unknown {
    label
  } else {
    @input.detected_format_name(parsed)
  }
}

///|
fn normalized_written_content(text : String) -> String {
  if text == "" || text.has_suffix("\n") {
    text
  } else {
    text + "\n"
  }
}

///|
priv struct CliResolvedAssets {
  content : String
  assets : Array[@core.AssetRef]
  warnings : Array[String]
}

///|
fn resolve_cli_assets(
  _input_path : String,
  content : String,
  assets : Array[@core.AssetRef],
) -> CliResolvedAssets {
  let available : Array[@core.AssetRef] = []
  let warnings : Array[String] = []
  let rendered = Ref(content)
  for asset in assets {
    if cli_asset_is_materializable(asset) {
      available.push(asset)
      continue
    }
    let rel_path = asset.path.unwrap_or(asset.asset_id)
    let source = cli_asset_source_label(asset, rel_path)
    let warning = "asset unavailable: " + source
    warnings.push(warning)
    rendered.val = cli_replace_unavailable_image(rendered.val, asset, source)
  }
  { content: rendered.val, assets: available, warnings, }
}

///|
fn resolve_cli_assets_for_stdout(
  content : String,
  assets : Array[@core.AssetRef],
) -> CliResolvedAssets {
  let warnings : Array[String] = []
  let rendered = Ref(content)
  for asset in assets {
    let rel_path = asset.path.unwrap_or(asset.asset_id)
    let source = cli_asset_source_label(asset, rel_path)
    warnings.push("asset not materialized on stdout: " + source)
    rendered.val = cli_replace_unavailable_image(
      rendered.val,
      asset,
      source,
      diagnostic_label="Asset not materialized on stdout",
    )
  }
  { content: rendered.val, assets: [], warnings, }
}

///|
fn cli_asset_is_materializable(asset : @core.AssetRef) -> Bool {
  asset.payload is Some(Bytes(_)) || asset.payload is Some(Utf8(_))
}

///|
fn cli_asset_source_label(asset : @core.AssetRef, fallback : String) -> String {
  match asset.payload {
    Some(SourcePath(path)) => path
    _ => asset.attrs.get("source_path").unwrap_or(fallback)
  }
}

///|
fn cli_replace_unavailable_image(
  content : String,
  asset : @core.AssetRef,
  source : String,
  diagnostic_label~ : String = "Asset unavailable",
) -> String {
  let rendered = Ref(content)
  let paths : Array[String] = []
  match asset.path {
    Some(path) => paths.push(path)
    None => ()
  }
  match asset.attrs.get("reference_path") {
    Some(path) if !paths.contains(path) => paths.push(path)
    _ => ()
  }
  for path in paths {
    rendered.val = cli_replace_unavailable_image_path(
      rendered.val,
      path,
      source,
      diagnostic_label,
    )
  }
  rendered.val
}

///|
fn cli_replace_unavailable_image_path(
  content : String,
  path : String,
  source : String,
  diagnostic_label : String,
) -> String {
  if path == "" {
    return content
  }
  let close_marker = "](" + path + ")"
  let rendered = Ref(content)
  while true {
    let close_index = match rendered.val.find(close_marker) {
      Some(value) => value
      None => break
    }
    let open_index = match
      cli_last_image_open_before(rendered.val, close_index) {
      Some(value) => value
      None => break
    }
    let alt = rendered.val[open_index + 2:close_index].to_owned()
    rendered.val = rendered.val[:open_index].to_owned() +
      alt +
      " [" +
      diagnostic_label +
      ": " +
      source +
      "]" +
      rendered.val[close_index + close_marker.length():].to_owned()
  }
  rendered.val
}

///|
fn cli_last_image_open_before(content : String, before : Int32) -> Int32? {
  let cursor = Ref(0)
  let found : Ref[Int32?] = Ref(None)
  while cursor.val < before {
    let relative = match content[cursor.val:before].find("![") {
      Some(value) => value
      None => break
    }
    let absolute = cursor.val + relative
    found.val = Some(absolute)
    cursor.val = absolute + 2
  }
  found.val
}

///|
fn persist_cli_assets(
  _input_path : String,
  output_path : String,
  assets : Array[@core.AssetRef],
) -> Unit raise @fs.IOError {
  let output_dir = dirname_of_path(output_path)
  for asset in assets {
    let rel_path = asset.path.unwrap_or("").trim().to_owned()
    if rel_path == "" {
      continue
    }
    if !persist_asset_payload(output_dir, rel_path, asset) {
      raise IOError(
        "output asset lacks its validated payload: " + asset.asset_id,
      )
    }
  }
}

///|
fn cli_asset_relative_path_is_safe(path : String) -> Bool {
  let normalized = path.trim().to_owned().replace(old="\\", new="/")
  if normalized == "" || normalized.has_prefix("/") || normalized.contains(":") {
    return false
  }
  for segment in normalized.split("/") {
    if segment == "" || segment == "." || segment == ".." {
      return false
    }
  }
  true
}

///|
fn validate_cli_assets(
  _input_path : String,
  assets : Array[@core.AssetRef],
) -> Result[Unit, String] {
  let paths : Map[String, String] = Map([])
  for asset in assets {
    let rel_path = asset.path.unwrap_or("").trim().to_owned()
    if !cli_asset_relative_path_is_safe(rel_path) {
      return Err("unsafe or empty asset path: " + rel_path)
    }
    match paths.get(rel_path) {
      Some(existing) if existing != asset.asset_id =>
        return Err("asset output path collision: " + rel_path)
      _ => paths.set(rel_path, asset.asset_id)
    }
    if cli_asset_is_materializable(asset) {
      continue
    }
    if asset.attrs.get("zip_entry_path") is Some(_) ||
      asset.attrs.get("zip_nested_archive_entry_path") is Some(_) {
      return Err(
        "output archive asset lacks its validated payload: " + rel_path,
      )
    }
    if asset.payload is Some(SourcePath(_)) {
      return Err(
        "source asset was not materialized by its bounded conversion session",
      )
    }
  }
  Ok(())
}

///|
fn persist_asset_payload(
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @fs.IOError {
  let bytes = match asset.payload {
    Some(Bytes(bytes)) => bytes
    Some(Utf8(text)) => @utf8.encode(text)
    Some(SourcePath(_)) =>
      raise IOError(
        "source asset was not materialized by its bounded conversion session",
      )
    None => return false
  }
  let dst = join_dir_path(output_dir, rel_path)
  ensure_dir_tree(dirname_of_path(dst))
  @fs.write_bytes_to_file(dst, bytes)
  true
}

///|
fn join_dir_path(dir : String, rel : String) -> String {
  if dir == "" || dir == "." {
    rel
  } else if dir.has_suffix("/") {
    dir + rel
  } else {
    dir + "/" + rel
  }
}
