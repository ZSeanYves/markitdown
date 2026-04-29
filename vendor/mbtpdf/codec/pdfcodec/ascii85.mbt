///|
fn ascii85_pow85() -> Array[Int64] {
  [
    Int64::from_int(85 * 85 * 85 * 85),
    Int64::from_int(85 * 85 * 85),
    Int64::from_int(85 * 85),
    Int64::from_int(85),
    Int64::from_int(1),
  ]
}

///|
fn ascii85_byte(value : Int64, shift : Int) -> Byte {
  let mask = Int64::from_int(0xff)
  ((value >> shift) & mask).to_int().to_byte()
}

///|
fn encode_ascii85(stream : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let pow85 = ascii85_pow85()
  let size = @pdfio.bytes_size(stream)
  let groups = (size + 3) / 4
  // Each group expands to <= 5 bytes, plus "~>" terminator.
  let output = Array::new(capacity=groups * 5 + 2)
  let mut index = 0
  while index < size {
    let remaining = size - index
    let chunk_len = if remaining >= 4 { 4 } else { remaining }
    let b0 = stream[index].to_int()
    let b1 = if chunk_len > 1 { stream[index + 1].to_int() } else { 0 }
    let b2 = if chunk_len > 2 { stream[index + 2].to_int() } else { 0 }
    let b3 = if chunk_len > 3 { stream[index + 3].to_int() } else { 0 }
    let value = (Int64::from_int(b0) << 24) |
      (Int64::from_int(b1) << 16) |
      (Int64::from_int(b2) << 8) |
      Int64::from_int(b3)
    if chunk_len == 4 && value == Int64::from_int(0) {
      output.push(b'z')
    } else {
      let digits = Array::new(capacity=5)
      let mut remaining_value = value
      for pow in pow85 {
        let digit = remaining_value / pow
        remaining_value = remaining_value % pow
        digits.push(digit.to_int())
      }
      let count = if chunk_len < 4 { chunk_len + 1 } else { 5 }
      for i in 0..<count {
        output.push((digits[i] + 33).to_byte())
      }
    }
    index = index + chunk_len
  }
  output.push(b'~')
  output.push(b'>')
  output
}

///|
fn decode_ascii85(input : @pdfio.Input) -> @pdfio.MutableBytes raise CodecError {
  let pow85 = ascii85_pow85()
  let output = Array::new()
  let mut digits : Array[Int] = Array::new(capacity=5)
  fn flush_group(group : Array[Int]) -> Unit {
    let len = group.length()
    if len < 2 {
      return
    }
    let mut value = Int64::from_int(0)
    for i in 0..<5 {
      let digit = if i < len { group[i] } else { 84 }
      value = value + Int64::from_int(digit) * pow85[i]
    }
    let bytes = [
      ascii85_byte(value, 24),
      ascii85_byte(value, 16),
      ascii85_byte(value, 8),
      ascii85_byte(value, 0),
    ]
    let count = len - 1
    for i in 0..<count {
      output.push(bytes[i])
    }
  }

  try {
    while true {
      let c = get_streamchar(input)
      if c == 'z' {
        flush_group(digits)
        digits = Array::new(capacity=5)
        output.push((0).to_byte())
        output.push((0).to_byte())
        output.push((0).to_byte())
        output.push((0).to_byte())
      } else if c == '~' {
        flush_group(digits)
        break
      } else if c >= '!' && c <= 'u' {
        if digits.length() == 5 {
          flush_group(digits)
          digits = Array::new(capacity=5)
        }
        digits.push(c.to_int() - '!'.to_int())
      } else {
        raise Failure::Failure("ASCII85")
      }
    }
    output
  } catch {
    _ => raise CodecError::CouldntDecodeStream("ASCII85")
  }
}
