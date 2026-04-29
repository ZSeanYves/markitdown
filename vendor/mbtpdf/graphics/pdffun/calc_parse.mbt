///|
fn keyword_of_string(value : String) -> Calculator? {
  match value {
    "abs" => Some(Calculator::Abs)
    "add" => Some(Calculator::Add)
    "atan" => Some(Calculator::Atan)
    "ceiling" => Some(Calculator::Ceiling)
    "cos" => Some(Calculator::Cos)
    "cvi" => Some(Calculator::Cvi)
    "cvr" => Some(Calculator::Cvr)
    "div" => Some(Calculator::Div)
    "exp" => Some(Calculator::Exp)
    "floor" => Some(Calculator::Floor)
    "idiv" => Some(Calculator::Idiv)
    "ln" => Some(Calculator::Ln)
    "log" => Some(Calculator::Log)
    "mod" => Some(Calculator::Mod)
    "mul" => Some(Calculator::Mul)
    "neg" => Some(Calculator::Neg)
    "round" => Some(Calculator::Round)
    "sin" => Some(Calculator::Sin)
    "sqrt" => Some(Calculator::Sqrt)
    "sub" => Some(Calculator::Sub)
    "truncate" => Some(Calculator::Truncate)
    "and" => Some(Calculator::And)
    "bitshift" => Some(Calculator::Bitshift)
    "eq" => Some(Calculator::Eq)
    "ge" => Some(Calculator::Ge)
    "gt" => Some(Calculator::Gt)
    "le" => Some(Calculator::Le)
    "lt" => Some(Calculator::Lt)
    "ne" => Some(Calculator::Ne)
    "not" => Some(Calculator::Not)
    "or" => Some(Calculator::Or)
    "xor" => Some(Calculator::Xor)
    "copy" => Some(Calculator::Copy)
    "exch" => Some(Calculator::Exch)
    "pop" => Some(Calculator::Pop)
    "dup" => Some(Calculator::Dup)
    "index" => Some(Calculator::Index)
    "roll" => Some(Calculator::Roll)
    _ => None
  }
}

///|
fn strip_outer_braces(tokens : Array[Token]) -> Array[Token] {
  let mut start = 0
  let mut end = tokens.length()
  while start < end {
    match tokens[start] {
      Token::LexName("{") | Token::LexName("}") => {
        start = start + 1
        if end > start {
          end = end - 1
        }
      }
      _ => break
    }
  }
  tokens.sub(start~, end~).to_array()
}

///|
fn group_operators(tokens : Array[Token]) -> Array[Array[Token]] {
  let groups = Array::new()
  let mut i = 0
  while i < tokens.length() {
    match tokens[i] {
      Token::LexName("{") => {
        let mut j = i + 1
        while j < tokens.length() {
          match tokens[j] {
            Token::LexName("}") => break
            _ => j = j + 1
          }
        }
        let group = tokens.sub(start=i + 1, end=j).to_array()
        groups.push(group)
        i = if j < tokens.length() { j + 1 } else { j }
      }
      _ => {
        groups.push([tokens[i]])
        i = i + 1
      }
    }
  }
  groups
}

///|
fn is_single_name(tokens : Array[Token], name : String) -> Bool {
  match tokens {
    [Token::LexName(value)] => value == name
    _ => false
  }
}

///|
fn parse_groups(groups : Array[Array[Token]]) -> Array[Calculator] raise {
  let out = Array::new(capacity=groups.length())
  let mut i = 0
  while i < groups.length() {
    if i + 2 < groups.length() && is_single_name(groups[i + 2], "ifelse") {
      let a = parse_calculator_tokens(groups[i])
      let b = parse_calculator_tokens(groups[i + 1])
      out.push(Calculator::IfElse(a, b))
      i = i + 3
    } else if i + 1 < groups.length() && is_single_name(groups[i + 1], "if") {
      let body = parse_calculator_tokens(groups[i])
      out.push(Calculator::If(body))
      i = i + 2
    } else {
      let group = groups[i]
      match group {
        [Token::LexName("true")] => out.push(Calculator::Bool(true))
        [Token::LexName("false")] => out.push(Calculator::Bool(false))
        [Token::LexReal(f)] => out.push(Calculator::Float(f))
        [Token::LexInt(v)] => out.push(Calculator::Int(v))
        [Token::LexName(name)] =>
          match keyword_of_string(name) {
            Some(op) => out.push(op)
            None => {
              @pdfe.log("Bad keyword \{name}\n")
              raise @pdf.PdfError::Msg("Cannot parse Type 4 function")
            }
          }
        _ => raise @pdf.PdfError::Msg("Cannot parse Type 4 function")
      }
      i = i + 1
    }
  }
  out
}

///|
fn parse_calculator_tokens(tokens : Array[Token]) -> Array[Calculator] raise {
  let stripped = strip_outer_braces(tokens)
  let groups = group_operators(stripped)
  parse_groups(groups)
}

