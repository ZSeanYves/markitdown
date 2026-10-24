///|
const EPUB_CONTAINER_PART : String = "META-INF/container.xml"

///|
const EPUB_CONTAINER_NAMESPACE : String = "urn:oasis:names:tc:opendocument:xmlns:container"

///|
priv struct EpubContainerConsumer {
  rows : Array[EpubRootfileInfo]
  mut depth : Int32
  mut root_seen : Bool
  mut legacy_namespace : Bool
  mut rootfiles_active : Bool
}

///|
fn require_container_archive_healthy(
  archive : @zip.ZipArchive,
) -> Unit raise EpubError {
  require_container_budget_healthy(archive)
  if @zip.archive_hard_failure(archive) is Some(message) {
    raise ZipError(message)
  }
}

///|
fn require_container_budget_healthy(
  archive : @zip.ZipArchive,
) -> Unit raise EpubError {
  if @zip.archive_budget_context(archive) is Some(context) &&
    context.account.failure() is Some(error) {
    let message = @budget.budget_error_message(error)
    @zip.record_hard_failure(archive, message)
    raise ZipError(message)
  }
}

///|
fn container_hard_error(
  archive : @zip.ZipArchive,
  error : EpubError,
) -> EpubError {
  match error {
    InvalidEncoding(_) | ZipError(_) =>
      @zip.record_hard_failure(archive, error.to_string())
    _ => ()
  }
  error
}

///|
fn container_cursor_error(error : @xml.XmlCursorError) -> EpubError {
  match error {
    Budget(error) => ZipError(@budget.budget_error_message(error))
    InvalidEncoding(message, position) =>
      InvalidEncoding(
        EPUB_CONTAINER_PART +
        ": " +
        message +
        "; utf8_byte=" +
        position.utf8_byte.to_string(),
      )
    Syntax(_, detail, span) =>
      InvalidXml(
        EPUB_CONTAINER_PART +
        ": " +
        detail +
        "; utf8_byte=" +
        span.start.utf8_byte.to_string(),
      )
    Limit(_, observed~, limit~) =>
      InvalidXml(
        EPUB_CONTAINER_PART +
        ": unexpected configured cursor cap; observed=" +
        observed.to_string() +
        "; limit=" +
        limit.to_string(),
      )
    InvalidState(detail) =>
      InvalidXml(EPUB_CONTAINER_PART + ": cursor protocol: " + detail)
  }
}

///|
fn container_scratch(
  context : @budget.BudgetContext?,
  amount : Int64,
) -> @budget.BudgetLease? raise EpubError {
  match context {
    None => None
    Some(context) =>
      match context.account.reserve(WorkingBytes, amount) {
        Ok(lease) => Some(lease)
        Err(error) => raise ZipError(@budget.budget_error_message(error))
      }
  }
}

///|
fn container_work(
  context : @budget.BudgetContext?,
  amount : Int64,
) -> Unit raise EpubError {
  if context is Some(context) {
    match context.account.charge(ParseWork, amount) {
      Ok(_) => ()
      Err(error) => raise ZipError(@budget.budget_error_message(error))
    }
  }
}

///|
fn container_utf8_bytes(value : StringView) -> Int64 {
  let mut bytes = 0L
  for ch in value {
    let scalar = ch.to_int()
    bytes += if scalar <= 0x7f {
      1L
    } else if scalar <= 0x7ff {
      2L
    } else if scalar <= 0xffff {
      3L
    } else {
      4L
    }
  }
  bytes
}

///|
// Cursor-returned Strings have a pull lifetime. Admit only the selected values
// that escape into package DTOs, under the same conversion account. Aliased
// DTO copies do not re-admit them. This is selected payload, not object/RSS size.
fn retain_container_string(
  context : @budget.BudgetContext?,
  value : StringView,
) -> Unit raise EpubError {
  if context is Some(context) {
    match
      context.account.charge(SourceMetadataBytes, container_utf8_bytes(value)) {
      Ok(_) => ()
      Err(error) => raise ZipError(@budget.budget_error_message(error))
    }
    match
      (context.retain_resident)(CacheBytes, value.length().to_int64() * 2L) {
      Ok(_) => ()
      Err(error) => raise ZipError(@budget.budget_error_message(error))
    }
  }
}

