///|
test "main cli batch writes manifest for single markdown input" {
  let root = test_tmp_root() + "/main-cli-batch-single"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_path = root + "/note.md"
  let out_dir = root + "/out"
  write_utf8_text(input_path, "# Title\n\nhello batch\n")

  let exit_code = run_cli_app_silent([
    "markitdown-mb", "batch", input_path, out_dir,
  ])
  assert_eq(exit_code, 0)
  assert_true(@fs.path_exists(out_dir + "/manifest.json"))
  assert_true(@fs.path_exists(out_dir + "/note.md.md"))
  let manifest = read_utf8_text(out_dir + "/manifest.json")
  assert_true(manifest.contains("\"status\": \"success\""))
  assert_true(manifest.contains("\"relative_path\": \"note.md\""))
}

///|
test "main cli batch accurate keeps pdf tasks in the manifest instead of prefiltering them" {
  let root = test_tmp_root() + "/main-cli-batch-accurate"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_dir = root + "/in"
  let out_dir = root + "/out"
  ensure_dir_tree(input_dir)
  write_utf8_text(input_dir + "/note.md", "# Title\n\nok\n")
  write_utf8_text(input_dir + "/scan.pdf", "%PDF-1.4 fake")

  let exit_code = run_cli_app_silent([
    "markitdown-mb", "batch", "accurate", input_dir, out_dir,
  ])
  assert_eq(exit_code, 1)
  let manifest = read_utf8_text(out_dir + "/manifest.json")
  assert_true(manifest.contains("\"relative_path\": \"note.md\""))
  assert_true(manifest.contains("\"relative_path\": \"scan.pdf\""))
  assert_true(!manifest.contains("\"dependency_diagnostics\":"))
  assert_true(manifest.contains("accurate mode is unsupported for `markdown`"))
  assert_true(!@fs.path_exists(out_dir + "/note.md.md"))
}

///|
test "main CLI batch filesystem helpers and missing inputs fail closed" {
  assert_eq(dirname_of_path("file.txt"), ".")
  assert_eq(dirname_of_path("/file.txt"), ".")
  assert_eq(basename_of_path("file.txt"), "file.txt")
  assert_eq(basename_of_path("dir/file.txt"), "file.txt")
  ensure_dir_tree("") catch {
    err => fail(err.to_string())
  }
  ensure_dir_tree(".") catch {
    err => fail(err.to_string())
  }
  let root = ".tmp/tests/cli-batch-helper"
  cleanup_temp_dir(root)
  ensure_dir_tree(root + "/./nested/deeper") catch {
    err => fail("create batch helper dirs: " + err.to_string())
  }
  defer cleanup_temp_dir(root)
  @fs.write_string_to_file(root + "/single.md", "# single", encoding="utf8") catch {
    err => fail("write batch single fixture: " + err.to_string())
  }
  @fs.write_string_to_file(
    root + "/nested/deeper/child.md",
    "# child",
    encoding="utf8",
  ) catch {
    err => fail("write batch nested fixture: " + err.to_string())
  }
  assert_true(
    collect_batch_input_paths(root, root + "/single.md") ==
    [root + "/single.md"],
  )
  assert_eq(collect_batch_input_paths(root, root).length(), 2)
  assert_eq(
    batch_relative_path(root + "/single.md", root + "/single.md"),
    "single.md",
  )
  assert_eq(
    batch_relative_path(root + "/single.md", root + "/nested/deeper/child.md"),
    "child.md",
  )
  assert_eq(
    batch_relative_path(root + "/", root + "/nested/deeper/child.md"),
    "nested/deeper/child.md",
  )
  assert_eq(batch_relative_path(root, "/outside/value.md"), "value.md")
  assert_true(!fs_is_dir("/definitely/missing/batch"))
  assert_true(!fs_is_file("/definitely/missing/batch"))
  assert_eq(fs_read_dir("/definitely/missing/batch").length(), 0)
  assert_eq(batch_output_suffix(Debug), ".debug.json")
  assert_eq(
    run_cli_app_silent([
      "markitdown",
      "batch",
      "/definitely/missing/input",
      root + "/output",
    ]),
    1,
  )
  assert_true(parse_batch_cli_options(["batch", root], 1) is Err(_))
}
