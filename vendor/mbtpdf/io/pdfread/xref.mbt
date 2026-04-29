///|
priv enum XRef {
  Plain(Int, Int)
  Stream(Int, Int)
}

///|
priv enum XRefLine {
  Invalid
  Section(Int, Int) // second Int (length) is unused but required for parsing
  Valid(Int, Int)
  Free(Int, Int) // both Ints are unused but required for parsing
  InObjectStream(Int, Int)
  StreamFree(Int, Int) // constructed but not read in current implementation
  XRefNull // constructed but not read in current implementation
  Finished
}

///|
fn parse_digits(chars : StringView, start : Int, len : Int) -> Int? {
  if start < 0 || len < 0 || start + len > chars.length() {
    return None
  }
  let mut value = 0
  for i in start..<(start + len) {
    let c = chars[i]
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn count_leading_spaces(chars : StringView) -> Int {
  let mut i = 0
  for ch in chars {
    if ch == ' ' {
      i = i + 1
    } else {
      break
    }
  }
  i
}

///|
fn split_fields(line : String) -> Array[String] {
  let parts = Array::new()
  for part in line.split(" ") {
    let s = part.to_string()
    if s != "" {
      parts.push(s)
    }
  }
  parts
}

///|
fn parse_uint_string(s : String) -> Int? {
  if s == "" {
    return None
  }
  let mut value = 0
  for c in s {
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  Some(value)
}

///|
fn read_xref_line(input : @pdfio.Input) -> XRefLine raise {
  let pos = (input.pos_in)()
  @pdfsyntax.PdfSyntax::new().dropwhite(input)
  let line = @pdfsyntax.PdfSyntax::new().input_line(input)
  if line == "xref" || line == "xref " {
    return read_xref_line(input)
  }
  let chars = line[:]
  let offset_opt = if chars.length() >= 18 {
    parse_digits(chars, 0, 10)
  } else {
    None
  }
  let gen_opt = if chars.length() >= 18 {
    parse_digits(chars, 11, 5)
  } else {
    None
  }
  match (offset_opt, gen_opt) {
    (Some(offset), Some(gen)) =>
      if chars.length() > 17 {
        let mark = chars[17]
        if mark is 'n' {
          return Valid(offset, gen)
        } else if mark is 'f' {
          return Free(offset, gen)
        } else {
          return Invalid
        }
      } else {
        return Invalid
      }
    _ => ()
  }
  if chars.length() > 17 {
    let mark = chars[17]
    if mark is 'n' && parse_digits(chars, 0, 10) is Some(0) {
      return Free(0, 0)
    }
  }
  if line.has_prefix("trailer") {
    let leading_spaces = count_leading_spaces(chars)
    (input.seek_in)(pos + 7 + leading_spaces)
    return Finished
  }
  let parts = split_fields(line)
  match parts {
    ["xref", first, second, ..] | [first, second, ..] =>
      match (parse_uint_string(first), parse_uint_string(second)) {
        (Some(s), Some(l)) => return Section(s, l)
        _ => ()
      }
    _ => ()
  }
  Invalid
}

///|
fn read_xref(input : @pdfio.Input) -> Array[(Int, XRef)] raise {
  fn fail_read() -> Unit raise {
    let message = @pdf.input_pdferror(input, "Could not read x-ref table")
    raise @pdf.PdfError::Msg(message)
  }

  let xrefs = Array::new()
  let mut finished = false
  let mut objnumber = 0
  while !finished {
    match read_xref_line(input) {
      Invalid => fail_read()
      Valid(offset, gen) => {
        xrefs.push((objnumber, XRef::Plain(offset, gen)))
        objnumber = objnumber + 1
      }
      Free(offset, gen) => {
        ignore(offset)
        ignore(gen)
        objnumber = objnumber + 1
      }
      Section(start, len) => {
        ignore(len)
        objnumber = start
      }
      Finished => finished = true
      _ => ()
    }
  }
  xrefs
}

///|
/// local methods
fn[A] Array::get_slice(
  self : Array[A],
  start : Int,
  finish : Int,
) -> ArrayView[A]? {
  if start < 0 || finish > self.length() || start > finish {
    return None
  }
  Some(self[start:finish])
}

///|
test "Array:get_slice" {
  let data = [1, 2, 3, 4, 6]
  debug_inspect(data.get_slice(0, 0), content="Some(<ArrayView: []>)")
  debug_inspect(data.get_slice(0, 3), content="Some(<ArrayView: [1, 2, 3]>)")
  debug_inspect(data.get_slice(1, 4), content="Some(<ArrayView: [2, 3, 4]>)")
  debug_inspect(
    data.get_slice(0, 5),
    content="Some(<ArrayView: [1, 2, 3, 4, 6]>)",
  )
  debug_inspect(data.get_slice(-1, 3), content="None")
}

///|
fn read_xref_line_stream(
  input : @pdfio.Input,
  w1 : Int,
  w2 : Int,
  w3 : Int,
) -> XRefLine raise {
  fn read_field(bytes : Int) -> Int raise {
    if bytes == 0 {
      return 0
    }
    let mut value = 0
    for _ in 0..<bytes {
      let b = (input.input_byte)()
      if b == @pdfio.no_more {
        let message = @pdf.input_pdferror(input, "Bad xref stream")
        raise @pdf.PdfError::Msg(message)
      }
      value = value * 256 + b
    }
    value
  }

  let f1 = read_field(w1)
  let f2 = read_field(w2)
  let f3 = read_field(w3)
  match f1 {
    0 => StreamFree(f2, f3)
    1 => Valid(f2, f3)
    2 => InObjectStream(f2, f3)
    _ => XRefNull
  }
}

///|

///|
fn read_xref_stream(
  ctx : PdfRead,
  input : @pdfio.Input,
) -> (Array[(Int, XRef)], Int, @pdf.PdfObject) raise {
  let original_pos = (input.pos_in)()
  let err = @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Bad xref stream"))
  let dict_level : Ref[Int] = { val: 0 }
  let array_level : Ref[Int] = { val: 0 }
  let xrefstream_objectnumber = match
    @pdfsyntax.PdfSyntax::new().lex_next(
      dict_level,
      array_level,
      false,
      input,
      Array::new(),
      true,
      _ => [],
    ) {
    LexInt(i) => i
    _ => {
      (ctx.logger)("couldn't lex object number\n")
      raise err
    }
  }
  if ctx.read_debug {
    (ctx.logger)(
      "Object number of this xref stream is \{xrefstream_objectnumber}\n",
    )
  }
  (input.seek_in)(original_pos)
  fn lex_untilstream(
    input : @pdfio.Input,
    read_stream_data : Bool,
  ) -> Array[@pdfgenlex.Token] {
    let lexemes = Array::new()
    let dict_level : Ref[Int] = { val: 0 }
    let array_level : Ref[Int] = { val: 0 }
    let mut done = false
    while !done {
      let t = @pdfsyntax.PdfSyntax::new().lex_next(
        dict_level,
        array_level,
        true,
        input,
        lexemes,
        read_stream_data,
        _ => [],
      )
      match t {
        StopLexing | LexNone => done = true
        _ => lexemes.push(t)
      }
    }
    lexemes
  }

  let dictlex = lex_untilstream(input, true)
  if dictlex.length() < 2 {
    raise err
  }
  let (objnum, gen) = match dictlex {
    [LexInt(o), LexInt(g), ..] => (o, g)
    _ => raise err
  }
  let stream_token = @pdfsyntax.PdfSyntax::new().lex_stream(
    input,
    dictlex,
    _ => [],
    true,
  )
  let tokens = Array::new()
  for t in dictlex {
    tokens.push(t)
  }
  tokens.push(stream_token)
  tokens.push(LexEndStream)
  tokens.push(LexEndObj)
  let (_, parsed) = @pdfsyntax.PdfSyntax::new().parse(tokens)
  let stream_obj = match parsed {
    @pdf.PdfObject::Stream(_) => parsed
    _ => raise err
  }
  @pdfcodec.PdfCodec::new().decode_pdfstream(@pdf.Pdf::empty(), stream_obj)
  stream_obj.getstream()
  let (w1, w2, w3) = match @pdf.Pdf::empty().lookup_direct("/W", stream_obj) {
    Some(Array([Integer(a), Integer(b), Integer(c)])) => (a, b, c)
    _ => raise err
  }
  let raw_input = match stream_obj {
    Stream(r) =>
      match r.val {
        (_, @pdf.Stream::Got(bytes)) => @pdfio.Input::of_bytes(bytes)
        _ => raise err
      }
    _ => raise err
  }
  let xrefs_raw = Array::new()
  try {
    while true {
      xrefs_raw.push(read_xref_line_stream(raw_input, w1, w2, w3))
    }
  } catch {
    _ => ()
  }
  let starts_and_lens = match
    @pdf.Pdf::empty().lookup_direct("/Index", stream_obj) {
    Some(Array(elts)) => {
      // PDF spec: /Index is an array of (start, count) pairs, so it must be even-length.
      let pairs = Array::new()
      // TODO(upstream): `;` should be optional
      for i = 0; i < elts.length(); {
        match elts.get_slice(i, i + 2) {
          Some([Integer(s), Integer(l)]) => {
            pairs.push((s, l))
            continue i + 2
          }
          _ =>
            raise @pdf.PdfError::Msg(
              @pdf.input_pdferror(input, "Bad /Index entry"),
            )
        }
      }
      pairs
    }
    Some(_) =>
      raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Unknown /Index"))
    None => {
      let size = match @pdf.Pdf::empty().lookup_direct("/Size", stream_obj) {
        Some(@pdf.PdfObject::Integer(s)) => s
        _ =>
          raise @pdf.PdfError::Msg(
            @pdf.input_pdferror(input, "Missing /Size in xref dict"),
          )
      }
      [(0, size)]
    }
  }
  let xrefs = Array::new()
  let mut raw_pos = 0
  for pair in starts_and_lens {
    let (start, len) = pair
    let mut objnumber = start
    let mut i = 0
    while i < len {
      match xrefs_raw.get(raw_pos) {
        None =>
          raise @pdf.PdfError::Msg(
            @pdf.input_pdferror(input, "Bad xref stream"),
          )
        Some(Valid(offset, gen)) =>
          xrefs.push((objnumber, XRef::Plain(offset, gen)))
        Some(InObjectStream(stream, index)) =>
          xrefs.push((objnumber, XRef::Stream(stream, index)))
        Some(StreamFree(offset, gen)) => {
          ignore(offset)
          ignore(gen)
        }
        Some(XRefNull) => ()
        _ => ()
      }
      objnumber = objnumber + 1
      raw_pos = raw_pos + 1
      i = i + 1
    }
  }
  (input.seek_in)(original_pos)
  let _ = objnum
  let _ = gen
  (xrefs, xrefstream_objectnumber, stream_obj)
}

///|
fn read_int_from_stream(input : @pdfio.Input) -> Int raise {
  @pdfsyntax.PdfSyntax::new().dropwhite(input)
  match @pdfsyntax.PdfSyntax::new().lex_number(input) {
    LexInt(i) => i
    _ => {
      let message = @pdf.input_pdferror(input, "objstm offset problem")
      raise @pdf.PdfError::Msg(message)
    }
  }
}

///|
fn parse_object_stream(
  input : @pdfio.Input,
  xrefs : Map[Int, XRef],
  objstm : Int,
  user_password : String?,
  owner_password : String?,
  partial_pdf : @pdf.Pdf,
  indexes? : Array[Int],
) -> Array[(Int, @pdf.PdfObject)] raise {
  let lexemes = lex_object_for_xref(input, xrefs, true, objstm)
  let (_, stmobj) = @pdfsyntax.PdfSyntax::new().parse(lexemes)
  let gen = match xrefs.get(objstm) {
    Some(XRef::Plain(_, g)) => g
    _ => 0
  }
  let stmobj = @pdfcrypt.PdfCrypt::new().decrypt_single_stream(
    user_password, owner_password, partial_pdf, objstm, gen, stmobj,
  )
  match stmobj {
    @pdf.PdfObject::Stream(_) => ()
    _ => {
      let message = @pdf.input_pdferror(
        input, "lex_stream_object: not a stream",
      )
      raise @pdf.PdfError::Msg(message)
    }
  }
  @pdfcodec.PdfCodec::new().decode_pdfstream(partial_pdf, stmobj)
  stmobj.getstream()
  let (dict, stream_bytes) = match stmobj {
    @pdf.PdfObject::Stream(r) => r.val
    _ => raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Bad objstm"))
  }
  let n = match @pdf.Pdf::empty().lookup_direct("/N", dict) {
    Some(@pdf.PdfObject::Integer(v)) => v
    _ => raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "malformed /N"))
  }
  let first = match @pdf.Pdf::empty().lookup_direct("/First", dict) {
    Some(@pdf.PdfObject::Integer(v)) => v
    _ =>
      raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "malformed /First"))
  }
  let raw = match stream_bytes {
    @pdf.Stream::Got(bytes) => bytes
    _ =>
      raise @pdf.PdfError::Msg(
        @pdf.input_pdferror(input, "couldn't decode objstream"),
      )
  }
  let stm_input = @pdfio.Input::of_bytes(raw)
  let rawnums = Array::new()
  let mut i = 0
  while i < n * 2 {
    rawnums.push(read_int_from_stream(stm_input))
    i = i + 1
  }
  let (use_indexes, sorted_indexes) = match indexes {
    Some(values) => {
      let ordered = values.copy()
      ordered.sort_by((a, b) => a - b)
      (true, ordered)
    }
    None => (false, Array::new())
  }
  let objects = Array::new()
  let mut idx = 0
  let mut current_index = 0
  let mut wanted_pos = 0
  while idx < rawnums.length() {
    if use_indexes && wanted_pos >= sorted_indexes.length() {
      break
    }
    let objnum = match rawnums.get(idx) {
      Some(value) => value
      None => raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Bad objstm"))
    }
    let offset = match rawnums.get(idx + 1) {
      Some(value) => value
      None => raise @pdf.PdfError::Msg(@pdf.input_pdferror(input, "Bad objstm"))
    }
    let should_parse = if use_indexes {
      let want = match sorted_indexes.get(wanted_pos) {
        Some(value) => value
        None => break
      }
      if current_index == want {
        wanted_pos = wanted_pos + 1
        true
      } else {
        false
      }
    } else {
      true
    }
    if should_parse {
      (stm_input.seek_in)(offset + first)
      let lexemes = @pdfsyntax.PdfSyntax::new().lex_object_at(
        true,
        stm_input,
        true,
        _ => [],
      )
      let (_, obj) = @pdfsyntax.PdfSyntax::new().parse(lexemes)
      objects.push((objnum, obj))
    }
    current_index = current_index + 1
    idx = idx + 2
  }
  objects
}

