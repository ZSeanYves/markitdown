// Vendored from moonbit-community/flate@0.8.5, revision
// 3cbcb5c8bde0b34117fd7980b9f41719f2b8f3d7. Apache-2.0.
// See LICENSE, NOTICE and UPSTREAM.md for exact source hashes and local changes.

///|
/// The 32 KB sliding window: the largest back-reference distance DEFLATE can
/// express, since distance codes top out at 32768 (RFC 1951 §3.2.5, "the
/// compressor terminates a block ... distances are limited to 32K bytes"; the
/// distance code table in §3.2.5 maps the largest code to base 24577 + 8192).
pub const WINDOW_SIZE : Int32 = 32768

///|
pub const MAX_NUM_LIT : Int32 = 286

///|
pub const MAX_NUM_DIST : Int32 = 30

///|
pub const NUM_CODES : Int32 = 19

///|
/// Order in which code-length code lengths are stored (RFC 1951 §3.2.7).
let code_order : FixedArray[Int32] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

// ---- length / distance symbol tables ----

///|
let len_base : FixedArray[Int32] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let len_extra : FixedArray[Int32] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
fn build_length_code_info_table() -> FixedArray[Int32] {
  FixedArray::makei(29, index => (len_base[index] << 3) | len_extra[index])
}

///|
/// Packed `(base << 3) | extra_bits` data shared directly by both decoders.
let length_code_info_table : FixedArray[Int32] = build_length_code_info_table()

///|
let dist_base : FixedArray[Int32] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let dist_extra : FixedArray[Int32] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
fn build_distance_code_info_table() -> FixedArray[Int32] {
  FixedArray::makei(MAX_NUM_DIST, symbol => {
    (dist_base[symbol] << 4) | dist_extra[symbol]
  })
}

///|
/// Packed `(base << 4) | extra_bits` data shared directly by both decoders.
let distance_code_info_table : FixedArray[Int32] = build_distance_code_info_table()

///|
/// Bit-reversal of a byte (DEFLATE Huffman codes are read MSB-first while the
/// bit stream is filled LSB-first, so codes are looked up bit-reversed).
fn reverse8(x : Byte) -> Byte {
  rev8tab[x.to_int()].to_byte()
}

///|
fn reverse16(x : UInt32) -> UInt32 {
  rev8tab[((x & 0xff00) >> 8).reinterpret_as_int()] |
  (rev8tab[(x & 0xff).reinterpret_as_int()] << 8)
}

///|
let rev8tab : FixedArray[UInt32] = [
  0, 128, 64, 192, 32, 160, 96, 224, 16, 144, 80, 208, 48, 176, 112, 240, 8, 136,
  72, 200, 40, 168, 104, 232, 24, 152, 88, 216, 56, 184, 120, 248, 4, 132, 68, 196,
  36, 164, 100, 228, 20, 148, 84, 212, 52, 180, 116, 244, 12, 140, 76, 204, 44, 172,
  108, 236, 28, 156, 92, 220, 60, 188, 124, 252, 2, 130, 66, 194, 34, 162, 98, 226,
  18, 146, 82, 210, 50, 178, 114, 242, 10, 138, 74, 202, 42, 170, 106, 234, 26, 154,
  90, 218, 58, 186, 122, 250, 6, 134, 70, 198, 38, 166, 102, 230, 22, 150, 86, 214,
  54, 182, 118, 246, 14, 142, 78, 206, 46, 174, 110, 238, 30, 158, 94, 222, 62, 190,
  126, 254, 1, 129, 65, 193, 33, 161, 97, 225, 17, 145, 81, 209, 49, 177, 113, 241,
  9, 137, 73, 201, 41, 169, 105, 233, 25, 153, 89, 217, 57, 185, 121, 249, 5, 133,
  69, 197, 37, 165, 101, 229, 21, 149, 85, 213, 53, 181, 117, 245, 13, 141, 77, 205,
  45, 173, 109, 237, 29, 157, 93, 221, 61, 189, 125, 253, 3, 131, 67, 195, 35, 163,
  99, 227, 19, 147, 83, 211, 51, 179, 115, 243, 11, 139, 75, 203, 43, 171, 107, 235,
  27, 155, 91, 219, 59, 187, 123, 251, 7, 135, 71, 199, 39, 167, 103, 231, 23, 151,
  87, 215, 55, 183, 119, 247, 15, 143, 79, 207, 47, 175, 111, 239, 31, 159, 95, 223,
  63, 191, 127, 255,
]
