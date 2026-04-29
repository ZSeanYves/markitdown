///|
async fn cleanup(path : String) -> Unit {
  let _ : Result[Unit, Error] = try? @fs.remove(path)

}

///|
async fn write_pdf_bytes(pdf : @pdf.Pdf, path : String) -> Unit {
  let (output, buffer) = @pdfio.Output::of_bytes(1024)
  let write_res : Result[Unit, Error] = try? @pdfwrite.PdfWrite::new().pdf_to_output(
    None,
    true,
    pdf,
    output,
  )
  match write_res {
    Ok(_) => ()
    Err(_) => fail("failed to serialize pdf")
  }
  let bytes = output.extract_bytes(buffer)
  let fs_res : Result[Unit, Error] = try? @fs.write_file(
    path,
    Bytes::from_array(bytes),
    create=0o644,
    truncate=true,
  )
  match fs_res {
    Ok(_) => ()
    Err(_) => fail("failed to write pdf bytes")
  }
}

///|
async test "run rebuilds pages and writes output" {
  let prev_pdfe = @pdfe.quiet.val
  let prev_pdfutil = @pdfutil.quiet.val
  @pdfe.quiet.val = true
  @pdfutil.quiet.val = true
  try {
    run(["pdftest"], quiet=true)
    let in_file = "cmd_pdftest_in.pdf"
    let out_file = "cmd_pdftest_out.pdf"
    cleanup(in_file)
    cleanup(out_file)
    let pdf = @pdfpage.PdfPageDoc::minimum_valid()
    write_pdf_bytes(pdf, in_file)
    run(["pdftest", in_file, out_file], quiet=true)
    assert_true(@fs.exists(out_file))
    let enc_file = "cmd_pdftest_enc.pdf"
    let out_enc = "cmd_pdftest_enc_out.pdf"
    cleanup(enc_file)
    cleanup(out_enc)
    let enc = @pdfcrypt.PdfCrypt::new().encrypt_pdf_40bit(
      "user",
      "owner",
      [],
      pdf,
    )
    write_pdf_bytes(enc, enc_file)
    run(["pdftest", enc_file, out_enc], quiet=true)
    assert_true(!@fs.exists(out_enc))
    cleanup(in_file)
    cleanup(out_file)
    cleanup(enc_file)
    cleanup(out_enc)
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
