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
      if !entry.notes.contains("native text-PDF") {
        fail("pdf registry notes should document native text boundary")
      }
    }
    None => fail("expected pdf registry entry")
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
  ignore(try? @doc.open_docx_model("__docx_guard_missing__.docx"))
}
