///|
async test "cleanup status remains incomplete across a real nonempty-directory failure and retry" {
  let account = temp_test_account(cap=4L)
  let original = native_ops()
  let closes = Ref(0)
  let reports : Array[TempFailure] = []
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
    report_failure=error => reports.push(error),
    ops~,
  ).unwrap()
  defer ignore(owner.close())
  assert_false(owner.cleanup_complete())
  owner.append(b"data").unwrap()
  // The owned payload can be removed, but a second real file prevents rmdir.
  // No private remove/rmdir callback pretends this OS failure happened.
  let blocker_path = owner.state.directory + "/blocker"
  let blocker = @fs.open(
    blocker_path,
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer blocker.close()
  defer (@fs.remove(blocker_path) catch { _ => () })
  blocker.write(b"still owned by test")
  blocker.close()
  assert_true(owner.close() is Err(Io(stage="rmdir", ..)))
  let first = owner.failure().unwrap()
  assert_false(owner.cleanup_complete())
  assert_eq(closes.val, 1)
  assert_eq(reports.length(), 1)
  assert_true(owner.state.sdk_close_completed)
  assert_true(owner.state.file_removed)
  assert_false(owner.state.directory_removed)
  assert_false(@fs.exists(owner.state.path))
  assert_true(@fs.exists(blocker_path))
  // Payload credit is refundable once the payload name is gone. The empty
  // private directory is still a cleanup obligation, not payload capacity.
  assert_eq(account.snapshot().resident.temporary_bytes, 0L)
  @fs.remove(blocker_path)
  assert_true(owner.close() is Err(error) && error == first)
  assert_true(owner.cleanup_complete())
  assert_false(@fs.exists(owner.state.directory))
  assert_eq(closes.val, 1)
  assert_eq(reports.length(), 1)
  assert_true(owner.close() is Err(error) && error == first)
  assert_true(owner.cleanup_complete())
  account.close().unwrap()
}
