///|
fn ooxml_replay_scratch(
  context : @budget.BudgetContext?,
  bytes : Int64,
) -> @budget.BudgetLease? raise OoxmlError {
  match context {
    None => None
    Some(context) =>
      match context.account.reserve(WorkingBytes, bytes) {
        Ok(lease) => Some(lease)
        Err(error) => raise BudgetExceeded(error)
      }
  }
}

///|
fn ooxml_replay_charge(
  context : @budget.BudgetContext?,
  bytes : Int64,
) -> Unit raise OoxmlError {
  if context is Some(context) {
    match context.account.charge(ParseWork, bytes) {
      Ok(_) => ()
      Err(error) => raise BudgetExceeded(error)
    }
  }
}

///|
// Error-only path: the first XML cursor has failed and cannot resume. Re-read
// the same bounded entry to validate UTF8 + ZIP EOF/CRC before allowing a soft
// syntax fallback. This is an explicit second read/inflate/decode, charged to
// the same account; successful XML still uses only the original cursor pass.
async fn verify_ooxml_xml_entry_integrity(
  archive : @zip.ZipArchive,
  part : String,
  chunk_size~ : Int32,
) -> Unit raise OoxmlError {
  let context = @zip.archive_budget_context(archive)
  require_relationship_archive_healthy(archive)
  let carry = Ref(b"")
  let carry_lease : Ref[@budget.BudgetLease?] = Ref(None)
  defer (if carry_lease.val is Some(lease) { lease.release() })
  let offset = Ref(0L)
  let callback_failure : Ref[OoxmlError?] = Ref(None)
  let visited = @zip.visit_inflated_entry_chunks(
    archive,
    part,
    chunk_size~,
    max_output_size=128 * 1024 * 1024,
    chunk => {
      let checked = try {
        let combined_bytes = carry.val.length().to_int64() +
          chunk.length().to_int64()
        ooxml_replay_charge(context, combined_bytes)
        // Combined/prefix Bytes, decoder UTF16 payload/scratch and <=3-byte
        // suffix trial copies fit this conservative live-payload upper bound.
        // This does not claim to measure allocator or object/GC overhead.
        let scratch = ooxml_replay_scratch(context, combined_bytes * 8L + 12L)
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
            raise InvalidEncoding(
              part +
              ": " +
              message +
              "; replay_buffer_utf8_byte=" +
              start.to_string(),
            )
        }
        let next_lease = if decoded.1.length() == 0 {
          None
        } else {
          ooxml_replay_scratch(context, decoded.1.length().to_int64())
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
          callback_failure.val = Some(ooxml_cursor_hard_failure(archive, error))
          Err("OOXML integrity replay stopped")
        }
      }
    },
  )
  if visited is Err(message) {
    if context is Some(context) && context.account.failure() is Some(error) {
      raise ooxml_cursor_hard_failure(archive, BudgetExceeded(error))
    }
    if callback_failure.val is Some(error) {
      raise error
    }
    raise ZipError(message)
  }
  if carry.val.length() > 0 {
    ooxml_replay_charge(context, carry.val.length().to_int64()) catch {
      error => raise ooxml_cursor_hard_failure(archive, error)
    }
    let scratch = ooxml_replay_scratch(
      context,
      carry.val.length().to_int64() * 8L + 12L,
    ) catch {
      error => raise ooxml_cursor_hard_failure(archive, error)
    }
    defer (if scratch is Some(lease) { lease.release() })
    match @sourceio.decode_utf8_source_chunk(carry.val, true) {
      Ok(_) => ()
      Err(message) =>
        raise ooxml_cursor_hard_failure(
          archive,
          InvalidEncoding(part + ": " + message + "; incomplete replay EOF"),
        )
    }
  }
  require_relationship_archive_healthy(archive)
}
