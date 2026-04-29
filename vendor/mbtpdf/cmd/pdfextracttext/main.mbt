///|
async fn main {
  run(@env.args())
}

///|
pub async fn run(args : Array[String], quiet? : Bool = false) -> Unit {
  if args.length() < 2 || args.length() > 3 {
    if !quiet {
      println("Syntax: pdftext <input> [output]")
    }
    return
  }
  let in_file = args[1]
  let out_file = if args.length() == 3 { Some(args[2]) } else { None }
  try {
    let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, in_file)
    if @pdfcrypt.PdfCrypt::new().is_encrypted(pdf) {
      fail("File is encrypted.")
    }
    let text = @pdftext.PdfText::new(pdf).extract_text()
    match out_file {
      Some(path) => @fs.write_file(path, text, create=0o644, truncate=true)
      None => if !quiet { println(text) }
    }
  } catch {
    err =>
      if !quiet {
        println("Failed to extract text.")
        println(err)
      }
  }
}
