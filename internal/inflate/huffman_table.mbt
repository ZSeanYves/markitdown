// Vendored from moonbit-community/flate@0.8.5, revision
// 3cbcb5c8bde0b34117fd7980b9f41719f2b8f3d7. Apache-2.0.
// See LICENSE, NOTICE and UPSTREAM.md for exact source hashes and local changes.

// Huffman decode tables for the decode pipeline: per-symbol code lengths in,
// a zlib-style chunked lookup table out. Shared by the streaming `Inflater`
// and the in-memory `MemDecoder`.

///|
const MAX_CODE_LEN : Int32 = 16

///|
pub const HUFFMAN_CHUNK_BITS : Int32 = 9

///|
pub const HUFFMAN_VALUE_SHIFT : Int32 = 4

///|
/// zlib-style chunked Huffman decode table. `chunk & 0xF` is the code length,
/// For plain tables `chunk >> 4` is the symbol. Native data tables keep the
/// symbol in bits 4..12 and length/distance metadata in bits 13..31. Primary
/// links are never decorated: their value remains a flat link-table offset.
/// Keeping all link tables contiguous removes one pointer
/// chase from the decode hot path.
priv struct HuffmanDecoder {
  mut min : Int32
  chunks : FixedArray[UInt32]
  mut links : FixedArray[UInt32]
  mut link_mask : UInt32
}

///|
fn HuffmanDecoder::HuffmanDecoder() -> HuffmanDecoder {
  { min: 0, chunks: FixedArray::make(512, 0U), links: [], link_mask: 0, }
}

///|
/// Build the decode table from per-symbol code lengths. Returns false if the
/// lengths do not form a complete (or valid degenerate) Huffman tree.
/// Optional metadata has one entry per symbol and only uses bits 13..31.
/// Callers supplying it must mask the nine-bit symbol on terminal entries.
fn HuffmanDecoder::initialize(
  self : HuffmanDecoder,
  lengths : ArrayView[Int32],
  metadata~ : FixedArray[UInt32]? = None,
  length_totals~ : Bool = false,
) -> Bool {
  if self.min != 0 {
    self.min = 0
    self.links = []
    self.link_mask = 0
  }
  let count = FixedArray::make(MAX_CODE_LEN, 0)
  let mut min = 0
  let mut max = 0
  for n in lengths {
    if n == 0 {
      continue
    }
    if min == 0 || n < min {
      min = n
    }
    if n > max {
      max = n
    }
    count[n] = count[n] + 1
  }
  guard max != 0 else {
    self.chunks.fill(0U)
    return true
  }
  let mut code = 0
  let nextcode = FixedArray::make(MAX_CODE_LEN, 0)
  for i in min..<=max {
    code = code << 1
    nextcode[i] = code
    code = code + count[i]
  }
  // Complete trees overwrite every primary entry with a terminal or link.
  // Empty/degenerate/invalid trees must not retain entries from the old tree.
  let complete = code == 1 << max
  if !complete {
    self.chunks.fill(0U)
  }
  guard complete || (code == 1 && max == 1) else { return false }
  self.min = min
  if max > HUFFMAN_CHUNK_BITS {
    let num_links = 1 << (max - HUFFMAN_CHUNK_BITS)
    self.link_mask = (num_links - 1).reinterpret_as_uint()
    let link = nextcode[HUFFMAN_CHUNK_BITS + 1] >> 1
    self.links = FixedArray::make((512 - link) * num_links, 0U)
    for j in link..<512 {
      let mut reverse = reverse16((j & 0xffff).reinterpret_as_uint()).reinterpret_as_int()
      reverse = reverse >> (16 - HUFFMAN_CHUNK_BITS)
      let off = (j - link) * num_links
      self.chunks[reverse] = (off.reinterpret_as_uint() << HUFFMAN_VALUE_SHIFT) |
        (HUFFMAN_CHUNK_BITS + 1).reinterpret_as_uint()
    }
  }
  for idx, n in lengths {
    if n == 0 {
      continue
    }
    let code = nextcode[n]
    nextcode[n] = nextcode[n] + 1
    let extra = if metadata is Some(values) { values[idx] } else { 0U }
    // Length metadata uses only bits 13..24. Store code + extra-bit count
    // above it so the native loop can advance directly to the distance code.
    let extra = if length_totals && extra != 0U {
      extra | ((n.reinterpret_as_uint() + ((extra >> 13) & 7U)) << 25)
    } else {
      extra
    }
    let chunk = (idx << HUFFMAN_VALUE_SHIFT).reinterpret_as_uint() |
      n.reinterpret_as_uint() |
      extra
    let mut reverse = reverse16((code & 0xffff).reinterpret_as_uint()).reinterpret_as_int()
    reverse = reverse >> (16 - n)
    if n <= HUFFMAN_CHUNK_BITS {
      for off = reverse; off < self.chunks.length(); off = off + (1 << n) {
        self.chunks[off] = chunk
      }
    } else {
      let j = reverse & 0x1FF
      let value = (self.chunks[j] >> HUFFMAN_VALUE_SHIFT).reinterpret_as_int()
      let num_links = 1 << (max - HUFFMAN_CHUNK_BITS)
      reverse = reverse >> HUFFMAN_CHUNK_BITS
      for off = reverse
          off < num_links
          off = off + (1 << (n - HUFFMAN_CHUNK_BITS)) {
        self.links[value + off] = chunk
      }
    }
  }
  true
}

///|
/// The fixed literal/length Huffman table (RFC 1951 §3.2.6), built from its
/// canonical code lengths so we never transcribe a precomputed table.
fn make_fixed_huffman_decoder() -> HuffmanDecoder {
  let lengths = FixedArray::make(288, 0)
  lengths.fill(8, start=0, end=144)
  lengths.fill(9, start=144, end=256)
  lengths.fill(7, start=256, end=280)
  lengths.fill(8, start=280, end=288)
  let h = HuffmanDecoder()
  let _ = h.initialize(lengths[:])
  h
}

///|
let fixed_huffman_decoder : HuffmanDecoder = make_fixed_huffman_decoder()
