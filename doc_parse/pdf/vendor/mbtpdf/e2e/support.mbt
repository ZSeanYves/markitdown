///|
fn touch_imports() -> Unit {
  let _ = @pdf.Pdf::empty()
  let _ = @pdfe.quiet.val
  let _ = @pdfannot.PdfAnnot::new(@pdf.Pdf::empty())
  let _ = @pdfdest.Destination::NullDestination
  let _ = @pdfmarks.PdfMarks::new(@pdf.Pdf::empty())
  let _ = @pdfmerge.PdfMergeDoc::new(@pdf.Pdf::empty())
  let _ = @pdfops.Opq
  let _ = @pdfocg.PdfOcg::new(@pdf.Pdf::empty())
  let _ = @pdfio.Input::of_string("")
  let _ = @pdfpaper.a4
  let _ = @pdfpage.Rotation::Rotate0
  let _ = @pdfpagelabels.PdfPageLabels::new()
  let _ = @pdftree.PdfTree::new(@pdf.Pdf::empty())
  let _ = @pdfread.PdfRead::new()
  let _ = @pdfreadfs.PdfReadFs::new()
  let _ = @pdftext.PdfText::new(@pdf.Pdf::empty())
  let _ = @pdfwrite.PdfWrite::new()
  let _ = @pdfwritefs.PdfWriteFs::new()
  let _ = @sys.get_env_var
  let _ = @async.now()
  let _ = @fs.exists
}

///|
fn init {
  touch_imports()
}
