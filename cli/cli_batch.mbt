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
      provenance
    }
    _ => provenance
  }
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
      Some(value) => fields.set(entry.0, value.to_json())
      None => ()
    }
  }
  Json::object(fields)
}

///|
fn run_batch_cli_app(cli_args : Array[String]) -> Int {
  let parsed = parse_batch_cli_options(cli_args, 1)
  let (opts, output_dir) = match parsed {
    Ok(value) => value
    Err(msg) => return exit_cli_error(msg, true)
  }
  let input_path = opts.input
  let tasks = if fs_is_dir(input_path) {
    collect_batch_input_paths(input_path, input_path)
  } else if @fs.path_exists(input_path) {
    [input_path]
  } else {
    return exit_cli_error("batch input path not found: " + input_path, false)
  }
  ensure_dir_tree(output_dir) catch {
    err =>
      return exit_cli_error(
        "create batch output dir failed: " + err.to_string(),
        false,
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
    "task_count": results.length().to_json(),
    "results": results.map(batch_task_result_to_json).to_json(),
  })
  @fs.write_string_to_file(
    manifest_path,
    manifest.stringify(indent=2) + "\n",
    encoding="utf8",
  ) catch {
    err =>
      return exit_cli_error(
        "write batch manifest failed: " + err.to_string(),
        false,
      )
  }
  if results.any(fn(result) { result.status == Failed }) {
    1
  } else {
    0
  }
}

///|
fn parse_batch_cli_options(
  args : Array[String],
  start_index : Int,
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
  let parsed = parse_cli_options_from_index(
    args,
    parsed_index,
    mode~,
    allow_batch_audio_language_without_explicit_format=true,
  )
  let opts = match parsed {
    Ok(value) => value
    Err(msg) => return Err(msg)
  }
  if opts.provenance_output is Some(_) {
    return Err("batch does not support --provenance-out; use manifest.json")
  }
  if opts.audio_options.language is Some(_) &&
    !(match opts.explicit_format {
      Some(Audio(Wav | Mp3 | M4a)) => true
      _ => false
    }) {
    return Err("batch --audio-lang requires explicit --format wav|mp3|m4a")
  }
  if opts.output is None {
    return Err("batch requires <input> <output_dir>")
  }
  match opts.output {
    Some(output_dir) => Ok(({ ..opts, output: None }, output_dir))
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
  @fs.read_dir(path) catch {
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
fn run_single_batch_task(
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
    }
  }
  let output_path = batch_output_path(
    output_dir,
    relative_path,
    base_opts.output_mode,
  )
  let opts = { ..base_opts, input: task_input, output: Some(output_path) }
  let convert_options = @convert.make_convert_options(
    opts.convert_mode,
    opts.output_mode,
    opts.explicit_format,
    opts.ocr_options,
    @convert.default_resource_limits(),
    audio_options=opts.audio_options,
    rag_options=opts.rag_options,
  )
  match
    @convert.convert_input_with_provenance_and_image_ocr_provider(
      @input.input_from_path(task_input),
      convert_options,
      @focr.run_ocr_provider,
    ) {
    Ok(execution) =>
      match cli_render_convert_result(opts, execution.result) {
        Ok(_) =>
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
          }
        Err(msg) =>
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
            error: Some(msg),
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
      }
  }
}

///|
fn path_extension_label(path : String) -> String? {
  let trimmed = path.trim().to_owned().to_lower()
  let chars = trimmed.to_array()
  let mut last_dot : Int? = None
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
  input_path : String,
  content : String,
  assets : Array[@core.AssetRef],
) -> CliResolvedAssets {
  let available : Array[@core.AssetRef] = []
  let warnings : Array[String] = []
  let rendered = Ref(content)
  let input_dir = dirname_of_path(input_path)
  let zip_archive = load_zip_archive_for_assets(input_path, assets)
  for asset in assets {
    if cli_asset_is_materializable(input_dir, zip_archive, asset) {
      available.push(asset)
      continue
    }
    let rel_path = asset.path.unwrap_or(asset.asset_id)
    let source = cli_asset_source_label(asset, rel_path)
    let warning = "asset unavailable: " + source
    warnings.push(warning)
    rendered.val = cli_replace_unavailable_image(rendered.val, asset, source)
  }
  { content: rendered.val, assets: available, warnings }
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
  { content: rendered.val, assets: [], warnings }
}

