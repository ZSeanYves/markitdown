///|
fn encrypt_pdf_128bit_inner(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/Standard"))),
    ("/V", @pdf.PdfObject::Integer(2)),
    ("/R", @pdf.PdfObject::Integer(3)),
    ("/O", @pdf.PdfObject::String(owner)),
    ("/U", @pdf.PdfObject::String(user)),
    ("/Length", @pdf.PdfObject::Integer(128)),
    ("/P", @pdf.PdfObject::Integer(p)),
  ])
  match
    process_cryption(
      false,
      true,
      pdf,
      @pdfcryptprimitives.Encryption::ARC4(128, 3),
      user_pw,
      3,
      user,
      owner,
      p,
      id,
      128,
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
    None => raise @pdf.PdfError::Msg("Encryption 128 failed")
  }
}

///|
fn encrypt_pdf_128bit_inner_r4(
  owner : String,
  user : String,
  p : Int,
  user_pw : String,
  id : String,
  pdf : @pdf.Pdf,
  encrypt_metadata : Bool,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/Standard"))),
    ("/V", @pdf.PdfObject::Integer(4)),
    (
      "/CF",
      @pdf.PdfObject::Dictionary([
        (
          "/StdCF",
          @pdf.PdfObject::Dictionary([
            ("/Length", @pdf.PdfObject::Integer(16)),
            (
              "/AuthEvent",
              @pdf.PdfObject::Name(@pdf.PdfName::of_string("/DocOpen")),
            ),
            ("/CFM", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/V2"))),
          ]),
        ),
      ]),
    ),
    ("/EncryptMetadata", @pdf.PdfObject::Boolean(encrypt_metadata)),
    ("/Length", @pdf.PdfObject::Integer(128)),
    ("/R", @pdf.PdfObject::Integer(4)),
    ("/O", @pdf.PdfObject::String(owner)),
    ("/U", @pdf.PdfObject::String(user)),
    ("/P", @pdf.PdfObject::Integer(p)),
    ("/StrF", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/StdCF"))),
    ("/StmF", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/StdCF"))),
  ])
  match
    process_cryption(
      !encrypt_metadata,
      true,
      pdf,
      @pdfcryptprimitives.Encryption::ARC4(128, 4),
      user_pw,
      4,
      user,
      owner,
      p,
      id,
      128,
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
    None => raise @pdf.PdfError::Msg("Encryption 128 r4 failed")
  }
}

///|
/// Encrypt a PDF document using 128-bit encryption.
pub fn PdfCrypt::encrypt_pdf_128bit(
  _self : PdfCrypt,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let p = p_of_banlist(banlist)
  let owner = mk_owner(3, owner_pw, user_pw, 128)
  let (id, pdf_updated) = get_or_add_id(pdf)
  let user = mk_user(false, user_pw, owner, p, id, 3, 128)
  encrypt_pdf_128bit_inner(owner, user, p, user_pw, id, pdf_updated)
}
