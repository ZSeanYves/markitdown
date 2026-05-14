///|
fn already_decrypted(pdf : @pdf.Pdf, objnum : Int) -> Bool {
  try {
    let entry = @pdf.pdfobjmap_find(objnum, pdf.objects.objects)
    match entry.0.val {
      @pdf.ObjectData::ParsedAlreadyDecrypted(_) => true
      _ => false
    }
  } catch {
    _ => false
  }
}

///|
fn is_identity(
  no_encrypt_metadata : Bool,
  pdf : @pdf.Pdf,
  dict : @pdf.PdfObject,
) -> Bool {
  let identity_crypt_filter_present = match pdf.lookup_direct("/Filter", dict) {
    Some(Name(name)) if name.equal_string_bytes("/Crypt") => true
    Some(Array([Name(name), ..])) if name.equal_string_bytes("/Crypt") => true
    _ => false
  }
  let identity_param = if identity_crypt_filter_present {
    match pdf.lookup_direct("/DecodeParms", dict) {
      Some(Dictionary(decodeparms)) =>
        match
          pdf.lookup_direct("/Name", @pdf.PdfObject::Dictionary(decodeparms)) {
          Some(Name(name)) if name.equal_string_bytes("/Identity") => true
          None => true
          _ => false
        }
      Some(Array([Dictionary(decodeparms), ..])) =>
        match
          pdf.lookup_direct("/Name", @pdf.PdfObject::Dictionary(decodeparms)) {
          Some(Name(name)) if name.equal_string_bytes("/Identity") => true
          None => true
          _ => false
        }
      Some(Array(_)) => true
      _ => true
    }
  } else {
    false
  }
  let is_metadata = if no_encrypt_metadata {
    match pdf.lookup_direct("/Type", dict) {
      Some(Name(name)) if name.equal_string_bytes("/Metadata") => true
      _ => false
    }
  } else {
    false
  }
  is_metadata || identity_param
}

///|
fn decrypt_stream(
  decrypt_obj : (@pdf.PdfObject) -> @pdf.PdfObject raise,
  crypt_type : @pdfcryptprimitives.Encryption,
  pdf : @pdf.Pdf,
  no_encrypt_metadata : Bool,
  encrypt : Bool,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int,
  r : Int,
  file_encryption_key : String?,
  stream : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  match (stream : @pdf.PdfObject) {
    Stream(rf) =>
      match rf.val {
        (dict, data) =>
          if is_identity(no_encrypt_metadata, pdf, dict) {
            stream
          } else {
            let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
            let crypt = @pdf.ToGetCrypt::ToDecrypt(@pdf.DeferredEncryption::{
              crypt_type,
              file_encryption_key,
              obj,
              gen,
              key,
              keylength,
              r,
            })
            let data_out : @pdf.Stream = match data {
              Got(bytes) => {
                if (r == 5 || r == 6) && file_encryption_key is None {
                  raise @pdf.PdfError::Msg("decrypt: no key C")
                }
                Got(
                  prims.decrypt_stream_data(
                    crypt_type, encrypt, file_encryption_key, obj, gen, key, keylength,
                    r, bytes,
                  ),
                )
              }
              ToGet(toget) =>
                if encrypt {
                  @pdf.PdfObject::Stream(rf).getstream()
                  match rf.val {
                    (_, Got(got_bytes)) => {
                      if (r == 5 || r == 6) && file_encryption_key is None {
                        raise @pdf.PdfError::Msg("decrypt: no key C")
                      }
                      Got(
                        prims.decrypt_stream_data(
                          crypt_type, encrypt, file_encryption_key, obj, gen, key,
                          keylength, r, got_bytes,
                        ),
                      )
                    }
                    _ => data
                  }
                } else {
                  ToGet(@pdf.ToGet::{
                    input: toget.input,
                    position: toget.position,
                    length: toget.length,
                    crypt,
                  })
                }
            }
            let dict_out : @pdf.PdfObject = match (dict : @pdf.PdfObject) {
              Dictionary(entries) => {
                let out = Array::new(capacity=entries.length())
                for entry in entries {
                  out.push((entry.0, decrypt_obj(entry.1)))
                }
                Dictionary(out)
              }
              _ => dict
            }
            let dict_updated = match data_out {
              Got(bytes) =>
                dict_out.replace_entry(
                  "/Length",
                  @pdf.PdfObject::Integer(bytes.length()),
                )
              _ => dict_out
            }
            rf.val = (dict_updated, data_out)
            Stream(rf)
          }
      }
    _ => stream
  }
}