///|
fn cli_asset_is_materializable(
  input_dir : String,
  zip_archive : @dzip.ZipArchive?,
  asset : @core.AssetRef,
) -> Bool {
  match asset.attrs.get("zip_nested_archive_entry_path") {
    Some(outer_path) => {
      let inner_path = match asset.attrs.get("zip_nested_asset_entry_path") {
        Some(value) => value
        None => return false
      }
      let archive = match zip_archive {
        Some(value) => value
        None => return false
      }
      let bytes = try
        @dzip.read_entry(archive, normalized_zip_asset_entry(outer_path))
        |> Some
      catch {
        _ => None
      }
      let bytes = match bytes {
        Some(value) => value
        None => return false
      }
      let nested = try @dzip.open_zip(bytes) |> Some catch {
        _ => None
      }
      let nested = match nested {
        Some(value) => value
        None => return false
      }
      return try {
        ignore(@dzip.read_entry(nested, normalized_zip_asset_entry(inner_path)))
        true
      } catch {
        _ => false
      }
    }
    None => ()
  }
  match asset.attrs.get("zip_entry_path") {
    Some(entry_path) => {
      let archive = match zip_archive {
        Some(value) => value
        None => return false
      }
      return try {
        ignore(
          @dzip.read_entry(archive, normalized_zip_asset_entry(entry_path)),
        )
        true
      } catch {
        _ => false
      }
    }
    None => ()
  }
  match asset.payload {
    Some(Bytes(_)) | Some(Utf8(_)) => true
    Some(SourcePath(source_path)) =>
      cli_asset_relative_path_is_safe(source_path) &&
      @fs.path_exists(join_dir_path(input_dir, source_path))
    None => false
  }
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
  diagnostic_label? : String = "Asset unavailable",
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
fn cli_last_image_open_before(content : String, before : Int) -> Int? {
  let cursor = Ref(0)
  let found : Ref[Int?] = Ref(None)
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
  input_path : String,
  output_path : String,
  assets : Array[@core.AssetRef],
) -> Unit raise @fs.IOError {
  if assets.length() == 0 {
    return
  }
  let output_dir = dirname_of_path(output_path)
  let input_dir = dirname_of_path(input_path)
  let zip_archive = load_zip_archive_for_assets(input_path, assets)
  for asset in assets {
    let rel_path = asset.path.unwrap_or("").trim().to_owned()
    if rel_path == "" {
      continue
    }
    if persist_nested_zip_backed_asset(zip_archive, output_dir, rel_path, asset) {
      continue
    }
    if persist_zip_backed_asset(zip_archive, output_dir, rel_path, asset) {
      continue
    }
    if persist_asset_payload(input_dir, output_dir, rel_path, asset) {
      continue
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
  input_path : String,
  assets : Array[@core.AssetRef],
) -> Result[Unit, String] {
  if assets.length() == 0 {
    return Ok(())
  }
  let input_dir = dirname_of_path(input_path)
  let zip_archive = load_zip_archive_for_assets(input_path, assets)
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
    match asset.attrs.get("zip_nested_archive_entry_path") {
      Some(outer_path) => {
        let inner_path = match asset.attrs.get("zip_nested_asset_entry_path") {
          Some(value) => value
          None =>
            return Err(
              "nested ZIP asset is missing inner entry metadata: " + rel_path,
            )
        }
        let archive = match zip_archive {
          Some(value) => value
          None =>
            return Err(
              "container archive is unavailable for asset: " + rel_path,
            )
        }
        let nested_bytes = try
          @dzip.read_entry(archive, normalized_zip_asset_entry(outer_path))
          |> Ok
        catch {
          err => Err(err.to_string())
        }
        let nested_bytes = match nested_bytes {
          Ok(value) => value
          Err(message) =>
            return Err("read nested archive asset failed: " + message)
        }
        let nested = try @dzip.open_zip(nested_bytes) |> Ok catch {
          err => Err(err.to_string())
        }
        let nested = match nested {
          Ok(value) => value
          Err(message) =>
            return Err("open nested archive asset failed: " + message)
        }
        try
          @dzip.read_entry(nested, normalized_zip_asset_entry(inner_path))
          |> ignore
        catch {
          err =>
            return Err("read nested asset entry failed: " + err.to_string())
        }
        continue
      }
      None => ()
    }
    match asset.attrs.get("zip_entry_path") {
      Some(entry_path) => {
        let archive = match zip_archive {
          Some(value) => value
          None =>
            return Err(
              "container archive is unavailable for asset: " + rel_path,
            )
        }
        try
          @dzip.read_entry(archive, normalized_zip_asset_entry(entry_path))
          |> ignore
        catch {
          err => return Err("read asset entry failed: " + err.to_string())
        }
        continue
      }
      None => ()
    }
    match asset.payload {
      Some(Bytes(_)) | Some(Utf8(_)) => continue
      Some(SourcePath(source_path)) => {
        if !cli_asset_relative_path_is_safe(source_path) {
          return Err("unsafe source asset path: " + source_path)
        }
        let src = join_dir_path(input_dir, source_path)
        if !@fs.path_exists(src) {
          continue
        }
      }
      None => continue
    }
  }
  Ok(())
}

///|
fn persist_asset_payload(
  input_dir : String,
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @fs.IOError {
  let bytes = match asset.payload {
    Some(Bytes(bytes)) => bytes
    Some(Utf8(text)) => @utf8.encode(text)
    Some(SourcePath(source_path)) => {
      if !cli_asset_relative_path_is_safe(source_path) {
        return false
      }
      let source = join_dir_path(input_dir, source_path)
      if !@fs.path_exists(source) {
        return false
      }
      @fs.read_file_to_bytes(source)
    }
    None => return false
  }
  let dst = join_dir_path(output_dir, rel_path)
  ensure_dir_tree(dirname_of_path(dst))
  @fs.write_bytes_to_file(dst, bytes)
  true
}

///|
fn load_zip_archive_for_assets(
  input_path : String,
  assets : Array[@core.AssetRef],
) -> @dzip.ZipArchive? {
  let mut needs_zip = false
  for asset in assets {
    if asset.attrs.get("zip_entry_path") is Some(_) ||
      asset.attrs.get("zip_nested_archive_entry_path") is Some(_) {
      needs_zip = true
      break
    }
  }
  if !needs_zip {
    return None
  }
  let bytes = try @fs.read_file_to_bytes(input_path) |> Ok catch {
    _ => Err(())
  }
  let bytes = match bytes {
    Ok(value) => value
    Err(_) => return None
  }
  try @dzip.open_zip(bytes) |> Some catch {
    _ => None
  }
}

///|
fn persist_nested_zip_backed_asset(
  archive : @dzip.ZipArchive?,
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @fs.IOError {
  let outer_entry_path = match
    asset.attrs.get("zip_nested_archive_entry_path") {
    Some(value) => value
    None => return false
  }
  let inner_entry_path = match asset.attrs.get("zip_nested_asset_entry_path") {
    Some(value) => value
    None => return false
  }
  let archive = match archive {
    Some(value) => value
    None => return false
  }
  let nested_bytes = try
    @dzip.read_entry(archive, normalized_zip_asset_entry(outer_entry_path))
    |> Ok
  catch {
    _ => Err(())
  }
  let nested_bytes = match nested_bytes {
    Ok(value) => value
    Err(_) => return true
  }
  let nested_archive = try @dzip.open_zip(nested_bytes) |> Ok catch {
    _ => Err(())
  }
  let nested_archive = match nested_archive {
    Ok(value) => value
    Err(_) => return true
  }
  let data = try
    @dzip.read_entry(
      nested_archive,
      normalized_zip_asset_entry(inner_entry_path),
    )
    |> Ok
  catch {
    _ => Err(())
  }
  let data = match data {
    Ok(value) => value
    Err(_) => return true
  }
  let dst = join_dir_path(output_dir, rel_path)
  ensure_dir_tree(dirname_of_path(dst))
  @fs.write_bytes_to_file(dst, data)
  true
}

///|
fn persist_zip_backed_asset(
  archive : @dzip.ZipArchive?,
  output_dir : String,
  rel_path : String,
  asset : @core.AssetRef,
) -> Bool raise @fs.IOError {
  let entry_path = match asset.attrs.get("zip_entry_path") {
    Some(value) => value
    None => return false
  }
  let archive = match archive {
    Some(value) => value
    None => return false
  }
  let data = try
    @dzip.read_entry(archive, normalized_zip_asset_entry(entry_path)) |> Ok
  catch {
    _ => Err(())
  }
  let data = match data {
    Ok(value) => value
    Err(_) => return true
  }
  let dst = join_dir_path(output_dir, rel_path)
  ensure_dir_tree(dirname_of_path(dst))
  @fs.write_bytes_to_file(dst, data)
  true
}

///|
fn normalized_zip_asset_entry(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  let parts : Array[String] = []
  for part in normalized.split("/") {
    if part == "" || part == "." {
      continue
    }
    if part == ".." {
      return path
    }
    parts.push(part.to_owned())
  }
  parts.join("/")
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
