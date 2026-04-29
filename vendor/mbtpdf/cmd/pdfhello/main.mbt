///|
pub async fn run(
  out_file? : String = "hello.pdf",
  quiet? : Bool = false,
) -> Unit {
  try {
    let font = @pdf.PdfObject::Dictionary([
      ("/Type", Name(@pdf.PdfName::of_string("/Font"))),
      ("/Subtype", Name(@pdf.PdfName::of_string("/Type1"))),
      ("/BaseFont", Name(@pdf.PdfName::of_string("/Times-Italic"))),
    ])
    let ops : Array[@pdfops.Op] = [
      Opcm(
        @pdftransform.Transform::new([
          @pdftransform.TransformOp::Translate(50.0, 770.0),
        ]).to_matrix(),
      ),
      OpBT,
      OpTf("/F0", 36.0),
      OpTj("Hello, World!"),
      OpET,
    ]
    let stream = @pdfops.Op::stream_of_ops(ops)
    let page : @pdfpage.Page = {
      content: [stream],
      mediabox: @pdfpage.Page::blank(@pdfpaper.a4).mediabox,
      resources: Dictionary([("/Font", Dictionary([("/F0", font)]))]),
      rotate: @pdfpage.Rotation::Rotate0,
      rest: Dictionary([]),
    }
    let (pdf, pageroot) = @pdfpage.PdfPageDoc::new(@pdf.Pdf::empty()).add_pagetree([
        page,
      ],
    )
    let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pageroot, [])
    @pdfwritefs.PdfWriteFs::new().pdf_to_file(pdf, out_file)
  } catch {
    err =>
      if !quiet {
        println("Failed to produce output.")
        println(err)
      }
  }
}

///|
async fn main {
  run()
}
