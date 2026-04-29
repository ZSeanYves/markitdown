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
fn process_cryption(
  no_encrypt_metadata : Bool,
  encrypt : Bool,
  pdf : @pdf.Pdf,
  crypt_type : @pdfcryptprimitives.Encryption,
  user_pw : String,
  r : Int,
  u : String,
  o : String,
  p : Int,
  id : String,
  keylength : Int,
  file_encryption_key : String?,
) -> @pdf.Pdf? raise {
  let mut encryption_object_number = -1
  match pdf.trailerdict.lookup_immediate("/Encrypt") {
    Some(Indirect(n)) => encryption_object_number = n
    _ => ()
  }
  let do_encryption = fn(key : Array[Int]) -> @pdf.Pdf? raise {
    let entries = pdf.objects.objects.to_array()
    entries.sort_by((a, b) => a.0 - b.0)
    for entry in entries {
      let objnum = entry.0
      let gennum = entry.1.1
      if objnum != encryption_object_number {
        let obj = pdf.lookup_obj(objnum)
        let new_obj = decrypt(
          crypt_type, pdf, no_encrypt_metadata, encrypt, objnum, gennum, key, keylength,
          r, file_encryption_key, obj,
        ) catch {
          _ => {
            @pdfe.log("Warning: unable to decrypt object \{objnum}\n")
            obj
          }
        }
        pdf.addobj_given_num((objnum, new_obj))
      }
    }
    pdf.trailerdict = pdf.trailerdict.remove_entry("/Encrypt")
    Some(pdf)
  }
  if r == 5 || r == 6 {
    match file_encryption_key {
      Some(k) => do_encryption(@pdfio.int_array_of_string(k))
      None => None
    }
  } else if authenticate_user(
      no_encrypt_metadata, user_pw, r, u, o, p, id, keylength,
    ) {
    do_encryption(
      find_key(no_encrypt_metadata, user_pw, r, o, p, id, keylength),
    )
  } else {
    None
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
      s[0:need].to_string()
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
/// Decrypt a PDF document using the user password.
pub fn PdfCrypt::decrypt_pdf(
  self : PdfCrypt,
  user_pw : String,
  pdf : @pdf.Pdf,
  keyfromowner? : String,
) -> (@pdf.Pdf?, Array[Permission]) raise {
  match pdf.lookup_direct("/Encrypt", pdf.trailerdict) {
    None => (Some(pdf), [])
    Some(encrypt_dict) => {
      let (crypt_type, u, o, p, id, ue, oe) = self.get_encryption_values(pdf)
      let (r, keylength, file_encryption_key) = match
        (crypt_type : @pdfcryptprimitives.Encryption) {
        AESV2 => (4, 128, None)
        AESV3(iso) =>
          match (oe, ue) {
            (Some(_), Some(ue_val)) =>
              match keyfromowner {
                Some(k) => (5, 256, Some(k))
                None => {
                  let perms = match pdf.lookup_direct("/Perms", encrypt_dict) {
                    Some(String(s)) => s
                    _ =>
                      raise @pdf.PdfError::Msg(
                        "Missing /Perms in encryption dictionary",
                      )
                  }
                  let auth = authenticate_user_password_aesv3(
                    iso,
                    make_utf8(user_pw),
                    u,
                  )
                  if !auth {
                    (5, 256, None)
                  } else {
                    let key = file_encryption_key_aesv3_user(
                      iso,
                      make_utf8(user_pw),
                      u,
                      ue_val,
                    )
                    match p_of_perms(key, perms) {
                      None =>
                        raise Failure::Failure(
                          "/Perms file permissions corrupted",
                        )
                      Some(x) if x == p =>
                        (5, 256, Some(@pdfio.string_of_bytes(key)))
                      Some(_) =>
                        raise Failure::Failure(
                          "Mismatched /Perms and /P permissions",
                        )
                    }
                  }
                }
              }
            _ => raise Failure::Failure("decrypt_pdf: no oe")
          }
        ARC4(k, r_val) => (r_val, k, None)
      }
      let encrypt_metadata = match
        pdf.lookup_direct("/EncryptMetadata", encrypt_dict) {
        Some(Boolean(false)) => false
        _ => true
      }
      let perms = match pdf.lookup_direct("/Perms", encrypt_dict) {
        Some(String(s)) => s
        _ => ""
      }
      pdf.saved_encryption = Some(@pdf.SavedEncryption::{
        from_get_encryption_values: (crypt_type, u, o, p, id, ue, oe),
        encrypt_metadata,
        perms,
      })
      (
        process_cryption(
          !encrypt_metadata,
          false,
          pdf,
          crypt_type,
          user_pw,
          r,
          u,
          o,
          p,
          id,
          keylength,
          file_encryption_key,
        ),
        self.banlist_of_p(p),
      )
    }
  }
}

///|
fn key_or_user_password_from_owner(
  owner_pw : String,
  pdf : @pdf.Pdf,
  encryption_values? : (@pdfcryptprimitives.Encryption, String, String, String?),
) -> (String, String)? raise {
  let padded_owner = pad_password(@pdfio.int_array_of_string(owner_pw))
  let (crypt_type, u, o, oe) = match encryption_values {
    Some(values) => values
    None => {
      let (crypt_type, u, o, _, _, _, oe) = PdfCrypt::new().get_encryption_values(
        pdf,
      )
      (crypt_type, u, o, oe)
    }
  }
  let (r, keylength) = crypt_type.r_and_keylength()
  if r == 5 || r == 6 {
    if authenticate_owner_password_aesv3(r == 6, make_utf8(owner_pw), u, o) {
      match oe {
        Some(oe_val) => {
          let key = @pdfio.string_of_bytes(
            file_encryption_key_aesv3(r == 6, make_utf8(owner_pw), o, oe_val, u),
          )
          Some((key, ""))
        }
        None =>
          raise @pdf.PdfError::Msg("decrypt_pdf_owner: No /OE entry found")
      }
    } else {
      None
    }
  } else {
    let user_pw = {
      let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
      let key = owner_key(padded_owner, keylength, r)
      if r == 2 {
        @pdfio.string_of_bytes(prims.crypt(key, @pdfio.bytes_of_string(o)))
      } else {
        let mut acc = prims.crypt(key, @pdfio.bytes_of_string(o))
        for x in 19>=..0 {
          acc = prims.crypt(mkkey(key, x), acc)
        }
        @pdfio.string_of_bytes(acc)
      }
    }
    Some(("", user_pw))
  }
}

///|
/// Decrypt a PDF document using the owner password.
pub fn PdfCrypt::decrypt_pdf_owner(
  self : PdfCrypt,
  owner_pw : String,
  pdf : @pdf.Pdf,
) -> @pdf.Pdf? raise {
  match pdf.lookup_direct("/Encrypt", pdf.trailerdict) {
    None => Some(pdf)
    Some(_) =>
      match key_or_user_password_from_owner(owner_pw, pdf) {
        None => None
        Some((key, user_pw)) => {
          let (pdf_opt, _) = self.decrypt_pdf(user_pw, pdf, keyfromowner=key)
          pdf_opt
        }
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
            value => decrypt(
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
            ),
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
                  value => decrypt(
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
                  ),
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
                  value => decrypt(
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
                  ),
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

///|
fn load_saved_encryption_from_pdf(pdf : @pdf.Pdf) -> @pdf.SavedEncryption raise {
  let (crypt_type, u, o, p, id, ue, oe) = PdfCrypt::new().get_encryption_values(
    pdf,
  )
  let encrypt_dict = match pdf.lookup_direct("/Encrypt", pdf.trailerdict) {
    Some(value) => value
    None => raise @pdf.PdfError::Msg("recrypt_pdf: unencrypted pdf")
  }
  let encrypt_metadata = match
    pdf.lookup_direct("/EncryptMetadata", encrypt_dict) {
    Some(@pdf.PdfObject::Boolean(false)) => false
    _ => true
  }
  let perms = match pdf.lookup_direct("/Perms", encrypt_dict) {
    Some(@pdf.PdfObject::String(s)) => s
    _ => ""
  }
  {
    from_get_encryption_values: (crypt_type, u, o, p, id, ue, oe),
    encrypt_metadata,
    perms,
  }
}

///|
fn recrypt_pdf_user(pdf : @pdf.Pdf, pw : String) -> @pdf.Pdf raise {
  let saved = match pdf.saved_encryption {
    Some(value) => value
    None => {
      let saved = load_saved_encryption_from_pdf(pdf)
      pdf.saved_encryption = Some(saved)
      saved
    }
  }
  let (crypt_type, u, o, p, id, ue, oe) = saved.from_get_encryption_values
  let encrypt_metadata = saved.encrypt_metadata
  let perms = saved.perms
  match crypt_type {
    @pdfcryptprimitives.Encryption::AESV3(iso) => {
      let oe_val = match oe {
        Some(val) => val
        None => raise @pdf.PdfError::Msg("recrypt_pdf: bad /oe")
      }
      let ue_val = match ue {
        Some(val) => val
        None => raise @pdf.PdfError::Msg("recrypt_pdf: bad /ue")
      }
      let key = if authenticate_user_password_aesv3(iso, make_utf8(pw), u) {
        file_encryption_key_aesv3_user(iso, make_utf8(pw), u, ue_val)
      } else {
        raise @pdf.PdfError::Msg("recrypt_pdf: failed AESV3 fek.")
      }
      encrypt_pdf_AES256_inner(
        iso,
        encrypt_metadata,
        o,
        u,
        p,
        perms,
        oe_val,
        ue_val,
        id,
        @pdfio.string_of_bytes(key),
        pdf,
      )
    }
    @pdfcryptprimitives.Encryption::AESV2 =>
      encrypt_pdf_AES_inner(o, u, p, pw, id, encrypt_metadata, pdf)
    @pdfcryptprimitives.Encryption::ARC4(40, _) =>
      encrypt_pdf_40bit_inner(o, u, p, pw, id, pdf)
    @pdfcryptprimitives.Encryption::ARC4(128, 4) =>
      encrypt_pdf_128bit_inner_r4(o, u, p, pw, id, pdf, encrypt_metadata)
    @pdfcryptprimitives.Encryption::ARC4(128, _) =>
      encrypt_pdf_128bit_inner(o, u, p, pw, id, pdf)
    _ => raise @pdf.PdfError::Msg("recrypt_pdf: bad encryption")
  }
}

///|
fn recrypt_pdf_owner(pdf : @pdf.Pdf, owner_pw : String) -> @pdf.Pdf raise {
  let saved = match pdf.saved_encryption {
    Some(value) => value
    None => {
      let saved = load_saved_encryption_from_pdf(pdf)
      pdf.saved_encryption = Some(saved)
      saved
    }
  }
  let (crypt_type, u, o, p, id, ue, oe) = saved.from_get_encryption_values
  let encrypt_metadata = saved.encrypt_metadata
  let perms = saved.perms
  let key_and_pw = match
    key_or_user_password_from_owner(
      owner_pw,
      pdf,
      encryption_values=(crypt_type, u, o, oe),
    ) {
    None => raise @pdf.PdfError::Msg("Recrypt with owner password failed.")
    Some(pair) => pair
  }
  let key = key_and_pw.0
  let pw = key_and_pw.1
  match crypt_type {
    @pdfcryptprimitives.Encryption::AESV3(iso) => {
      let oe_val = match oe {
        Some(val) => val
        None => raise @pdf.PdfError::Msg("recrypt_pdf: bad /oe")
      }
      let ue_val = match ue {
        Some(val) => val
        None => raise @pdf.PdfError::Msg("recrypt_pdf: bad /ue")
      }
      encrypt_pdf_AES256_inner(
        iso, encrypt_metadata, o, u, p, perms, oe_val, ue_val, id, key, pdf,
      )
    }
    @pdfcryptprimitives.Encryption::AESV2 =>
      encrypt_pdf_AES_inner(o, u, p, pw, id, encrypt_metadata, pdf)
    @pdfcryptprimitives.Encryption::ARC4(40, _) =>
      encrypt_pdf_40bit_inner(o, u, p, pw, id, pdf)
    @pdfcryptprimitives.Encryption::ARC4(128, 4) =>
      encrypt_pdf_128bit_inner_r4(o, u, p, pw, id, pdf, encrypt_metadata)
    @pdfcryptprimitives.Encryption::ARC4(128, _) =>
      encrypt_pdf_128bit_inner(o, u, p, pw, id, pdf)
    _ => raise @pdf.PdfError::Msg("recrypt_pdf_owner: bad encryption")
  }
}

///|
/// Re-encrypt a PDF document, using the saved encryption metadata.
pub fn PdfCrypt::recrypt_pdf(
  self : PdfCrypt,
  pdf : @pdf.Pdf,
  pw : String,
  renumber? : Bool = true,
) -> @pdf.Pdf raise {
  let mut pdf = pdf
  if pdf.saved_encryption is None && self.is_encrypted(pdf) {
    let saved_result : Result[@pdf.SavedEncryption, Error] = try? load_saved_encryption_from_pdf(
      pdf,
    )
    match saved_result {
      Ok(saved) => pdf.saved_encryption = Some(saved)
      Err(_) => ()
    }
    let dec_result : Result[(@pdf.Pdf?, Array[Permission]), Error] = try? self.decrypt_pdf(
      pw,
      pdf.deep_copy(),
    )
    match dec_result {
      Ok((Some(pdf_dec), _)) => pdf = pdf_dec
      _ => {
        let owner_result : Result[@pdf.Pdf?, Error] = try? self.decrypt_pdf_owner(
          pw,
          pdf.deep_copy(),
        )
        match owner_result {
          Ok(Some(pdf_dec)) => pdf = pdf_dec
          _ => ()
        }
      }
    }
  }
  if renumber {
    let nums = pdf.objnumbers()
    let changes : Map[Int, Int] = Map::new(capacity=nums.length())
    let mut i = 1
    for n in nums {
      changes.set(n, i)
      i = i + 1
    }
    pdf = pdf.renumber(changes)
  }
  recrypt_pdf_user(pdf, pw) catch {
    _ =>
      recrypt_pdf_owner(pdf, pw) catch {
        _ => raise @pdf.PdfError::Msg("recrypt_pdf failed. Wrong password?")
      }
  }
}
