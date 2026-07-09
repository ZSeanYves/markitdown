///|
test "main cli batch writes manifest for single markdown input" {
  let root = test_tmp_root() + "/main-cli-batch-single"
  recreate_clean_dir(root)
  defer cleanup_temp_dir(root)

  let input_path = root + "/note.md"
  let out_dir = root + "/out"
  write_utf8_text(input_path, "# Title\n\nhello batch\n")

  let exit_code = run_cli_app(["markitdown-mb", "batch", input_path, out_dir])
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

  let exit_code = run_cli_app([
    "markitdown-mb", "batch", "accurate", input_dir, out_dir,
  ])
  assert_eq(exit_code, 0)
  let manifest = read_utf8_text(out_dir + "/manifest.json")
  assert_true(manifest.contains("\"relative_path\": \"note.md\""))
  assert_true(manifest.contains("\"relative_path\": \"scan.pdf\""))
  assert_true(!manifest.contains("\"dependency_diagnostics\":"))
  assert_true(@fs.path_exists(out_dir + "/note.md.md"))
}
