///|
fn bytes_slice(
  bytes : @pdfio.MutableBytes,
  start : Int,
  len : Int,
) -> @pdfio.MutableBytes {
  let out = @pdfio.mkbytes(len)
  for i in 0..<len {
    out[i] = bytes[start + i]
  }
  out
}

///|
fn bytes_concat(parts : Array[@pdfio.MutableBytes]) -> @pdfio.MutableBytes {
  let mut total = 0
  for part in parts {
    total = total + part.length()
  }
  let out = @pdfio.mkbytes(total)
  let mut pos = 0
  for part in parts {
    for i in 0..<part.length() {
      out[pos] = part[i]
      pos = pos + 1
    }
  }
  out
}

///|
fn mod3_bytes(bytes : @pdfio.MutableBytes) -> Int {
  let mut x = 0
  for i in 0..<16 {
    x = x + @pdfio.bget(bytes, i)
  }
  x % 3
}

///|
fn shamix(password : String, udata : String?, s : String) -> String raise {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  let mut k = prims.sha256(@pdfio.Input::of_string(s))
  let mut k_bytes = @pdfio.bytes_of_string(k)
  let mut fin = false
  let mut round = 0
  let mut last_e = 0
  let pw_bytes = @pdfio.bytes_of_string(password)
  let u_bytes = match udata {
    Some(u) => Some(@pdfio.bytes_of_string(u))
    None => None
  }
  while !fin {
    round = round + 1
    let parts = Array::new()
    parts.push(pw_bytes)
    parts.push(k_bytes)
    match u_bytes {
      Some(ub) => parts.push(ub)
      None => ()
    }
    let k1 = bytes_concat(parts)
    let k1_64 = bytes_concat(Array::make(64, k1))
    let key = @pdfio.int_array_of_bytes(bytes_prefix(k_bytes, 16))
    let firstblock = @pdfio.int_array_of_bytes(bytes_slice(k_bytes, 16, 16))
    let raw = prims.aes_encrypt_data(4, key, k1_64, firstblock~)
    let raw_len = raw.length()
    let e = if raw_len > 32 {
      bytes_slice(raw, 16, raw_len - 32)
    } else {
      @pdfio.mkbytes(0)
    }
    if e.length() > 0 {
      last_e = @pdfio.bget(e, e.length() - 1)
    } else {
      last_e = 0
    }
    let next_k = match mod3_bytes(e) {
      0 => prims.sha256(@pdfio.Input::of_bytes(e))
      1 => prims.sha384(@pdfio.Input::of_bytes(e))
      _ => prims.sha512(@pdfio.Input::of_bytes(e))
    }
    k = next_k
    k_bytes = @pdfio.bytes_of_string(k)
    fin = round >= 64 && last_e <= round - 32
  }
  @pdfio.string_of_bytes(bytes_prefix(k_bytes, 32))
}

///|
fn file_encryption_key_aesv3(
  iso : Bool,
  utf8pw : String,
  o : String,
  oe : String,
  u : String,
  digest? : Array[Int],
) -> @pdfio.MutableBytes raise {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  if o.length() < 48 || u.length() < 48 {
    raise @pdf.PdfError::Msg(
      "/O too short in make_intermediate_owner_key_aesv3",
    )
  }
  let d = match digest {
    Some(digest) => digest
    None => {
      let o_bytes = @pdfio.bytes_of_string(o)
      let u_bytes = @pdfio.bytes_of_string(u)
      let concat = bytes_concat([
        @pdfio.bytes_of_string(utf8pw),
        bytes_slice(o_bytes, 40, 8),
        bytes_slice(u_bytes, 0, 48),
      ])
      let digest_str = if iso {
        shamix(utf8pw, Some(u), @pdfio.string_of_bytes(concat))
      } else {
        prims.sha256(@pdfio.Input::of_bytes(concat))
      }
      @pdfio.int_array_of_string(digest_str)
    }
  }
  let data = bytes_concat([
    @pdfio.bytes_of_string(zero_iv),
    @pdfio.bytes_of_string(oe),
  ])
  prims.aes_decrypt_data(8, d, data, remove_padding=false)
}

///|
fn file_encryption_key_aesv3_user(
  iso : Bool,
  utf8pw : String,
  u : String,
  ue : String,
) -> @pdfio.MutableBytes raise {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  if u.length() < 48 {
    raise @pdf.PdfError::Msg("/U too short in file_encryption_key_aesv3_user")
  }
  let u_bytes = @pdfio.bytes_of_string(u)
  let concat = bytes_concat([
    @pdfio.bytes_of_string(utf8pw),
    bytes_slice(u_bytes, 40, 8),
  ])
  let digest_str = if iso {
    shamix(utf8pw, None, @pdfio.string_of_bytes(concat))
  } else {
    prims.sha256(@pdfio.Input::of_bytes(concat))
  }
  let key = @pdfio.int_array_of_string(digest_str)
  let data = bytes_concat([
    @pdfio.bytes_of_string(zero_iv),
    @pdfio.bytes_of_string(ue),
  ])
  prims.aes_decrypt_data(8, key, data, remove_padding=false)
}

///|
fn authenticate_owner_password_aesv3(
  iso : Bool,
  utf8pw : String,
  u : String,
  o : String,
) -> Bool raise {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  if o.length() < 48 || u.length() < 48 {
    raise @pdf.PdfError::Msg("/O too short in authenticate_owner_password")
  }
  let u_bytes = @pdfio.bytes_of_string(u)
  let o_bytes = @pdfio.bytes_of_string(o)
  let concat = bytes_concat([
    @pdfio.bytes_of_string(utf8pw),
    bytes_slice(o_bytes, 32, 8),
    bytes_slice(u_bytes, 0, 48),
  ])
  let digest_str = if iso {
    shamix(utf8pw, Some(u), @pdfio.string_of_bytes(concat))
  } else {
    prims.sha256(@pdfio.Input::of_bytes(concat))
  }
  let digest = @pdfio.bytes_of_string(digest_str)
  bytes_equal(bytes_slice(o_bytes, 0, 32), bytes_prefix(digest, 32))
}

///|
fn authenticate_user_password_aesv3(
  iso : Bool,
  utf8pw : String,
  u : String,
) -> Bool raise {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  if u.length() < 48 {
    raise @pdf.PdfError::Msg("/U too short in authenticate_owner_password")
  }
  let u_bytes = @pdfio.bytes_of_string(u)
  let concat = bytes_concat([
    @pdfio.bytes_of_string(utf8pw),
    bytes_slice(u_bytes, 32, 8),
  ])
  let digest_str = if iso {
    shamix(utf8pw, None, @pdfio.string_of_bytes(concat))
  } else {
    prims.sha256(@pdfio.Input::of_bytes(concat))
  }
  let digest = @pdfio.bytes_of_string(digest_str)
  bytes_equal(bytes_slice(u_bytes, 0, 32), bytes_prefix(digest, 32))
}
