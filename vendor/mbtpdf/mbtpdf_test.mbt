///|
fn test_tmp_root() -> String {
  match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
}

///|
fn fixture_path_mbtpdf(path : String) -> String {
  "vendor/mbtpdf/" + path
}

///|
async fn ensure_tmp_dir(path : String) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path, permission=0o755, recursive=true)
  }
}

///|
async test "root facade read_file" {
  let pdf = read_file(fixture_path_mbtpdf("testdata/logo.pdf"))
  assert_true(pdf.objcard() > 0)
}

///|
async test "root facade write_file" {
  let pdf = @pdf.Pdf::empty()
  let dir = test_tmp_root() + "/scratch/mbtpdf"
  ensure_tmp_dir(dir)
  let filename = dir + "/mbtpdf_facade_write_test.pdf"
  write_file(pdf, filename)
  assert_true(@fs.exists(filename))
  @fs.remove(filename)
}
