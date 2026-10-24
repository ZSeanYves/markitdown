///|
fn temp_test_account(cap? : Int64) -> @budget.Budget {
  @budget.Budget::new(
    @budget.BudgetLimits::new(
      MeasurementOnly,
      inflate_bytes=None,
      parse_work=None,
      output_utf8_bytes=None,
      source_metadata_bytes=None,
      rag_metadata_bytes=None,
      read_traffic_bytes=None,
      cache_bytes=None,
      working_bytes=None,
      temporary_bytes=cap,
      ir_bytes=None,
    ).unwrap(),
  )
}

///|
async test "temporary owner reads raw byte ranges only after sealing and cleans its names" {
  let account = temp_test_account(cap=8L)
  let owner = TempOwner::create(account, capacity=8L).unwrap()
  defer ignore(owner.close())
  let path = owner.state.path
  let directory = owner.state.directory
  assert_true(@fs.exists(path))
  owner.append(b"A\xf0\x9f").unwrap()
  owner.append(b"\x98\x80\r\nZ").unwrap()
  assert_eq(owner.length(), 8L)
  assert_true(owner.range(0L, 8L) is Err(_))
  owner.seal().unwrap()
  let range = owner.range(1L, 4L).unwrap()
  let buffer = FixedArray::make(6, b'!')
  for index in 0..<4 {
    assert_true(
      owner.read_at(range, index.to_int64(), buffer, offset=index + 1, length=1)
      is Ok(1),
    )
  }
  assert_eq(Bytes::from_array(buffer[:]), b"!\xf0\x9f\x98\x80!")
  assert_true(owner.read_at(range, 4L, buffer) is Ok(0))
  assert_true(owner.append(b"x") is Err(State(_)))
  assert_eq(account.snapshot().resident.temporary_bytes, 8L)
  assert_eq(account.snapshot().cumulative.read_traffic_bytes, 4L)
  owner.close().unwrap()
  owner.close().unwrap()
  assert_false(@fs.exists(path))
  assert_false(@fs.exists(directory))
  assert_true(owner.read_at(range, 0L, buffer) is Err(State(_)))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(account.snapshot().resident_peak.temporary_bytes, 8L)
  assert_true(account.close() is Ok(_))
}

///|
async test "temporary ranges reject foreign owners and checked arithmetic" {
  let account = temp_test_account()
  let first = TempOwner::create(account, capacity=4L).unwrap()
  defer ignore(first.close())
  let second = TempOwner::create(account, capacity=4L).unwrap()
  defer ignore(second.close())
  first.append(b"data").unwrap()
  first.seal().unwrap()
  second.seal().unwrap()
  let range = first.range(0L, 4L).unwrap()
  let buffer = FixedArray::make(4, b'\x00')
  assert_true(second.read_at(range, 0L, buffer) is Err(State(_)))
  assert_true(first.range(-1L, 1L) is Err(State(_)))
  assert_true(first.range(1L, 9223372036854775807L) is Err(State(_)))
  assert_true(first.read_at(range, -1L, buffer) is Err(State(_)))
  assert_true(first.read_at(range, 0L, buffer, offset=5) is Err(State(_)))
  assert_true(first.read_at(range, 0L, buffer) is Ok(4))
}

///|
async test "private finite capacity rejects before disk write and keeps the original resource units" {
  let account = temp_test_account(cap=100L)
  let reports : Array[TempFailure] = []
  let owner = TempOwner::create(account, capacity=3L, report_failure=error => {
    reports.push(error)
  }).unwrap()
  defer ignore(owner.close())
  owner.append(b"abc").unwrap()
  assert_true(
    owner.append(b"d")
    is Err(
      Budget(
        LimitExceeded(Resident(TemporaryBytes), used=3L, requested=1L, limit=3L)
      )
    ),
  )
  assert_eq(owner.length(), 3L)
  assert_eq(@fs.file_size(owner.state.path), 3L)
  assert_eq(reports.length(), 1)
  assert_true(owner.append(b"e") is Err(_))
  assert_eq(reports.length(), 1)
  assert_true(owner.close() is Err(_))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
}