///|
fn parse_calculator(text : String) -> Array[Calculator] raise {
  let tokens = @pdfgenlex.PdfGenLex::new().lex(@pdfio.Input::of_string(text))
  parse_calculator_tokens(tokens)
}

///|
/// Parse a function given a document and function object.
pub fn PdfFunction::parse(pdf : @pdf.Pdf, obj : PdfObject) -> PdfFunction raise {
  let f = pdf.direct(obj)
  let getnum_direct = (value : PdfObject) => pdf.getnum(value)
  let domain = match pdf.lookup_fail("No /Domain", "/Domain", f) {
    Array(values) => values.map(getnum_direct)
    _ => raise @pdf.PdfError::Msg("Bad /Domain")
  }
  let range = match pdf.lookup_direct("/Range", f) {
    Some(Array(values)) => Some(values.map(getnum_direct))
    _ => None
  }
  let func = match pdf.lookup_fail("no /FunctionType", "/FunctionType", f) {
    Integer(0) => {
      let size = match pdf.lookup_fail("no /Size (sampled fun)", "/Size", f) {
        Array(values) =>
          values.map(value => match value {
            Integer(n) => n
            _ => raise @pdf.PdfError::Msg("bad /Size (sampled fun)")
          })
        _ => raise @pdf.PdfError::Msg("Bad /Size (sampled fun)")
      }
      let order = match pdf.lookup_direct("/Order", f) {
        Some(Integer(n)) => n
        _ => 1
      }
      let encode = match pdf.lookup_direct("/Encode", f) {
        Some(Array(values)) if values.length() == 2 * size.length() =>
          values.map(getnum_direct)
        _ =>
          interleave_lists(
            many(0.0, size.length()),
            size.map(x => (x - 1).to_double()),
          )
      }
      let decode = match pdf.lookup_direct("/Decode", f) {
        Some(Array(values)) => values.map(getnum_direct)
        _ =>
          match range {
            Some(values) => values
            None => raise @pdf.PdfError::Msg("No /Range")
          }
      }
      let bitspersample = match
        pdf.lookup_fail("no /BitsPerSample", "/BitsPerSample", f) {
        Integer(i) => i
        _ => raise @pdf.PdfError::Msg("Bad /BitsPerSample")
      }
      @pdfcodec.PdfCodec::new().decode_pdfstream(pdf, f)
      let samples_count = product(size) * (decode.length() / 2)
      let data = match f {
        Stream(r) =>
          match r.val {
            (_, @pdf.Stream::Got(bytes)) => bytes
            _ => raise @pdf.PdfError::Msg("No stream data")
          }
        _ => raise @pdf.PdfError::Msg("This is not a function")
      }
      let samples = read_samples(data, samples_count, bitspersample)
      PdfFunctionKind::Sampled({
        size,
        order,
        encode,
        decode,
        bps: bitspersample,
        samples,
      })
    }
    Integer(2) => {
      let c0 = match pdf.lookup_direct("/C0", f) {
        Some(Array(values)) => values.map(getnum_direct)
        _ => [0.0]
      }
      let c1 = match pdf.lookup_direct("/C1", f) {
        Some(Array(values)) => values.map(getnum_direct)
        _ => [1.0]
      }
      let n = getnum_direct(pdf.lookup_fail("No /N in Type 2 fun", "/N", f))
      PdfFunctionKind::Interpolation({ c0, c1, n })
    }
    Integer(3) => {
      let functions = match pdf.lookup_fail("no /Functions", "/Functions", f) {
        Array(values) => values
        _ => raise @pdf.PdfError::Msg("Bad /Functions")
      }
      let bounds = match pdf.lookup_fail("no /Bounds", "/Bounds", f) {
        Array(values) => values.map(getnum_direct)
        _ => raise @pdf.PdfError::Msg("Bad /Bounds")
      }
      let encode = match pdf.lookup_fail("no /Encode", "/Encode", f) {
        Array(values) => values.map(getnum_direct)
        _ => raise @pdf.PdfError::Msg("Bad /Bounds")
      }
      PdfFunctionKind::Stitching({
        functions: functions.map(value => PdfFunction::parse(pdf, value)),
        bounds,
        stitch_encode: encode,
      })
    }
    Integer(4) => {
      @pdfcodec.PdfCodec::new().decode_pdfstream(pdf, f)
      match f {
        Stream(r) =>
          match r.val {
            (_, @pdf.Stream::Got(bytes)) =>
              PdfFunctionKind::Calculator(
                parse_calculator(@pdfio.string_of_bytes(bytes)),
              )
            _ => raise @pdf.PdfError::Msg("This is not a function")
          }
        _ => raise @pdf.PdfError::Msg("This is not a function")
      }
    }
    _ => raise @pdf.PdfError::Msg("Unknown function type")
  }
  { domain, range, func }
}