///|
fn container_attribute(
  attributes : Array[@xml.XmlCursorAttribute],
  key : String,
) -> String? {
  for attribute in attributes {
    if !attribute.namespace_declaration &&
      attribute.name.namespace_uri is None &&
      !attribute.name.raw.contains(":") &&
      attribute.name.local_name == key {
      return Some(attribute.value)
    }
  }
  None
}

///|
fn container_name_matches(
  consumer : EpubContainerConsumer,
  name : @xml.XmlCursorName,
  local_name : String,
) -> Bool {
  name.local_name == local_name &&
  (if consumer.legacy_namespace {
    name.namespace_uri is None && !name.raw.contains(":")
  } else {
    name.namespace_uri == Some(EPUB_CONTAINER_NAMESPACE)
  })
}

///|
fn append_container_rootfile(
  consumer : EpubContainerConsumer,
  attributes : Array[@xml.XmlCursorAttribute],
  entry_index : Map[String, String],
  context : @budget.BudgetContext?,
) -> Unit raise EpubError {
  let path_view = container_attribute(attributes, "full-path")
    .unwrap_or("")
    .trim()
  if path_view == "" {
    return
  }
  retain_container_string(context, path_view)
  let full_path = path_view.to_owned()
  let media_view = container_attribute(attributes, "media-type")
    .unwrap_or("")
    .trim()
  let media_type = if media_view == "" {
    None
  } else {
    retain_container_string(context, media_view)
    Some(media_view.to_owned())
  }
  // Existing normalization can hold trim/copy/lower/segment/join payloads.
  // Reserve the conservative private UTF16 payload bound before invoking it;
  // array/map/allocator bookkeeping is not claimed by this field model.
  let scratch = container_scratch(
    context,
    full_path.length().to_int64() * 14L + 2L,
  )
  defer (if scratch is Some(lease) { lease.release() })
  let normalized_path = Some(normalize_package_full_path(full_path)) catch {
    InvalidPath(_) => None
    error => raise error
  }
  if normalized_path is Some(path) {
    retain_container_string(context, path[:])
  }
  let exists = match normalized_path {
    Some(path) => entry_index.contains(path)
    None => false
  }
  consumer.rows.push({
    full_path,
    media_type,
    normalized_path,
    exists,
    usable: exists,
    is_primary: false,
  })
}

///|
fn consume_container_token(
  consumer : EpubContainerConsumer,
  token : @xml.XmlCursorToken,
  entry_index : Map[String, String],
  context : @budget.BudgetContext?,
) -> Unit raise EpubError {
  match token {
    StartElement(name, attributes, self_closing, span) => {
      if consumer.depth == 0 {
        if consumer.root_seen ||
          name.local_name != "container" ||
          !(name.namespace_uri == Some(EPUB_CONTAINER_NAMESPACE) ||
          (name.namespace_uri is None && !name.raw.contains(":"))) {
          raise InvalidXml(
            EPUB_CONTAINER_PART +
            ": expected OCF container root; utf8_byte=" +
            span.start.utf8_byte.to_string(),
          )
        }
        consumer.root_seen = true
        consumer.legacy_namespace = name.namespace_uri is None
      } else if consumer.depth == 1 &&
        container_name_matches(consumer, name, "rootfiles") {
        consumer.rootfiles_active = !self_closing
      } else if consumer.depth == 2 &&
        consumer.rootfiles_active &&
        container_name_matches(consumer, name, "rootfile") {
        append_container_rootfile(consumer, attributes, entry_index, context)
      }
      if !self_closing {
        consumer.depth += 1
      }
    }
    EndElement(_, _) => {
      if consumer.depth == 2 {
        consumer.rootfiles_active = false
      }
      consumer.depth -= 1
    }
    _ => ()
  }
}

