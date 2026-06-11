///|
fn registry_assert_contains_extension(
  values : Array[String],
  ext : String,
) -> Unit raise {
  for value in values {
    if value == ext {
      return
    }
  }
  fail("expected registry extension: " + ext)
}

///|
fn dispatcher_pdf_pad_xref_offset(value : Int) -> String {
  let mut out = value.to_string()
  while out.length() < 10 {
    out = "0" + out
  }
  out
}

///|
fn dispatcher_pdf_object(number : Int, body : String) -> String {
  "\{number} 0 obj\n" + body + "\nendobj\n"
}

///|
fn dispatcher_pdf_stream_object(content : String) -> String {
  "<< /Length " +
  content.length().to_string() +
  " >>\nstream\n" +
  content +
  "endstream"
}

///|
fn dispatcher_pdf_from_objects(objects : Array[(Int, String)]) -> String {
  let header = "%PDF-1.4\n"
  let pieces : Array[String] = [header]
  let offsets : Array[Int] = []
  let mut offset = header.length()
  for pair in objects {
    let object_text = dispatcher_pdf_object(pair.0, pair.1)
    offsets.push(offset)
    pieces.push(object_text)
    offset = offset + object_text.length()
  }
  let xref_offset = offset
  let size = objects.length() + 1
  let xref_entries : Array[String] = [
    "xref\n0 \{size}\n",
    "0000000000 65535 f \n",
  ]
  for object_offset in offsets {
    xref_entries.push(
      dispatcher_pdf_pad_xref_offset(object_offset) + " 00000 n \n",
    )
  }
  xref_entries.push(
    "trailer\n<< /Root 1 0 R /Size \{size} >>\nstartxref\n\{xref_offset}\n%%EOF\n",
  )
  pieces.push(xref_entries.join(""))
  pieces.join("")
}

///|
fn dispatcher_simple_text_pdf(text : String) -> String {
  dispatcher_pdf_from_objects([
    (1, "<< /Type /Catalog /Pages 2 0 R >>"),
    (2, "<< /Type /Pages /Count 1 /Kids [3 0 R] >>"),
    (
      3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    ),
    (
      4,
      dispatcher_pdf_stream_object(
        "BT\n/F1 12 Tf\n72 720 Td\n(" + text + ") Tj\nET\n",
      ),
    ),
    (5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"),
  ])
}

///|
fn dispatcher_options() -> @conv.ConvertOptions {
  {
    out_dir: None,
    max_heading: Some(6),
    pdf_enhance_mode: None,
    pdf_extract_debug: false,
    pdf_dump_selected_raw: false,
    pdf_pipeline_debug: false,
  }
}

///|
test "dispatcher registry documents default native formats" {
  let entries = @conv.list_converter_registry_entries()
  if entries.length() < 16 {
    fail("converter registry should include shipped and future boundary rows")
  }

  let native_extensions = @conv.supported_native_extensions()
  for
    ext in [
      "docx", "pdf", "xlsx", "pptx", "html", "htm", "csv", "tsv", "txt", "xml", "json",
      "yaml", "yml", "md", "markdown", "zip", "epub",
    ] {
    registry_assert_contains_extension(native_extensions, ext)
  }

  match @conv.lookup_converter_registry_entry("PDF") {
    Some(entry) => {
      if entry.format != "pdf" {
        fail("PDF extension should normalize to pdf format")
      }
      if !entry.default_enabled {
        fail("pdf registry entry should stay default-enabled")
      }
      if !entry.notes.contains("native PDF conversion") {
        fail("pdf registry notes should document native PDF route")
      }
      if !entry.notes.contains("convert/pdf_v2") {
        fail("pdf registry notes should document convert/pdf_v2 route")
      }
      if !entry.notes.contains("convert/pdf v1 retained") {
        fail("pdf registry notes should document retained v1 route")
      }
    }
    None => fail("expected pdf registry entry")
  }
}

///|
test "pdf dispatcher routes registry to v2 product bridge entry" {
  match @conv.lookup_converter_registry_entry("pdf") {
    Some(entry) => {
      assert_eq(entry.format, "pdf")
      assert_eq(entry.default_enabled, true)
      assert_eq(entry.notes.contains("native PDF conversion"), true)
      assert_eq(entry.notes.contains("convert/pdf_v2"), true)
      assert_eq(entry.notes.contains("product bridge"), true)
    }
    None => fail("expected pdf registry entry")
  }
}

///|
async test "pdf dispatcher parse uses v2 product bridge" {
  let out_dir = origin_tmp_root() + "/dispatcher_pdf_v2_route"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)
  let input = out_dir + "/dispatcher-v2.pdf"
  write_utf8_text(input, dispatcher_simple_text_pdf("Hello V2 Route"))

  let result = @conv.parse_to_ir(input, dispatcher_options())
  match result {
    Ok(doc) => {
      if doc.blocks.val.length() == 0 {
        fail("dispatcher pdf route should produce at least one block")
      }
      let markdown = @cor.emit_markdown(doc)
      if !markdown.contains("Hello V2 Route") {
        fail("dispatcher pdf v2 route should parse tiny text PDF")
      }
      if markdown.contains("PDF_V2_PIPELINE_DIAGNOSTICS") {
        fail("dispatcher pdf v2 route must not emit diagnostics")
      }
      for block in doc.blocks.val {
        match block {
          @cor.Block::Paragraph(_)
          | @cor.Block::Heading(_, _)
          | @cor.Block::ListItem(_, _, _)
          | @cor.Block::BlankLine => ()
          _ => fail("dispatcher pdf v2 bridge must stay text-semantic only")
        }
      }
    }
    Err(err) => fail("dispatcher pdf route failed: " + err.to_string())
  }
}

