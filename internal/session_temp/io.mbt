///|
/// Reserve the full requested growth before writing. A failed/cancelled append
/// keeps that conservative reservation, even if no committed extent is visible.
pub async fn TempOwner::append(
  self : TempOwner,
  bytes : BytesView,
) -> Result[Unit, TempFailure] noraise {
  let state = self.state
  state.mutex.acquire()
  defer state.mutex.release()
  if health(state) is Some(error) {
    return Err(error)
  }
  if state.is_sealed {
    return Err(State("cannot append to sealed temporary store"))
  }
  let amount = bytes.length().to_int64()
  if amount > state.capacity - state.reserved {
    return Err(
      latch(
        state,
        Budget(
          LimitExceeded(
            Resident(TemporaryBytes),
            used=state.reserved,
            requested=amount,
            limit=state.capacity,
          ),
        ),
      ),
    )
  }
  let lease = match state.account.reserve(TemporaryBytes, amount) {
    Err(error) => return Err(latch(state, Budget(error)))
    Ok(lease) => lease
  }
  if amount == 0L {
    return Ok(())
  }
  state.leases.push(lease)
  state.reserved += amount
  guard state.handle is Some(handle) else {
    return Err(latch(state, State("temporary store has no handle")))
  }
  let completed = Ref(false)
  // Cancellation is a separate control channel, so Error catches cannot
  // poison the owner. Retire its writable state before releasing the mutex:
  // a partial write may already have advanced the SDK File's write head.
  defer (if !completed.val {
    ignore(latch(state, State("temporary append did not complete")))
  })
  for written = 0; written < bytes.length(); {
    let count = (state.ops.write)(handle, bytes[written:]) catch {
      error =>
        return Err(latch(state, Io(stage="append", message=error.to_string())))
    }
    if count <= 0 || count > bytes.length() - written {
      return Err(
        latch(
          state,
          Io(stage="append", message="invalid temporary-file write count"),
        ),
      )
    }
    continue written + count
  }
  state.committed += amount
  completed.val = true
  Ok(())
}

///|
/// Read into caller-owned storage. A short positive read is returned as-is;
/// zero before the recorded extent is a hard unexpected-EOF error.
pub async fn TempOwner::read_at(
  self : TempOwner,
  range : TempRange,
  relative_offset : Int64,
  buffer : FixedArray[Byte],
  offset~ : Int32 = 0,
  length~ : Int32 = buffer.length() - offset,
) -> Result[Int32, TempFailure] noraise {
  let state = self.state
  state.mutex.acquire()
  defer state.mutex.release()
  if health(state) is Some(error) {
    return Err(error)
  }
  if !state.is_sealed || !physical_equal(range.identity, state.identity) {
    return Err(State("temporary range does not belong to this sealed owner"))
  }
  if relative_offset < 0L ||
    relative_offset > range.length ||
    offset < 0 ||
    offset > buffer.length() ||
    length < 0 ||
    length > buffer.length() - offset {
    return Err(State("temporary read is outside its range or buffer"))
  }
  let remaining = range.length - relative_offset
  let length = if remaining < length.to_int64() {
    remaining.to_int()
  } else {
    length
  }
  if length == 0 {
    return Ok(0)
  }
  guard state.handle is Some(handle) else {
    return Err(latch(state, State("temporary store has no handle")))
  }
  let count = (state.ops.read)(
    handle,
    buffer,
    offset,
    length,
    range.start + relative_offset,
  ) catch {
    error =>
      return Err(latch(state, Io(stage="read", message=error.to_string())))
  }
  if count <= 0 || count > length {
    return Err(
      latch(
        state,
        Io(stage="read", message="unexpected temporary-file EOF or count"),
      ),
    )
  }
  match state.account.charge(ReadTrafficBytes, count.to_int64()) {
    Err(error) => Err(latch(state, Budget(error)))
    Ok(_) => Ok(count)
  }
}
