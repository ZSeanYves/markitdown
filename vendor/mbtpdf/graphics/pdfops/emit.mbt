///|
fn lexemes_of_op(op : Op) -> Array[Lexeme] {
  let out : Array[Lexeme] = Array::new()
  fn push(lexeme : Lexeme) -> Unit {
    out.push(lexeme)
  }

  match op {
    Op::Opw(w) => {
      push(Obj(Token::LexReal(w)))
      push(Op("w"))
    }
    Op::OpJ(j) => {
      push(Obj(Token::LexInt(j)))
      push(Op("J"))
    }
    Op::Opj(j) => {
      push(Obj(Token::LexInt(j)))
      push(Op("j"))
    }
    Op::OpM(m) => {
      push(Obj(Token::LexReal(m)))
      push(Op("M"))
    }
    Op::Opd(values, phase) => {
      push(Obj(Token::LexLeftSquare))
      for value in values {
        push(Obj(Token::LexReal(value)))
      }
      push(Obj(Token::LexRightSquare))
      push(Obj(Token::LexReal(phase)))
      push(Op("d"))
    }
    Op::Opri(name) => {
      push(Obj(Token::LexName(name)))
      push(Op("ri"))
    }
    Op::Opi(value) => {
      push(Obj(Token::LexInt(value)))
      push(Op("i"))
    }
    Op::Opgs(name) => {
      push(Obj(Token::LexName(name)))
      push(Op("gs"))
    }
    Op::Opq => push(Op("q"))
    Op::OpQ => push(Op("Q"))
    Op::Opcm(t) => {
      push(Obj(Token::LexReal(t.a)))
      push(Obj(Token::LexReal(t.b)))
      push(Obj(Token::LexReal(t.c)))
      push(Obj(Token::LexReal(t.d)))
      push(Obj(Token::LexReal(t.e)))
      push(Obj(Token::LexReal(t.f)))
      push(Op("cm"))
    }
    Op::Opm(x, y) => {
      push(Obj(Token::LexReal(x)))
      push(Obj(Token::LexReal(y)))
      push(Op("m"))
    }
    Op::Opl(x, y) => {
      push(Obj(Token::LexReal(x)))
      push(Obj(Token::LexReal(y)))
      push(Op("l"))
    }
    Op::Opc(x1, y1, x2, y2, x3, y3) => {
      push(Obj(Token::LexReal(x1)))
      push(Obj(Token::LexReal(y1)))
      push(Obj(Token::LexReal(x2)))
      push(Obj(Token::LexReal(y2)))
      push(Obj(Token::LexReal(x3)))
      push(Obj(Token::LexReal(y3)))
      push(Op("c"))
    }
    Op::Opv(x2, y2, x3, y3) => {
      push(Obj(Token::LexReal(x2)))
      push(Obj(Token::LexReal(y2)))
      push(Obj(Token::LexReal(x3)))
      push(Obj(Token::LexReal(y3)))
      push(Op("v"))
    }
    Op::Opy(x1, y1, x3, y3) => {
      push(Obj(Token::LexReal(x1)))
      push(Obj(Token::LexReal(y1)))
      push(Obj(Token::LexReal(x3)))
      push(Obj(Token::LexReal(y3)))
      push(Op("y"))
    }
    Op::Oph => push(Op("h"))
    Op::Opre(x, y, w, h) => {
      push(Obj(Token::LexReal(x)))
      push(Obj(Token::LexReal(y)))
      push(Obj(Token::LexReal(w)))
      push(Obj(Token::LexReal(h)))
      push(Op("re"))
    }
    Op::OpS => push(Op("S"))
    Op::Ops => push(Op("s"))
    Op::Opf => push(Op("f"))
    Op::OpF => push(Op("F"))
    Op::OpfStar => push(Op("f*"))
    Op::OpB => push(Op("B"))
    Op::OpBStar => push(Op("B*"))
    Op::Opb => push(Op("b"))
    Op::OpbStar => push(Op("b*"))
    Op::Opn => push(Op("n"))
    Op::OpW => push(Op("W"))
    Op::OpWStar => push(Op("W*"))
    Op::OpBT => push(Op("BT"))
    Op::OpET => push(Op("ET"))
    Op::OpTc(value) => {
      push(Obj(Token::LexReal(value)))
      push(Op("Tc"))
    }
    Op::OpTw(value) => {
      push(Obj(Token::LexReal(value)))
      push(Op("Tw"))
    }
    Op::OpTz(value) => {
      push(Obj(Token::LexReal(value)))
      push(Op("Tz"))
    }
    Op::OpTL(value) => {
      push(Obj(Token::LexReal(value)))
      push(Op("TL"))
    }
    Op::OpTf(name, size) => {
      push(Obj(Token::LexName(name)))
      push(Obj(Token::LexReal(size)))
      push(Op("Tf"))
    }
    Op::OpTr(value) => {
      push(Obj(Token::LexInt(value)))
      push(Op("Tr"))
    }
    Op::OpTs(value) => {
      push(Obj(Token::LexReal(value)))
      push(Op("Ts"))
    }
    Op::OpTd(tx, ty) => {
      push(Obj(Token::LexReal(tx)))
      push(Obj(Token::LexReal(ty)))
      push(Op("Td"))
    }
    Op::OpTD(tx, ty) => {
      push(Obj(Token::LexReal(tx)))
      push(Obj(Token::LexReal(ty)))
      push(Op("TD"))
    }
    Op::OpTm(t) => {
      push(Obj(Token::LexReal(t.a)))
      push(Obj(Token::LexReal(t.b)))
      push(Obj(Token::LexReal(t.c)))
      push(Obj(Token::LexReal(t.d)))
      push(Obj(Token::LexReal(t.e)))
      push(Obj(Token::LexReal(t.f)))
      push(Op("Tm"))
    }
    Op::OpTStar => push(Op("T*"))
    Op::OpTj(text) => {
      push(Obj(Token::LexString(text)))
      push(Op("Tj"))
    }
    Op::OpTJ(obj) => {
      push(Lexeme::PdfObj(obj))
      push(Op("TJ"))
    }
    Op::OpSingleQuote(text) => {
      push(Obj(Token::LexString(text)))
      push(Op("'"))
    }
    Op::OpDoubleQuote(word, char, text) => {
      push(Obj(Token::LexReal(word)))
      push(Obj(Token::LexReal(char)))
      push(Obj(Token::LexString(text)))
      push(Op("\""))
    }
    Op::Opd0(wx, wy) => {
      push(Obj(Token::LexReal(wx)))
      push(Obj(Token::LexReal(wy)))
      push(Op("d0"))
    }
    Op::Opd1(wx, wy, llx, lly, urx, ury) => {
      push(Obj(Token::LexReal(wx)))
      push(Obj(Token::LexReal(wy)))
      push(Obj(Token::LexReal(llx)))
      push(Obj(Token::LexReal(lly)))
      push(Obj(Token::LexReal(urx)))
      push(Obj(Token::LexReal(ury)))
      push(Op("d1"))
    }
    Op::OpCS(name) => {
      push(Obj(Token::LexName(name)))
      push(Op("CS"))
    }
    Op::Opcs(name) => {
      push(Obj(Token::LexName(name)))
      push(Op("cs"))
    }
    Op::OpSC(values) => {
      for value in values {
        push(Obj(Token::LexReal(value)))
      }
      push(Op("SC"))
    }
    Op::Opsc(values) => {
      for value in values {
        push(Obj(Token::LexReal(value)))
      }
      push(Op("sc"))
    }
    Op::OpSCN(values) => {
      for value in values {
        push(Obj(Token::LexReal(value)))
      }
      push(Op("SCN"))
    }
    Op::Opscn(values) => {
      for value in values {
        push(Obj(Token::LexReal(value)))
      }
      push(Op("scn"))
    }
    Op::OpSCNName(name, values) => {
      for value in values {
        push(Obj(Token::LexReal(value)))
      }
      push(Obj(Token::LexName(name)))
      push(Op("SCN"))
    }
    Op::OpscnName(name, values) => {
      for value in values {
        push(Obj(Token::LexReal(value)))
      }
      push(Obj(Token::LexName(name)))
      push(Op("scn"))
    }
    Op::OpG(value) => {
      push(Obj(Token::LexReal(value)))
      push(Op("G"))
    }
    Op::Opg(value) => {
      push(Obj(Token::LexReal(value)))
      push(Op("g"))
    }
    Op::OpRG(r, g, b) => {
      push(Obj(Token::LexReal(r)))
      push(Obj(Token::LexReal(g)))
      push(Obj(Token::LexReal(b)))
      push(Op("RG"))
    }
    Op::Oprg(r, g, b) => {
      push(Obj(Token::LexReal(r)))
      push(Obj(Token::LexReal(g)))
      push(Obj(Token::LexReal(b)))
      push(Op("rg"))
    }
    Op::OpK(c, m, y, k) => {
      push(Obj(Token::LexReal(c)))
      push(Obj(Token::LexReal(m)))
      push(Obj(Token::LexReal(y)))
      push(Obj(Token::LexReal(k)))
      push(Op("K"))
    }
    Op::Opk(c, m, y, k) => {
      push(Obj(Token::LexReal(c)))
      push(Obj(Token::LexReal(m)))
      push(Obj(Token::LexReal(y)))
      push(Obj(Token::LexReal(k)))
      push(Op("k"))
    }
    Op::Opsh(name) => {
      push(Obj(Token::LexName(name)))
      push(Op("sh"))
    }
    Op::InlineImage(data) => push(Lexeme::LexInlineImage(data))
    Op::OpDo(name) => {
      push(Obj(Token::LexName(name)))
      push(Op("Do"))
    }
    Op::OpMP(name) => {
      push(Obj(Token::LexName(name)))
      push(Op("MP"))
    }
    Op::OpDP(name, obj) => {
      push(Obj(Token::LexName(name)))
      push(Lexeme::PdfObj(obj))
      push(Op("DP"))
    }
    Op::OpBMC(name) => {
      push(Obj(Token::LexName(name)))
      push(Op("BMC"))
    }
    Op::OpBDC(name, obj) => {
      push(Obj(Token::LexName(name)))
      push(Lexeme::PdfObj(obj))
      push(Op("BDC"))
    }
    Op::OpEMC => push(Op("EMC"))
    Op::OpBX => push(Op("BX"))
    Op::OpEX => push(Op("EX"))
    Op::OpUnknown(_) => ()
    Op::OpComment(text) =>
      if write_comments.val {
        push(Obj(Token::LexComment(text)))
      } else {
        ()
      }
  }
  out
}

