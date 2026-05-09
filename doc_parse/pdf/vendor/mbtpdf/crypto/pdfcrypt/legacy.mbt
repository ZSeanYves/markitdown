///|
fn find_key(
  no_encrypt_metadata : Bool,
  password : String,
  r : Int,
  o : String,
  p : Int,
  id : String,
  keylength : Int,
) -> Array[Int] {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  let password_ints = @pdfio.int_array_of_string(password)
  let o_ints = @pdfio.int_array_of_string(o)
  let id_ints = @pdfio.int_array_of_string(id)
  let pw = pad_password(password_ints)
  let from_p = [
    Int::land(p, 0xff),
    Int::land(p >> 8, 0xff),
    Int::land(p >> 16, 0xff),
    Int::land(p >> 24, 0xff),
  ]
  let rev4_no_metadata = if r >= 4 && no_encrypt_metadata {
    [255, 255, 255, 255]
  } else {
    []
  }
  let digest_input = bytes_of_int_arrays([
    pw, o_ints, from_p, id_ints, rev4_no_metadata,
  ])
  let h = prims.md5(digest_input)
  let key_len = keylength / 8
  if r >= 3 {
    let mut i = 1
    let mut h_bytes = h
    while i <= 50 {
      let digest = prims.md5(h_bytes)
      h_bytes = bytes_prefix(digest, key_len)
      i = i + 1
    }
    @pdfio.int_array_of_bytes(h_bytes)
  } else {
    @pdfio.int_array_of_bytes(bytes_prefix(h, key_len))
  }
}

///|
fn authenticate_user(
  no_encrypt_metadata : Bool,
  password : String,
  r : Int,
  u : String,
  o : String,
  p : Int,
  id : String,
  keylength : Int,
) -> Bool {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  let u_ints = @pdfio.int_array_of_string(u)
  let key = find_key(no_encrypt_metadata, password, r, o, p, id, keylength)
  if r >= 3 {
    let id_ints = @pdfio.int_array_of_string(id)
    let digest_input = bytes_of_int_arrays([paddings, id_ints])
    let hashed = prims.md5(digest_input)
    let encrypted = prims.crypt(key, hashed)
    let mut u_prime = @pdfio.int_array_of_bytes(encrypted)
    let mut x = 1
    while x <= 19 {
      let key_prime = Array::make(keylength / 8, 0)
      let mut k = 0
      while k < keylength / 8 {
        key_prime[k] = key[k] ^ x
        k = k + 1
      }
      let data_bytes = @pdfio.bytes_of_int_array(u_prime)
      let new_bytes = prims.crypt(key_prime, data_bytes)
      u_prime = @pdfio.int_array_of_bytes(new_bytes)
      x = x + 1
    }
    array_equal(int_array_prefix(u_ints, 16), u_prime)
  } else {
    let encrypted = prims.crypt(key, @pdfio.bytes_of_int_array(paddings))
    array_equal(u_ints, @pdfio.int_array_of_bytes(encrypted))
  }
}

///|
fn owner_key(padded_owner : Array[Int], keylength : Int, r : Int) -> Array[Int] {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  let mut d = prims.md5(@pdfio.bytes_of_int_array(padded_owner))
  if r >= 3 {
    let mut i = 1
    while i <= 50 {
      d = prims.md5(d)
      i = i + 1
    }
  }
  @pdfio.int_array_of_bytes(bytes_prefix(d, keylength / 8))
}

///|
fn mk_owner(
  r : Int,
  owner_pw : String,
  user_pw : String,
  keylength : Int,
) -> String {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  let source = if owner_pw == "" { user_pw } else { owner_pw }
  let padded_owner = pad_password(@pdfio.int_array_of_string(source))
  let key = owner_key(padded_owner, keylength, r)
  let padded_user = pad_password(@pdfio.int_array_of_string(user_pw))
  if r == 2 {
    @pdfio.string_of_bytes(
      prims.crypt(key, @pdfio.bytes_of_int_array(padded_user)),
    )
  } else {
    let mut acc = prims.crypt(key, @pdfio.bytes_of_int_array(padded_user))
    let mut x = 1
    while x <= 19 {
      acc = prims.crypt(mkkey(key, x), acc)
      x = x + 1
    }
    @pdfio.string_of_bytes(acc)
  }
}

///|
fn mk_user(
  no_encrypt_metadata : Bool,
  user_pw : String,
  o : String,
  p : Int,
  id : String,
  r : Int,
  keylength : Int,
) -> String {
  let prims = @pdfcryptprimitives.PdfCryptPrimitives::new()
  let key = find_key(no_encrypt_metadata, user_pw, r, o, p, id, keylength)
  if r == 2 {
    @pdfio.string_of_bytes(
      prims.crypt(key, @pdfio.bytes_of_int_array(paddings)),
    )
  } else {
    let digest_input = bytes_of_int_arrays([
      paddings,
      @pdfio.int_array_of_string(id),
    ])
    let d = prims.md5(digest_input)
    let mut acc = prims.crypt(key, d)
    let mut x = 1
    while x <= 19 {
      acc = prims.crypt(mkkey(key, x), acc)
      x = x + 1
    }
    let zeros = @pdfio.mkbytes(16)
    @pdfio.string_of_bytes(acc) + @pdfio.string_of_bytes(zeros)
  }
}
