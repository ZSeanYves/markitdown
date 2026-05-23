///|
fn fixture_path_pdfread_object_stream(path : String) -> String {
  let direct = path
  if @fs.path_exists(direct) {
    direct
  } else if path.has_prefix(".external/quality_corpus/pdf_external/pdfjs/") {
    let name = path.split("/").last().unwrap_or("").to_owned()
    if name != "" {
        let repo_tracked = "../../../../testdata/pdfjs/" + name
        if @fs.path_exists(repo_tracked) {
          repo_tracked
        } else {
          let suffix = path[25:].to_owned()
          let repo_local_lab = "markitdown-quality-lab/external_quality/" + suffix
          if @fs.path_exists(repo_local_lab) {
            repo_local_lab
          } else {
            let sibling_lab = "../markitdown-quality-lab/external_quality/" + suffix
            if @fs.path_exists(sibling_lab) {
              sibling_lab
            } else {
            "../../../../../" + path
          }
        }
      }
    } else {
      "../../../../../" + path
    }
  } else if path.has_prefix(".external/quality_corpus/") {
    let suffix = path[25:].to_owned()
    let repo_local_lab = "markitdown-quality-lab/external_quality/" + suffix
    if @fs.path_exists(repo_local_lab) {
      repo_local_lab
    } else {
      let sibling_lab = "../markitdown-quality-lab/external_quality/" + suffix
      if @fs.path_exists(sibling_lab) {
        sibling_lab
      } else {
        "../../../../../" + path
      }
    }
  } else {
    "../../../../../" + path
  }
}

///|
fn find_bytes_offset(haystack : Array[Byte], needle : Array[Byte]) -> Int? {
  if needle.length() == 0 || haystack.length() < needle.length() {
    return None
  }
  let last = haystack.length() - needle.length()
  for start = 0; start <= last; start = start + 1 {
    let mut matched = true
    for i = 0; i < needle.length(); i = i + 1 {
      if haystack[start + i] != needle[i] {
        matched = false
        break
      }
    }
    if matched {
      return Some(start)
    }
  }
  None
}

///|
fn assert_first_widget_value_pdfread(
  pdf : @pdf.Pdf,
  label : String,
) -> Unit raise {
  let pages = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
  if pages.length() != 1 {
    fail(label + ": expected one page")
  }
  let annots = match pdf.lookup_direct("/Annots", pages[0].rest) {
    Some(@pdf.PdfObject::Array(items)) => items
    _ => fail(label + ": expected page /Annots array")
  }
  let first = pdf.direct(annots[0])
  let has_ap = first.lookup_immediate("/AP") is Some(_)
  let has_v = first.lookup_immediate("/V") is Some(_)
  let label_text = match pdf.lookup_direct("/TU", first) {
    Some(@pdf.PdfObject::String(s)) =>
      s
      .replace(old="\u{0000}", new="?")
      .replace(old="\u{00FE}", new="?")
      .replace(old="\u{00FF}", new="?")
    _ => "None"
  }
  match pdf.lookup_direct("/V", first) {
    Some(
      @pdf.PdfObject::String(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
      )
    ) => ()
    Some(other) =>
      fail(
        label + ": expected first widget /V string, got " + other.to_string(),
      )
    None =>
      fail(
        label +
        ": expected first widget /V from object stream; has_ap=" +
        has_ap.to_string() +
        "; has_v=" +
        has_v.to_string() +
        "; label=" +
        label_text,
      )
  }
}

///|
fn assert_object_61_state(pdf : @pdf.Pdf, label : String) -> Unit raise {
  let entry = @pdf.pdfobjmap_find(61, pdf.objects.objects)
  match entry.0.val {
    @pdf.ObjectData::Parsed(obj)
    | @pdf.ObjectData::ParsedAlreadyDecrypted(obj) => {
      let has_ap = obj.lookup_immediate("/AP") is Some(_)
      let has_v = obj.lookup_immediate("/V") is Some(_)
      if !has_ap || !has_v {
        let label_text = match obj.lookup_immediate("/TU") {
          Some(@pdf.PdfObject::String(s)) =>
            s
            .replace(old="\u{0000}", new="?")
            .replace(old="\u{00FE}", new="?")
            .replace(old="\u{00FF}", new="?")
          _ => "None"
        }
        fail(
          label +
          ": object-table 61 missing keys; has_ap=" +
          has_ap.to_string() +
          "; has_v=" +
          has_v.to_string() +
          "; tu=" +
          label_text,
        )
      }
    }
    @pdf.ObjectData::ToParse =>
      fail(label + ": object-table 61 unexpectedly still ToParse")
    @pdf.ObjectData::ToParseFromObjectStream(_, stream_id, index, _) =>
      fail(
        label +
        ": object-table 61 still delayed from stream " +
        stream_id.to_string() +
        " index " +
        index.to_string(),
      )
  }
}

