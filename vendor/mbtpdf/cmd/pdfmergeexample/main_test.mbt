///|
async fn cleanup(path : String) -> Unit {
  let _ : Result[Unit, Error] = try? @fs.remove(path)

}

///|
async test "run handles usage and merges inputs" {
  let prev_pdfe = @pdfe.quiet.val
  let prev_pdfutil = @pdfutil.quiet.val
  @pdfe.quiet.val = true
  @pdfutil.quiet.val = true
  try {
    run(["pdfmerge"], quiet=true)
    let in1 = "cmd_pdfmerge_in1.pdf"
    let in2 = "cmd_pdfmerge_in2.pdf"
    let out = "cmd_pdfmerge_out.pdf"
    cleanup(in1)
    cleanup(in2)
    cleanup(out)
    let pdf1 = @pdfpage.PdfPageDoc::minimum_valid()
    let pdf2 = @pdfpage.PdfPageDoc::minimum_valid()
    @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf1, in1)
    @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf2, in2)
    run(["pdfmerge", in1, in2, out], quiet=true)
    assert_true(@fs.exists(out))
    cleanup(in1)
    cleanup(in2)
    cleanup(out)
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
