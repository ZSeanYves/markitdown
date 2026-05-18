///|
fn resolve_sample_path(path : String) -> String raise {
  if @fs.path_exists(path) {
    return path
  }

  let fallback = "../../" + path
  if @fs.path_exists(fallback) {
    return fallback
  }

  fail("sample file not found: " + path)
}

///|
async test "pdf inspect dump smoke on text_simple" {
  let input = resolve_sample_path("samples/main_process/pdf/text_simple.pdf")
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() == 0 {
    fail("PDF model should contain pages")
  }

  let page = doc.pages[0]
  if @model.page_line_count(page) <= 0 {
    fail("PDF page should expose line count")
  }
  if @model.page_span_count(page) <= 0 {
    fail("PDF page should expose span count")
  }
  if @model.page_char_count(page) <= 0 {
    fail("PDF page should expose char count")
  }

  let dump = match
    @inspect.extract_document_inspect_dump(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_inspect_dump failed: " + e.to_string())
  }

  if !dump.contains("PdfDocumentInspect(") {
    fail("inspect dump should contain header")
  }
  if !dump.contains("signals: top_edge_threshold=") {
    fail("inspect dump should contain page edge signal")
  }
  if !dump.contains("block_source[0]=") {
    fail("inspect dump should contain block source refs")
  }
}

///|
async test "pdf lower-layer groups hardwrapped sample into shared text blocks" {
  let input = resolve_sample_path("samples/main_process/pdf/hardwrap_en.pdf")
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() != 1 {
    fail("hardwrap sample should contain exactly one page")
  }

  let page = doc.pages[0]
  if page.text_blocks.length() != 3 {
    fail(
      "expected hardwrap sample to collapse into 3 text blocks, got " +
      page.text_blocks.length().to_string(),
    )
  }

  if @model.block_text(page.text_blocks[1]).trim().to_owned() !=
    "This project aims to build a unified document conversion pipeline for docx, pdf, xlsx, pptx, and html." {
    fail("expected first body block to preserve merged English hardwrap text")
  }

  if @model.block_text(page.text_blocks[2]).trim().to_owned() !=
    "The parser should support international text processing and preserve semantic structure whenever possible." {
    fail("expected second body block to preserve merged English hardwrap text")
  }
}

///|
async test "pdf lower-layer surfaces text widget form values from real pdfjs sample" {
  let input = resolve_sample_path(
    ".external/quality_corpus/pdf_external/pdfjs/annotation-text-widget.pdf",
  )
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() != 1 {
    fail("expected one page in annotation-text-widget.pdf")
  }

  let page = doc.pages[0]
  if page.forms.length() != 7 {
    fail("expected 7 text widget forms, got " + page.forms.length().to_string())
  }

  let values = page.forms.map(fn(form) {
    match form.field_value {
      Some(v) => v
      None => "None"
    }
  })
  let names = page.forms.map(fn(form) {
    match form.field_name {
      Some(v) => v
      None => "None"
    }
  })
  let form_dump = page.forms
    .map(fn(form) {
      let name = match form.field_name {
        Some(v) => v
        None => "None"
      }
      let value = match form.field_value {
        Some(v) => v
        None => "None"
      }
      form.field_type + "|" + name + "|" + value
    })
    .join(" || ")

  if values[0] != "Lorem ipsum dolor sit amet, consectetur adipiscing elit." {
    fail(
      "expected first text widget value to be preserved; names=" +
      names.join(" | ") +
      "; forms=" +
      form_dump,
    )
  }
  if values[1] != "Lorem ipsu" {
    fail("expected max-length text widget value to be preserved")
  }
  if values[2] != "Lorem ipsum dolor sit amet, consectetur adipiscing elit." {
    fail("expected center-aligned text widget value to be preserved")
  }
  if values[3] != "Lorem ipsum dolor sit amet, consectetur adipiscing elit." {
    fail("expected right-aligned text widget value to be preserved")
  }
  if values[4] != "None" {
    fail("expected read-only empty text widget to stay empty")
  }
  if values[5] != "abcdefghijklmnopqrstuvwxyz" {
    fail("expected comb text widget value to be preserved")
  }
  if !values[6].contains("Aliquam vitae felis ac lectus bibendum ultricies") {
    fail("expected multiline text widget value to be preserved")
  }
}

///|
async test "pdf lower-layer surfaces choice widget selections from real pdfjs sample" {
  let input = resolve_sample_path(
    ".external/quality_corpus/pdf_external/pdfjs/annotation-choice-widget.pdf",
  )
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() != 1 {
    fail("expected one page in annotation-choice-widget.pdf")
  }

  let page = doc.pages[0]
  if page.forms.length() != 5 {
    fail(
      "expected 5 choice widget forms, got " + page.forms.length().to_string(),
    )
  }

  let dump = page.forms
    .map(fn(form) {
      let name = match form.field_name {
        Some(v) => v
        None => "None"
      }
      let value = match form.field_value {
        Some(v) => v
        None => "None"
      }
      form.field_type + "|" + name + "|" + value + "|" + form.options.join(", ")
    })
    .join(" || ")

  if page.forms[0].field_value != Some("Dolor") {
    fail("expected combo box selected value Dolor; forms=" + dump)
  }
  if page.forms[1].field_value != None {
    fail(
      "expected read-only combo box to expose options without selected value; forms=" +
      dump,
    )
  }
  if page.forms[2].field_value != Some("Sit") {
    fail("expected single-select list box value Sit; forms=" + dump)
  }
  if page.forms[3].field_value != Some("Ipsum, Amet, Consectetur, Elit") {
    fail("expected multi-select list box values to be preserved; forms=" + dump)
  }
  if page.forms[4].field_value != None {
    fail(
      "expected read-only list box to expose options without selected value; forms=" +
      dump,
    )
  }
}

