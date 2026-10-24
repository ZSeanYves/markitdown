///|
// Paragraph-local semantic ranges, not an XML tree. The complete part String
// and final domain runs remain resident outside this borrowed scope.
priv struct DocxParagraphFrame {
  tag : String
  start : Int32
  open_end : Int32
  mut close_start : Int32
  mut end : Int32
  mut style_seen : Bool
  mut style_id : String?
  mut rpr_seen : Bool
  mut rpr_depth : Int32?
  mut bold : Bool
}

///|
priv struct DocxParagraphScope {
  frames : Array[DocxParagraphFrame]
  properties : Map[String, String?]
  leases : Array[@budget.BudgetLease]
  context : @budget.BudgetContext?
  collect_properties : Bool
  mut depth : Int32
  mut pending : DocxParagraphFrame?
}

///|
priv struct DocxParagraphProjection {
  style_id : String?
  alignment : String?
  numbering : DocxNumberingRef?
  runs : Array[DocxSourceRun]
}

///|
priv suberror DocxParagraphAbort {
  Cursor(@xml.XmlCursorError)
  Unicode(String)
}

///|
fn DocxParagraphScope::close(self : DocxParagraphScope) -> Unit {
  for lease in self.leases {
    lease.release()
  }
  self.leases.clear()
}

///|
fn DocxParagraphScope::reserve(
  self : DocxParagraphScope,
  bytes : Int64,
) -> Unit raise DocxParagraphAbort {
  if self.context is Some(context) {
    match context.account.reserve(WorkingBytes, bytes) {
      Ok(lease) => self.leases.push(lease)
      Err(error) => raise Cursor(Budget(error))
    }
  }
}

///|
fn DocxParagraphScope::hold(
  self : DocxParagraphScope,
  value : String?,
) -> Unit raise DocxParagraphAbort {
  // Cursor token fields are bare Strings. Retaining one past next() borrows
  // this scope's lease until semantic dispatch finishes, including on error.
  if value is Some(value) {
    self.reserve(value.length().to_int64() * 2L)
  }
}

///|
fn docx_cursor_value(attrs : Array[@xml.XmlCursorAttribute]) -> String? {
  for attr in attrs {
    if attr.name.raw == "w:val" {
      return Some(attr.value)
    }
  }
  None
}

///|
fn DocxParagraphScope::consume(
  self : DocxParagraphScope,
  token : @xml.XmlCursorToken,
) -> Unit raise DocxParagraphAbort {
  match token {
    StartElement(name, attrs, self_closing, span) => {
      if self.depth == 0 {
        self.depth = 1
        return
      }
      let tag = name.raw
      if self.collect_properties &&
        (
          tag == "w:pStyle" ||
          tag == "w:jc" ||
          tag == "w:numId" ||
          tag == "w:ilvl"
        ) &&
        !self.properties.contains(tag) {
        let value = docx_cursor_value(attrs)
        self.hold(Some(tag))
        self.hold(value)
        // Even an absent w:val consumes the first matching tag, as before.
        self.properties.set(tag, value)
      }
      if self.depth == 1 {
        self.hold(Some(tag))
        self.pending = Some({
          tag,
          // <docx-scope> is exactly 12 ASCII/UTF16 units. Cursor positions
          // precede CRLF folding and entity decoding. No UTF8 offset is used
          // as a String index, and no prefix is rescanned for translation.
          start: (span.start.utf16 - 12L).to_int(),
          open_end: (span.end.utf16 - 12L).to_int(),
          close_start: (span.end.utf16 - 12L).to_int(),
          end: (span.end.utf16 - 12L).to_int(),
          style_seen: false,
          style_id: None,
          rpr_seen: false,
          rpr_depth: None,
          bold: false,
        })
      } else if self.pending is Some(frame) && frame.tag == "w:r" {
        if tag == "w:rStyle" && !frame.style_seen {
          frame.style_seen = true
          let value = docx_cursor_value(attrs)
          self.hold(value)
          frame.style_id = value
        }
        if tag == "w:rPr" && !frame.rpr_seen {
          frame.rpr_seen = true
          if !self_closing {
            frame.rpr_depth = Some(self.depth)
          }
        } else if frame.rpr_depth is Some(_) && tag.has_prefix("w:b") {
          // Preserve the existing broad w:b* convention (including bCs and
          // w:val='0'); comments and quoted attributes are no longer tags.
          frame.bold = true
        }
      }
      if self_closing {
        if self.depth == 1 && self.pending is Some(frame) {
          self.frames.push(frame)
          self.pending = None
        }
      } else {
        self.depth += 1
      }
    }
    EndElement(_, span) => {
      self.depth -= 1
      if self.pending is Some(frame) {
        if frame.rpr_depth == Some(self.depth) {
          frame.rpr_depth = None
        }
        if self.depth == 1 {
          frame.close_start = (span.start.utf16 - 12L).to_int()
          frame.end = (span.end.utf16 - 12L).to_int()
          self.frames.push(frame)
          self.pending = None
        }
      }
    }
    _ => ()
  }
}