///|
fn assert_object_61_delayed(pdf : @pdf.Pdf, label : String) -> Unit raise {
  let entry = @pdf.pdfobjmap_find(61, pdf.objects.objects)
  match entry.0.val {
    @pdf.ObjectData::ToParseFromObjectStream(_, stream_id, index, _) => {
      assert_eq(stream_id, 81)
      assert_eq(index, 1)
    }
    @pdf.ObjectData::Parsed(_) | @pdf.ObjectData::ParsedAlreadyDecrypted(_) =>
      fail(label + ": expected object-table 61 to stay delayed before lookup")
    @pdf.ObjectData::ToParse =>
      fail(label + ": object-table 61 unexpectedly plain ToParse")
  }
}

///|
fn assert_real_widget_slice_parses(bytes : Array[Byte]) -> Unit raise {
  let decoded = @pdfe.with_silenced_logs(fn() raise {
    let input = @pdfio.Input::of_bytes(bytes, source="widget-slice")
    let tokens = @pdfsyntax.PdfSyntax::new().lex_object_at(true, input, true, _ => {
      []
    })
    let (_, obj) = @pdfsyntax.PdfSyntax::new().parse(tokens)
    obj
  })
  if decoded.lookup_immediate("/AP") is None {
    fail("real widget slice lost /AP during parse")
  }
  match decoded.lookup_immediate("/V") {
    Some(
      @pdf.PdfObject::String(
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
      )
    ) => ()
    Some(other) =>
      fail("real widget slice parsed unexpected /V: " + other.to_string())
    None => fail("real widget slice lost /V during parse")
  }
}

///|
test "pdfread eager and lazy keep text widget /V from object stream sample" {
  let path = fixture_path_pdfread_object_stream(
    "doc_parse/pdf/testdata/pdfjs/annotation-text-widget.pdf",
  )
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read fixture failed: " + e.to_string())
  }

  let eager_input = @pdfio.Input::of_bytes(bytes.to_array(), source=path)
  let eager = @pdfe.with_silenced_logs(fn() raise {
    @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input(None, None, eager_input)
  })

  let lazy_input = @pdfio.Input::of_bytes(bytes.to_array(), source=path)
  let lazy_pdf = @pdfe.with_silenced_logs(fn() raise {
    @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input_lazy(
      None,
      None,
      lazy_input,
    )
  })

  assert_object_61_state(eager, "eager")
  assert_object_61_delayed(lazy_pdf, "lazy")
  let _ = lazy_pdf.lookup_obj(61)
  assert_object_61_state(lazy_pdf, "lazy resolved")
  assert_first_widget_value_pdfread(eager, "eager")
  assert_first_widget_value_pdfread(lazy_pdf, "lazy")
}

///|
test "pdfread decodes object stream bytes containing widget /AP and /V" {
  let path = fixture_path_pdfread_object_stream(
    "doc_parse/pdf/testdata/pdfjs/annotation-text-widget.pdf",
  )
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => fail("read fixture failed: " + e.to_string())
  }
  let raw = bytes.to_array()
  let marker = @pdfio.bytes_of_string("81 0 obj")
  let obj_pos = match find_bytes_offset(raw, marker) {
    Some(v) => v
    None => fail("expected to locate object stream marker")
  }
  let input = @pdfio.Input::of_bytes(raw, source=path)
  (input.seek_in)(obj_pos)
  let tokens = @pdfsyntax.PdfSyntax::new().lex_object_at(false, input, true, _ => {
    []
  })
  let (_objnum, obj) = @pdfsyntax.PdfSyntax::new().parse(tokens)
  @pdfcodec.PdfCodec::new().decode_pdfstream(@pdf.Pdf::empty(), obj)
  let decoded = match obj {
    @pdf.PdfObject::Stream(r) =>
      match r.val.1 {
        @pdf.Stream::Got(v) => v
        _ => fail("expected decoded stream bytes")
      }
    _ => fail("expected object stream")
  }
  let decoded_text = @pdfio.string_of_bytes(decoded)
  if !decoded_text.contains("<</AP<</N 75 0 R>>") {
    fail("expected decoded object stream to retain /AP bytes")
  }
  if !decoded_text.contains(
      "/V(Lorem ipsum dolor sit amet, consectetur adipiscing elit.)",
    ) {
    fail("expected decoded object stream to retain /V bytes")
  }
  let start_marker = @pdfio.bytes_of_string("<</AP<</N 75 0 R>>/DA(")
  let end_marker = @pdfio.bytes_of_string("<</AP<</N 74 0 R>>/DA(")
  let start = match find_bytes_offset(decoded, start_marker) {
    Some(v) => v
    None => fail("expected first widget marker in decoded object stream")
  }
  let finish = match find_bytes_offset(decoded, end_marker) {
    Some(v) => v
    None => fail("expected second widget marker in decoded object stream")
  }
  assert_real_widget_slice_parses(decoded[start:finish].to_owned())
}
