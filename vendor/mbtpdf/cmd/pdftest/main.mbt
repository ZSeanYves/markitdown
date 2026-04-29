///|
fn rebuild_page(pdf : @pdf.Pdf, page : @pdfpage.Page) -> @pdfpage.Page raise {
  let ops = @pdfops.Op::parse_operators(pdf, page.resources, page.content)
  let stream = @pdfops.Op::stream_of_ops(ops)
  {
    content: [stream],
    mediabox: page.mediabox,
    resources: page.resources,
    rotate: page.rotate,
    rest: page.rest,
  }
}

///|
async fn main {
  run(@env.args())
}

///|
pub async fn run(args : Array[String], quiet? : Bool = false) -> Unit {
  if args.length() != 3 {
    if !quiet {
      println("Syntax: pdftest <input> <output>")
    }
    return
  }
  let in_name = args[1]
  let out_name = args[2]
  try {
    let file = @fs.open(in_name, mode=ReadOnly)
    let size = file.size().to_int()
    let data = file.read_exactly(size)
    file.close()
    let bytes = data.to_array()
    let input = @pdfio.Input::of_bytes(bytes, source=in_name)
    let pdf = @pdfread.PdfRead::new().pdf_of_input(None, None, input)
    if @pdfcrypt.PdfCrypt::new().is_encrypted(pdf) {
      fail("File is encrypted.")
    }
    let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    let rebuilt = Array::new()
    for page in pages {
      rebuilt.push(rebuild_page(pdf, page))
    }
    let pdf = @pdfpage.PdfPageDoc::new(pdf).change_pages(true, rebuilt)
    pdf.remove_unreferenced()
    let (output, buffer) = @pdfio.Output::of_bytes(1024)
    @pdfwrite.PdfWrite::new().pdf_to_output(None, true, pdf, output)
    let out_bytes = output.extract_bytes(buffer)
    @fs.write_file(
      out_name,
      Bytes::from_array(out_bytes),
      create=0o644,
      truncate=true,
    )
  } catch {
    err =>
      if !quiet {
        println("Test failed:")
        println(err)
      }
  }
}
