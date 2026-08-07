///|
pub fn parse_paddle_ocr_wrapper_payload(
  payload : String,
  request : OcrProviderRequest,
) -> Result[OcrProviderResult, OcrProviderError] {
  let trimmed = payload.trim().to_owned()
  if trimmed == "" {
    return Err(
      EmptyResult(
        "PaddleOCR wrapper produced an empty payload on this runtime.",
      ),
    )
  }
  let root = @djson.parse_json_document(trimmed) catch {
    err =>
      return Err(
        OutputParseFailed(
          "PaddleOCR wrapper emitted invalid JSON on this runtime: " +
          err.to_string(),
        ),
      )
  }
  let root_object = match root.root {
    Object(entries) => paddle_json_object(entries)
    _ =>
      return Err(
        OutputParseFailed(
          "PaddleOCR wrapper payload root must be a JSON object on this runtime.",
        ),
      )
  }
  let provider_name = match
    paddle_json_string_required(root_object, "provider_name") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let jobs = match root_object.get("jobs") {
    Some(Array(items)) =>
      match paddle_json_job_results(items, request) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OutputParseFailed(
          "PaddleOCR wrapper payload must include a `jobs` array on this runtime.",
        ),
      )
  }
  let pages : Array[OcrPageModel] = []
  let mut has_ok_job = false
  let mut has_empty_job = false
  let mut has_error_job = false
  for job in jobs {
    match job.status {
      "ok" => {
        has_ok_job = true
        pages.append(job.pages[:])
      }
      "empty" => has_empty_job = true
      _ => has_error_job = true
    }
  }
  let diagnostics = match root_object.get("diagnostics") {
    Some(Array(items)) => paddle_json_string_array(items)
    _ => []
  }
  if pages.length() == 0 {
    if has_empty_job && !has_ok_job && !has_error_job {
      return Err(
        EmptyResult("PaddleOCR wrapper produced zero pages on this runtime."),
      )
    }
    if request.image_paths.length() == 1 && has_error_job && !has_ok_job {
      let mut first_error_message = "unknown error"
      for job in jobs {
        if job.status == "error" {
          match job.error_message {
            Some(message) => first_error_message = message
            None => ()
          }
          break
        }
      }
      return Err(
        ExecutionFailed(
          "PaddleOCR wrapper job failed on this runtime: " + first_error_message,
        ),
      )
    }
  }
  Ok(
    make_ocr_provider_result(
      pages,
      provider_name,
      provider_version=paddle_json_string_optional(
        root_object, "provider_version",
      ),
      diagnostics~,
      jobs~,
    ),
  )
}

