///|
pub fn run_ocr_provider(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  match request.provider_kind {
    OcrProviderKind::Tesseract => run_tesseract_provider(request)
    OcrProviderKind::PaddleOcr => run_paddle_ocr_provider(request)
  }
}

///|
pub fn paddle_ocr_runtime_available() -> Bool {
  normalized_env_var(paddle_ocr_command_env_var()) is Some(_)
}

///|
pub async fn run_ocr_provider_async(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  match request.provider_kind {
    OcrProviderKind::Tesseract => run_tesseract_provider_async(request)
    OcrProviderKind::PaddleOcr => run_paddle_ocr_provider_async(request)
  }
}

///|
pub fn resolved_ocr_provider_kind_for_target(
  target : OcrProviderSelectionTarget,
) -> OcrProviderKind {
  ignore(target)
  default_ocr_provider_kind_for_target(target)
}

///|
pub fn ocr_provider_fallback_for_target(
  target : OcrProviderSelectionTarget,
) -> (OcrProviderKind, OcrProviderKind)? {
  ignore(target)
  None
}

///|
pub fn ocr_provider_target_requires_fallback(
  target : OcrProviderSelectionTarget,
) -> Bool {
  ocr_provider_fallback_for_target(target) is Some(_)
}

///|
pub fn paddle_ocr_command_env_var() -> String {
  "MARKITDOWN_PADDLE_OCR_CMD"
}

///|
pub fn paddle_ocr_not_configured_message() -> String {
  "PaddleOCR provider is not configured on this runtime. Set `" +
  paddle_ocr_command_env_var() +
  "` to an adapter command.\n\n" +
  paddle_ocr_install_hint()
}

///|
pub fn build_paddle_ocr_command(
  request : OcrProviderRequest,
) -> Result[(String, Array[String]), OcrProviderError] {
  match normalized_env_var(paddle_ocr_command_env_var()) {
    Some(command) => build_paddle_ocr_command_with_adapter(request, command)
    None =>
      Err(OcrProviderError::NotConfigured(paddle_ocr_not_configured_message()))
  }
}

///|
pub fn build_paddle_ocr_command_with_adapter(
  request : OcrProviderRequest,
  adapter_command : String,
) -> Result[(String, Array[String]), OcrProviderError] {
  let trimmed = adapter_command.trim().to_owned()
  if trimmed == "" {
    return Err(
      OcrProviderError::NotConfigured(paddle_ocr_not_configured_message()),
    )
  }
  let parts = trimmed
    .split(" ")
    .to_array()
    .map(part => part.trim().to_owned())
    .filter(part => part != "")
  if parts.length() == 0 {
    return Err(
      OcrProviderError::NotConfigured(paddle_ocr_not_configured_message()),
    )
  }
  let argv : Array[String] = []
  argv.append(parts[1:][:])
  argv.push(request.image_path)
  match request.language {
    Some(language) => {
      let trimmed_language = language.trim().to_owned()
      if trimmed_language != "" {
        argv.push("--lang")
        argv.push(trimmed_language)
      }
    }
    None => ()
  }
  Ok((parts[0], argv))
}

///|
pub fn run_paddle_ocr_provider(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  run_paddle_ocr_provider_with_command(request, collect_paddle_ocr_output)
}

///|
pub async fn run_paddle_ocr_provider_async(
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  run_paddle_ocr_provider_with_async_command(request, (cmd, args) => {
    collect_paddle_ocr_output(cmd, args)
  })
}

