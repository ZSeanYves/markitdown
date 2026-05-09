///|
fn is_encryption_error(err : Error) -> Bool {
  match err {
    @pdf.PdfError::Msg(message) =>
      message.contains("Encryption") || message.contains("encryption")
    _ => false
  }
}

///|
fn should_fallback_on_error(
  ctx : PdfRead,
  err : Error,
  revision : Int?,
) -> Bool {
  if ctx.error_on_malformed {
    return false
  }
  if revision is Some(-1) {
    return false
  }
  match err {
    ReadPdfError::Revisions(_) | ReadPdfError::BadRevision => false
    _ => !is_encryption_error(err)
  }
}

///|
fn advance_to_integer(input : @pdfio.Input) -> Bool {
  let mut found = false
  while !found {
    let b = (input.input_byte)()
    if b == @pdfio.no_more {
      return false
    }
    let c = b.to_byte().to_char()
    if is_digit(c) {
      input.rewind()
      found = true
    }
  }
  true
}

///|
fn read_malformed_pdf_objects(
  input : @pdfio.Input,
  read_stream_data : Bool,
) -> (@pdf.PdfObjMap, Int) raise {
  let objects : @pdf.PdfObjMap = Map::new()
  let mut max_obj = 0
  (input.seek_in)(0)
  while true {
    if !advance_to_integer(input) {
      break
    }
    let start = (input.pos_in)()
    let objnum_str = @pdfsyntax.PdfSyntax::new().getuntil_white_or_delimiter_string(
      input,
    )
    let objnum = match parse_uint_string(objnum_str) {
      Some(v) => v
      None => {
        (input.seek_in)(start + 1)
        continue
      }
    }
    @pdfsyntax.PdfSyntax::new().dropwhite(input)
    let gen_str = @pdfsyntax.PdfSyntax::new().getuntil_white_or_delimiter_string(
      input,
    )
    let gen = match parse_uint_string(gen_str) {
      Some(v) => v
      None => {
        (input.seek_in)(start + 1)
        continue
      }
    }
    @pdfsyntax.PdfSyntax::new().dropwhite(input)
    let kw = @pdfsyntax.PdfSyntax::new().getuntil_white_or_delimiter_string(
      input,
    )
    if kw != "obj" {
      (input.seek_in)(start + 1)
      continue
    }
    let parsed = try {
      (input.seek_in)(start)
      let lexemes = @pdfsyntax.PdfSyntax::new().lex_object_at(
        false,
        input,
        read_stream_data,
        _ => [],
      )
      let (_, obj) = @pdfsyntax.PdfSyntax::new().parse(
        lexemes,
        failure_is_ok=true,
      )
      Some(obj)
    } catch {
      _ => None
    }
    match parsed {
      Some(obj) => {
        objects.set(objnum, ({ val: @pdf.ObjectData::Parsed(obj) }, gen))
        if objnum > max_obj {
          max_obj = objnum
        }
      }
      None => (input.seek_in)(start + 1)
    }
  }
  (objects, max_obj)
}

///|
fn trailer_boundary_ok(input : @pdfio.Input, pos : Int, len : Int) -> Bool {
  let before_ok = if pos == 0 {
    true
  } else {
    (input.seek_in)(pos - 1)
    let c = (input.input_char)()
    (input.seek_in)(pos)
    match c {
      None => true
      Some(ch) => @pdfsyntax.PdfSyntax::new().is_whitespace_or_delimiter(ch)
    }
  }
  let after_ok = if pos + len >= input.in_channel_length {
    true
  } else {
    (input.seek_in)(pos + len)
    let c = (input.input_char)()
    (input.seek_in)(pos)
    match c {
      None => true
      Some(ch) => @pdfsyntax.PdfSyntax::new().is_whitespace_or_delimiter(ch)
    }
  }
  before_ok && after_ok
}