///|
async test "shared temporary account remains stricter than a larger private capacity" {
  let account = temp_test_account(cap=3L)
  let owner = TempOwner::create(account, capacity=20L).unwrap()
  defer ignore(owner.close())
  owner.append(b"abc").unwrap()
  let result = owner.append(b"d")
  assert_true(
    result
    is Err(
      Budget(
        LimitExceeded(Resident(TemporaryBytes), used=3L, requested=1L, limit=3L)
      )
    ),
  )
  assert_eq(@fs.file_size(owner.state.path), 3L)
  let first = account.failure().unwrap()
  assert_true(owner.close() is Err(Budget(error)) && error == first)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
}

///|
async test "temporary owner rejects negative capacity and supports an explicit zero capacity" {
  let account = temp_test_account()
  assert_true(
    TempOwner::create(account, capacity=-1L)
    is Err(Budget(InvalidLimit(Resident(TemporaryBytes), -1L))),
  )
  let owner = TempOwner::create(account, capacity=0L).unwrap()
  defer ignore(owner.close())
  owner.append(b"").unwrap()
  owner.seal().unwrap()
  let range = owner.range(0L, 0L).unwrap()
  assert_true(owner.read_at(range, 0L, FixedArray::make(0, b'\x00')) is Ok(0))
  assert_eq(account.snapshot().active_leases, 0L)
  owner.close().unwrap()
}

///|
async test "partial failed writes retain full admission without publishing a committed range" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let ops = {
    ..original,
    write: async fn(handle, bytes) {
      ignore((original.write)(handle, bytes[:2]))
      raise Failure("injected error after a real partial write")
    },
  }
  let owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  defer ignore(owner.close())
  assert_true(owner.append(b"data") is Err(Io(stage="append", ..)))
  assert_eq(@fs.file_size(owner.state.path), 2L)
  assert_eq(owner.length(), 0L)
  assert_eq(account.snapshot().resident.temporary_bytes, 4L)
  assert_true(owner.seal() is Err(_))
  assert_true(owner.range(0L, 0L) is Err(_))
  assert_true(owner.close() is Err(Io(stage="append", ..)))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_false(@fs.exists(owner.state.path))
}

///|
async test "standard SDK close is invoked once and idempotent cleanup leaves later files usable" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let closes = Ref(0)
  let ops = {
    ..original,
    close: fn(handle) {
      closes.val += 1
      (original.close)(handle)
    },
  }
  let owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  defer ignore(owner.close())
  owner.append(b"data").unwrap()
  owner.close().unwrap()
  let later = TempOwner::create(account, capacity=4L).unwrap()
  defer ignore(later.close())
  owner.close().unwrap()
  later.append(b"safe").unwrap()
  later.seal().unwrap()
  let buffer = FixedArray::make(4, b'\x00')
  assert_true(later.read_at(later.range(0L, 4L).unwrap(), 0L, buffer) is Ok(4))
  assert_eq(Bytes::from_array(buffer[:]), b"safe")
  later.close().unwrap()
  assert_eq(closes.val, 1)
  assert_true(owner.state.handle is None)
  assert_false(@fs.exists(owner.state.path))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_true(account.close() is Ok(_))
}

///|
async test "named remove failure retains quota and retry never closes a later independent file" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let closes = Ref(0)
  let removes = Ref(0)
  let ops = {
    ..original,
    close: fn(handle) {
      closes.val += 1
      (original.close)(handle)
    },
    remove: async fn(path) {
      removes.val += 1
      if removes.val == 1 {
        raise Failure("injected named-file remove failure")
      }
      (original.remove)(path)
    },
  }
  let owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  defer ignore(owner.close())
  owner.append(b"data").unwrap()
  assert_true(owner.close() is Err(Io(stage="remove", ..)))
  assert_true(@fs.exists(owner.state.path))
  assert_eq(account.snapshot().resident.temporary_bytes, 4L)
  // A later independently owned file remains usable after a second cleanup.
  let other_path = owner.state.directory + "/other"
  let other = @fs.open(
    other_path,
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer other.close()
  defer (@fs.remove(other_path) catch { _ => () })
  assert_true(owner.close() is Err(Io(stage="remove", ..)))
  other.write_at(b"safe", position=0L)
  assert_eq(other.size(), 4L)
  assert_eq(closes.val, 1)
  assert_eq(removes.val, 2)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  other.close()
  @fs.remove(other_path)
  assert_true(owner.close() is Err(Io(stage="remove", ..)))
  assert_false(@fs.exists(owner.state.directory))
}

