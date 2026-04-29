///|
async fn cleanup(path : String) -> Unit {
  let _ : Result[Unit, Error] = try? @fs.remove(path)

}

///|
async test "run decompresses streams and writes output" {
  let prev_pdfe = @pdfe.quiet.val
  let prev_pdfutil = @pdfutil.quiet.val
  @pdfe.quiet.val = true
  @pdfutil.quiet.val = true
  try {
    run(["pdfdecomp"], quiet=true)
    let in_file = "cmd_pdfdecomp_in.pdf"
    let out_file = "cmd_pdfdecomp_out.pdf"
    cleanup(in_file)
    cleanup(out_file)
    let pdf = @pdfpage.PdfPageDoc::minimum_valid()
    @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, in_file)
    run(["pdfdecomp", in_file, out_file], quiet=true)
    assert_true(@fs.exists(out_file))
    cleanup(in_file)
    cleanup(out_file)
    @pdfe.quiet.val = prev_pdfe
    @pdfutil.quiet.val = prev_pdfutil
  } catch {
    err => {
      @pdfe.quiet.val = prev_pdfe
      @pdfutil.quiet.val = prev_pdfutil
      raise err
    }
  }
}
