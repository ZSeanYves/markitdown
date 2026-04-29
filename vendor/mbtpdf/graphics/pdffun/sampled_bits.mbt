///|
fn read_samples(
  data : @pdfio.MutableBytes,
  count : Int,
  bits_per_sample : Int,
) -> Array[Int] {
  let out = Array::new(capacity=count)
  let bit_pos = Ref::new(0)
  for _ in 0..<count {
    out.push(read_bits(data, bit_pos, bits_per_sample))
  }
  out
}

///|
fn read_bits(data : @pdfio.MutableBytes, bit_pos : Ref[Int], bits : Int) -> Int {
  let mut value = 0
  for _ in 0..<bits {
    let byte_index = bit_pos.val / 8
    let bit_index = 7 - bit_pos.val % 8
    let byte = @pdfio.bget_unsafe(data, byte_index)
    let bit = (byte >> bit_index) & 1
    value = (value << 1) | bit
    bit_pos.val = bit_pos.val + 1
  }
  value
}
