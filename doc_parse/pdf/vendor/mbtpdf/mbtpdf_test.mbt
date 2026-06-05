///|
fn test_tmp_root() -> String {
  match @sys.get_env_var("MARKITDOWN_TMP_DIR") {
    Some(dir) => if dir.trim() == "" { ".tmp" } else { dir }
    None => ".tmp"
  }
}

///|
fn fixture_path_mbtpdf(path : String) -> String {
  "doc_parse/pdf/vendor/mbtpdf/" + path
}

///|
async fn read_mbtpdf_test_pdf(filename : String) -> @pdf.Pdf {
  let input = @pdfiofs.input_of_file(filename, source=filename)
  @pdfread.PdfRead::new().pdf_of_input(None, None, input)
}

///|
async fn write_mbtpdf_test_pdf(pdf : @pdf.Pdf, filename : String) -> Unit {
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  @pdfwrite.PdfWrite::new().pdf_to_output(
    preserve_objstm=true,
    generate_objstm=false,
    compress_objstm=true,
    None,
    true,
    pdf,
    output,
  )
  @fs.write_file(
    filename,
    Bytes::from_array(output.extract_bytes(buffer)),
    create=0o644,
    truncate=true,
  )
}

///|
async fn ensure_tmp_dir(path : String) -> Unit {
  if !@fs.exists(path) {
    @fs.mkdir(path, permission=0o755, recursive=true)
  }
}

///|
async test "pdfread reads fixture logo pdf via direct file input" {
  let pdf = read_mbtpdf_test_pdf(fixture_path_mbtpdf("testdata/logo.pdf"))
  assert_true(pdf.objcard() > 0)
}

///|
async test "pdfwrite writes empty pdf fixture via direct file output" {
  let pdf = @pdf.Pdf::empty()
  let dir = test_tmp_root() + "/scratch/mbtpdf"
  ensure_tmp_dir(dir)
  let filename = dir + "/mbtpdf_writefs_test.pdf"
  write_mbtpdf_test_pdf(pdf, filename)
  assert_true(@fs.exists(filename))
  @fs.remove(filename)
}
