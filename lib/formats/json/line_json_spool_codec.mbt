///|
/// Private JSONL framing, not an IR serialization format. All offsets/lengths
/// are physical bytes in one sealed TempOwner. The 25-byte header is a tag and
/// three nonnegative little-endian Int64 values: line, record index, UTF8 length.
const LINE_JSON_SPOOL_HEADER : Int32 = 25

///|
priv struct LineJsonSpoolCursor {
  owner : @temp.TempOwner
  range : @temp.TempRange
  mut offset : Int64
}

///|
priv struct LineJsonSpoolFrame {
  tag : Byte
  line : Int32
  record : Int32
  text : String
}

///|
fn line_json_spool_failure(
  source : @input.InputSource,
  failure : @temp.TempFailure,
) -> String {
  let message = match failure {
    Budget(error) => {
      @input.record_input_budget_failure(source, error)
      @budget.budget_error_message(error)
    }
    Io(stage~, message~) => "JSONL temporary " + stage + ": " + message
    State(message) => "JSONL temporary state: " + message
  }
  if !(failure is Budget(_)) {
    @input.record_input_failure(source, message)
  }
  @input.input_source_error(source).unwrap_or(message)
}

///|
fn line_json_spool_budget_failure(
  source : @input.InputSource,
  error : @budget.BudgetError,
) -> String {
  line_json_spool_failure(source, Budget(error))
}

///|
fn line_json_spool_invalid(
  source : @input.InputSource,
  message : String,
) -> String {
  @input.record_input_failure(source, message)
  @input.input_source_error(source).unwrap_or(message)
}

///|
fn line_json_spool_working(
  source : @input.InputSource,
  account : @budget.Budget,
  bytes : Int64,
) -> Result[@budget.BudgetLease, String] {
  match account.reserve(WorkingBytes, bytes) {
    Ok(lease) => Ok(lease)
    Err(error) => Err(line_json_spool_budget_failure(source, error))
  }
}

///|
fn line_json_spool_put_int64(
  header : FixedArray[Byte],
  at : Int32,
  value : Int64,
) -> Unit {
  for index in 0..<8 {
    header[at + index] = ((value >> (index * 8)) & 255L).to_int().to_byte()
  }
}

///|
fn line_json_spool_get_int64(header : FixedArray[Byte], at : Int32) -> Int64 {
  let mut result = 0L
  for index in 0..<8 {
    result = result |
      ((header[at + index].to_int() & 255).to_int64() << (index * 8))
  }
  result
}

///|
async fn create_line_json_spool_owner(
  source : @input.InputSource,
  account : @budget.Budget,
  capacity : Int64,
) -> Result[@temp.TempOwner, String] {
  let owner = match
    @temp.TempOwner::create(account, capacity~, report_failure=failure => {
      ignore(line_json_spool_failure(source, failure))
    }) {
    Ok(owner) => owner
    Err(error) => return Err(line_json_spool_failure(source, error))
  }
  let registered = Ref(false)
  defer (if !registered.val { ignore(owner.close()) })
  match
    @input.register_input_temporary_cleanup(source, async fn() {
      ignore(owner.close())
      // close retains original operation failure even after reclamation. The
      // reporter already recorded that typed failure before this callback retires.
      if owner.cleanup_complete() {
        Ok(())
      } else {
        Err(
          @input.input_source_failure(source).unwrap_or(
            InputError("JSONL temporary cleanup is incomplete"),
          ),
        )
      }
    }) {
    Ok(_) => {
      registered.val = true
      Ok(owner)
    }
    Err(_) =>
      Err(
        @input.input_source_error(source).unwrap_or(
          "JSONL temporary cleanup registration failed",
        ),
      )
  }
}

