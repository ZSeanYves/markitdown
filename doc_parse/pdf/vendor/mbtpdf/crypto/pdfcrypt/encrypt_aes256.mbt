///|
fn encrypt_pdf_AES256_inner(
  iso : Bool,
  encrypt_metadata : Bool,
  owner : String,
  user : String,
  p : Int,
  perms : String,
  oe : String,
  ue : String,
  id : String,
  key : String,
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let crypt_dict = @pdf.PdfObject::Dictionary([
    ("/Filter", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/Standard"))),
    ("/V", @pdf.PdfObject::Integer(5)),
    (
      "/CF",
      @pdf.PdfObject::Dictionary([
        (
          "/StdCF",
          @pdf.PdfObject::Dictionary([
            ("/Length", @pdf.PdfObject::Integer(32)),
            (
              "/AuthEvent",
              @pdf.PdfObject::Name(@pdf.PdfName::of_string("/DocOpen")),
            ),
            ("/CFM", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/AESV3"))),
          ]),
        ),
      ]),
    ),
    ("/EncryptMetadata", @pdf.PdfObject::Boolean(encrypt_metadata)),
    ("/Length", @pdf.PdfObject::Integer(256)),
    ("/R", @pdf.PdfObject::Integer(if iso { 6 } else { 5 })),
    ("/O", @pdf.PdfObject::String(owner)),
    ("/U", @pdf.PdfObject::String(user)),
    ("/P", @pdf.PdfObject::Integer(p)),
    ("/StrF", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/StdCF"))),
    ("/StmF", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/StdCF"))),
    ("/Perms", @pdf.PdfObject::String(perms)),
    ("/OE", @pdf.PdfObject::String(oe)),
    ("/UE", @pdf.PdfObject::String(ue)),
  ])
  match
    process_cryption(
      !encrypt_metadata,
      true,
      pdf,
      @pdfcryptprimitives.Encryption::AESV3(iso),
      "",
      if iso {
        6
      } else {
        5
      },
      user,
      owner,
      p,
      id,
      256,
      Some(key),
    ) {
    Some(pdf_val) => {
      let crypt_dict_num = pdf_val.addobj(crypt_dict)
      pdf_val.trailerdict = pdf_val.trailerdict.add_entry(
        "/Encrypt",
        @pdf.PdfObject::Indirect(crypt_dict_num),
      )
      pdf_val
    }
    None => raise @pdf.PdfError::Msg("256 bit Encryption AES failed")
  }
}

///|
fn encrypt_pdf_AES256_call(
  iso : Bool,
  encrypt_metadata : Bool,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let user_pw_utf8 = make_utf8(user_pw)
  let owner_pw_utf8 = make_utf8(owner_pw)
  let user_validation_salt = mksalt()
  let user_key_salt = mksalt()
  let owner_validation_salt = mksalt()
  let owner_key_salt = mksalt()
  let file_encryption_key = @pdfio.bytes_of_string(mkfilekey())
  let p = p_of_banlist(banlist)
  let (u, ue) = make_ue(
    iso, file_encryption_key, user_pw_utf8, user_validation_salt, user_key_salt,
  )
  let (o, oe, digest) = make_oe(
    iso, file_encryption_key, owner_pw_utf8, owner_validation_salt, owner_key_salt,
    u,
  )
  let (id, pdf_updated) = get_or_add_id(pdf)
  let perms = perms_of_p(
    iso, encrypt_metadata, p, owner_pw_utf8, o, oe, u, digest,
  )
  encrypt_pdf_AES256_inner(
    iso,
    encrypt_metadata,
    o,
    u,
    p,
    @pdfio.string_of_bytes(perms),
    oe,
    ue,
    id,
    @pdfio.string_of_bytes(file_encryption_key),
    pdf_updated,
  )
}

///|
/// Encrypt a PDF document using AESV3 (non-ISO).
pub fn PdfCrypt::encrypt_pdf_AES256(
  _self : PdfCrypt,
  encrypt_metadata : Bool,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  encrypt_pdf_AES256_call(
    false, encrypt_metadata, user_pw, owner_pw, banlist, pdf,
  )
}

///|
/// Encrypt a PDF document using AESV3 (ISO).
pub fn PdfCrypt::encrypt_pdf_AES256ISO(
  _self : PdfCrypt,
  encrypt_metadata : Bool,
  user_pw : String,
  owner_pw : String,
  banlist : Array[Permission],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  encrypt_pdf_AES256_call(
    true, encrypt_metadata, user_pw, owner_pw, banlist, pdf,
  )
}
