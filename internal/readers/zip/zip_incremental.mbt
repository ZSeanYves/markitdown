///|
priv enum ZipEmitError {
  EntryFailure(ZipError)
  ConsumerFailure(String)
}

///|
fn zip_budget_check(context : @budget.BudgetContext?) -> Unit raise ZipError {
  match context {
    None => ()
    Some(context) =>
      match context.account.charge(InflateBytes, 0L) {
        Ok(_) => ()
        Err(error) => raise BudgetExceeded(error)
      }
  }
}

///|
fn zip_check_archive_ready(archive : ZipArchive) -> Unit raise ZipError {
  zip_budget_check(archive.budget_context)
  if archive.hard_failure.val is Some(message) {
    raise DecodeFailed(message)
  }
}

///|
fn zip_charge_inflate(
  context : @budget.BudgetContext?,
  produced : Int32,
) -> Unit raise ZipError {
  match context {
    None => ()
    Some(context) =>
      match context.account.charge(InflateBytes, produced.to_int64()) {
        Ok(_) => ()
        Err(error) => raise BudgetExceeded(error)
      }
  }
}

///|
fn zip_retain_payload(
  context : @budget.BudgetContext?,
  kind : @budget.ResidentKind,
  amount : Int64,
) -> Unit raise ZipError {
  match context {
    None => ()
    Some(context) =>
      match (context.retain_resident)(kind, amount) {
        Ok(_) => ()
        Err(error) => raise BudgetExceeded(error)
      }
  }
}

///|
fn zip_reserve_scratch(
  context : @budget.BudgetContext?,
  amount : Int64,
) -> @budget.BudgetLease? raise ZipError {
  match context {
    None => None
    Some(context) =>
      match context.account.reserve(WorkingBytes, amount) {
        Ok(lease) => Some(lease)
        Err(error) => raise BudgetExceeded(error)
      }
  }
}

///|
fn zip_release_scratch(lease : @budget.BudgetLease?) -> Unit {
  if lease is Some(lease) {
    lease.release()
  }
}

///|
fn zip_check_entry_output_limit(
  entry : ZipEntryMeta,
  max_output_size : Int32,
) -> Unit raise ZipError {
  if max_output_size < 0 || entry.uncompressed_size > max_output_size {
    raise InvalidStructure(
      "decoded entry exceeds max_output_size: max=" +
      max_output_size.to_string() +
      ", actual=" +
      entry.uncompressed_size.to_string(),
    )
  }
}

///|
// The returned bare Bytes can outlive this read. Its reservation is held by
// the owning conversion scope even on cache-map removal. Buffer storage is a
// separate, private scratch lease and is released on every return path.
async fn collect_zip_entry_chunks(
  archive : ZipArchive,
  slice : ZipEntryDataSlice,
  max_output_size : Int32,
  resident_kind : @budget.ResidentKind,
) -> Bytes raise ZipError {
  let entry = slice.entry
  zip_check_entry_output_limit(entry, max_output_size)
  zip_retain_payload(
    archive.budget_context,
    resident_kind,
    entry.uncompressed_size.to_int64(),
  )
  // Buffer never grows: the shared emitter rejects a size overflow before
  // the append. Its minimum backing allocation is one byte for empty entries.
  let scratch = zip_reserve_scratch(
    archive.budget_context,
    entry.uncompressed_size.max(1).to_int64(),
  )
  defer zip_release_scratch(scratch)
  let output = Buffer(size_hint=entry.uncompressed_size)
  match
    emit_zip_entry_chunks(
      archive.source_read_at,
      slice,
      64 * 1024,
      max_output_size,
      archive.budget_context,
      false,
      chunk => {
        output.write_bytes(chunk)
        Ok(())
      },
    ) {
    Ok(_) => output.to_bytes()
    Err(EntryFailure(error)) => raise error
    Err(ConsumerFailure(message)) => raise DecodeFailed(message)
  }
}

///|
async fn deliver_zip_copied_chunk(
  output : FixedArray[Byte],
  produced : Int32,
  context : @budget.BudgetContext?,
  retain_chunks : Bool,
  crc : @checksum.Crc32,
  on_chunk : async (Bytes) -> Result[Unit, String],
) -> Result[Unit, ZipEmitError] noraise {
  let copied_payload = if retain_chunks {
    zip_retain_payload(context, WorkingBytes, produced.to_int64()) catch {
      error => return Err(EntryFailure(error))
    }
    None
  } else {
    zip_reserve_scratch(context, produced.to_int64()) catch {
      error => return Err(EntryFailure(error))
    }
  }
  defer zip_release_scratch(copied_payload)
  let chunk = Bytes::makei(produced, i => output[i])
  crc.update(chunk[:])
  let delivered = on_chunk(chunk) catch {
    error =>
      return Err(
        ConsumerFailure("ZIP chunk consumer failed: " + error.to_string()),
      )
  }
  match delivered {
    Ok(_) => Ok(())
    Err(message) => Err(ConsumerFailure(message))
  }
}

