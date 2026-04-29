///|
fn filterspecial(filters : Array[@pdf.PdfObject]) -> Bool {
  filters.any(filter => match filter {
    Name(name) =>
      name.equal_string_bytes("/ASCIIHexDecode") ||
      name.equal_string_bytes("/ASCII85Decode") ||
      name.equal_string_bytes("/AHx") ||
      name.equal_string_bytes("/A85")
    _ => false
  })
}

///|
fn is_inline_image_whitespace(chr : Char) -> Bool {
  match chr.to_int() {
    0 | 9 | 10 | 12 | 13 | 32 => true
    _ => false
  }
}

///|
fn is_inline_image_delimiter(chr : Char) -> Bool {
  is_inline_image_whitespace(chr) || is_delimiter_char(chr)
}

///|
fn inline_image_end_ahead(input : @pdfio.Input) -> Bool {
  let pos = (input.pos_in)()
  let b1 = (input.input_byte)()
  let b2 = (input.input_byte)()
  let b3 = (input.input_byte)()
  (input.seek_in)(pos)
  if b1 == @pdfio.no_more || b2 == @pdfio.no_more {
    return false
  }
  if b1 != 'E'.to_int() || b2 != 'I'.to_int() {
    return false
  }
  if b3 == @pdfio.no_more {
    return true
  }
  match b3.to_char() {
    Some(ch) => is_inline_image_delimiter(ch)
    None => false
  }
}

///|
fn read_inline_image_encoded_data(
  input : @pdfio.Input,
) -> @pdfio.MutableBytes raise {
  let (output, data) = @pdfio.Output::of_bytes(4096)
  let mut done = false
  while !done {
    let pos = (input.pos_in)()
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      raise @pdf.PdfError::Msg(
        "Could not read inline image data - end of stream",
      )
    }
    match b.to_char() {
      Some(ch) if is_inline_image_whitespace(ch) =>
        if inline_image_end_ahead(input) {
          (input.seek_in)(pos)
          done = true
        } else {
          (output.output_byte)(b)
        }
      _ => (output.output_byte)(b)
    }
  }
  output.extract_bytes(data)
}

///|
fn get_jpeg_data(input : @pdfio.Input) -> @pdfio.MutableBytes raise {
  let (output, data) = @pdfio.Output::of_bytes(4096)
  let mut finished = false
  let mut last = 0
  while !finished {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      raise @pdf.PdfError::Msg("Could not read JPEG data - end of stream")
    }
    if b == 0xD9 {
      if last == 0xFF {
        finished = true
      } else {
        last = 0xD9
      }
      (output.output_byte)(0xD9)
    } else {
      last = b
      (output.output_byte)(b)
    }
  }
  output.extract_bytes(data)
}