///|
fn build_pdf_objects(
  ctx : PdfRead,
  input : @pdfio.Input,
  xref_entries : Array[(Int, XRef)],
  read_stream_data : Bool,
  trailerdict : @pdf.PdfObject,
  user_password : String?,
  owner_password : String?,
) -> @pdf.PdfObjects {
  let xrefs : Map[Int, XRef] = Map::new()
  for pair in xref_entries {
    xrefs.set(pair.0, pair.1)
  }
  let objects : @pdf.PdfObjMap = Map::new()
  let object_stream_ids : Map[Int, Int] = Map::new()
  let stream_id_seen : Map[Int, Bool] = Map::new()
  let stream_groups : Map[Int, Array[(Int, Int)]] = Map::new()
  let mut max_obj = 0
  let stream_ids = Array::new()
  for pair in xref_entries {
    let objnum = pair.0
    let xref = pair.1
    if objnum > max_obj {
      max_obj = objnum
    }
    match xref {
      XRef::Plain(_, gen) =>
        objects.set(objnum, ({ val: @pdf.ObjectData::ToParse }, gen))
      XRef::Stream(stream_id, _index) => {
        if stream_id_seen.get(stream_id) is None {
          stream_id_seen.set(stream_id, true)
          stream_ids.push(stream_id)
        }
        object_stream_ids.set(objnum, stream_id)
        let entries = match stream_groups.get(stream_id) {
          Some(existing) => existing
          None => {
            let created = Array::new()
            stream_groups.set(stream_id, created)
            created
          }
        }
        entries.push((objnum, _index))
      }
    }
  }
  fn parse_obj(num : Int) -> @pdf.PdfObject {
    try {
      let lexemes = lex_object_for_xref(input, xrefs, read_stream_data, num)
      let (_, obj) = @pdfsyntax.PdfSyntax::new().parse(lexemes)
      obj
    } catch {
      _ => {
        if ctx.read_debug {
          (ctx.logger)("parse_obj failed for object \{num}\n")
        }
        @pdf.PdfObject::Null
      }
    }
  }

  let partial_pdf : @pdf.Pdf = {
    major: 0,
    minor: 0,
    root: 0,
    objects: {
      max_obj_num: max_obj,
      parse: Some(parse_obj),
      objects,
      object_stream_ids,
    },
    trailerdict,
    was_linearized: false,
    saved_encryption: None,
  }
  if read_stream_data {
    for stream_id in stream_ids {
      let parsed = parse_object_stream(
        input, xrefs, stream_id, user_password, owner_password, partial_pdf,
      ) catch {
        _ => {
          (ctx.logger)("Warning: unable to parse object stream \{stream_id}\n")
          Array::new()
        }
      }
      for pair in parsed {
        let objnum = pair.0
        let obj = pair.1
        objects.set(
          objnum,
          ({ val: @pdf.ObjectData::ParsedAlreadyDecrypted(obj) }, 0),
        )
        object_stream_ids.set(objnum, stream_id)
      }
    }
  } else {
    let themap : Map[Int, Array[Int]] = Map::new()
    for group in stream_groups {
      let entries = group.1
      for entry in entries {
        let objnum = entry.0
        let index = entry.1
        let indexes = match themap.get(objnum) {
          Some(existing) => existing
          None => {
            let created = Array::new()
            themap.set(objnum, created)
            created
          }
        }
        indexes.push(index)
      }
    }
    fn parse_stream(
      stream_objnum : Int,
      indexes : Array[Int],
    ) -> Array[(Int, (Ref[@pdf.ObjectData], Int))] {
      try {
        let parsed = parse_object_stream(
          input,
          xrefs,
          stream_objnum,
          user_password,
          owner_password,
          partial_pdf,
          indexes~,
        )
        let out = Array::new(capacity=parsed.length())
        for pair in parsed {
          out.push(
            (
              pair.0,
              (Ref::new(@pdf.ObjectData::ParsedAlreadyDecrypted(pair.1)), 0),
            ),
          )
        }
        out
      } catch {
        _ => Array::new()
      }
    }

    for group in stream_groups {
      let stream_id = group.0
      let entries = group.1
      for entry in entries {
        let objnum = entry.0
        let index = entry.1
        objects.set(
          objnum,
          (
            {
              val: @pdf.ObjectData::ToParseFromObjectStream(
                themap, stream_id, index, parse_stream,
              ),
            },
            0,
          ),
        )
      }
    }
  }
  { max_obj_num: max_obj, parse: Some(parse_obj), objects, object_stream_ids }
}