///|
fn read_malformed_trailerdicts(
  input : @pdfio.Input,
) -> Array[@pdf.PdfObject] raise {
  let dicts = Array::new()
  let target = "trailer"
  let len = target.length()
  let mut pos = 0
  while pos + len <= input.in_channel_length {
    (input.seek_in)(pos)
    if @pdfsyntax.PdfSyntax::new().read_chunk(len, input) == target &&
      trailer_boundary_ok(input, pos, len) {
      (input.seek_in)(pos + len)
      try {
        @pdfsyntax.PdfSyntax::new().dropwhite(input)
        let lexemes = @pdfsyntax.PdfSyntax::new().lex_dictionary(false, input)
        let (_, parsed) = @pdfsyntax.PdfSyntax::new().parse(
          lexemes,
          failure_is_ok=true,
        )
        let dict = extract_trailer_dict(parsed)
        dicts.push(dict)
      } catch {
        _ => ()
      }
      let next_pos = (input.pos_in)()
      if next_pos <= pos {
        pos = pos + 1
      } else {
        pos = next_pos
      }
    } else {
      pos = pos + 1
    }
  }
  dicts
}

///|
fn find_catalog_object(objects : @pdf.PdfObjMap) -> Int? {
  for entry in objects {
    let objnum = entry.0
    let (obj_ref, _gen) = entry.1
    match obj_ref.val {
      @pdf.ObjectData::Parsed(obj)
      | @pdf.ObjectData::ParsedAlreadyDecrypted(obj) =>
        match obj.lookup_immediate("/Type") {
          Some(@pdf.PdfObject::Name(name)) if name.equal_string_bytes(
              "/Catalog",
            ) => return Some(objnum)
          _ => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn read_malformed_pdf(
  ctx : PdfRead,
  revision : Int?,
  user_password : String?,
  owner_password : String?,
  input : @pdfio.Input,
  read_stream_data : Bool,
) -> @pdf.Pdf raise {
  let _ = revision
  let _ = user_password
  let _ = owner_password
  (input.seek_in)(0)
  let (major_header, minor_header) = read_header(ctx, input)
  let (objects, max_obj) = read_malformed_pdf_objects(input, read_stream_data)
  let trailers = read_malformed_trailerdicts(input)
  let mut trailerdict = if trailers.length() > 0 {
    trailers[trailers.length() - 1]
  } else {
    @pdf.PdfObject::Dictionary([])
  }
  let root = match trailerdict.lookup_immediate("/Root") {
    Some(@pdf.PdfObject::Indirect(i)) => i
    Some(_) => {
      let from_catalog = find_catalog_object(objects)
      match from_catalog {
        Some(i) => i
        None => raise @pdf.PdfError::Msg("Malformed /Root entry")
      }
    }
    None => {
      let from_catalog = find_catalog_object(objects)
      match from_catalog {
        Some(i) => i
        None => raise @pdf.PdfError::Msg("No /Root entry")
      }
    }
  }
  if trailerdict.lookup_immediate("/Root") is None {
    trailerdict = trailerdict.add_entry("/Root", @pdf.PdfObject::Indirect(root))
  }
  let sanitized_trailer = sanitize_trailerdict(objects.length(), trailerdict)
  let pdf_objects : @pdf.PdfObjects = {
    max_obj_num: max_obj,
    parse: None,
    objects,
    object_stream_ids: Map::new(),
  }
  let pdf_tmp = @pdf.Pdf::{
    major: major_header,
    minor: minor_header,
    root,
    objects: pdf_objects,
    trailerdict: sanitized_trailer,
    was_linearized: false,
    saved_encryption: None,
  }
  let (major, minor) = match version_from_catalog(ctx, pdf_tmp) {
    Some(pair) => pair
    None => (major_header, minor_header)
  }
  @pdf.Pdf::{
    major,
    minor,
    root,
    objects: pdf_objects,
    trailerdict: sanitized_trailer,
    was_linearized: false,
    saved_encryption: None,
  }
}