///|
fn lexemes_of_ops(ops : Array[Op]) -> Array[Lexeme] {
  let out : Array[Lexeme] = Array::new()
  for op in ops {
    let lexemes = lexemes_of_op(op)
    for lexeme in lexemes {
      out.push(lexeme)
    }
  }
  out
}

///|
fn lexemelists_of_ops(ops : Array[Op]) -> Array[Array[Lexeme]] {
  let out : Array[Array[Lexeme]] = Array::new(capacity=ops.length())
  for op in ops {
    out.push(lexemes_of_op(op))
  }
  out
}

///|
fn string_of_lexeme(lexeme : Lexeme) -> String raise {
  match lexeme {
    Lexeme::LexComment => ""
    Lexeme::Obj(token) => PdfSyntax::new().string_of_lexeme(token)
    Lexeme::Op(op) => op
    Lexeme::PdfObj(obj) => obj.to_string()
    Lexeme::LexInlineImage((dict, dp, data)) => {
      let dict_data = match
        @pdf.Pdf::empty().lookup_direct_orelse("/F", "/Filter", dict) {
        None | Some(Array([])) => {
          let _ = dp
          let dict = dict.add_entry(
            "/F",
            PdfObject::Name(@pdf.PdfName::of_string("/Fl")),
          )
          let encoded = @pdfcodec.PdfCodec::new().encode_flate(data)
          (dict, encoded)
        }
        _ => (dict, data)
      }
      let dict = dict_data.0
      let data = dict_data.1
      let dict = dict.add_entry(
        "/L",
        PdfObject::Integer(@pdfio.bytes_size(data)),
      )
      let dict_string = dict.to_string()
      let dict_body = strip_dict_markers(dict_string)
      let filters = match
        @pdf.Pdf::empty().lookup_direct_orelse("/F", "/Filter", dict) {
        Some(Array(items)) => items
        Some(Name(name)) => [PdfObject::Name(name)]
        _ => []
      }
      let space = if filterspecial(filters) { "" } else { " " }
      let sb = StringBuilder::new()
      sb.write_string("BI\n")
      sb.write_string(dict_body)
      sb.write_string(" ID")
      sb.write_string(space)
      sb.write_string(@pdfio.string_of_bytes(data))
      sb.write_string("\nEI\n")
      sb.to_string()
    }
  }
}

