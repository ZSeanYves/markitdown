///|
fn decode_lzw(
  early : Int,
  input : @pdfio.Input,
) -> @pdfio.MutableBytes raise CodecError {
  let prefix_code : Array[Int] = Array::make(8192, 0)
  let append_character : Array[Int] = Array::make(8192, 0)
  let mut bit_count = 0
  let mut bit_buffer : UInt = 0
  let mut endflush = 4
  let mut code_length = 9
  let mut next_code = 258
  let mut new_code = 0
  let mut old_code = 256
  let mut character = 0
  fn reset_table() -> Unit {
    next_code = 258
    code_length = 9
    old_code = 256
  }

  fn decode_string(code : Int) -> Array[Int] {
    let out : Array[Int] = Array::new()
    fn build(c : Int) -> Unit {
      if c > 255 {
        build(prefix_code[c])
        out.push(append_character[c])
      } else {
        out.push(c)
      }
    }

    build(code)
    out
  }

  fn input_code() -> Int raise {
    while bit_count <= 24 {
      let streambyte = (input.input_byte)()
      let value = if streambyte == @pdfio.no_more {
        if endflush == 0 {
          raise Failure::Failure("End_of_file")
        }
        endflush = endflush - 1
        0
      } else {
        streambyte
      }
      bit_buffer = bit_buffer |
        (value.reinterpret_as_uint() << (24 - bit_count))
      bit_count = bit_count + 8
    }
    let result = (bit_buffer >> (32 - code_length)).reinterpret_as_int()
    let mask : UInt = 0xffff_ffff
    bit_buffer = (bit_buffer << code_length) & mask
    bit_count = bit_count - code_length
    result
  }

  fn strip_clear_codes() -> Unit raise {
    while old_code == 256 {
      old_code = input_code()
    }
  }

  try {
    bit_count = 0
    bit_buffer = 0
    endflush = 4
    reset_table()
    let output : Array[Byte] = Array::new()
    strip_clear_codes()
    if old_code == 257 {
      return @pdfio.mkbytes(0)
    }
    character = old_code
    output.push(old_code.to_byte())
    let mut finished = false
    while !finished {
      new_code = input_code()
      if new_code == 257 {
        finished = true
      } else if new_code == 256 {
        reset_table()
        prefix_code.fill(0)
        append_character.fill(0)
        strip_clear_codes()
        if old_code == 257 {
          finished = true
        } else {
          character = old_code
          output.push(old_code.to_byte())
        }
      } else {
        let chars = if new_code >= next_code {
          let expanded = decode_string(old_code)
          expanded.push(character)
          expanded
        } else {
          decode_string(new_code)
        }
        if chars.length() == 0 {
          raise Failure::Failure("LZW")
        }
        character = chars[0]
        for ch in chars {
          output.push(ch.to_byte())
        }
        if next_code < prefix_code.length() {
          prefix_code[next_code] = old_code
          append_character[next_code] = character
          next_code = next_code + 1
          let next_check = next_code + early
          if next_check == 512 || next_check == 1024 || next_check == 2048 {
            code_length = code_length + 1
          }
        }
        old_code = new_code
      }
    }
    output
  } catch {
    _ => raise CodecError::CouldntDecodeStream("LZW")
  }
}

///|
fn encode_lzw(
  early : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let clear_code = 256
  let eod_code = 257
  let mut code_length = 9
  let mut next_code = 258
  let mut dict : Map[Int, Int] = Map::new(capacity=4096)
  let out = @pdfio.BitstreamWrite::new()
  fn reset_table() -> Unit {
    dict = Map::new(capacity=4096)
    next_code = 258
    code_length = 9
  }

  try {
    out.putval(code_length, clear_code)
    if data.length() == 0 {
      out.putval(code_length, eod_code)
      return out.bytes()
    }
    let mut w_code = data[0].to_int()
    let mut i = 1
    while i < data.length() {
      let k = data[i].to_int()
      let key = (w_code << 8) | k
      match dict.get(key) {
        Some(code) => w_code = code
        None => {
          out.putval(code_length, w_code)
          if next_code < 4096 {
            dict[key] = next_code
            next_code = next_code + 1
            let next_check = next_code + early
            if next_check == 512 || next_check == 1024 || next_check == 2048 {
              code_length = code_length + 1
            }
          } else {
            out.putval(code_length, clear_code)
            reset_table()
          }
          w_code = k
        }
      }
      i = i + 1
    }
    out.putval(code_length, w_code)
    out.putval(code_length, eod_code)
    out.bytes()
  } catch {
    _ => raise CodecError::CouldntDecodeStream("LZW")
  }
}