///|
fn drain_docx_paragraph_cursor(
  scope : DocxParagraphScope,
  cursor : @xml.XmlCursor,
) -> Unit raise DocxParagraphAbort {
  while true {
    match cursor.next() {
      Err(error) => raise Cursor(error)
      Ok(NeedInput) | Ok(End) => return
      Ok(Token(token)) => scope.consume(token)
    }
  }
}

///|
fn scan_docx_paragraph_scope(
  scope : DocxParagraphScope,
  raw : String,
) -> Unit raise DocxParagraphAbort {
  let size = match @input.validated_text_utf8_size(raw) {
    Ok(size) => size
    Err(message) => raise Unicode(message)
  }
  scope.reserve(size)
  let bytes = @utf8.encode(raw)
  let limits = match
    @xml.XmlCursorLimits::new(
      MeasurementOnly,
      max_depth=None,
      max_token_bytes=None,
      max_attributes=None,
      max_tokens=None,
      text_fragment_bytes=64 * 1024,
    ) {
    Ok(limits) => limits
    Err(error) => raise Cursor(error)
  }
  // Original paragraph fragments do not contain their ancestor namespace
  // declarations. Compatibility is private to DOCX's existing raw-QName
  // contract; the shared cursor default and other consumers remain strict.
  let budget_context = scope.context
  let cursor = match
    @xml.new_xml_cursor(limits, budget_context?, allow_unbound_prefixes=true) {
    Ok(cursor) => cursor
    Err(error) => raise Cursor(error)
  }
  defer cursor.close()
  match cursor.feed(b"<docx-scope>", eof=false) {
    Ok(_) => drain_docx_paragraph_cursor(scope, cursor)
    Err(error) => raise Cursor(error)
  }
  let mut offset = 0
  while offset < bytes.length() {
    let end = (offset + 64 * 1024).min(bytes.length())
    // A feed owns a bounded slice copy; include its temporary lifetime as
    // well as the cursor's own decoded input/carry accounting.
    let lease = match scope.context {
      None => None
      Some(context) =>
        match context.account.reserve(WorkingBytes, (end - offset).to_int64()) {
          Ok(lease) => Some(lease)
          Err(error) => raise Cursor(Budget(error))
        }
    }
    defer (if lease is Some(lease) { lease.release() })
    match cursor.feed(bytes[offset:end].to_owned(), eof=false) {
      Ok(_) => drain_docx_paragraph_cursor(scope, cursor)
      Err(error) => raise Cursor(error)
    }
    offset = end
  }
  match cursor.feed(b"</docx-scope>", eof=true) {
    Ok(_) => drain_docx_paragraph_cursor(scope, cursor)
    Err(error) => raise Cursor(error)
  }
}