///|
fn string_of_lexemes(lexemes : Array[Lexeme]) -> String raise {
  let sb = StringBuilder::new()
  let mut last_char : Char? = None
  for lexeme in lexemes {
    let text = string_of_lexeme(lexeme)
    if text.length() > 0 {
      let first = string_first_char(text)
      if last_char is Some(prev) && first is Some(curr) {
        if !is_delimiter_char(prev) && !is_delimiter_char(curr) {
          sb.write_char(' ')
        }
      }
      sb.write_string(text)
      last_char = string_last_char(text)
    }
  }
  sb.to_string()
}

///|
/// Make a string of several operators (debug only).
pub fn Op::string_of_ops(ops : Array[Op]) -> String raise {
  string_of_lexemes(lexemes_of_ops(ops))
}

///|
/// Make a string of a single operator (debug only).
pub fn Op::to_string(self : Op) -> String raise {
  Op::string_of_ops([self])
}

///|
/// Concatenate byte streams with whitespace between them.
pub fn Op::concat_bytess(
  ss : Array[@pdfio.MutableBytes],
) -> @pdfio.MutableBytes {
  let mut total = 0
  for bytes in ss {
    total = total + @pdfio.bytes_size(bytes)
  }
  let out = @pdfio.mkbytes(total + ss.length())
  let mut pos = 0
  for bytes in ss {
    let len = @pdfio.bytes_size(bytes)
    for i in 0..<len {
      @pdfio.bset_unsafe(out, pos, @pdfio.bget_unsafe(bytes, i))
      pos = pos + 1
    }
    @pdfio.bset_unsafe(out, pos, ' '.to_int())
    pos = pos + 1
  }
  out
}