///|
fn paddle_json_job_results(
  items : Array[@djson.JsonValue],
  request : OcrProviderRequest,
) -> Result[Array[OcrProviderJobResult], OcrProviderError] {
  let jobs : Array[OcrProviderJobResult] = []
  for item in items {
    let job_object = match item {
      Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OutputParseFailed(
            "PaddleOCR wrapper job entries must be JSON objects on this runtime.",
          ),
        )
    }
    jobs.push(
      match paddle_json_job_result(job_object, request) {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  }
  Ok(jobs)
}

///|
fn paddle_json_job_result(
  payload : Map[String, @djson.JsonValue],
  request : OcrProviderRequest,
) -> Result[OcrProviderJobResult, OcrProviderError] {
  let job_id = match paddle_json_string_required(payload, "job_id") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let status = match paddle_json_string_required(payload, "status") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let page_items = match payload.get("pages") {
    Some(Array(items)) => items
    _ =>
      return Err(
        OutputParseFailed(
          "PaddleOCR wrapper job payload must include a `pages` array on this runtime.",
        ),
      )
  }
  let pages = match paddle_json_pages(page_items) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let image_path = match paddle_job_image_path(request, job_id) {
    Some(path) => path
    None => ""
  }
  Ok(
    make_ocr_provider_job_result(
      image_path,
      status~,
      error_kind=paddle_json_string_optional(payload, "error_kind"),
      error_message=paddle_json_string_optional(payload, "error_message"),
      pages,
      diagnostics=match payload.get("diagnostics") {
        Some(Array(items)) => paddle_json_string_array(items)
        _ => []
      },
    ),
  )
}

///|
fn paddle_job_image_path(
  request : OcrProviderRequest,
  job_id : String,
) -> String? {
  let prefix = "job-"
  if !job_id.has_prefix(prefix) {
    return None
  }
  let suffix = job_id[prefix.length():]
  let index = @string.parse_int(suffix) catch { _ => return None }
  if index < 0 || index >= request.image_paths.length() {
    None
  } else {
    Some(request.image_paths[index])
  }
}

///|
fn paddle_json_pages(
  items : Array[@djson.JsonValue],
) -> Result[Array[OcrPageModel], OcrProviderError] {
  let pages : Array[OcrPageModel] = []
  for item in items {
    let page_object = match item {
      Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OutputParseFailed(
            "PaddleOCR wrapper page entries must be JSON objects on this runtime.",
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
    Some(Array(items)) =>
      match paddle_json_blocks(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OutputParseFailed(
          "PaddleOCR wrapper page payload must include a `blocks` array on this runtime.",
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
      Some(Array(items)) => paddle_json_string_array(items)
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
      Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OutputParseFailed(
            "PaddleOCR wrapper block entries must be JSON objects on this runtime.",
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
    Some(Array(items)) =>
      match paddle_json_lines(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OutputParseFailed(
          "PaddleOCR wrapper block payload must include a `lines` array on this runtime.",
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
      Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OutputParseFailed(
            "PaddleOCR wrapper line entries must be JSON objects on this runtime.",
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
    Some(Array(items)) =>
      match paddle_json_words(items) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    _ =>
      return Err(
        OutputParseFailed(
          "PaddleOCR wrapper line payload must include a `words` array on this runtime.",
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
      Object(entries) => paddle_json_object(entries)
      _ =>
        return Err(
          OutputParseFailed(
            "PaddleOCR wrapper word entries must be JSON objects on this runtime.",
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
    Some(String(value)) => Ok(value)
    _ =>
      Err(
        OutputParseFailed(
          "PaddleOCR wrapper payload is missing required string field `" +
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
    Some(String(value)) => Some(value)
    _ => None
  }
}

///|
fn paddle_json_string_array(items : Array[@djson.JsonValue]) -> Array[String] {
  items
  .map(item => {
    match item {
      String(value) => value
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
    Some(Number(value)) =>
      Ok(
        @string.parse_int(value) catch {
          _ =>
            return Err(
              OutputParseFailed(
                "PaddleOCR wrapper numeric field `" +
                key +
                "` is not a valid integer on this runtime.",
              ),
            )
        },
      )
    _ =>
      Err(
        OutputParseFailed(
          "PaddleOCR wrapper payload is missing required numeric field `" +
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
    Some(Number(value)) =>
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
    Some(Object(entries)) =>
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
async fn collect_paddle_ocr_output_async(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
) -> Result[(Int, String, String), OcrProviderError] {
  match @rtcmd.run_resolved_command_async(command, args) {
    Ok(output) => {
      if output.timed_out {
        return Err(
          ExecutionFailed("PaddleOCR command timed out after 300000 ms"),
        )
      }
      if output.stdout_limit_exceeded || output.stderr_limit_exceeded {
        return Err(
          ExecutionFailed("PaddleOCR command output exceeded 8 MiB limit"),
        )
      }
      Ok((output.exit_code, output.stdout, output.stderr))
    }
    Err(message) =>
      Err(
        ExecutionFailed(
          "launch PaddleOCR wrapper failed on this runtime: " +
          message +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command) +
          "\n\n" +
          paddle_ocr_install_hint(),
        ),
      )
  }
}

///|
fn collect_paddle_ocr_output(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
) -> Result[(Int, String, String), OcrProviderError] {
  collect_paddle_ocr_output_bounded(command, args)
}

///|
fn collect_paddle_ocr_output_bounded(
  command : @rtcmd.ResolvedCommand,
  args : Array[String],
) -> Result[(Int, String, String), OcrProviderError] {
  match @rtcmd.run_resolved_command(command, args) {
    Ok(output) => {
      if output.timed_out {
        return Err(
          ExecutionFailed("PaddleOCR command timed out after 300000 ms"),
        )
      }
      if output.stdout_limit_exceeded || output.stderr_limit_exceeded {
        return Err(
          ExecutionFailed("PaddleOCR command output exceeded 8 MiB limit"),
        )
      }
      Ok((output.exit_code, output.stdout, output.stderr))
    }
    Err(message) =>
      Err(
        ExecutionFailed(
          "launch PaddleOCR wrapper failed on this runtime: " +
          message +
          "\nResolved command: " +
          @rtcmd.resolved_command_context(command) +
          "\n\n" +
          paddle_ocr_install_hint(),
        ),
      )
  }
}