///|
fn docx_paragraph_escape(
  scope : DocxParagraphScope,
  value : String?,
) -> Unit raise DocxParagraphAbort {
  if scope.context is Some(context) && value is Some(value) {
    let bytes = match @input.validated_text_utf8_size(value) {
      Ok(bytes) => bytes
      Err(message) => raise Unicode(message)
    }
    match context.account.charge(SourceMetadataBytes, bytes) {
      Ok(_) => ()
      Err(error) => raise Cursor(Budget(error))
    }
    match
      (context.retain_resident)(CacheBytes, value.length().to_int64() * 2L) {
      Ok(_) => ()
      Err(error) => raise Cursor(Budget(error))
    }
  }
}

///|
fn docx_paragraph_failure(
  pkg : @ox.OoxmlPackage?,
  error : DocxParagraphAbort,
) -> Bool {
  // Syntax stops this local scope at its completed prefix. No second scanner
  // reparses it. Typed hard failures must reach the package boundary before
  // any subsequent auxiliary-part I/O or successful output.
  let message = match error {
    Cursor(Syntax(_, _, _)) => return false
    Cursor(Budget(error)) => @budget.budget_error_message(error)
    Cursor(InvalidEncoding(message, _))
    | Cursor(InvalidState(message))
    | Unicode(message) => message
    Cursor(Limit(_, observed~, limit~)) =>
      "DOCX paragraph cursor configured limit; observed=" +
      observed.to_string() +
      "; limit=" +
      limit.to_string()
  }
  if pkg is Some(pkg) {
    @dzip.record_hard_failure(pkg.archive, message)
  }
  true
}

///|
async fn analyze_docx_paragraph(
  raw : String,
  paragraph_key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
  collect_properties~ : Bool = true,
) -> DocxParagraphProjection noraise {
  let empty : DocxParagraphProjection = {
    style_id: None,
    alignment: None,
    numbering: None,
    runs: [],
  }
  if pkg is Some(pkg) && @dzip.archive_hard_failure(pkg.archive) is Some(_) {
    return empty
  }
  let scope : DocxParagraphScope = {
    frames: [],
    properties: Map([]),
    leases: [],
    context: match pkg {
      Some(pkg) => @dzip.archive_budget_context(pkg.archive)
      None => None
    },
    collect_properties,
    depth: 0,
    pending: None,
  }
  defer scope.close()
  scan_docx_paragraph_scope(scope, raw) catch {
    error => if docx_paragraph_failure(pkg, error) { return empty }
  }
  try {
    let style_id = scope.properties.get("w:pStyle").unwrap_or(None)
    let alignment = scope.properties.get("w:jc").unwrap_or(None)
    let num_id = scope.properties.get("w:numId").unwrap_or(None)
    let ilvl = scope.properties.get("w:ilvl").unwrap_or(None)
    docx_paragraph_escape(scope, style_id)
    docx_paragraph_escape(scope, alignment)
    docx_paragraph_escape(scope, num_id)
    if num_id is Some(_) {
      docx_paragraph_escape(scope, ilvl)
    }
    let runs = dispatch_docx_paragraph_frames(
      raw, scope, paragraph_key, relationships, pkg, warnings,
    )
    {
      style_id,
      alignment,
      numbering: match num_id {
        Some(num_id) => Some({ num_id, ilvl, })
        None => None
      },
      runs,
    }
  } catch {
    error => {
      ignore(docx_paragraph_failure(pkg, error))
      empty
    }
  }
}

