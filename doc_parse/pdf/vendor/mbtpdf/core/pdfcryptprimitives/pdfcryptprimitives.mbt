///|
/// Types of encryption.
pub(all) enum Encryption {
  ARC4(Int, Int)
  AESV2
  AESV3(Bool)
} derive(Debug)

///|
/// Return the PDF "revision" (`/R`) and key length (in bits) implied by the
/// encryption variant.
///
/// - `ARC4(bits, r)` uses the explicit values from the parsed encryption dict.
/// - `AESV2` is always revision 4 with a 128-bit key.
/// - `AESV3(is_iso)` is revision 5 (or 6 in ISO mode) with a 256-bit key.
///
/// This is a small convenience API to avoid scattering the same `match` in
/// multiple packages.
pub fn Encryption::r_and_keylength(self : Encryption) -> (Int, Int) {
  match self {
    ARC4(bits, r) => (r, bits)
    AESV2 => (4, 128)
    AESV3(is_iso) => (if is_iso { 6 } else { 5 }, 256)
  }
}

///|
pub struct PdfCryptPrimitives {
  unit : Unit
}

///|
pub fn PdfCryptPrimitives::new() -> PdfCryptPrimitives {
  { unit: () }
}

///|
fn bytes_of_int_arrays(values : Array[Array[Int]]) -> @pdfio.MutableBytes {
  let mut total = 0
  for v in values {
    total = total + v.length()
  }
  let out = @pdfio.mkbytes(total)
  let mut pos = 0
  for v in values {
    for value in v {
      @pdfio.bset(out, pos, value)
      pos = pos + 1
    }
  }
  out
}

///|
/// Given an object number, generation number, input key and key length in bits,
/// apply Algorithm 3.1 to obtain the hash to be used by the encryption function.
pub fn PdfCryptPrimitives::find_hash(
  self : PdfCryptPrimitives,
  crypt_type : Encryption,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int,
) -> Array[Int] {
  let from_obj = [
    Int::land(obj, 0xff),
    Int::land(obj >> 8, 0xff),
    Int::land(obj >> 16, 0xff),
  ]
  let from_gen = [Int::land(gen, 0xff), Int::land(gen >> 8, 0xff)]
  let extra = match crypt_type {
    AESV2 => [0x73, 0x41, 0x6c, 0x54]
    _ => []
  }
  let digest_input = bytes_of_int_arrays([key, from_obj, from_gen, extra])
  let digest = self.md5(digest_input)
  let out_len = Int::min(16, keylength / 8 + 5)
  let out = Array::make(out_len, 0)
  for i in 0..<out_len {
    out[i] = @pdfio.bget(digest, i)
  }
  out
}

///|
/// Decrypt or encrypt stream data using the active crypt settings.
pub fn PdfCryptPrimitives::decrypt_stream_data(
  self : PdfCryptPrimitives,
  crypt_type : Encryption,
  encrypt : Bool,
  file_encryption_key : String?,
  obj : Int,
  gen : Int,
  key : Array[Int],
  keylength : Int,
  r : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise {
  if r == 5 || r == 6 {
    let key_bytes = match file_encryption_key {
      Some(k) => @pdfio.int_array_of_string(k)
      None => fail("decrypt_stream_data: missing file encryption key")
    }
    match crypt_type {
      AESV2 =>
        if encrypt {
          self.aes_encrypt_data(4, key_bytes, data)
        } else {
          self.aes_decrypt_data(4, key_bytes, data)
        }
      AESV3(_) =>
        if encrypt {
          self.aes_encrypt_data(8, key_bytes, data)
        } else {
          self.aes_decrypt_data(8, key_bytes, data)
        }
      ARC4(_, _) => self.crypt(key_bytes, data)
    }
  } else {
    let hash = self.find_hash(crypt_type, obj, gen, key, keylength)
    match crypt_type {
      AESV2 =>
        if encrypt {
          self.aes_encrypt_data(4, hash, data)
        } else {
          self.aes_decrypt_data(4, hash, data)
        }
      AESV3(_) =>
        if encrypt {
          self.aes_encrypt_data(8, hash, data)
        } else {
          self.aes_decrypt_data(8, hash, data)
        }
      ARC4(_, _) => self.crypt(hash, data)
    }
  }
}
