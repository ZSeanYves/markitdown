///|
fn get_streamchar(input : @pdfio.Input) -> Char raise {
  let value = (input.input_byte)()
  if value == @pdfio.no_more {
    raise Failure::Failure("End_of_file")
  }
  let c = value.to_byte().to_char()
  if @pdf.is_whitespace(c) {
    get_streamchar(input)
  } else {
    c
  }
}

///|
fn hex_value(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 'a'.to_int() + 10)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn encode_asciihex(stream : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let hex : Array[Byte] = [
    b'0', b'1', b'2', b'3', b'4', b'5', b'6', b'7', b'8', b'9', b'A', b'B', b'C',
    b'D', b'E', b'F',
  ]
  let size = @pdfio.bytes_size(stream)
  let out = Array::new(capacity=size * 2 + 1)
  for i in 0..<size {
    let value = stream[i].to_int()
    out.push(hex[value >> 4])
    out.push(hex[value & 0x0f])
  }
  out.push(b'>')
  out
}

///|
fn decode_asciihex(
  input : @pdfio.Input,
) -> @pdfio.MutableBytes raise CodecError {
  let output = Array::new()
  let mut enddata = false
  try {
    while !enddata {
      let first = get_streamchar(input)
      let second = get_streamchar(input)
      if first == '>' {
        enddata = true
        input.rewind()
      } else {
        let hi = match hex_value(first) {
          Some(v) => v
          None => raise Failure::Failure("ASCIIHex")
        }
        if second == '>' {
          output.push(((hi << 4) | 0).to_byte())
          enddata = true
        } else {
          let lo = match hex_value(second) {
            Some(v) => v
            None => raise Failure::Failure("ASCIIHex")
          }
          output.push(((hi << 4) | lo).to_byte())
        }
      }
    }
    output
  } catch {
    Failure::Failure(msg) =>
      if msg == "End_of_file" {
        output
      } else {
        raise CodecError::CouldntDecodeStream("ASCIIHex")
      }
    _ => raise CodecError::CouldntDecodeStream("ASCIIHex")
  }
}
