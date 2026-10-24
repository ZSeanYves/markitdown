///|
async test "atomic writer repeated abort never unlinks a later foreign file at its former sibling name" {
  let root = test_tmp_root() + "/atomic-name-owner-reentry"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let output = root + "/output.md"
  let writer = open_atomic_file_writer(output).unwrap()
  atomic_file_writer_write(writer, "partial original").unwrap()
  let names = @asset_fs.readdir(root)
  assert_eq(names.length(), 1)
  assert_true(names[0].has_prefix("output.md.tmp."))
  let sibling = root + "/" + names[0]
  atomic_file_writer_abort(writer).unwrap()
  assert_false(@fs.path_exists(sibling))
  write_utf8_text(sibling, "foreign replacement must survive")
  atomic_file_writer_abort(writer).unwrap()
  assert_true(
    @fs.path_exists(sibling),
    msg="a retired owner removed a foreign replacement",
  )
  assert_eq(read_utf8_text(sibling), "foreign replacement must survive")
  assert_false(@fs.path_exists(output))
}

///|
async test "atomic finalizer leaves a foreign sibling after explicit successful abort" {
  let root = test_tmp_root() + "/atomic-name-owner-finalizer"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let owner = Ref(Some(open_atomic_file_writer(root + "/out.md").unwrap()))
  atomic_file_writer_write(owner.val.unwrap(), "original").unwrap()
  let sibling = root + "/" + @asset_fs.readdir(root)[0]
  atomic_file_writer_abort(owner.val.unwrap()).unwrap()
  assert_true(atomic_writer_cleanup_complete_ffi(owner.val.unwrap()))
  write_utf8_text(sibling, "foreign after abort")
  owner.val = None
  assert_true(@fs.path_exists(sibling))
  assert_eq(read_utf8_text(sibling), "foreign after abort")
}

///|
async test "atomic rename failure is poisoned and its already closed stream can be cleaned exactly once" {
  let root = test_tmp_root() + "/atomic-rename-poison"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let output = root + "/target-directory"
  @asset_fs.mkdir(output)
  let writer = open_atomic_file_writer(output).unwrap()
  atomic_file_writer_write(writer, "payload").unwrap()
  assert_eq(atomic_writer_last_write_count_ffi(writer), 7L)
  let name = @asset_fs.readdir(root).filter(name => {
      name.has_prefix("target-directory.tmp.")
    })[0]
  let original = atomic_file_writer_commit(writer)
  assert_true(original is Err(_))
  assert_eq(atomic_writer_error_stage_ffi(writer), 6)
  assert_true(atomic_writer_operation_error_ffi(writer) != 0)
  assert_true(
    atomic_file_writer_write(writer, "must never be written") == original,
  )
  assert_true(atomic_file_writer_commit(writer) == original)
  assert_true(atomic_file_writer_abort(writer) == original)
  assert_true(atomic_writer_cleanup_complete_ffi(writer))
  assert_false(@fs.path_exists(root + "/" + name))
  assert_true(@fs.path_exists(output))
  assert_true(atomic_file_writer_abort(writer) == original)
}

///|
async test "atomic remove failure is observable retryable and preserves the original CLI error class" {
  let root = test_tmp_root() + "/atomic-remove-retry"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let writer = open_atomic_file_writer(root + "/out.md").unwrap()
  atomic_file_writer_write(writer, "pending").unwrap()
  let sibling = root + "/" + @asset_fs.readdir(root)[0]
  let parked = root + "/parked-owned-file"
  @asset_fs.rename(sibling, parked)
  @asset_fs.mkdir(sibling)
  // unlink(directory) is a deterministic actual filesystem error on both
  // target platforms, independent of uid/root permission bypass.
  let error = cli_abort_atomic_failure(
    writer,
    cli_failure(ResourceFailure, "original typed limit"),
  )
  assert_true(error.kind == ResourceFailure)
  assert_true(
    error.message.has_prefix(
      "original typed limit; atomic cleanup remove failed",
    ),
  )
  assert_true(atomic_writer_remove_error_ffi(writer) != 0)
  assert_eq(atomic_writer_close_error_ffi(writer), 0)
  assert_false(atomic_writer_cleanup_complete_ffi(writer))
  assert_true(atomic_file_writer_write(writer, "poison") is Err(_))
  assert_eq(atomic_writer_operation_error_ffi(writer), 0)
  @asset_fs.rmdir(sibling)
  @asset_fs.rename(parked, sibling)
  // Cleanup error history is retained even though the retry is now complete.
  assert_true(atomic_file_writer_abort(writer) is Err(_))
  assert_true(atomic_writer_cleanup_complete_ffi(writer))
  assert_false(@fs.path_exists(sibling))
  write_utf8_text(sibling, "later owner")
  assert_true(atomic_file_writer_abort(writer) is Err(_))
  assert_eq(read_utf8_text(sibling), "later owner")
}

///|
async test "atomic output invalid UTF16 becomes a controlled poisoned encoding error before encoder invocation" {
  let root = test_tmp_root() + "/atomic-encoding-poison"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let writer = open_atomic_file_writer(root + "/out.md").unwrap()
  let invalid = String::from_array([(0xD800).unsafe_to_char()])
  let original = atomic_file_writer_write(writer, invalid)
  assert_true(original is Err(_))
  assert_eq(atomic_writer_error_stage_ffi(writer), 8)
  assert_eq(atomic_writer_last_write_count_ffi(writer), 0L)
  assert_true(atomic_file_writer_write(writer, "later") == original)
  assert_true(atomic_file_writer_commit(writer) == original)
  assert_true(atomic_file_writer_abort(writer) == original)
  assert_true(atomic_writer_cleanup_complete_ffi(writer))
  assert_eq(@asset_fs.readdir(root).length(), 0)
}

///|
async test "cancelled atomic conversion aborts its real sibling without publishing a target" {
  let root = test_tmp_root() + "/atomic-cancel-owner"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let entered = Ref(false)
  let resumed = Ref(false)
  let input = b"line one\n"
  let source = @input.input_from_reader(
    @input.make_async_input_reader(async fn(offset, length) {
      if offset < input.length().to_int64() {
        let start = offset.to_int()
        Ok(input[start:(start + length).min(input.length())].to_owned())
      } else {
        entered.val = true
        @async.sleep(60000)
        resumed.val = true
        Ok(b"")
      }
    }),
    source_name="cancel.txt",
  )
  let opts = cli_options(
    "cancel.txt",
    Some(root + "/out.md"),
    Some(Txt),
    Markdown,
  )
  let options = @convert.make_convert_options(
    Balanced,
    Markdown,
    Some(Txt),
    @convert.default_resource_limits(),
  )
  @async.with_task_group(group => {
    let task = group.spawn(() => {
      @async.handle_cancellation(() => {
        ignore(cli_convert_to_atomic_stream_file(opts, options, false, source))
      })
    })
    while !entered.val {
      @async.pause()
    }
    assert_eq(@asset_fs.readdir(root).length(), 1)
    task.cancel()
  })
  assert_false(resumed.val)
  assert_eq(@asset_fs.readdir(root).length(), 0)
  assert_false(@fs.path_exists(root + "/out.md"))
}