///|
async test "pdf dispatcher v2 route fails closed on malformed pdf" {
  let out_dir = origin_tmp_root() + "/dispatcher_pdf_v2_malformed"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)
  let input = out_dir + "/malformed.pdf"
  write_utf8_text(input, "%PDF-1.4\nnot a valid body\n%%EOF\n")

  match @conv.parse_to_ir(input, dispatcher_options()) {
    Ok(doc) =>
      fail(
        "malformed pdf should not produce document: " + @cor.emit_markdown(doc),
      )
    Err(err) => {
      let message = err.to_string()
      if !message.contains("pdf-v2") {
        fail("malformed pdf should fail through v2 bridge: " + message)
      }
      if !message.contains("parse_pdf_v2_model_from_path") {
        fail("malformed pdf should expose v2 parse stage: " + message)
      }
    }
  }
}

///|
test "v1 pdf code remains present for reference" {
  if !@fs.path_exists("convert/pdf/pdf_parser.mbt") {
    fail("v1 pdf parser should remain present")
  }
  if !@fs.path_exists("convert/pdf/pdf_to_ir.mbt") {
    fail("v1 pdf IR lowering should remain present")
  }
}

///|
async test "dispatcher non pdf route remains unaffected" {
  let out_dir = origin_tmp_root() + "/dispatcher_txt_unaffected"
  recreate_clean_dir(out_dir)
  defer cleanup_temp_dir(out_dir)
  let input = out_dir + "/note.txt"
  write_utf8_text(input, "Plain text route\n")

  match @conv.parse_to_ir(input, dispatcher_options()) {
    Ok(doc) => {
      let markdown = @cor.emit_markdown(doc)
      if !markdown.contains("Plain text route") {
        fail("txt dispatcher route should remain active")
      }
    }
    Err(err) => fail("txt dispatcher route failed: " + err.to_string())
  }
}

///|
test "dispatcher source routes pdf through v2 bridge only" {
  let dispatcher_text = read_utf8_text("convert/convert/dispatcher.mbt")
  if !dispatcher_text.contains("@pdfv2conv.parse_pdf_v2") {
    fail("dispatcher pdf arm should call v2 wrapper")
  }
  if dispatcher_text.contains("@pdf.parse_pdf") {
    fail("dispatcher pdf arm should not call v1 parser")
  }
}

///|
test "dispatcher registry keeps OCR and future provider routes explicit" {
  match @conv.lookup_converter_registry_entry("png") {
    Some(entry) => {
      if entry.format != "image-ocr" {
        fail("png should map to image-ocr boundary row")
      }
      if entry.default_enabled {
        fail("image OCR should not become default dispatcher routing")
      }
      if entry.capability != @conv.ConverterCapability::ImageOcr {
        fail("png should be marked as ImageOcr capability")
      }
    }
    None => fail("expected image OCR boundary row")
  }

  match @conv.lookup_converter_registry_entry("odt") {
    Some(entry) => {
      if entry.default_enabled {
        fail("future provider formats should fail closed by default")
      }
      if entry.capability != @conv.ConverterCapability::ExplicitProviderFuture {
        fail("odt should be marked as future explicit provider work")
      }
    }
    None => fail("expected future provider boundary row")
  }
}

///|
test "docx runtime uses current package without legacy reintroduction" {
  match @conv.lookup_converter_registry_entry("docx") {
    Some(entry) => {
      if entry.format != "docx" {
        fail("docx extension should normalize to docx format")
      }
      if !entry.default_enabled {
        fail("docx should stay default-enabled")
      }
      if entry.capability != @conv.ConverterCapability::NativeDocument {
        fail("docx should remain a native document route")
      }
      if !entry.notes.contains("OOXML document conversion") {
        fail("docx registry notes should document native OOXML conversion")
      }
    }
    None => fail("expected docx registry entry")
  }

  // Compile-time link guard: DOCX resolves through the current convert/docx API.
  ignore(
    try @doc.open_docx_model("__docx_guard_missing__.docx") |> Ok catch {
      e => Err(e)
    },
  )
}
