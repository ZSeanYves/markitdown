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

///|
fn p_of_perms(key : @pdfio.MutableBytes, perms : String) -> Int? raise {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  if perms.length() < 16 {
    raise @pdf.PdfError::Msg("Wrong length in /Perms")
  }
  let ps = prims.aes_decrypt_data_ecb(
    8,
    @pdfio.int_array_of_bytes(key),
    @pdfio.bytes_of_string(perms),
    remove_padding=false,
  )
  let ints = @pdfio.int_array_of_bytes(ps)
  if ints[9] != 'a'.to_int() ||
    ints[10] != 'd'.to_int() ||
    ints[11] != 'b'.to_int() {
    None
  } else {
    let p = (ints[0] & 0xff) |
      ((ints[1] & 0xff) << 8) |
      ((ints[2] & 0xff) << 16) |
      ((ints[3] & 0xff) << 24)
    Some(p)
  }
}

///|
fn perms_of_p(
  iso : Bool,
  encrypt_metadata : Bool,
  p : Int,
  utf8pw : String,
  o : String,
  oe : String,
  u : String,
  digest : Array[Int],
) -> @pdfio.MutableBytes raise {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  let extendedp = UInt64::lor(
    0xffff_ffff_0000_0000,
    UInt64::extend_uint(p.reinterpret_as_uint()),
  )
  let b = Array::make(16, 0)
  for n in 0..<8 {
    let v = (extendedp >> (n * 8)).to_int()
    b[n] = Int::land(v, 0xff)
  }
  b[8] = if encrypt_metadata { 'T'.to_int() } else { 'F'.to_int() }
  b[9] = 'a'.to_int()
  b[10] = 'd'.to_int()
  b[11] = 'b'.to_int()
  let key = @pdfio.int_array_of_bytes(
    file_encryption_key_aesv3(iso, utf8pw, o, oe, u, digest~),
  )
  prims.aes_encrypt_data_ecb(8, key, @pdfio.bytes_of_int_array(b))
}

///|
fn make_ue(
  iso : Bool,
  file_encryption_key : @pdfio.MutableBytes,
  user_pw : String,
  user_validation_salt : String,
  user_key_salt : String,
) -> (String, String) raise {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  let hash = fn(s : String) -> String raise {
    if iso {
      shamix(user_pw, None, s)
    } else {
      prims.sha256(@pdfio.Input::of_string(s))
    }
  }
  let u = hash(user_pw + user_validation_salt) +
    user_validation_salt +
    user_key_salt
  let ue = prims.aes_encrypt_data(
    8,
    @pdfio.int_array_of_string(hash(user_pw + user_key_salt)),
    file_encryption_key,
    firstblock=@pdfio.int_array_of_string(zero_iv),
  )
  let ue_slice = bytes_slice(ue, 16, 32)
  (u, @pdfio.string_of_bytes(ue_slice))
}

///|
fn make_oe(
  iso : Bool,
  file_encryption_key : @pdfio.MutableBytes,
  owner_pw : String,
  owner_validation_salt : String,
  owner_key_salt : String,
  u : String,
) -> (String, String, Array[Int]) raise {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  let hash = fn(s : String) -> String raise {
    if iso {
      shamix(owner_pw, Some(u), s)
    } else {
      prims.sha256(@pdfio.Input::of_string(s))
    }
  }
  let o = hash(owner_pw + owner_validation_salt + u) +
    owner_validation_salt +
    owner_key_salt
  let digest = @pdfio.int_array_of_string(hash(owner_pw + owner_key_salt + u))
  let oe = prims.aes_encrypt_data(
    8,
    digest,
    file_encryption_key,
    firstblock=@pdfio.int_array_of_string(zero_iv),
  )
  let oe_slice = bytes_slice(oe, 16, 32)
  (o, @pdfio.string_of_bytes(oe_slice), digest)
}