///|
fn stream_of_lexemes(
  oplists : Array[Array[Lexeme]],
) -> @pdfio.MutableBytes raise {
  let sb = StringBuilder::new()
  let mut prev : String = ""
  for oplist in oplists {
    let text = string_of_lexemes(oplist)
    if !sb.is_empty() {
      let prev_len = prev.length()
      let curr_len = text.length()
      let mut insert = true
      if !always_add_whitespace.val {
        let prev_delim = if prev_len > 0 {
          match string_last_char(prev) {
            Some(chr) => is_delimiter_char(chr)
            None => false
          }
        } else {
          false
        }
        let curr_delim = if curr_len > 0 {
          match string_first_char(text) {
            Some(chr) => is_delimiter_char(chr)
            None => false
          }
        } else {
          false
        }
        if prev_delim || curr_delim {
          insert = false
        }
      }
      if insert {
        sb.write_string(whitespace.val)
      }
    }
    sb.write_string(text)
    prev = text
  }
  @pdfio.bytes_of_string(sb.to_string())
}

///|
/// Flatten a list of operators to an uncompressed PDF stream.
pub fn Op::stream_of_ops(ops : Array[Op]) -> @pdf.PdfObject raise {
  let data = stream_of_lexemes(lexemelists_of_ops(ops))
  PdfObject::Stream(
    Ref::new(
      (
        PdfObject::Dictionary([
          ("/Length", PdfObject::Integer(@pdfio.bytes_size(data))),
        ]),
        @pdf.Stream::Got(data),
      ),
    ),
  )
}

