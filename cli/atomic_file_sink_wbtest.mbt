///|
test "atomic file writer commits complete output" {
  let root = test_tmp_root() + "/atomic-file-sink"
  ensure_dir_tree(root) catch {
    error => fail(error.to_string())
  }
  let path = root + "/output.md"
  let writer = open_atomic_file_writer(path).unwrap()
  atomic_file_writer_write(writer, "alpha").unwrap()
  atomic_file_writer_write(writer, "\nbeta\n").unwrap()
  atomic_file_writer_commit(writer).unwrap()
  assert_eq(read_utf8_text(path), "alpha\nbeta\n")
}

///|
test "atomic file writer abort does not publish a partial target" {
  let root = test_tmp_root() + "/atomic-file-abort"
  ensure_dir_tree(root) catch {
    error => fail(error.to_string())
  }
  let path = root + "/output.md"
  let writer = open_atomic_file_writer(path).unwrap()
  atomic_file_writer_write(writer, "partial").unwrap()
  atomic_file_writer_abort(writer)
  assert_false(@fs.path_exists(path))
}

///|
test "CLI writes assetless Markdown through the atomic unbuffered sink" {
  let root = test_tmp_root() + "/atomic-cli-stream"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)
  let input_path = root + "/input.txt"
  let output_path = root + "/output.md"
  write_utf8_text(input_path, "alpha\n\nbeta")
  let rendered = run_cli(
    cli_options(input_path, Some(output_path), Some(Txt), Markdown),
  ).unwrap()
  assert_eq(rendered, "alpha\n\nbeta\n")
  assert_eq(read_utf8_text(output_path), rendered)
}