///|
fn decrypt(
  crypt_type : @pdfcryptprimitives.Encryption,
  pdf : @pdf.Pdf,
  no_encrypt_metadata : Bool,
  encrypt : Bool,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int,
  r : Int,
  file_encryption_key : String?,
  objval : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  let decrypt_obj = fn(value : @pdf.PdfObject) -> @pdf.PdfObject raise {
    decrypt(
      crypt_type, pdf, no_encrypt_metadata, encrypt, obj, gen, key, keylength, r,
      file_encryption_key, value,
    )
  }
  match objval {
    String(s) =>
      if already_decrypted(pdf, obj) {
        objval
      } else {
        let s_bytes = @pdfio.bytes_of_string(s)
        if (r == 5 || r == 6) && file_encryption_key is None {
          raise @pdf.PdfError::Msg("decrypt: no key B")
        }
        let out_bytes = @pdfcryptprimitives.PdfCryptPrimitives::new().decrypt_stream_data(
          crypt_type, encrypt, file_encryption_key, obj, gen, key, keylength, r,
          s_bytes,
        )
        String(@pdfio.string_of_bytes(out_bytes))
      }
    Stream(_) =>
      decrypt_stream(
        decrypt_obj, crypt_type, pdf, no_encrypt_metadata, encrypt, obj, gen, key,
        keylength, r, file_encryption_key, objval,
      )
    Array(values) =>
      if already_decrypted(pdf, obj) {
        objval
      } else {
        let out = Array::new(capacity=values.length())
        for value in values {
          out.push(decrypt_obj(value))
        }
        Array(out)
      }
    Dictionary(values) =>
      if already_decrypted(pdf, obj) {
        objval
      } else {
        let out = Array::new(capacity=values.length())
        for entry in values {
          out.push((entry.0, decrypt_obj(entry.1)))
        }
        Dictionary(out)
      }
    _ => objval
  }
}