///|
async fn append_line_json_spool_frame(
  owner : @temp.TempOwner,
  source : @input.InputSource,
  account : @budget.Budget,
  tag : Byte,
  line : Int32,
  record : Int32,
  text : String,
) -> Result[Unit, String] {
  let size = match @input.validated_text_utf8_size(text) {
    Ok(size) => size
    Err(message) => return Err(line_json_spool_invalid(source, message))
  }
  // The SDK encoder returns one Native Bytes value. Reject an unaddressable
  // value before invoking it; this is the platform array extent, not a newly
  // chosen product quota or a default temporary limit.
  if size > 2147483647L {
    return Err(
      line_json_spool_invalid(
        source, "JSONL spool value exceeds Native Bytes extent",
      ),
    )
  }
  let extent = LINE_JSON_SPOOL_HEADER.to_int64() + size
  // Validate the complete frame before codec allocation or partial header
  // growth. The actual owner independently reserves each append under its
  // mutex; no preflight lease is transferred or charged twice concurrently.
  match account.reserve(TemporaryBytes, extent) {
    Ok(lease) => lease.release()
    Err(error) => return Err(line_json_spool_budget_failure(source, error))
  }
  let working = match
    line_json_spool_working(
      source,
      account,
      2L * LINE_JSON_SPOOL_HEADER.to_int64() + size,
    ) {
    Ok(lease) => lease
    Err(error) => return Err(error)
  }
  defer working.release()
  let header = FixedArray::make(LINE_JSON_SPOOL_HEADER, b'\x00')
  header[0] = tag
  line_json_spool_put_int64(header, 1, line.to_int64())
  line_json_spool_put_int64(header, 9, record.to_int64())
  line_json_spool_put_int64(header, 17, size)
  match account.charge(ParseWork, extent) {
    Ok(_) => ()
    Err(error) => return Err(line_json_spool_budget_failure(source, error))
  }
  let bytes = @utf8.encode(text)
  match owner.append(Bytes::from_array(header[:])) {
    Ok(_) => ()
    Err(error) => return Err(line_json_spool_failure(source, error))
  }
  match owner.append(bytes) {
    Ok(_) => Ok(())
    Err(error) => Err(line_json_spool_failure(source, error))
  }
}

///|
async fn read_line_json_spool_exact(
  cursor : LineJsonSpoolCursor,
  source : @input.InputSource,
  buffer : FixedArray[Byte],
) -> Result[Unit, String] {
  for at = 0; at < buffer.length(); {
    match
      cursor.owner.read_at(
        cursor.range,
        cursor.offset + at.to_int64(),
        buffer,
        offset=at,
        length=buffer.length() - at,
      ) {
      Ok(count) if count > 0 => continue at + count
      Ok(_) =>
        return Err(line_json_spool_invalid(source, "premature JSONL spool EOF"))
      Err(error) => return Err(line_json_spool_failure(source, error))
    }
  }
  cursor.offset += buffer.length().to_int64()
  Ok(())
}

///|
async fn next_line_json_spool_frame(
  cursor : LineJsonSpoolCursor,
  source : @input.InputSource,
  budget : @budget.BudgetContext,
) -> Result[LineJsonSpoolFrame?, String] {
  if cursor.offset == cursor.range.length {
    return Ok(None)
  }
  if cursor.offset > cursor.range.length ||
    cursor.range.length - cursor.offset < LINE_JSON_SPOOL_HEADER.to_int64() {
    return Err(line_json_spool_invalid(source, "incomplete JSONL spool header"))
  }
  let header_lease = match
    line_json_spool_working(
      source,
      budget.account,
      LINE_JSON_SPOOL_HEADER.to_int64(),
    ) {
    Ok(lease) => lease
    Err(error) => return Err(error)
  }
  defer header_lease.release()
  let header = FixedArray::make(LINE_JSON_SPOOL_HEADER, b'\x00')
  match read_line_json_spool_exact(cursor, source, header) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let line = line_json_spool_get_int64(header, 1)
  let record = line_json_spool_get_int64(header, 9)
  let size = line_json_spool_get_int64(header, 17)
  if (header[0].to_int() & 255) > 2 ||
    (header[0] == b'\x01' && size != 0L) ||
    line <= 0L ||
    line > 2147483647L ||
    record < 0L ||
    record > 2147483647L ||
    size < 0L ||
    size > 2147483647L ||
    size > cursor.range.length - cursor.offset {
    return Err(
      line_json_spool_invalid(source, "invalid JSONL spool frame extent"),
    )
  }
  let payload_lease = match
    line_json_spool_working(source, budget.account, 4L * size) {
    Ok(lease) => lease
    Err(error) => return Err(error)
  }
  defer payload_lease.release()
  let payload = FixedArray::make(size.to_int(), b'\x00')
  match read_line_json_spool_exact(cursor, source, payload) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match
    budget.account.charge(ParseWork, LINE_JSON_SPOOL_HEADER.to_int64() + size) {
    Ok(_) => ()
    Err(error) => return Err(line_json_spool_budget_failure(source, error))
  }
  let text = @utf8.decode(Bytes::from_array(payload[:]), ignore_bom=false) catch {
    _ =>
      return Err(
        line_json_spool_invalid(source, "invalid UTF8 in JSONL spool payload"),
      )
  }
  // These strings may escape as final CoreEvents/IR. Retain a conservative
  // conversion-scope UTF16 payload lease before dropping transient workspace;
  // never claim next()/buffer release frees strings a consumer may still hold.
  match (budget.retain_resident)(CacheBytes, 2L * text.length().to_int64()) {
    Ok(_) => ()
    Err(error) => return Err(line_json_spool_budget_failure(source, error))
  }
  Ok(
    Some({ tag: header[0], line: line.to_int(), record: record.to_int(), text, }),
  )
}