///|
// One integrity / inflate accounting path for cached, transient and visitor
// reads. It never retains errors in a reusable payload cache. Visitor chunks
// are bare Bytes, so their WorkingBytes leases remain with the owner scope;
// callback completion does not establish that a caller released the bytes.
async fn emit_zip_entry_chunks(
  read_at : async (Int32, Int32) -> Result[Bytes, String],
  slice : ZipEntryDataSlice,
  chunk_size : Int32,
  max_output_size : Int32,
  context : @budget.BudgetContext?,
  retain_chunks : Bool,
  on_chunk : async (Bytes) -> Result[Unit, String],
) -> Result[Unit, ZipEmitError] noraise {
  let fail = fn(error : ZipError) -> Result[Unit, ZipEmitError] {
    Err(EntryFailure(error))
  }
  zip_budget_check(context) catch {
    error => return fail(error)
  }
  let entry = slice.entry
  zip_check_entry_output_limit(entry, max_output_size) catch {
    error => return fail(error)
  }
  if entry.compression_method is Unsupported(code) {
    return fail(UnsupportedCompressionMethod(code))
  }
  let chunk_size = if chunk_size <= 0 { 64 * 1024 } else { chunk_size }
  let feed_capacity = (slice.data_end - slice.data_start).min(chunk_size).max(1)
  let output_capacity = chunk_size.min(64 * 1024)
  // read_zip_source_fully owns a source chunk, a growing Buffer (capacity
  // strictly below 2*request), and its final copy. Reserve 4*request to include
  // all overlapping payloads. Inflater/output storage is private to this call.
  let scratch_bytes = feed_capacity.to_int64() * 4L +
    (if entry.compression_method == DeflateRaw {
      output_capacity.to_int64() + @inflate.inflater_payload_upper_bound()
    } else {
      0L
    })
  let scratch = zip_reserve_scratch(context, scratch_bytes) catch {
    error => return fail(error)
  }
  defer zip_release_scratch(scratch)
  let mut emitted_bytes = 0
  let crc = @checksum.Crc32()
  match entry.compression_method {
    Store => {
      let mut pos = slice.data_start
      while pos < slice.data_end {
        let end_ = pos + (slice.data_end - pos).min(chunk_size)
        let chunk = match read_zip_source_fully(read_at, pos, end_ - pos) {
          Ok(value) => value
          Err(message) => return fail(DecodeFailed(message))
        }
        zip_charge_inflate(context, chunk.length()) catch {
          error => return fail(error)
        }
        if chunk.length() > entry.uncompressed_size - emitted_bytes {
          return fail(
            InvalidStructure("decoded size overflow for entry: " + entry.name),
          )
        }
        if retain_chunks {
          zip_retain_payload(context, WorkingBytes, chunk.length().to_int64()) catch {
            error => return fail(error)
          }
        }
        emitted_bytes += chunk.length()
        crc.update(chunk[:])
        let delivered = on_chunk(chunk) catch {
          error =>
            return Err(
              ConsumerFailure("ZIP chunk consumer failed: " + error.to_string()),
            )
        }
        if delivered is Err(message) {
          return Err(ConsumerFailure(message))
        }
        pos = end_
      }
    }
    DeflateRaw => {
      let inflater = @inflate.Inflater()
      let output = FixedArray::make(output_capacity, b'\x00')
      let mut pos = slice.data_start
      let mut done = false
      while !done {
        let feed_end = pos + (slice.data_end - pos).min(chunk_size)
        let compressed = match
          read_zip_source_fully(read_at, pos, feed_end - pos) {
          Ok(value) => value
          Err(message) => return fail(DecodeFailed(message))
        }
        pos = feed_end
        let mut consumed = 0
        let mut needs_more_input = false
        while !done && !needs_more_input {
          let status = inflater.step(
            compressed[consumed:],
            output.mut_view(),
            end=pos == slice.data_end,
          ) catch {
            InflateError(_, message) => {
              // A corrupt step may already have written scratch output. The
              // local leaf preserves that count before releasing its views.
              // Account the physical work, but never copy/deliver failed data.
              zip_charge_inflate(context, inflater.last_produced()) catch {
                error => return fail(error)
              }
              return fail(
                DecodeFailed(
                  "decode failed for `" + entry.name + "`: " + message,
                ),
              )
            }
          }
          consumed += inflater.last_consumed()
          let produced = inflater.last_produced()
          // Charge actual work before copying the scratch output or exposing
          // it. Later size/CRC/consumer failures never refund prior charges.
          zip_charge_inflate(context, produced) catch {
            error => return fail(error)
          }
          if produced > entry.uncompressed_size - emitted_bytes {
            return fail(
              InvalidStructure("decoded size overflow for entry: " + entry.name),
            )
          }
          if produced > 0 {
            emitted_bytes += produced
            match
              deliver_zip_copied_chunk(
                output, produced, context, retain_chunks, crc, on_chunk,
              ) {
              Ok(_) => ()
              Err(error) => return Err(error)
            }
          }
          match status {
            NeedMoreInput =>
              if pos >= slice.data_end {
                return fail(
                  DecodeFailed(
                    "decode failed for `" + entry.name + "`: unexpected EOF",
                  ),
                )
              } else {
                needs_more_input = true
              }
            NeedMoreOutput => ()
            Done => {
              if consumed != compressed.length() || pos != slice.data_end {
                return fail(
                  InvalidStructure(
                    "decoded entry left trailing compressed bytes: " +
                    entry.name,
                  ),
                )
              }
              done = true
            }
          }
        }
      }
    }
    Unsupported(code) => return fail(UnsupportedCompressionMethod(code))
  }
  if emitted_bytes != entry.uncompressed_size {
    return fail(
      InvalidStructure(
        "decoded size mismatch for entry: " +
        entry.name +
        " expected=" +
        entry.uncompressed_size.to_string() +
        " actual=" +
        emitted_bytes.to_string(),
      ),
    )
  }
  let actual_crc = crc.finish().reinterpret_as_int()
  if actual_crc != entry.crc32 {
    return fail(ChecksumMismatch(entry.name, entry.crc32, actual_crc))
  }
  Ok(())
}