///|
fn drain_container_cursor(
  cursor : @xml.XmlCursor,
  consumer : EpubContainerConsumer,
  entry_index : Map[String, String],
  context : @budget.BudgetContext?,
) -> Bool raise EpubError {
  while true {
    match cursor.next() {
      Err(error) => raise container_cursor_error(error)
      Ok(NeedInput) => return false
      Ok(End) => return true
      Ok(Token(token)) =>
        consume_container_token(consumer, token, entry_index, context)
    }
  }
  false
}

///|
fn finalize_container_rootfiles(
  rows : Array[EpubRootfileInfo],
) -> Array[EpubRootfileInfo] raise EpubError {
  if rows.is_empty() {
    raise InvalidXml("container.xml missing rootfile")
  }
  let index = first_usable_rootfile_index(rows)
  if index < 0 {
    raise InvalidXml("container.xml has no usable rootfile")
  }
  let primary_path = rows[index].normalized_path.unwrap_or("")
  let finalized : Array[EpubRootfileInfo] = []
  for i, item in rows {
    finalized.push({
      full_path: item.full_path,
      media_type: item.media_type,
      normalized_path: item.normalized_path,
      exists: item.exists,
      usable: item.usable,
      is_primary: i == index && item.normalized_path == Some(primary_path),
    })
  }
  finalized
}

///|
// Mandatory metadata: on ordinary grammar failure, close the failed cursor and
// validate the same bounded entry's UTF8 + ZIP EOF/size/CRC before reporting it.
// Success has one traversal/cursor parse. Error-only replay performs additional
// real read/inflate/work under the same account, with no normalized whole text.
async fn read_container_rootfiles(
  archive : @zip.ZipArchive,
  entry_index : Map[String, String],
  chunk_size~ : Int32 = 64 * 1024,
) -> Array[EpubRootfileInfo] raise EpubError {
  require_container_archive_healthy(archive)
  let raw_part = match entry_index.get(EPUB_CONTAINER_PART) {
    Some(path) => path
    None => raise MissingPart(EPUB_CONTAINER_PART)
  }
  if chunk_size <= 0 {
    raise InvalidXml(EPUB_CONTAINER_PART + ": nonpositive chunk size")
  }
  let context = @zip.archive_budget_context(archive)
  let limits = match
    @xml.XmlCursorLimits::new(
      MeasurementOnly,
      max_depth=None,
      max_token_bytes=None,
      max_attributes=None,
      max_tokens=None,
      text_fragment_bytes=chunk_size.max(4),
    ) {
    Ok(value) => value
    Err(error) => raise container_cursor_error(error)
  }
  let budget_context = context
  let cursor = match @xml.new_xml_cursor(limits, budget_context?) {
    Ok(value) => value
    Err(error) =>
      raise container_hard_error(archive, container_cursor_error(error))
  }
  defer cursor.close()
  let consumer = {
    rows: [],
    depth: 0,
    root_seen: false,
    legacy_namespace: false,
    rootfiles_active: false,
  }
  let callback_failure : Ref[EpubError?] = Ref(None)
  let visited = @zip.visit_inflated_entry_chunks(
    archive,
    raw_part,
    chunk_size~,
    max_output_size=128 * 1024 * 1024,
    chunk => {
      let checked = try {
        require_container_archive_healthy(archive)
        match cursor.feed(chunk, eof=false) {
          Ok(_) => ()
          Err(error) => raise container_cursor_error(error)
        }
        if drain_container_cursor(cursor, consumer, entry_index, context) {
          raise EpubError::InvalidXml(
            EPUB_CONTAINER_PART + ": cursor ended before final input",
          )
        }
        require_container_archive_healthy(archive)
        Ok(())
      } catch {
        error => Err(error)
      }
      match checked {
        Ok(_) => Ok(())
        Err(error) => {
          callback_failure.val = Some(container_hard_error(archive, error))
          Err("EPUB container XML consumer stopped")
        }
      }
    },
  )
  if visited is Err(message) {
    require_container_budget_healthy(archive)
    if callback_failure.val is Some(error) && error is InvalidEncoding(_) {
      raise error
    }
    require_container_archive_healthy(archive)
    if callback_failure.val is Some(error) {
      cursor.close()
      if error is InvalidXml(_) {
        verify_container_xml_integrity(archive, raw_part, chunk_size~)
      }
      raise error
    }
    raise ZipError(message)
  }
  let finished = try {
    match cursor.feed(b"", eof=true) {
      Ok(_) => ()
      Err(error) => raise container_cursor_error(error)
    }
    if !drain_container_cursor(cursor, consumer, entry_index, context) {
      raise EpubError::InvalidXml(
        EPUB_CONTAINER_PART + ": missing final cursor End",
      )
    }
    Ok(())
  } catch {
    error => Err(container_hard_error(archive, error))
  }
  if finished is Err(error) {
    cursor.close()
    require_container_budget_healthy(archive)
    if error is InvalidEncoding(_) {
      raise error
    }
    require_container_archive_healthy(archive)
    if error is InvalidXml(_) {
      verify_container_xml_integrity(archive, raw_part, chunk_size~)
    }
    raise error
  }
  require_container_archive_healthy(archive)
  finalize_container_rootfiles(consumer.rows)
}