///|
async test "cancellation during an awaiting partial append runs nocancel cleanup before returning" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let entered = Ref(false)
  let resumed = Ref(false)
  let closes = Ref(0)
  let ops = {
    ..original,
    write: async fn(handle, bytes) {
      ignore((original.write)(handle, bytes[:2]))
      entered.val = true
      @async.sleep(60000)
      resumed.val = true
      2
    },
    close: fn(handle) {
      closes.val += 1
      (original.close)(handle)
    },
    remove: async fn(path) {
      @async.pause()
      (original.remove)(path)
    },
  }
  let owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        defer ignore(owner.close())
        owner.append(b"data").unwrap()
      })
    })
    while !entered.val {
      @async.pause()
    }
    assert_eq(account.snapshot().resident.temporary_bytes, 4L)
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_false(resumed.val)
  assert_eq(closes.val, 1)
  assert_eq(owner.length(), 0L)
  assert_false(@fs.exists(owner.state.path))
  assert_false(@fs.exists(owner.state.directory))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
}

///|
async test "cleanup waits for the same mutex as an in-flight real append" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let entered = Ref(false)
  let release_write = Ref(false)
  let writing = Ref(false)
  let closed_while_writing = Ref(false)
  let ops = {
    ..original,
    write: async fn(handle, bytes) {
      entered.val = true
      writing.val = true
      while !release_write.val {
        @async.pause()
      }
      let count = (original.write)(handle, bytes)
      writing.val = false
      count
    },
    close: fn(handle) {
      closed_while_writing.val = writing.val
      (original.close)(handle)
    },
  }
  let owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  defer ignore(owner.close())
  @async.with_task_group(group => {
    let append = group.spawn(() => owner.append(b"data"))
    while !entered.val {
      @async.pause()
    }
    let close = group.spawn(() => owner.close())
    @async.pause()
    assert_true(owner.state.handle is Some(_))
    release_write.val = true
    append.wait().unwrap()
    close.wait().unwrap()
  })
  assert_eq(owner.length(), 4L)
  assert_false(closed_while_writing.val)
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
}

///|
async test "cancelled awaited reads bypass generic Error catches and still remove owned storage" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let entered = Ref(false)
  let reads = Ref(0)
  let ops = {
    ..original,
    read: async fn(handle, buffer, offset, length, position) {
      reads.val += 1
      entered.val = true
      @async.sleep(60000)
      (original.read)(handle, buffer, offset, length, position)
    },
  }
  let owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  owner.append(b"data").unwrap()
  owner.seal().unwrap()
  let range = owner.range(0L, 4L).unwrap()
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        defer ignore(owner.close())
        owner.read_at(range, 0L, FixedArray::make(4, b'\x00')).unwrap()
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_eq(reads.val, 1)
  assert_true(owner.failure() is None)
  assert_false(@fs.exists(owner.state.path))
  assert_false(@fs.exists(owner.state.directory))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
}

///|
async test "real premature disk EOF is a hard failure while short positive reads remain valid" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let ops = {
    ..original,
    read: async fn(handle, buffer, offset, length, position) {
      (original.read)(handle, buffer, offset, length.min(1), position)
    },
  }
  let owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  defer ignore(owner.close())
  owner.append(b"data").unwrap()
  owner.seal().unwrap()
  let range = owner.range(0L, 4L).unwrap()
  let buffer = FixedArray::make(4, b'\x00')
  assert_true(owner.read_at(range, 0L, buffer) is Ok(1))
  let truncater = @fs.open(
    owner.state.path,
    mode=WriteOnly,
    create_mode=TruncateExisting,
  )
  truncater.close()
  assert_true(owner.read_at(range, 1L, buffer) is Err(Io(stage="read", ..)))
  assert_true(owner.close() is Err(Io(stage="read", ..)))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
}