///|
/// Read encryption parameters from an encrypted PDF.
pub fn PdfCrypt::get_encryption_values(
  _self : PdfCrypt,
  pdf : @pdf.Pdf,
) -> (
  @pdfcryptprimitives.Encryption,
  String,
  String,
  Int,
  String,
  String?,
  String?,
) raise {
  let encryptdict = match pdf.lookup_direct("/Encrypt", pdf.trailerdict) {
    Some(value) => value
    None => raise @pdf.PdfError::Msg("get_encryption_values: unencrypted pdf")
  }
  let filter = pdf.lookup_direct("/Filter", encryptdict)
  let v_val = pdf.lookup_direct("/V", encryptdict)
  let length_val = pdf.lookup_direct("/Length", encryptdict)
  let r_val = pdf.lookup_direct("/R", encryptdict)
  let crypt_type = match (filter, v_val, length_val, r_val) {
    (
      Some(@pdf.PdfObject::Name(name)),
      Some(@pdf.PdfObject::Integer(1)),
      _,
      Some(@pdf.PdfObject::Integer(r)),
    ) if name.equal_string_bytes("/Standard") =>
      Some(@pdfcryptprimitives.Encryption::ARC4(40, r))
    (
      Some(@pdf.PdfObject::Name(name)),
      Some(@pdf.PdfObject::Integer(2)),
      None,
      Some(@pdf.PdfObject::Integer(r)),
    ) if name.equal_string_bytes("/Standard") =>
      Some(@pdfcryptprimitives.Encryption::ARC4(40, r))
    (
      Some(@pdf.PdfObject::Name(name)),
      Some(@pdf.PdfObject::Integer(2)),
      Some(@pdf.PdfObject::Integer(n)),
      _,
    ) if name.equal_string_bytes("/Standard") =>
      if n % 8 == 0 && n >= 40 && n <= 128 {
        Some(@pdfcryptprimitives.Encryption::ARC4(n, 3))
      } else {
        None
      }
    (
      Some(@pdf.PdfObject::Name(name)),
      Some(@pdf.PdfObject::Integer(v)),
      length,
      Some(@pdf.PdfObject::Integer(r)),
    ) if name.equal_string_bytes("/Standard") =>
      if v == 4 || v == 5 {
        match pdf.lookup_direct("/CF", encryptdict) {
          Some(cfdict) =>
            match pdf.lookup_direct("/StdCF", cfdict) {
              Some(stdcfdict) =>
                match pdf.lookup_direct("/CFM", stdcfdict) {
                  Some(@pdf.PdfObject::Name(cfm)) if cfm.equal_string_bytes(
                      "/V2",
                    ) =>
                    match length {
                      Some(@pdf.PdfObject::Integer(i)) =>
                        Some(@pdfcryptprimitives.Encryption::ARC4(i, 4))
                      _ =>
                        match pdf.lookup_direct("/Length", cfdict) {
                          Some(@pdf.PdfObject::Integer(i)) =>
                            Some(@pdfcryptprimitives.Encryption::ARC4(i, 4))
                          _ => None
                        }
                    }
                  Some(@pdf.PdfObject::Name(cfm)) if cfm.equal_string_bytes(
                      "/AESV2",
                    ) => Some(@pdfcryptprimitives.Encryption::AESV2)
                  Some(@pdf.PdfObject::Name(cfm)) if cfm.equal_string_bytes(
                      "/AESV3",
                    ) => Some(@pdfcryptprimitives.Encryption::AESV3(r == 6))
                  _ => None
                }
              _ => None
            }
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
  let chop_string3248 = fn(name : String, s : String) -> String raise {
    let need = match crypt_type {
      Some(@pdfcryptprimitives.Encryption::AESV3(_)) => 48
      _ => 32
    }
    if s.length() < need {
      raise @pdf.PdfError::Msg("\{name}: too small in get_encryption_values")
    } else {
      s[0:need].to_owned()
    }
  }
  match crypt_type {
    None => raise @pdf.PdfError::Msg("No encryption method")
    Some(ct) => {
      let o = match pdf.lookup_direct("/O", encryptdict) {
        Some(String(o)) => chop_string3248("/O", o)
        _ => raise @pdf.PdfError::Msg("Bad or missing /O entry")
      }
      let u = match pdf.lookup_direct("/U", encryptdict) {
        Some(String(u)) => chop_string3248("/U", u)
        _ => raise @pdf.PdfError::Msg("Bad or missing /U entry")
      }
      let p = match pdf.lookup_direct("/P", encryptdict) {
        Some(Integer(flags)) => flags
        _ => raise @pdf.PdfError::Msg("Bad or missing /P entry")
      }
      let id = match pdf.lookup_direct("/ID", pdf.trailerdict) {
        Some(Array([String(s), _])) => s
        _ => raise @pdf.PdfError::Msg("Bad or missing /ID element")
      }
      let oe = match pdf.lookup_direct("/OE", encryptdict) {
        Some(String(s)) => Some(s)
        _ => None
      }
      let ue = match pdf.lookup_direct("/UE", encryptdict) {
        Some(String(s)) => Some(s)
        _ => None
      }
      (ct, u, o, p, id, ue, oe)
    }
  }
}

///|
/// Just decrypt a single stream, given the user password and pdf.
pub fn PdfCrypt::decrypt_single_stream(
  self : PdfCrypt,
  user_pw : String?,
  owner_pw : String?,
  pdf : @pdf.Pdf,
  obj : Int,
  gen : Int,
  stream : @pdf.PdfObject,
) -> @pdf.PdfObject raise {
  match pdf.lookup_direct("/Encrypt", pdf.trailerdict) {
    None => stream
    Some(encrypt_dict) => {
      let (crypt_type, u, o, p, id, ue, oe) = self.get_encryption_values(pdf)
      let (r, keylength) = crypt_type.r_and_keylength()
      let no_encrypt_metadata = match
        pdf.lookup_direct("/EncryptMetadata", encrypt_dict) {
        Some(@pdf.PdfObject::Boolean(false)) => true
        _ => false
      }
      match (r, keylength, ue, oe) {
        (5 | 6, 256, Some(ue_val), Some(oe_val)) => {
          let owner_pw_val = match owner_pw {
            Some(value) => value
            None => ""
          }
          let user_pw_val = match user_pw {
            Some(value) => value
            None => ""
          }
          let file_encryption_key = if authenticate_user_password_aesv3(
              r == 6,
              make_utf8(user_pw_val),
              u,
            ) {
            file_encryption_key_aesv3_user(
              r == 6,
              make_utf8(user_pw_val),
              u,
              ue_val,
            )
          } else if authenticate_owner_password_aesv3(
              r == 6,
              make_utf8(owner_pw_val),
              u,
              o,
            ) {
            file_encryption_key_aesv3(
              r == 6,
              make_utf8(owner_pw_val),
              o,
              oe_val,
              u,
            )
          } else {
            raise @pdf.PdfError::Msg(
              "Encryption: Could not decrypt single stream: Bad or not supplied AESV3 user or owner password",
            )
          }
          decrypt_stream(
            value => {
              decrypt(
                crypt_type,
                pdf,
                no_encrypt_metadata,
                false,
                obj,
                gen,
                @pdfio.int_array_of_bytes(file_encryption_key),
                keylength,
                r,
                Some(@pdfio.string_of_bytes(file_encryption_key)),
                value,
              )
            },
            crypt_type,
            pdf,
            no_encrypt_metadata,
            false,
            obj,
            gen,
            @pdfio.int_array_of_bytes(file_encryption_key),
            keylength,
            r,
            Some(@pdfio.string_of_bytes(file_encryption_key)),
            stream,
          )
        }
        _ =>
          match owner_pw {
            Some(owner_string) => {
              let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
              let padded_owner = pad_password(
                @pdfio.int_array_of_string(owner_string),
              )
              let key = owner_key(padded_owner, keylength, r)
              let user_pw_string = if r == 2 {
                @pdfio.string_of_bytes(
                  prims.crypt(key, @pdfio.bytes_of_string(o)),
                )
              } else {
                let mut acc = prims.crypt(key, @pdfio.bytes_of_string(o))
                for x in 19>=..0 {
                  acc = prims.crypt(mkkey(key, x), acc)
                }
                @pdfio.string_of_bytes(acc)
              }
              if authenticate_user(
                  no_encrypt_metadata, user_pw_string, r, u, o, p, id, keylength,
                ) {
                let user_key = find_key(
                  no_encrypt_metadata, user_pw_string, r, o, p, id, keylength,
                )
                decrypt_stream(
                  value => {
                    decrypt(
                      crypt_type,
                      pdf,
                      no_encrypt_metadata,
                      false,
                      obj,
                      gen,
                      user_key,
                      keylength,
                      r,
                      None,
                      value,
                    )
                  },
                  crypt_type,
                  pdf,
                  no_encrypt_metadata,
                  false,
                  obj,
                  gen,
                  user_key,
                  keylength,
                  r,
                  None,
                  stream,
                )
              } else {
                raise @pdf.PdfError::Msg(
                  "Encryption: Bad or not supplied owner password when decrypting single stream",
                )
              }
            }
            None => {
              let user_pw_string = match user_pw {
                Some(value) => value
                None => ""
              }
              if authenticate_user(
                  no_encrypt_metadata, user_pw_string, r, u, o, p, id, keylength,
                ) {
                let user_key = find_key(
                  no_encrypt_metadata, user_pw_string, r, o, p, id, keylength,
                )
                decrypt_stream(
                  value => {
                    decrypt(
                      crypt_type,
                      pdf,
                      no_encrypt_metadata,
                      false,
                      obj,
                      gen,
                      user_key,
                      keylength,
                      r,
                      None,
                      value,
                    )
                  },
                  crypt_type,
                  pdf,
                  no_encrypt_metadata,
                  false,
                  obj,
                  gen,
                  user_key,
                  keylength,
                  r,
                  None,
                  stream,
                )
              } else {
                raise @pdf.PdfError::Msg(
                  "Encryption: Bad or not supplied password when decrypting single stream",
                )
              }
            }
          }
      }
    }
  }
}
