///|
/// Filesystem/channel helpers for `@pdfwrite`.
///
/// `@pdfwrite` itself is intentionally in-memory: it writes to `@pdfio.Output`.
/// This package concentrates native-only `@fs.File` and filename helpers.

///|
pub struct PdfWriteFs {
  writer : @pdfwrite.PdfWrite
}

///|
pub fn PdfWriteFs::new(logger? : (String) -> Unit) -> PdfWriteFs {
  { writer: @pdfwrite.PdfWrite::new(logger?) }
}

///|
pub fn PdfWriteFs::of_writer(writer : @pdfwrite.PdfWrite) -> PdfWriteFs {
  { writer, }
}

///|
pub async fn PdfWriteFs::pdf_to_channel(
  self : PdfWriteFs,
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  encryption : @pdfwrite.Encryption?,
  build_new_id : Bool,
  pdf : @pdf.Pdf,
  channel : @fs.File,
) -> Unit {
  let output = @pdfiofs.output_of_channel(channel)
  match recrypt {
    Some(value) =>
      self.writer.pdf_to_output(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        recrypt=value,
        encryption,
        build_new_id,
        pdf,
        output,
      )
    None =>
      self.writer.pdf_to_output(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        encryption,
        build_new_id,
        pdf,
        output,
      )
  }
  (output.flush)()
}

///|
pub async fn PdfWriteFs::pdf_to_file_options(
  self : PdfWriteFs,
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  encryption : @pdfwrite.Encryption?,
  build_new_id : Bool,
  pdf : @pdf.Pdf,
  filename : String,
) -> Unit {
  let file = @fs.open(filename, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  match recrypt {
    Some(value) =>
      self.pdf_to_channel(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        recrypt=value,
        encryption,
        build_new_id,
        pdf,
        file,
      )
    None =>
      self.pdf_to_channel(
        preserve_objstm~,
        generate_objstm~,
        compress_objstm~,
        encryption,
        build_new_id,
        pdf,
        file,
      )
  }
}

///|
pub async fn PdfWriteFs::pdf_to_file(
  self : PdfWriteFs,
  pdf : @pdf.Pdf,
  filename : String,
) -> Unit {
  self.pdf_to_file_options(
    preserve_objstm=true,
    generate_objstm=false,
    compress_objstm=true,
    None,
    true,
    pdf,
    filename,
  )
}