///|
async fn dispatch_docx_paragraph_frames(
  raw : String,
  scope : DocxParagraphScope,
  paragraph_key : DocxSourceKey,
  relationships : Array[@ox.OoxmlRelationship],
  pkg : @ox.OoxmlPackage?,
  warnings : Array[DocxSourceWarning],
) -> Array[DocxSourceRun] raise DocxParagraphAbort {
  let runs : Array[DocxSourceRun] = []
  let mut index = 0
  for frame in scope.frames {
    if pkg is Some(pkg) && @dzip.archive_hard_failure(pkg.archive) is Some(_) {
      break
    }
    if frame.tag == "w:pPr" {
      continue
    }
    let start = frame.start
    let end = frame.end
    if frame.tag == "w:r" {
      let key = docx_child_source_key(paragraph_key, "r", index)
      // Only the discovered lexical interval is copied. The legacy inline
      // helper receives original text, not cursor-decoded/reserialized XML.
      let lease = match scope.context {
        None => None
        Some(context) =>
          match
            context.account.reserve(
              WorkingBytes,
              (frame.close_start - frame.open_end).to_int64() * 2L,
            ) {
            Ok(lease) => Some(lease)
            Err(error) => raise Cursor(Budget(error))
          }
      }
      defer (if lease is Some(lease) { lease.release() })
      let inner = raw[frame.open_end:frame.close_start].to_owned()
      let inlines = parse_docx_run_inlines(
        inner, key, relationships, pkg, warnings,
      )
      if inlines.length() > 0 {
        docx_paragraph_escape(scope, frame.style_id)
        runs.push({
          style_id: frame.style_id,
          bold: frame.bold,
          inlines,
          source_key: key,
        })
      }
    } else {
      let kind = if frame.tag == "w:hyperlink" {
        "hyperlink"
      } else if frame.tag == "w:fldSimple" {
        "field"
      } else if frame.tag == "w:sdt" {
        "sdt"
      } else if frame.tag == "w:smartTag" {
        "smartTag"
      } else if is_docx_math_start(raw, start) {
        "math"
      } else if is_docx_tracked_change_start(raw, start) {
        "tracked"
      } else if frame.tag == "w:bookmarkStart" || frame.tag == "w:bookmarkEnd" {
        "bookmark"
      } else if docx_structural_block_kind(raw, start) is Some(_) {
        "structural"
      } else {
        "inline"
      }
      let key = docx_child_source_key(paragraph_key, kind, index)
      if kind == "math" || kind == "tracked" || kind == "inline" {
        docx_paragraph_escape(scope, Some(frame.tag))
      }
      let inline : DocxSourceInline = if kind == "hyperlink" {
        Hyperlink(
          parse_docx_hyperlink(
            raw, start, end, key, relationships, pkg, warnings,
          ),
        )
      } else if kind == "field" {
        parse_docx_fld_simple(
          raw, start, end, key, relationships, pkg, warnings,
        )
      } else if kind == "sdt" {
        ContentControl(
          parse_docx_inline_content_control(
            raw, start, end, "w:sdt", key, relationships, pkg, warnings,
          ),
        )
      } else if kind == "smartTag" {
        SmartTag(
          parse_docx_smart_tag_inline(
            raw, start, end, key, relationships, pkg, warnings,
          ),
        )
      } else if kind == "math" {
        parse_docx_math_inline(raw, start, end, frame.tag, key, warnings)
      } else if kind == "tracked" {
        parse_docx_tracked_change(
          raw,
          start,
          end,
          frame.tag,
          key,
          relationships,
          pkg,
          warnings,
        )
      } else if kind == "bookmark" {
        parse_docx_bookmark(raw, start, key, warnings)
      } else if kind == "structural" {
        match parse_docx_structural_inline(raw, start, key) {
          Some((marker, _)) => marker
          None => break
        }
      } else {
        warnings.push({
          kind: UnsupportedInline,
          message: "unsupported inline node: " + frame.tag,
          source_key: Some(key),
        })
        UnsupportedInline({
          tag: frame.tag,
          reason: "unsupported paragraph inline node",
          source_key: key,
        })
      }
      runs.push({
        style_id: None,
        bold: false,
        inlines: [inline],
        source_key: key,
      })
    }
    // An empty run still consumes its source-key index.
    index += 1
  }
  runs
}