///|
pub fn run_paddle_ocr_provider_with_command(
  request : OcrProviderRequest,
  collect_output : (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_paddle_ocr_command(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delegated = match collect_output(plan.0, plan.1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(delegated)
}

///|
pub async fn run_paddle_ocr_provider_with_async_command(
  request : OcrProviderRequest,
  collect_output : async (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match build_paddle_ocr_command(request) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delegated = match collect_output(plan.0, plan.1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(delegated)
}

///|
pub async fn run_paddle_ocr_provider_with_async_command_with_adapter(
  request : OcrProviderRequest,
  adapter_command : String,
  collect_output : async (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match
    build_paddle_ocr_command_with_adapter(request, adapter_command) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delegated = match collect_output(plan.0, plan.1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(delegated)
}

///|
pub fn run_paddle_ocr_provider_with_command_with_adapter(
  request : OcrProviderRequest,
  adapter_command : String,
  collect_output : (String, Array[String]) -> Result[
    (Int, String, String),
    OcrProviderError,
  ],
) -> Result[OcrProviderResult, OcrProviderError] {
  let plan = match
    build_paddle_ocr_command_with_adapter(request, adapter_command) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let delegated = match collect_output(plan.0, plan.1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  finalize_paddle_ocr_command_result(delegated)
}

///|
fn finalize_paddle_ocr_command_result(
  delegated : (Int, String, String),
) -> Result[OcrProviderResult, OcrProviderError] {
  match delegated {
    (0, stdout, _stderr) => parse_paddle_ocr_bridge_payload(stdout)
    (code, stdout, stderr) => {
      let stderr_text = stderr.trim().to_owned()
      let stdout_text = stdout.trim().to_owned()
      let raw_message = if stderr_text != "" {
        stderr_text
      } else if stdout_text != "" {
        stdout_text
      } else {
        "paddle adapter exited with code " + code.to_string()
      }
      let lowered = raw_message.to_lower()
      if lowered.contains("command not found") ||
        lowered.contains("not found") ||
        lowered.contains("no such file") {
        Err(
          OcrProviderError::CommandUnavailable(
            "PaddleOCR adapter command is unavailable on this runtime: " +
            raw_message +
            "\n\n" +
            paddle_ocr_install_hint(),
          ),
        )
      } else {
        Err(
          OcrProviderError::ExecutionFailed(
            "PaddleOCR adapter command failed on this runtime: " +
            raw_message +
            "\n\n" +
            paddle_ocr_install_hint(),
          ),
        )
      }
    }
  }
}

///|
pub fn parse_paddle_ocr_bridge_payload(
  payload : String,
) -> Result[OcrProviderResult, OcrProviderError] {
  let trimmed = payload.trim().to_owned()
  if trimmed == "" {
    return Err(
      OcrProviderError::EmptyResult(
        "PaddleOCR adapter produced an empty payload on this runtime.",
      ),
    )
  }
  let root = @djson.parse_json_document(trimmed) catch {
    err =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR adapter emitted invalid JSON on this runtime: " +
          err.to_string(),
        ),
      )
  }
  let root_object = match root.root {
    @djson.JsonValue::Object(entries) => paddle_json_object(entries)
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR adapter payload root must be a JSON object on this runtime.",
        ),
      )
  }
  let provider_name = match
    paddle_json_string_required(root_object, "provider_name") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let pages = match root_object.get("pages") {
    Some(@djson.JsonValue::Array(items)) =>
      match paddle_json_pages(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR adapter payload must include a `pages` array on this runtime.",
        ),
      )
  }
  if pages.length() == 0 {
    return Err(
      OcrProviderError::EmptyResult(
        "PaddleOCR adapter produced zero pages on this runtime.",
      ),
    )
  }
  let diagnostics = match root_object.get("diagnostics") {
    Some(@djson.JsonValue::Array(items)) => paddle_json_string_array(items)
    _ => []
  }
  Ok(
    make_ocr_provider_result(
      pages,
      provider_name,
      provider_version=paddle_json_string_optional(
        root_object, "provider_version",
      ),
      diagnostics~,
    ),
  )
}

///|
fn paddle_json_pages(
  items : Array[@djson.JsonValue],
) -> Result[Array[OcrPageModel], OcrProviderError] {
  let pages : Array[OcrPageModel] = []
  for item in items {
    let page_object = match item {
      @djson.JsonValue::Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OcrProviderError::OutputParseFailed(
            "PaddleOCR adapter page entries must be JSON objects on this runtime.",
          ),
        )
    }
    pages.push(
      match paddle_json_page(page_object) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(pages)
}

///|
fn paddle_json_page(
  payload : Map[String, @djson.JsonValue],
) -> Result[OcrPageModel, OcrProviderError] {
  let page_index = match paddle_json_int_required(payload, "page_index") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let blocks = match payload.get("blocks") {
    Some(@djson.JsonValue::Array(items)) =>
      match paddle_json_blocks(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR adapter page payload must include a `blocks` array on this runtime.",
        ),
      )
  }
  Ok({
    page_index,
    width: paddle_json_double_optional(payload, "width"),
    height: paddle_json_double_optional(payload, "height"),
    blocks,
    provider: Some(
      make_ocr_provider_info(
        "paddle_ocr",
        version=paddle_json_string_optional(payload, "provider_version"),
        language=paddle_json_string_optional(payload, "language"),
      ),
    ),
    diagnostics: match payload.get("diagnostics") {
      Some(@djson.JsonValue::Array(items)) => paddle_json_string_array(items)
      _ => []
    },
  })
}

///|
fn paddle_json_blocks(
  items : Array[@djson.JsonValue],
) -> Result[Array[OcrBlock], OcrProviderError] {
  let blocks : Array[OcrBlock] = []
  for item in items {
    let block_object = match item {
      @djson.JsonValue::Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OcrProviderError::OutputParseFailed(
            "PaddleOCR adapter block entries must be JSON objects on this runtime.",
          ),
        )
    }
    blocks.push(
      match paddle_json_block(block_object) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(blocks)
}

///|
fn paddle_json_block(
  payload : Map[String, @djson.JsonValue],
) -> Result[OcrBlock, OcrProviderError] {
  let block_index = match paddle_json_int_required(payload, "block_index") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let lines = match payload.get("lines") {
    Some(@djson.JsonValue::Array(items)) =>
      match paddle_json_lines(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR adapter block payload must include a `lines` array on this runtime.",
        ),
      )
  }
  Ok(
    make_ocr_block(
      block_index,
      lines~,
      bbox=paddle_json_bbox_optional(payload, "bbox"),
      confidence=paddle_json_double_optional(payload, "confidence"),
    ),
  )
}

///|
fn paddle_json_lines(
  items : Array[@djson.JsonValue],
) -> Result[Array[OcrLine], OcrProviderError] {
  let lines : Array[OcrLine] = []
  for item in items {
    let line_object = match item {
      @djson.JsonValue::Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OcrProviderError::OutputParseFailed(
            "PaddleOCR adapter line entries must be JSON objects on this runtime.",
          ),
        )
    }
    lines.push(
      match paddle_json_line(line_object) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(lines)
}

///|
fn paddle_json_line(
  payload : Map[String, @djson.JsonValue],
) -> Result[OcrLine, OcrProviderError] {
  let line_index = match paddle_json_int_required(payload, "line_index") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let text = match paddle_json_string_required(payload, "text") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let words = match payload.get("words") {
    Some(@djson.JsonValue::Array(items)) =>
      match paddle_json_words(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR adapter line payload must include a `words` array on this runtime.",
        ),
      )
  }
  Ok(
    make_ocr_line(
      line_index,
      text,
      words~,
      bbox=paddle_json_bbox_optional(payload, "bbox"),
      confidence=paddle_json_double_optional(payload, "confidence"),
    ),
  )
}

///|
fn paddle_json_words(
  items : Array[@djson.JsonValue],
) -> Result[Array[OcrWord], OcrProviderError] {
  let words : Array[OcrWord] = []
  for item in items {
    let word_object = match item {
      @djson.JsonValue::Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OcrProviderError::OutputParseFailed(
            "PaddleOCR adapter word entries must be JSON objects on this runtime.",
          ),
        )
    }
    words.push(
      match paddle_json_word(word_object) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(words)
}

///|
fn paddle_json_word(
  payload : Map[String, @djson.JsonValue],
) -> Result[OcrWord, OcrProviderError] {
  let word_index = match paddle_json_int_required(payload, "word_index") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let text = match paddle_json_string_required(payload, "text") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(
    make_ocr_word(
      word_index,
      text,
      bbox=paddle_json_bbox_optional(payload, "bbox"),
      confidence=paddle_json_double_optional(payload, "confidence"),
    ),
  )
}

///|
fn paddle_json_object(
  entries : Array[@djson.JsonMember],
) -> Map[String, @djson.JsonValue] {
  let mapped = Map([])
  for entry in entries {
    mapped[entry.key] = entry.value
  }
  mapped
}

///|
fn paddle_json_string_required(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Result[String, OcrProviderError] {
  match payload.get(key) {
    Some(@djson.JsonValue::String(value)) => Ok(value)
    _ =>
      Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR adapter payload is missing required string field `" +
          key +
          "` on this runtime.",
        ),
      )
  }
}

///|
fn paddle_json_string_optional(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> String? {
  match payload.get(key) {
    Some(@djson.JsonValue::String(value)) => Some(value)
    _ => None
  }
}

///|
fn paddle_json_string_array(items : Array[@djson.JsonValue]) -> Array[String] {
  items
  .map(item => {
    match item {
      @djson.JsonValue::String(value) => value
      _ => ""
    }
  })
  .filter(item => item != "")
}

///|
fn paddle_json_int_required(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Result[Int, OcrProviderError] {
  match payload.get(key) {
    Some(@djson.JsonValue::Number(value)) =>
      Ok(
        @string.parse_int(value) catch {
          _ =>
            return Err(
              OcrProviderError::OutputParseFailed(
                "PaddleOCR adapter numeric field `" +
                key +
                "` is not a valid integer on this runtime.",
              ),
            )
        },
      )
    _ =>
      Err(
        OcrProviderError::OutputParseFailed(
          "PaddleOCR adapter payload is missing required numeric field `" +
          key +
          "` on this runtime.",
        ),
      )
  }
}

///|
fn paddle_json_double_optional(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> Double? {
  match payload.get(key) {
    Some(@djson.JsonValue::Number(value)) =>
      Some(@string.parse_double(value) catch { _ => return None })
    _ => None
  }
}

///|
fn paddle_json_bbox_optional(
  payload : Map[String, @djson.JsonValue],
  key : String,
) -> @core.BBox? {
  match payload.get(key) {
    Some(@djson.JsonValue::Object(entries)) =>
      paddle_json_bbox_from_object(paddle_json_object(entries))
    _ => None
  }
}

///|
fn paddle_json_bbox_from_object(
  payload : Map[String, @djson.JsonValue],
) -> @core.BBox? {
  let x0 = match paddle_json_double_optional(payload, "x0") {
    Some(value) => value
    None => return None
  }
  let y0 = match paddle_json_double_optional(payload, "y0") {
    Some(value) => value
    None => return None
  }
  let x1 = match paddle_json_double_optional(payload, "x1") {
    Some(value) => value
    None => return None
  }
  let y1 = match paddle_json_double_optional(payload, "y1") {
    Some(value) => value
    None => return None
  }
  Some({ x0, y0, x1, y1 })
}

///|
#warnings("-deprecated")
fn collect_paddle_ocr_output(
  cmd : String,
  args : Array[String],
) -> Result[(Int, String, String), OcrProviderError] {
  let collected : Ref[Result[(Int, String, String), OcrProviderError]?] = {
    val: None,
  }
  @async.with_event_loop(_group => {
    let delegated = @process.collect_output(cmd, args) catch {
      e => {
        collected.val = Some(
          Err(
            OcrProviderError::ExecutionFailed(
              "launch PaddleOCR adapter failed on this runtime: " +
              e.to_string() +
              "\n\n" +
              paddle_ocr_install_hint(),
            ),
          ),
        )
        return
      }
    }
    match delegated {
      (code, stdout, stderr) => {
        let stdout_text = stdout.text() catch {
          e => {
            collected.val = Some(
              Err(
                OcrProviderError::OutputParseFailed(
                  "failed to decode PaddleOCR adapter stdout as UTF-8 on this runtime: " +
                  e.to_string(),
                ),
              ),
            )
            return
          }
        }
        let stderr_text = stderr.text() catch {
          e => {
            collected.val = Some(
              Err(
                OcrProviderError::OutputParseFailed(
                  "failed to decode PaddleOCR adapter stderr as UTF-8 on this runtime: " +
                  e.to_string(),
                ),
              ),
            )
            return
          }
        }
        collected.val = Some(Ok((code, stdout_text, stderr_text)))
      }
    }
  }) catch {
    e =>
      return Err(
        OcrProviderError::ExecutionFailed(
          "launch PaddleOCR adapter failed on this runtime: " +
          e.to_string() +
          "\n\n" +
          paddle_ocr_install_hint(),
        ),
      )
  }
  match collected.val {
    Some(result) => result
    None =>
      Err(
        OcrProviderError::ExecutionFailed(
          "launch PaddleOCR adapter failed on this runtime: event loop returned no result" +
          "\n\n" +
          paddle_ocr_install_hint(),
        ),
      )
  }
}

///|
fn normalized_env_var(name : String) -> String? {
  match @env.get_env_var(name) {
    Some(value) => {
      let trimmed = value.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
    None => None
  }
}