///|
async test "pdf lower-layer preserves pdfjs widget visibility flags for hidden no-view sample" {
  let input = resolve_sample_path(
    ".external/quality_corpus/pdf_external/pdfjs/annotation_hidden_noview.pdf",
  )
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() != 1 {
    fail("expected one page in annotation_hidden_noview.pdf")
  }

  let page = doc.pages[0]
  if page.forms.length() != 3 {
    fail(
      "expected 3 widget forms in annotation_hidden_noview.pdf, got " +
      page.forms.length().to_string(),
    )
  }

  let dump = page.forms
    .map(fn(form) {
      let name = match form.field_name {
        Some(v) => v
        None => "None"
      }
      let value = match form.field_value {
        Some(v) => v
        None => "None"
      }
      form.field_type +
      "|" +
      name +
      "|" +
      value +
      "|flags=" +
      form.flags.to_string() +
      "|view_visible=" +
      @model.pdf_annotation_is_view_visible(form.flags).to_string()
    })
    .join(" || ")

  if page.forms[0].field_name != Some("Text1") || page.forms[0].flags != 2 {
    fail("expected Text1 widget with flags=2; forms=" + dump)
  }
  if page.forms[1].field_name != Some("Text2") || page.forms[1].flags != 32 {
    fail("expected Text2 widget with flags=32; forms=" + dump)
  }
  if page.forms[2].field_name != Some("Button1") || page.forms[2].flags != 4 {
    fail("expected Button1 widget with flags=4; forms=" + dump)
  }
  if @model.pdf_annotation_is_view_visible(page.forms[0].flags) {
    fail("expected hidden widget Text1 to be non-view-visible; forms=" + dump)
  }
  if @model.pdf_annotation_is_view_visible(page.forms[1].flags) {
    fail("expected no-view widget Text2 to be non-view-visible; forms=" + dump)
  }
  if !@model.pdf_annotation_is_view_visible(page.forms[2].flags) {
    fail(
      "expected print-only Button1 widget to remain view-visible; forms=" + dump,
    )
  }
}

///|
async test "pdf lower-layer preserves printable hidden annotation flags for pdfjs sample" {
  let input = resolve_sample_path(
    ".external/quality_corpus/pdf_external/pdfjs/annotation_hidden_print.pdf",
  )
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() != 1 {
    fail("expected one page in annotation_hidden_print.pdf")
  }

  let page = doc.pages[0]
  if page.forms.length() != 0 {
    fail(
      "expected hidden print sample to expose no widget forms, got " +
      page.forms.length().to_string(),
    )
  }
  if page.annotations.length() != 2 {
    fail(
      "expected 2 annotations in annotation_hidden_print.pdf, got " +
      page.annotations.length().to_string(),
    )
  }

  let dump = page.annotations
    .map(fn(annotation) {
      let contents = match annotation.contents {
        Some(v) => v
        None => "None"
      }
      annotation.subtype +
      "|contents=" +
      contents +
      "|flags=" +
      annotation.flags.to_string() +
      "|view_visible=" +
      @model.pdf_annotation_is_view_visible(annotation.flags).to_string() +
      "|printable=" +
      @model.pdf_annotation_is_printable(annotation.flags).to_string()
    })
    .join(" || ")

  if page.annotations[0].subtype != "/Ink" || page.annotations[0].flags != 6 {
    fail(
      "expected first hidden-print annotation to be /Ink with flags=6; annots=" +
      dump,
    )
  }
  if @model.pdf_annotation_is_view_visible(page.annotations[0].flags) {
    fail(
      "expected hidden-print /Ink annotation to be non-view-visible; annots=" +
      dump,
    )
  }
  if !@model.pdf_annotation_is_printable(page.annotations[0].flags) {
    fail(
      "expected hidden-print /Ink annotation to remain printable; annots=" +
      dump,
    )
  }
}

///|
async test "pdf lower-layer keeps distinct square and circle annotations from pdfjs without-appearance sample" {
  let input = resolve_sample_path(
    ".external/quality_corpus/pdf_external/pdfjs/annotation-square-circle-without-appearance.pdf",
  )
  let doc = match
    @api.extract_document_model(input, @api.default_pdf_config()) {
    Ok(v) => v
    Err(e) => fail("extract_document_model failed: " + e.to_string())
  }

  if doc.pages.length() != 1 {
    fail("expected one page in annotation-square-circle-without-appearance.pdf")
  }

  let page = doc.pages[0]
  if page.annotations.length() != 4 {
    fail(
      "expected 4 raw/model annotations in without-appearance square/circle sample, got " +
      page.annotations.length().to_string(),
    )
  }

  let dump = page.annotations
    .map(fn(annotation) {
      let contents = match annotation.contents {
        Some(v) => v
        None => "None"
      }
      let subject = match annotation.subject {
        Some(v) => v
        None => "None"
      }
      let object_ref = match annotation.object_ref {
        Some(v) => v
        None => "None"
      }
      annotation.subtype +
      "|" +
      subject +
      "|" +
      contents +
      "|flags=" +
      annotation.flags.to_string() +
      "|ref=" +
      object_ref
    })
    .join(" || ")

  let square_count = page.annotations
    .filter(fn(annotation) { annotation.subtype == "/Square" })
    .length()
  let circle_count = page.annotations
    .filter(fn(annotation) { annotation.subtype == "/Circle" })
    .length()

  if square_count != 2 || circle_count != 2 {
    fail(
      "expected 2 square and 2 circle lower-layer annotations; annots=" + dump,
    )
  }
}

///|
