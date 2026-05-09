///|
pub fn open_docx_document(path : String) -> DocxDocument raise {
  let bytes = @fs.read_file_to_bytes(path) catch {
    e => raise DocxError::OpenFailed(path + ": " + e.to_string())
  }
  let pkg = @ox.open_ooxml_package(bytes) catch {
    e => raise DocxError::OoxmlFailure(e.to_string())
  }
  parse_docx_document_from_package(pkg)
}

///|
pub fn parse_docx_document_from_package(
  pkg : @ox.OoxmlPackage,
) -> DocxDocument raise {
  let doc_xml = @ox.read_part_text(pkg, "word/document.xml") catch {
    @ox.MissingPart(path) =>
      raise DocxError::OoxmlFailure("missing main document part: " + path)
    e => raise DocxError::OoxmlFailure(e.to_string())
  }

  let styles = if @ox.has_part(pkg, "word/styles.xml") {
    parse_docx_styles_xml(
      @ox.read_part_text(pkg, "word/styles.xml") catch {
        e => raise DocxError::ParseError("styles read failed: " + e.to_string())
      },
    )
  } else {
    empty_docx_styles()
  }

  let numbering = if @ox.has_part(pkg, "word/numbering.xml") {
    parse_docx_numbering_xml(
      @ox.read_part_text(pkg, "word/numbering.xml") catch {
        e =>
          raise DocxError::ParseError("numbering read failed: " + e.to_string())
      },
    )
  } else {
    empty_docx_numbering()
  }

  let issues : Array[DocxValidationIssue] = []
  let doc_rels = read_docx_relationship_index(pkg, "word/document.xml")
  let doc_ctx : DocxPartParseContext = {
    pkg,
    rels: doc_rels,
    source_part: "word/document.xml",
    issues,
  }

  let visible_doc_xml = strip_docx_text_box_content_xml(
    strip_docx_deleted_revision_xml(doc_xml),
  )
  let body_inner = extract_docx_body_inner(visible_doc_xml)
  let body_blocks = parse_docx_body_blocks(
    body_inner, doc_ctx, styles, numbering,
  )

  let notes = {
    footnotes: parse_docx_footnotes_xml(
      if @ox.has_part(pkg, "word/footnotes.xml") {
        @ox.read_part_text(pkg, "word/footnotes.xml") catch {
          _ => ""
        }
      } else {
        ""
      },
      pkg,
      styles,
      numbering,
      issues,
    ),
    endnotes: parse_docx_endnotes_xml(
      if @ox.has_part(pkg, "word/endnotes.xml") {
        @ox.read_part_text(pkg, "word/endnotes.xml") catch {
          _ => ""
        }
      } else {
        ""
      },
      pkg,
      styles,
      numbering,
      issues,
    ),
    comments: parse_docx_comments_xml(
      if @ox.has_part(pkg, "word/comments.xml") {
        @ox.read_part_text(pkg, "word/comments.xml") catch {
          _ => ""
        }
      } else {
        ""
      },
      pkg,
      styles,
      numbering,
      issues,
    ),
  }

  let headers : Array[DocxHeader] = []
  let footers : Array[DocxFooter] = []
  let text_boxes : Array[DocxTextBox] = []

  for
    item in collect_docx_text_boxes_from_xml(
      doc_xml,
      doc_ctx,
      styles,
      numbering,
      DocxTextBoxContext::Body,
      "word/document.xml",
      None,
    ) {
    text_boxes.push(item)
  }

  let header_footer_refs = parse_docx_header_footer_references(
    doc_xml, doc_rels, issues,
  )
  for part_ref in header_footer_refs {
    let xml = @ox.read_part_text(pkg, part_ref.part_name) catch {
      _ => {
        issues.push(
          docx_issue(
            DocxValidationIssueKind::MissingRelationshipTarget,
            DocxValidationSeverity::Warning,
            Some(part_ref.part_name),
            Some(part_ref.relationship_id),
            None,
            None,
            "header/footer part is missing or unreadable: " + part_ref.part_name,
          ),
        )
        continue
      }
    }
    let part_rels = read_docx_relationship_index(pkg, part_ref.part_name)
    let part_ctx : DocxPartParseContext = {
      pkg,
      rels: part_rels,
      source_part: part_ref.part_name,
      issues,
    }
    let visible_part_xml = strip_docx_text_box_content_xml(
      strip_docx_deleted_revision_xml(xml),
    )
    let part_blocks = parse_docx_body_blocks(
      visible_part_xml, part_ctx, styles, numbering,
    )

    if part_ref.is_header {
      headers.push({
        ref_type: part_ref.ref_type,
        relationship_id: part_ref.relationship_id,
        part_name: part_ref.part_name,
        body_blocks: part_blocks,
      })
      for
        box in collect_docx_text_boxes_from_xml(
          xml,
          part_ctx,
          styles,
          numbering,
          DocxTextBoxContext::Header,
          part_ref.part_name,
          Some(part_ref.relationship_id),
        ) {
        text_boxes.push(box)
      }
    } else {
      footers.push({
        ref_type: part_ref.ref_type,
        relationship_id: part_ref.relationship_id,
        part_name: part_ref.part_name,
        body_blocks: part_blocks,
      })
      for
        box in collect_docx_text_boxes_from_xml(
          xml,
          part_ctx,
          styles,
          numbering,
          DocxTextBoxContext::Footer,
          part_ref.part_name,
          Some(part_ref.relationship_id),
        ) {
        text_boxes.push(box)
      }
    }
  }

  let hyperlink_refs = collect_docx_hyperlinks_from_blocks(body_blocks)
  let media_refs = collect_docx_media_from_blocks(body_blocks)

  for note in notes.footnotes {
    for link in collect_docx_hyperlinks_from_blocks(note.body_blocks) {
      hyperlink_refs.push(link)
    }
    for media in collect_docx_media_from_blocks(note.body_blocks) {
      media_refs.push(media)
    }
  }
  for note in notes.endnotes {
    for link in collect_docx_hyperlinks_from_blocks(note.body_blocks) {
      hyperlink_refs.push(link)
    }
    for media in collect_docx_media_from_blocks(note.body_blocks) {
      media_refs.push(media)
    }
  }
  for comment in notes.comments {
    for link in collect_docx_hyperlinks_from_blocks(comment.body_blocks) {
      hyperlink_refs.push(link)
    }
    for media in collect_docx_media_from_blocks(comment.body_blocks) {
      media_refs.push(media)
    }
  }
  for header in headers {
    for link in collect_docx_hyperlinks_from_blocks(header.body_blocks) {
      hyperlink_refs.push(link)
    }
    for media in collect_docx_media_from_blocks(header.body_blocks) {
      media_refs.push(media)
    }
  }
  for footer in footers {
    for link in collect_docx_hyperlinks_from_blocks(footer.body_blocks) {
      hyperlink_refs.push(link)
    }
    for media in collect_docx_media_from_blocks(footer.body_blocks) {
      media_refs.push(media)
    }
  }
  for box in text_boxes {
    for link in collect_docx_hyperlinks_from_blocks(box.body_blocks) {
      hyperlink_refs.push(link)
    }
    for media in collect_docx_media_from_blocks(box.body_blocks) {
      media_refs.push(media)
    }
  }

  {
    body_blocks,
    relationships: doc_rels,
    styles,
    numbering,
    notes,
    headers,
    footers,
    text_boxes,
    media_refs,
    hyperlink_refs,
    issues,
  }
}

///|
pub fn classify_docx_error(err : DocxError) -> DocxErrorInfo {
  let detail = err.to_string()
  let lowered = detail.to_lower()
  let kind = match err {
    DocxError::OpenFailed(_) => DocxErrorKind::OpenFailed
    DocxError::OoxmlFailure(_) =>
      if lowered.contains("missing main document part") ||
        lowered.contains("word/document.xml") {
        DocxErrorKind::MissingMainDocument
      } else {
        DocxErrorKind::OoxmlFailure
      }
    DocxError::ParseError(_) =>
      if lowered.contains("styles") {
        DocxErrorKind::MalformedStylesXml
      } else if lowered.contains("numbering") {
        DocxErrorKind::MalformedNumberingXml
      } else if lowered.contains("document xml") || lowered.contains("<w:body>") {
        DocxErrorKind::MalformedDocumentXml
      } else {
        DocxErrorKind::Unknown
      }
  }
  { kind, detail }
}
