///|
async fn main {
  run(@env.args())
}

///|
pub async fn run(args : Array[String], quiet? : Bool = false) -> Unit {
  if args.length() != 4 {
    if !quiet {
      println("Syntax: pdfencrypt <input> <output> <owner-password>")
    }
    return
  }
  let in_file = args[1]
  let out_file = args[2]
  let owner_pw = args[3]
  try {
    let pdf = @pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, in_file)
    let banlist = [@pdfcrypt.Permission::NoEdit, @pdfcrypt.Permission::NoPrint]
    let encrypted = @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES(
      false, "", owner_pw, banlist, pdf,
    )
    @pdfwritefs.PdfWriteFs::new().pdf_to_file(encrypted, out_file)
  } catch {
    err =>
      if !quiet {
        println("Failed to produce output.")
        println(err)
      }
  }
}
