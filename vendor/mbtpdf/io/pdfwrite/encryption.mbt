///|
/// Encryption methods.
pub type EncryptionMethod = @pdfcrypt.EncryptionMethod

///|
/// Encryption settings.
pub struct Encryption {
  encryption_method : @pdfcrypt.EncryptionMethod
  owner_password : String
  user_password : String
  permissions : Array[@pdfcrypt.Permission]
}

///|
pub fn Encryption::new(
  encryption_method : @pdfcrypt.EncryptionMethod,
  owner_password : String,
  user_password : String,
  permissions : Array[@pdfcrypt.Permission],
) -> Encryption {
  { encryption_method, owner_password, user_password, permissions }
}

///|
let dummy_encryption : Encryption = {
  encryption_method: @pdfcrypt.EncryptionMethod::AlreadyEncrypted,
  owner_password: "",
  user_password: "",
  permissions: [],
}

///|
fn crypt_if_necessary(
  pdf : @pdf.Pdf,
  encryption : Encryption?,
) -> @pdf.Pdf raise {
  match encryption {
    None => pdf
    Some(enc) =>
      match enc.encryption_method {
        @pdfcrypt.EncryptionMethod::PDF40bit =>
          @pdfcrypt.PdfCrypt::new().encrypt_pdf_40bit(
            enc.user_password,
            enc.owner_password,
            enc.permissions,
            pdf,
          )
        @pdfcrypt.EncryptionMethod::PDF128bit =>
          @pdfcrypt.PdfCrypt::new().encrypt_pdf_128bit(
            enc.user_password,
            enc.owner_password,
            enc.permissions,
            pdf,
          )
        @pdfcrypt.EncryptionMethod::AES128bit(encrypt_metadata) =>
          @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES(
            encrypt_metadata,
            enc.user_password,
            enc.owner_password,
            enc.permissions,
            pdf,
          )
        @pdfcrypt.EncryptionMethod::AES256bit(encrypt_metadata) =>
          @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256(
            encrypt_metadata,
            enc.user_password,
            enc.owner_password,
            enc.permissions,
            pdf,
          )
        @pdfcrypt.EncryptionMethod::AES256bitISO(encrypt_metadata) =>
          @pdfcrypt.PdfCrypt::new().encrypt_pdf_AES256ISO(
            encrypt_metadata,
            enc.user_password,
            enc.owner_password,
            enc.permissions,
            pdf,
          )
        @pdfcrypt.EncryptionMethod::AlreadyEncrypted => pdf
      }
  }
}
