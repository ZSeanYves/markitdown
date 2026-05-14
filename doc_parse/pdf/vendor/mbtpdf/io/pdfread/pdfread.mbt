///|
pub struct PdfRead {
  // Keep IO-read configuration on the instance instead of global `Ref` state.
  read_debug : Bool
  error_on_malformed : Bool
  debug_always_treat_malformed : Bool
  logger : (String) -> Unit
}

///|
pub fn PdfRead::new(
  read_debug? : Bool = @pdfe.read_debug.val,
  error_on_malformed? : Bool = false,
  debug_always_treat_malformed? : Bool = false,
  logger? : (String) -> Unit = @pdfe.logger.val,
) -> PdfRead {
  { read_debug, error_on_malformed, debug_always_treat_malformed, logger }
}

///|
/// Read a PDF from an input.
pub fn PdfRead::pdf_of_input(
  self : PdfRead,
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
) -> @pdf.Pdf raise {
  read_pdf_internal(self, revision, user_password, owner_password, input, true)
}

///|
/// Read a PDF from an input, lazily.
pub fn PdfRead::pdf_of_input_lazy(
  self : PdfRead,
  revision? : Int,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
) -> @pdf.Pdf raise {
  read_pdf_internal(self, revision, user_password, owner_password, input, false)
}

///|
/// Return number of revisions.
pub fn PdfRead::revisions(self : PdfRead, input : @pdfio.Input) -> Int raise {
  try {
    let _ = read_pdf_internal(self, Some(-1), None, None, input, false)
    0
  } catch {
    ReadPdfError::Revisions(n) => n
    err => raise err
  }
}

///|
/// Return encryption method in use.
pub fn PdfRead::what_encryption(
  _self : PdfRead,
  pdf : @pdf.Pdf,
) -> @pdfcrypt.EncryptionMethod? {
  if !@pdfcrypt.PdfCrypt::new().is_encrypted(pdf) {
    return None
  }
  let values : Result[
    (
      @pdfcryptprimitives.Encryption,
      String,
      String,
      Int,
      String,
      String?,
      String?,
    ),
    Error,
  ] = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  match values {
    Ok((crypt, _, _, _, _, _, _)) => {
      let metadata = match pdf.lookup_direct("/Encrypt", pdf.trailerdict) {
        Some(encrypt_dict) =>
          match pdf.lookup_direct("/EncryptMetadata", encrypt_dict) {
            Some(@pdf.PdfObject::Boolean(false)) => false
            _ => true
          }
        None => true
      }
      match crypt {
        @pdfcryptprimitives.Encryption::ARC4(bits, _) =>
          match bits {
            40 => Some(@pdfcrypt.EncryptionMethod::PDF40bit)
            128 => Some(@pdfcrypt.EncryptionMethod::PDF128bit)
            _ => None
          }
        @pdfcryptprimitives.Encryption::AESV2 =>
          Some(@pdfcrypt.EncryptionMethod::AES128bit(metadata))
        @pdfcryptprimitives.Encryption::AESV3(is_iso) =>
          if is_iso {
            Some(@pdfcrypt.EncryptionMethod::AES256bitISO(metadata))
          } else {
            Some(@pdfcrypt.EncryptionMethod::AES256bit(metadata))
          }
      }
    }
    Err(_) => None
  }
}

///|
/// Return list of permissions.
pub fn PdfRead::permissions(
  _self : PdfRead,
  pdf : @pdf.Pdf,
) -> Array[@pdfcrypt.Permission] {
  if !@pdfcrypt.PdfCrypt::new().is_encrypted(pdf) {
    return []
  }
  let values : Result[
    (
      @pdfcryptprimitives.Encryption,
      String,
      String,
      Int,
      String,
      String?,
      String?,
    ),
    Error,
  ] = try? @pdfcrypt.PdfCrypt::new().get_encryption_values(pdf)
  match values {
    Ok((_, _, _, p, _, _, _)) => @pdfcrypt.PdfCrypt::new().banlist_of_p(p)
    Err(_) => []
  }
}

///|
/// Check if input is linearized.
pub fn PdfRead::is_linearized(self : PdfRead, input : @pdfio.Input) -> Bool {
  try {
    let _ = read_header(self, input)
    let lexemes = @pdfsyntax.PdfSyntax::new().lex_dictionary(false, input)
    let (_, parsed) = @pdfsyntax.PdfSyntax::new().parse(
      lexemes,
      failure_is_ok=true,
    )
    match @pdf.Pdf::empty().lookup_direct("/Linearized", parsed) {
      Some(@pdf.PdfObject::Integer(_)) | Some(@pdf.PdfObject::Real(_)) => true
      _ => false
    }
  } catch {
    _ => false
  }
}

///|
/// Read a PDF header.
fn read_header(ctx : PdfRead, input : @pdfio.Input) -> (Int, Int) raise {
  fn get8chars(input : @pdfio.Input) -> Array[Char] {
    let out = Array::new(capacity=8)
    let mut ok = true
    let mut i = 0
    while ok && i < 8 {
      match (input.input_char)() {
        Some(ch) => out.push(ch)
        None => ok = false
      }
      i = i + 1
    }
    if ok {
      out
    } else {
      Array::new()
    }
  }

  fn digits_to_int(digits : Array[Char]) -> Int {
    let mut value = 0
    for d in digits {
      value = value * 10 + (d.to_int() - '0'.to_int())
    }
    value
  }

  let mut pos = 0
  while pos <= 1024 {
    (input.seek_in)(pos)
    let chars = get8chars(input)
    if chars.length() == 8 &&
      chars[0] == '%' &&
      chars[1] == 'P' &&
      chars[2] == 'D' &&
      chars[3] == 'F' &&
      chars[4] == '-' &&
      chars[6] == '.' {
      let major_char = chars[5]
      if !(major_char is ('0'..='9')) {
        return (2, 0)
      }
      let minor_digits = Array::new()
      let mut idx = 7
      while idx < chars.length() {
        let c = chars[idx]
        if c is ('0'..='9') {
          minor_digits.push(c)
          idx = idx + 1
        } else {
          idx = chars.length()
        }
      }
      if minor_digits.length() == 0 {
        let message = @pdf.input_pdferror(input, "Malformed PDF header")
        raise @pdf.PdfError::Msg(message)
      }
      if ctx.read_debug {
        (ctx.logger)("setting offset to \{pos}\n")
      }
      (input.set_offset)(pos)
      return (major_char.to_int() - '0'.to_int(), digits_to_int(minor_digits))
    }
    pos = pos + 1
  }
  (2, 0)
}