///|
async test "failed construction without a returned file removes only its own empty directory" {
  let account = temp_test_account()
  let original = native_ops()
  let directory = Ref("")
  let ops = {
    ..original,
    directory: async fn() {
      let path = (original.directory)()
      directory.val = path
      path
    },
    open: async fn(_path) {
      @async.pause()
      raise Failure("injected open failure before file creation")
    },
  }
  assert_true(
    create_with_ops(account, capacity=4L, report_failure=fn(_) {  }, ops~)
    is Err(Io(stage="create file", ..)),
  )
  assert_false(directory.val.is_empty())
  assert_false(@fs.exists(directory.val + "/payload"))
  assert_false(@fs.exists(directory.val))
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "CreateNew collision never deletes an unacquired file or guesses creation ownership" {
  let account = temp_test_account()
  let original = native_ops()
  let directory = Ref("")
  let ops = {
    ..original,
    directory: async fn() {
      let path = (original.directory)()
      directory.val = path
      path
    },
    open: async fn(path) {
      let sentinel = (original.open)(path)
      defer sentinel.close()
      sentinel.write(b"unknown-owner")
      (original.open)(path)
    },
  }
  assert_true(
    create_with_ops(account, capacity=4L, report_failure=fn(_) {  }, ops~)
    is Err(Io(stage="create file", ..)),
  )
  let path = directory.val + "/payload"
  defer @fs.rmdir(directory.val)
  defer @fs.remove(path)
  let sentinel = @fs.open(path, mode=ReadOnly)
  defer sentinel.close()
  assert_eq(sentinel.read_exactly(13), b"unknown-owner")
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "a budget failure during constructor await is observed before publication and rolls back" {
  let account = temp_test_account(cap=0L)
  let original = native_ops()
  let path = Ref("")
  let ops = {
    ..original,
    open: async fn(filename) {
      let file = (original.open)(filename)
      path.val = filename
      ignore(account.reserve(TemporaryBytes, 1L))
      file
    },
  }
  assert_true(
    create_with_ops(account, capacity=4L, report_failure=fn(_) {  }, ops~)
    is Err(
      Budget(
        LimitExceeded(Resident(TemporaryBytes), used=0L, requested=1L, limit=0L)
      )
    ),
  )
  assert_false(@fs.exists(path.val))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "cancellation during protected construction transfers ownership before the next cancel point" {
  let account = temp_test_account()
  let original = native_ops()
  let entered = Ref(false)
  let allow_return = Ref(false)
  let published : Ref[TempOwner?] = Ref(None)
  let ops = {
    ..original,
    open: async fn(path) {
      let handle = (original.open)(path)
      entered.val = true
      while !allow_return.val {
        @async.pause()
      }
      handle
    },
  }
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        let owner = create_with_ops(
          account,
          capacity=4L,
          report_failure=fn(_) {  },
          ops~,
        ).unwrap()
        defer ignore(owner.close())
        published.val = Some(owner)
        @async.pause()
      })
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    allow_return.val = true
    assert_true(task.wait() is None)
  })
  let owner = published.val.unwrap()
  assert_true(owner.state.closed)
  assert_false(@fs.exists(owner.state.path))
  assert_false(@fs.exists(owner.state.directory))
  assert_eq(account.snapshot().active_leases, 0L)
}