///|
fn lex_inline_image(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> (@pdf.PdfObject, @pdf.PdfObject?, @pdfio.MutableBytes) raise {
  if debug.val {
    @pdfe.log("lex_inline_image at \{(input.pos_in)()}\n")
  }
  try {
    let lexemes = PdfSyntax::new().lex_dictionary(true, input)
    let tokens : Array[Token] = Array::new(capacity=lexemes.length() + 2)
    tokens.push(Token::LexLeftDict)
    for token in lexemes {
      match token {
        Token::StopLexing => ()
        _ => tokens.push(token)
      }
    }
    tokens.push(Token::LexRightDict)
    let dict = PdfSyntax::new().parse(tokens).1
    if debug.val {
      @pdfe.log("dict was \{dict.to_string()}\n")
    }
    PdfSyntax::new().dropwhite(input)
    let c = (input.input_byte)()
    let c2 = (input.input_byte)()
    if c != 'I'.to_int() || c2 != 'D'.to_int() {
      @pdfe.log("Did not recognise beginning of inline image ID\n")
      nocontent(input)
    }
    let filters = match pdf.lookup_direct_orelse("/F", "/Filter", dict) {
      Some(Array(items)) => items
      Some(Name(name)) => [PdfObject::Name(name)]
      _ => []
    }
    let toskip = !filterspecial(filters)
    if toskip {
      ignore((input.input_byte)())
    }
    if debug.val {
      @pdfe.log("**got ID header, skipped possible byte\n")
    }
    let bpc = match
      pdf.lookup_direct_orelse("/BPC", "/BitsPerComponent", dict) {
      Some(Integer(value)) => value
      _ => {
        @pdfe.log("no BPC\n")
        nocontent(input)
        0
      }
    }
    let cspace = match pdf.lookup_direct_orelse("/CS", "/ColorSpace", dict) {
      Some(Name(name)) =>
        if name.equal_string_bytes("/DeviceGray") ||
          name.equal_string_bytes("/DeviceRGB") ||
          name.equal_string_bytes("/DeviceCMYK") ||
          name.equal_string_bytes("/G") ||
          name.equal_string_bytes("/RGB") ||
          name.equal_string_bytes("/CMYK") {
          PdfObject::Name(name)
        } else {
          if debug.val {
            @pdfe.log("resources is \{resources.to_string()}\n")
          }
          match pdf.lookup_direct("/ColorSpace", resources) {
            Some(Dictionary(_) as d) =>
              match pdf.lookup_direct(name.to_string_bytes(), d) {
                Some(space) => space
                None => {
                  @pdfe.log("no colourspace A\n")
                  nocontent(input)
                  PdfObject::Null
                }
              }
            _ => {
              @pdfe.log("no colourspace B\n")
              nocontent(input)
              PdfObject::Null
            }
          }
        }
      Some(Array(_) as n) => n
      None =>
        match pdf.lookup_direct_orelse("/IM", "/ImageMask", dict) {
          Some(Boolean(true)) =>
            PdfObject::Name(@pdf.PdfName::of_string("/DeviceGray"))
          _ => {
            @pdfe.log("no colourspace C\n")
            nocontent(input)
            PdfObject::Null
          }
        }
      _ => {
        @pdfe.log("no colourspace D\n")
        nocontent(input)
        PdfObject::Null
      }
    }
    let width = match pdf.lookup_direct_orelse("/W", "/Width", dict) {
      Some(Integer(value)) => value
      _ => {
        @pdfe.log("no or malformed /W")
        nocontent(input)
        0
      }
    }
    let height = match pdf.lookup_direct_orelse("/H", "/Height", dict) {
      Some(Integer(value)) => value
      _ => {
        @pdfe.log("no or malformed /H")
        nocontent(input)
        0
      }
    }
    let bitwidth = Op::components(pdf, resources, cspace) * bpc * width
    let bytewidth = if bitwidth % 8 == 0 {
      bitwidth / 8
    } else {
      bitwidth / 8 + 1
    }
    let bytes = bytewidth * height
    let filter_opt = @pdf.Pdf::empty().lookup_direct_orelse(
      "/F", "/Filter", dict,
    )
    let data = match filter_opt {
      None | Some(Array([])) => {
        let out = @pdfio.mkbytes(bytes)
        for i in 0..<bytes {
          @pdfio.bset_unsafe(out, i, (input.input_byte)())
        }
        out
      }
      Some(Name(name)) =>
        if name.equal_string_bytes("/DCT") ||
          name.equal_string_bytes("/DCTDecode") {
          get_jpeg_data(input)
        } else {
          let encoded = read_inline_image_encoded_data(input)
          match @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
            Some(decoded) => decoded
            None => {
              @pdfe.log("decode_from_bytes failed\n")
              nocontent(input)
              @pdfio.mkbytes(0)
            }
          }
        }
      Some(Array(items)) =>
        if items.length() == 1 {
          match items[0] {
            Name(name) =>
              if name.equal_string_bytes("/DCT") ||
                name.equal_string_bytes("/DCTDecode") {
                get_jpeg_data(input)
              } else {
                let encoded = read_inline_image_encoded_data(input)
                match
                  @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
                  Some(decoded) => decoded
                  None => {
                    @pdfe.log("decode_from_bytes failed\n")
                    nocontent(input)
                    @pdfio.mkbytes(0)
                  }
                }
              }
            _ => {
              let encoded = read_inline_image_encoded_data(input)
              match @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
                Some(decoded) => decoded
                None => {
                  @pdfe.log("decode_from_bytes failed\n")
                  nocontent(input)
                  @pdfio.mkbytes(0)
                }
              }
            }
          }
        } else {
          let encoded = read_inline_image_encoded_data(input)
          match @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
            Some(decoded) => decoded
            None => {
              @pdfe.log("decode_from_bytes failed\n")
              nocontent(input)
              @pdfio.mkbytes(0)
            }
          }
        }
      Some(_) => {
        let encoded = read_inline_image_encoded_data(input)
        match @pdfcodec.PdfCodec::new().decode_from_bytes(encoded, dict) {
          Some(decoded) => decoded
          None => {
            @pdfe.log("decode_from_bytes failed\n")
            nocontent(input)
            @pdfio.mkbytes(0)
          }
        }
      }
    }
    PdfSyntax::new().dropwhite(input)
    let end1 = (input.input_byte)()
    let end2 = (input.input_byte)()
    if end1 != 'E'.to_int() || end2 != 'I'.to_int() {
      @pdfe.log("warning: bad end to inline image \{end1}, \{end2}\n")
      PdfSyntax::new().ignoreuntil(true, chr => chr == 'E', input)
      PdfSyntax::new().ignoreuntil(true, chr => chr == 'I', input)
      input.nudge()
      PdfSyntax::new().dropwhite(input)
    }
    let dict_clean = match filter_opt {
      Some(Name(name)) =>
        if name.equal_string_bytes("/DCT") ||
          name.equal_string_bytes("/DCTDecode") {
          dict
        } else {
          let mut cleaned = dict
          for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
            cleaned = cleaned.remove_entry(key)
          }
          cleaned
        }
      Some(Array(items)) =>
        if items.length() == 1 {
          match items[0] {
            Name(name) =>
              if name.equal_string_bytes("/DCT") ||
                name.equal_string_bytes("/DCTDecode") {
                dict
              } else {
                let mut cleaned = dict
                for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
                  cleaned = cleaned.remove_entry(key)
                }
                cleaned
              }
            _ => {
              let mut cleaned = dict
              for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
                cleaned = cleaned.remove_entry(key)
              }
              cleaned
            }
          }
        } else {
          let mut cleaned = dict
          for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
            cleaned = cleaned.remove_entry(key)
          }
          cleaned
        }
      _ => {
        let mut cleaned = dict
        for key in ["/Filter", "/F", "/DecodeParms", "/DP"] {
          cleaned = cleaned.remove_entry(key)
        }
        cleaned
      }
    }
    let dp = @pdf.Pdf::empty().lookup_direct_orelse("/DP", "/DecodeParms", dict)
    (dict_clean, dp, data)
  } catch {
    err => {
      @pdfe.log("inline image reading failed: \{err}\n")
      nocontent(input)
      (PdfObject::Null, None, @pdfio.mkbytes(0))
    }
  }
}

///|
fn lex_keyword(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  input : @pdfio.Input,
) -> Lexeme raise {
  match PdfSyntax::new().getuntil_white_or_delimiter_string(input) {
    "true" => Obj(Token::LexBool(true))
    "false" => Obj(Token::LexBool(false))
    "BI" => LexInlineImage(lex_inline_image(pdf, resources, input))
    "ID" | "EI" | "" => {
      nocontent(input)
      Op("")
    }
    opstring => Op(opstring)
  }
}
