///|
fn encrypt_pdf_40bit_inner(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/Standard"))),
    ("/V", @pdf.PdfObject::Integer(1)),
    ("/R", @pdf.PdfObject::Integer(2)),
    ("/O", @pdf.PdfObject::String(owner)),
    ("/U", @pdf.PdfObject::String(user)),
    ("/P", @pdf.PdfObject::Integer(p)),
  ])
  match
    process_cryption(
      false,
      true,
      pdf,
      @pdfcryptprimitives.Encryption::ARC4(40, 2),
      user_pw,
      2,
      user,
      owner,
      p,
      id,
      40,
      None,
    ) {
    Some(pdf_val) => {
      let crypt_dict_num = pdf_val.addobj(crypt_dict)
      pdf_val.trailerdict = pdf_val.trailerdict.add_entry(
        "/Encrypt",
        @pdf.PdfObject::Indirect(crypt_dict_num),
      )
      pdf_val
    }
    None => raise @pdf.PdfError::Msg("Encryption 40 failed")
  }
}

///|
/// Encrypt a PDF document using 40-bit encryption.
pub fn PdfCrypt::encrypt_pdf_40bit(
  _self : PdfCrypt,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let p = p_of_banlist(banlist)
  let owner = mk_owner(2, owner_pw, user_pw, 40)
  let (id, pdf_updated) = get_or_add_id(pdf)
  let user = mk_user(false, user_pw, owner, p, id, 2, 40)
  encrypt_pdf_40bit_inner(owner, user, p, user_pw, id, pdf_updated)
}