///|
async test "owner IO and shared budget first errors keep their order through cleanup" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let ops = {
    ..original,
    read: async fn(_, _, _, _, _) {
      @async.pause()
      raise Failure("injected read failure")
    },
    remove: async fn(path) {
      (original.remove)(path)
      raise Failure("injected remove report after real deletion")
    },
  }
  let owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  defer ignore(owner.close())
  owner.append(b"data").unwrap()
  owner.seal().unwrap()
  let range = owner.range(0L, 4L).unwrap()
  let buffer = FixedArray::make(4, b'\x00')
  assert_true(owner.read_at(range, 0L, buffer) is Err(Io(stage="read", ..)))
  assert_true(account.charge(ParseWork, -1L) is Err(_))
  assert_true(owner.close() is Err(Io(stage="read", ..)))
  assert_eq(owner.state.cleanup_failures.length(), 1)
  // A retry observes ENOENT and confirms reclamation without another close.
  assert_true(owner.close() is Err(Io(stage="read", ..)))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  assert_true(
    account.failure() is Some(NegativeAmount(Cumulative(ParseWork), -1L)),
  )
  let earlier = temp_test_account(cap=0L)
  let owner = TempOwner::create(earlier, capacity=4L).unwrap()
  defer ignore(owner.close())
  assert_true(earlier.reserve(TemporaryBytes, 1L) is Err(_))
  assert_true(owner.append(b"x") is Err(Budget(_)))
  assert_true(owner.close() is Err(Budget(_)))
}

///|
async test "positive real short writes accumulate and a zero write never publishes success" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let writes = Ref(0)
  let ops = {
    ..original,
    write: async fn(handle, bytes) {
      writes.val += 1
      (original.write)(handle, bytes[:1])
    },
  }
  let owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  defer ignore(owner.close())
  owner.append(b"data").unwrap()
  assert_eq(writes.val, 4)
  assert_eq(owner.length(), 4L)
  assert_eq(@fs.file_size(owner.state.path), 4L)
  owner.seal().unwrap()
  let bytes = FixedArray::make(4, b'\x00')
  assert_true(owner.read_at(owner.range(0L, 4L).unwrap(), 0L, bytes) is Ok(4))
  assert_eq(Bytes::from_array(bytes[:]), b"data")
  owner.close().unwrap()
  let zero_ops = { ..original, write: fn(_, _) { 0 }, }
  let zero_owner = create_with_ops(
    account,
    capacity=4L,
    report_failure=fn(_) {  },
    ops=zero_ops,
  ).unwrap()
  defer ignore(zero_owner.close())
  assert_true(zero_owner.append(b"data") is Err(Io(stage="append", ..)))
  assert_eq(zero_owner.length(), 0L)
  assert_eq(@fs.file_size(zero_owner.state.path), 0L)
  assert_eq(account.snapshot().resident.temporary_bytes, 4L)
  assert_true(zero_owner.close() is Err(_))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
}

///|
async test "cancelled partial append is terminal before another task can publish a wrong range" {
  let account = temp_test_account(cap=8L)
  let original = native_ops()
  let entered = Ref(false)
  let writes = Ref(0)
  let ops = {
    ..original,
    write: async fn(handle, bytes) {
      writes.val += 1
      if writes.val == 1 {
        let count = (original.write)(handle, bytes[:2])
        entered.val = true
        @async.sleep(60000)
        count
      } else {
        (original.write)(handle, bytes)
      }
    },
  }
  let owner = create_with_ops(
    account,
    capacity=8L,
    report_failure=fn(_) {  },
    ops~,
  ).unwrap()
  defer ignore(owner.close())
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => owner.append(b"abcd"))
    })
    while !entered.val {
      @async.pause()
    }
    task.cancel()
    assert_true(task.wait() is None)
  })
  assert_eq(owner.length(), 0L)
  assert_eq(@fs.file_size(owner.state.path), 2L)
  assert_eq(account.snapshot().resident.temporary_bytes, 4L)
  // Keep the owner alive after cancellation: closing it immediately would
  // hide a stale committed offset versus the SDK File's advanced write head.
  assert_true(owner.append(b"XY") is Err(State(_)))
  assert_true(owner.seal() is Err(State(_)))
  assert_true(owner.range(0L, 2L) is Err(State(_)))
  assert_eq(writes.val, 1)
  assert_eq(@fs.file_size(owner.state.path), 2L)
  assert_true(owner.close() is Err(State(_)))
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
}
