///|
test "md5 matches known vector" {
  let data = @pdfio.bytes_of_string("abc")
  let digest = @pdfcryptprimitives.PdfCryptPrimitives::new().md5(data)
  let expected = @pdfio.bytes_of_list([
    0x90, 0x01, 0x50, 0x98, 0x3c, 0xd2, 0x4f, 0xb0, 0xd6, 0x96, 0x3f, 0x7d, 0x28,
    0xe1, 0x7f, 0x72,
  ])
  assert_eq(digest, expected)
}

///|
test "arc4 crypt matches known vector" {
  let key = @pdfio.int_array_of_string("Key")
  let data = @pdfio.bytes_of_string("Plaintext")
  let out = @pdfcryptprimitives.PdfCryptPrimitives::new().crypt(key, data)
  let expected = @pdfio.bytes_of_list([
    0xbb, 0xf3, 0x16, 0xe8, 0xd9, 0x40, 0xaf, 0x0a, 0xd3,
  ])
  assert_eq(out, expected)
}

///|
test "aes ecb encrypt/decrypt uses standard vector" {
  let key : Array[Int] = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c,
    0x0d, 0x0e, 0x0f,
  ]
  let plaintext = @pdfio.bytes_of_list([
    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc,
    0xdd, 0xee, 0xff,
  ])
  let encrypted = @pdfcryptprimitives.PdfCryptPrimitives::new().aes_encrypt_data_ecb(
    4, key, plaintext,
  )
  let expected = @pdfio.bytes_of_list([
    0x69, 0xc4, 0xe0, 0xd8, 0x6a, 0x7b, 0x04, 0x30, 0xd8, 0xcd, 0xb7, 0x80, 0x70,
    0xb4, 0xc5, 0x5a,
  ])
  assert_eq(encrypted, expected)
  let decrypted = @pdfcryptprimitives.PdfCryptPrimitives::new().aes_decrypt_data_ecb(
    4,
    key,
    encrypted,
    remove_padding=false,
  )
  assert_eq(decrypted, plaintext)
}

///|
test "decrypt_stream_data arc4 roundtrip" {
  let key : Array[Int] = [1, 2, 3, 4, 5]
  let data = @pdfio.bytes_of_string("secret")
  let crypt_type = @pdfcryptprimitives.Encryption::ARC4(40, 4)
  let enc = @pdfcryptprimitives.PdfCryptPrimitives::new().decrypt_stream_data(
    crypt_type,
    true,
    None,
    7,
    0,
    key,
    40,
    4,
    data,
  )
  let dec = @pdfcryptprimitives.PdfCryptPrimitives::new().decrypt_stream_data(
    crypt_type,
    false,
    None,
    7,
    0,
    key,
    40,
    4,
    enc,
  )
  assert_eq(@pdfio.string_of_bytes(dec), "secret")
}
