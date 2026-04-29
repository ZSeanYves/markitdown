///|
fn encode_runlength(stream : @pdfio.MutableBytes) -> @pdfio.MutableBytes {
  let size = @pdfio.bytes_size(stream)
  let output : Array[Int] = Array::new(capacity=size + size / 128 + 2)
  let mut literal : Array[Byte] = Array::new(capacity=128)
  fn flush_literal() -> Unit {
    if literal.length() == 0 {
      return
    }
    output.push(literal.length() - 1)
    for b in literal {
      output.push(b.to_int())
    }
    literal = Array::new(capacity=128)
  }

  let mut index = 0
  while index < size {
    let value = stream[index]
    let mut run_len = 1
    while index + run_len < size &&
          run_len < 128 &&
          stream[index + run_len] == value {
      run_len = run_len + 1
    }
    if run_len >= 3 {
      flush_literal()
      let mut remaining = run_len
      while remaining > 0 {
        let chunk = if remaining > 128 { 128 } else { remaining }
        output.push(257 - chunk)
        output.push(value.to_int())
        remaining = remaining - chunk
      }
      index = index + run_len
    } else {
      if literal.length() + run_len > 128 {
        flush_literal()
      }
      for j = 0; j < run_len; j = j + 1 {
        literal.push(value)
      }
      index = index + run_len
    }
  }
  flush_literal()
  output.push(128)
  @pdfio.bytes_of_list(output)
}

///|
fn decode_runlength(input : @pdfio.Input) -> @pdfio.MutableBytes {
  let output : Array[Byte] = Array::new()
  let mut eod = false
  while !eod {
    let len = (input.input_byte)()
    if len == @pdfio.no_more {
      return output
    }
    if len < 128 {
      let mut count = len + 1
      while count > 0 {
        let value = (input.input_byte)()
        if value == @pdfio.no_more {
          return output
        }
        output.push(value.to_byte())
        count = count - 1
      }
    } else if len > 128 {
      let value = (input.input_byte)()
      if value == @pdfio.no_more {
        return output
      }
      let mut count = 257 - len
      while count > 0 {
        output.push(value.to_byte())
        count = count - 1
      }
    } else {
      eod = true
    }
  }
  output
}