///|
fn parse_operator(
  compatibility : Ref[Int],
  lexemes : Array[Lexeme],
  start : Int,
) -> (Op, Int) raise {
  if start >= lexemes.length() {
    return (Op::OpUnknown(""), start)
  }
  match lexemes[start] {
    Lexeme::LexInlineImage(data) => return (Op::InlineImage(data), start + 1)
    _ => ()
  }
  let (section, next_index) = split_lexemes(lexemes, start)
  if section.length() == 0 {
    return (Op::OpUnknown(""), next_index)
  }
  let op_lexeme = section[section.length() - 1]
  match op_lexeme {
    Lexeme::LexInlineImage(data) => return (Op::InlineImage(data), next_index)
    Lexeme::Op(op) => {
      let operand_count = section.length() - 1
      fn as_real(index : Int) -> Double? {
        if index < operand_count {
          lexeme_real(section[index])
        } else {
          None
        }
      }

      fn as_int(index : Int) -> Int? {
        if index < operand_count {
          lexeme_int(section[index])
        } else {
          None
        }
      }

      fn as_name(index : Int) -> String? {
        if index < operand_count {
          lexeme_name(section[index])
        } else {
          None
        }
      }

      fn as_string(index : Int) -> String? {
        if index < operand_count {
          lexeme_string(section[index])
        } else {
          None
        }
      }

      match op {
        "W" => return (Op::OpW, next_index)
        "W*" => return (Op::OpWStar, next_index)
        "q" => return (Op::Opq, next_index)
        "Q" => return (Op::OpQ, next_index)
        "h" => return (Op::Oph, next_index)
        "n" => return (Op::Opn, next_index)
        "f*" => return (Op::OpfStar, next_index)
        "f" => return (Op::Opf, next_index)
        "F" => return (Op::OpF, next_index)
        "BT" => return (Op::OpBT, next_index)
        "ET" => return (Op::OpET, next_index)
        "B" => return (Op::OpB, next_index)
        "B*" => return (Op::OpBStar, next_index)
        "b" => return (Op::Opb, next_index)
        "b*" => return (Op::OpbStar, next_index)
        "S" => return (Op::OpS, next_index)
        "s" => return (Op::Ops, next_index)
        "T*" => return (Op::OpTStar, next_index)
        "BX" => {
          compatibility.val = compatibility.val + 1
          return (Op::OpBX, next_index)
        }
        "EX" => {
          compatibility.val = compatibility.val - 1
          return (Op::OpEX, next_index)
        }
        "Td" =>
          if operand_count == 2 {
            let tx = as_real(0)
            let ty = as_real(1)
            if tx is Some(x) && ty is Some(y) {
              return (Op::OpTd(x, y), next_index)
            }
          }
        "TD" =>
          if operand_count == 2 {
            let tx = as_real(0)
            let ty = as_real(1)
            if tx is Some(x) && ty is Some(y) {
              return (Op::OpTD(x, y), next_index)
            }
          }
        "w" =>
          if operand_count == 1 {
            let w = as_real(0)
            if w is Some(value) {
              return (Op::Opw(value), next_index)
            }
          }
        "J" =>
          if operand_count == 1 {
            let cap = as_int(0)
            if cap is Some(value) {
              return (Op::OpJ(value), next_index)
            }
          }
        "j" =>
          if operand_count == 1 {
            let join = as_int(0)
            if join is Some(value) {
              return (Op::Opj(value), next_index)
            }
          }
        "m" =>
          if operand_count == 2 {
            let x = as_real(0)
            let y = as_real(1)
            if x is Some(xv) && y is Some(yv) {
              return (Op::Opm(xv, yv), next_index)
            }
          }
        "l" =>
          if operand_count == 2 {
            let x = as_real(0)
            let y = as_real(1)
            if x is Some(xv) && y is Some(yv) {
              return (Op::Opl(xv, yv), next_index)
            }
          }
        "TL" =>
          if operand_count == 1 {
            let leading = as_real(0)
            if leading is Some(value) {
              return (Op::OpTL(value), next_index)
            }
          }
        "Tf" =>
          if operand_count == 2 {
            let name = as_name(0)
            let size = as_real(1)
            if name is Some(n) && size is Some(s) {
              return (Op::OpTf(n, s), next_index)
            }
          }
        "Tj" =>
          if operand_count == 1 {
            let text = as_string(0)
            if text is Some(value) {
              return (Op::OpTj(value), next_index)
            }
          }
        "RG" =>
          if operand_count == 3 {
            let r = as_real(0)
            let g = as_real(1)
            let b = as_real(2)
            if r is Some(rv) && g is Some(gv) && b is Some(bv) {
              return (Op::OpRG(rv, gv, bv), next_index)
            }
          }
        "rg" =>
          if operand_count == 3 {
            let r = as_real(0)
            let g = as_real(1)
            let b = as_real(2)
            if r is Some(rv) && g is Some(gv) && b is Some(bv) {
              return (Op::Oprg(rv, gv, bv), next_index)
            }
          }
        "G" =>
          if operand_count == 1 {
            let g = as_real(0)
            if g is Some(value) {
              return (Op::OpG(value), next_index)
            }
          }
        "g" =>
          if operand_count == 1 {
            let g = as_real(0)
            if g is Some(value) {
              return (Op::Opg(value), next_index)
            }
          }
        "k" =>
          if operand_count == 4 {
            let c = as_real(0)
            let m = as_real(1)
            let y = as_real(2)
            let k = as_real(3)
            if c is Some(cv) && m is Some(mv) && y is Some(yv) && k is Some(kv) {
              return (Op::Opk(cv, mv, yv, kv), next_index)
            }
          }
        "K" =>
          if operand_count == 4 {
            let c = as_real(0)
            let m = as_real(1)
            let y = as_real(2)
            let k = as_real(3)
            if c is Some(cv) && m is Some(mv) && y is Some(yv) && k is Some(kv) {
              return (Op::OpK(cv, mv, yv, kv), next_index)
            }
          }
        "cm" =>
          if operand_count == 6 {
            let a = as_real(0)
            let b = as_real(1)
            let c = as_real(2)
            let d = as_real(3)
            let e = as_real(4)
            let f = as_real(5)
            if a is Some(av) &&
              b is Some(bv) &&
              c is Some(cv) &&
              d is Some(dv) &&
              e is Some(ev) &&
              f is Some(fv) {
              return (
                Op::Opcm({ a: av, b: bv, c: cv, d: dv, e: ev, f: fv }),
                next_index,
              )
            }
          }
        "Tm" =>
          if operand_count == 6 {
            let a = as_real(0)
            let b = as_real(1)
            let c = as_real(2)
            let d = as_real(3)
            let e = as_real(4)
            let f = as_real(5)
            if a is Some(av) &&
              b is Some(bv) &&
              c is Some(cv) &&
              d is Some(dv) &&
              e is Some(ev) &&
              f is Some(fv) {
              return (
                Op::OpTm({ a: av, b: bv, c: cv, d: dv, e: ev, f: fv }),
                next_index,
              )
            }
          }
        "MP" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::OpMP(value), next_index)
            }
          }
        "DP" =>
          if operand_count == 2 {
            let name = as_name(0)
            if name is Some(value) {
              match lexeme_pdfobj(section[1]) {
                Some(obj) => return (Op::OpDP(value, obj), next_index)
                None => ()
              }
            }
          }
        "BMC" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::OpBMC(value), next_index)
            }
          }
        "BDC" =>
          if operand_count == 2 {
            let name = as_name(0)
            if name is Some(value) {
              match lexeme_pdfobj(section[1]) {
                Some(obj) => return (Op::OpBDC(value, obj), next_index)
                None => ()
              }
            }
          }
        "EMC" => return (Op::OpEMC, next_index)
        "gs" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::Opgs(value), next_index)
            }
          }
        "Do" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::OpDo(value), next_index)
            }
          }
        "CS" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::OpCS(value), next_index)
            }
          }
        "cs" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::Opcs(value), next_index)
            }
          }
        "c" =>
          if operand_count == 6 {
            let x1 = as_real(0)
            let y1 = as_real(1)
            let x2 = as_real(2)
            let y2 = as_real(3)
            let x3 = as_real(4)
            let y3 = as_real(5)
            if x1 is Some(x1v) &&
              y1 is Some(y1v) &&
              x2 is Some(x2v) &&
              y2 is Some(y2v) &&
              x3 is Some(x3v) &&
              y3 is Some(y3v) {
              return (Op::Opc(x1v, y1v, x2v, y2v, x3v, y3v), next_index)
            }
          }
        "v" =>
          if operand_count == 4 {
            let x2 = as_real(0)
            let y2 = as_real(1)
            let x3 = as_real(2)
            let y3 = as_real(3)
            if x2 is Some(x2v) &&
              y2 is Some(y2v) &&
              x3 is Some(x3v) &&
              y3 is Some(y3v) {
              return (Op::Opv(x2v, y2v, x3v, y3v), next_index)
            }
          }
        "y" =>
          if operand_count == 4 {
            let x1 = as_real(0)
            let y1 = as_real(1)
            let x3 = as_real(2)
            let y3 = as_real(3)
            if x1 is Some(x1v) &&
              y1 is Some(y1v) &&
              x3 is Some(x3v) &&
              y3 is Some(y3v) {
              return (Op::Opy(x1v, y1v, x3v, y3v), next_index)
            }
          }
        "re" =>
          if operand_count == 4 {
            let x = as_real(0)
            let y = as_real(1)
            let w = as_real(2)
            let h = as_real(3)
            if x is Some(xv) && y is Some(yv) && w is Some(wv) && h is Some(hv) {
              return (Op::Opre(xv, yv, wv, hv), next_index)
            }
          }
        "ri" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::Opri(value), next_index)
            }
          }
        "i" =>
          if operand_count == 1 {
            let value = as_int(0)
            if value is Some(v) {
              return (Op::Opi(v), next_index)
            }
          }
        "M" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpM(v), next_index)
            }
          }
        "'" =>
          if operand_count == 1 {
            let text = as_string(0)
            if text is Some(value) {
              return (Op::OpSingleQuote(value), next_index)
            }
          }
        "\"" =>
          if operand_count == 3 {
            let aw = as_real(0)
            let ac = as_real(1)
            let text = as_string(2)
            if aw is Some(awp) && ac is Some(acp) && text is Some(txt) {
              return (Op::OpDoubleQuote(awp, acp, txt), next_index)
            }
          }
        "d0" =>
          if operand_count == 2 {
            let wx = as_real(0)
            let wy = as_real(1)
            if wx is Some(wxv) && wy is Some(wyv) {
              return (Op::Opd0(wxv, wyv), next_index)
            }
          }
        "d1" =>
          if operand_count == 6 {
            let wx = as_real(0)
            let wy = as_real(1)
            let llx = as_real(2)
            let lly = as_real(3)
            let urx = as_real(4)
            let ury = as_real(5)
            if wx is Some(wxv) &&
              wy is Some(wyv) &&
              llx is Some(llxv) &&
              lly is Some(llyv) &&
              urx is Some(urxv) &&
              ury is Some(uryv) {
              return (Op::Opd1(wxv, wyv, llxv, llyv, urxv, uryv), next_index)
            }
          }
        "sh" =>
          if operand_count == 1 {
            let name = as_name(0)
            if name is Some(value) {
              return (Op::Opsh(value), next_index)
            }
          }
        "Tc" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTc(v), next_index)
            }
          }
        "Tw" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTw(v), next_index)
            }
          }
        "Tz" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTz(v), next_index)
            }
          }
        "Tr" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTr(v.to_int()), next_index)
            }
          }
        "Ts" =>
          if operand_count == 1 {
            let value = as_real(0)
            if value is Some(v) {
              return (Op::OpTs(v), next_index)
            }
          }
        "sc" =>
          return (
            Op::Opsc(
              reals_of_lexemes(section[0:operand_count], "Malformed 'sc'"),
            ),
            next_index,
          )
        "SC" =>
          return (
            Op::OpSC(
              reals_of_lexemes(section[0:operand_count], "Malformed 'SC'"),
            ),
            next_index,
          )
        "scn" =>
          if operand_count > 0 {
            match lexeme_name(section[operand_count - 1]) {
              Some(name) => {
                let values = reals_of_lexemes(
                  section[0:operand_count - 1],
                  "scn",
                )
                return (Op::OpscnName(name, values), next_index)
              }
              None => {
                let values = reals_of_lexemes(
                  section[0:operand_count],
                  "Malformed 'scn'",
                )
                return (Op::Opscn(values), next_index)
              }
            }
          }
        "SCN" =>
          if operand_count > 0 {
            match lexeme_name(section[operand_count - 1]) {
              Some(name) => {
                let values = reals_of_lexemes(
                  section[0:operand_count - 1],
                  "SCN",
                )
                return (Op::OpSCNName(name, values), next_index)
              }
              None => {
                let values = reals_of_lexemes(
                  section[0:operand_count],
                  "Malformed 'SCN'",
                )
                return (Op::OpSCN(values), next_index)
              }
            }
          }
        "d" => return (parse_dash_op(section), next_index)
        "TJ" => return (parse_tj_op(section), next_index)
        _ => ()
      }
      @pdfe.log(
        "Empty or malformed graphics operation \{string_of_lexemes(section)}.\n",
      )
      (Op::OpUnknown(string_of_lexemes(section)), next_index)
    }
    _ => {
      @pdfe.log(
        "Empty or malformed graphics operation \{string_of_lexemes(section)}.\n",
      )
      (Op::OpUnknown(string_of_lexemes(section)), next_index)
    }
  }
}

///|
/// Parse a list of byte streams to an operator list.
pub fn Op::parse_stream(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  streams : Array[@pdfio.MutableBytes],
) -> Array[Op] raise {
  let stream = if streams.length() == 1 {
    streams[0]
  } else {
    Op::concat_bytess(streams)
  }
  Op::parse_single_stream(pdf, resources, stream)
}