///|
async fn verify_container_xml_integrity(
  archive : @zip.ZipArchive,
  raw_part : String,
  chunk_size~ : Int32,
) -> Unit raise EpubError {
  require_container_archive_healthy(archive)
  let context = @zip.archive_budget_context(archive)
  let carry = Ref(b"")
  let carry_lease : Ref[@budget.BudgetLease?] = Ref(None)
  defer (if carry_lease.val is Some(lease) { lease.release() })
  let offset = Ref(0L)
  let callback_failure : Ref[EpubError?] = Ref(None)
  let visited = @zip.visit_inflated_entry_chunks(
    archive,
    raw_part,
    chunk_size~,
    max_output_size=128 * 1024 * 1024,
    chunk => {
      let checked = try {
        require_container_archive_healthy(archive)
        let bytes = carry.val.length().to_int64() + chunk.length().to_int64()
        container_work(context, bytes)
        let scratch = container_scratch(context, bytes * 8L + 12L)
        defer (if scratch is Some(lease) { lease.release() })
        let start = offset.val - carry.val.length().to_int64()
        let combined = carry.val + chunk
        if carry_lease.val is Some(lease) {
          lease.release()
        }
        carry_lease.val = None
        let decoded = match
          @sourceio.decode_utf8_source_chunk(combined, false) {
          Ok(value) => value
          Err(message) =>
            raise EpubError::InvalidEncoding(
              EPUB_CONTAINER_PART +
              ": " +
              message +
              "; replay_buffer_utf8_byte=" +
              start.to_string(),
            )
        }
        let next_lease = if decoded.1.length() == 0 {
          None
        } else {
          container_scratch(context, decoded.1.length().to_int64())
        }
        carry.val = decoded.1
        carry_lease.val = next_lease
        offset.val += chunk.length().to_int64()
        Ok(())
      } catch {
        error => Err(error)
      }
      match checked {
        Ok(_) => Ok(())
        Err(error) => {
          callback_failure.val = Some(container_hard_error(archive, error))
          Err("EPUB container integrity replay stopped")
        }
      }
    },
  )
  if visited is Err(message) {
    require_container_budget_healthy(archive)
    if callback_failure.val is Some(error) && error is InvalidEncoding(_) {
      raise error
    }
    require_container_archive_healthy(archive)
    if callback_failure.val is Some(error) {
      raise error
    }
    raise ZipError(message)
  }
  if carry.val.length() > 0 {
    let checked = try {
      container_work(context, carry.val.length().to_int64())
      let scratch = container_scratch(
        context,
        carry.val.length().to_int64() * 8L + 12L,
      )
      defer (if scratch is Some(lease) { lease.release() })
      match @sourceio.decode_utf8_source_chunk(carry.val, true) {
        Ok(_) => ()
        Err(message) =>
          raise EpubError::InvalidEncoding(
            EPUB_CONTAINER_PART + ": " + message + "; incomplete replay EOF",
          )
      }
      Ok(())
    } catch {
      error => Err(container_hard_error(archive, error))
    }
    if checked is Err(error) {
      raise error
    }
  }
  require_container_archive_healthy(archive)
}
