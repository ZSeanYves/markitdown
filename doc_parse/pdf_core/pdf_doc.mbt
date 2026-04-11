///|
pub fn open_pdf(bytes : Bytes) -> PdfDocument raise {
  let version = parse_pdf_header(bytes)
  let startxref = find_startxref(bytes)
  let (xref, trailer) = parse_xref_and_trailer(bytes, startxref)
  { bytes, version, startxref, trailer, xref }
}

///|
pub fn pdf_version(doc : PdfDocument) -> String {
  doc.version
}

///|
pub fn get_indirect_object(
  doc : PdfDocument,
  obj_num : Int,
  gen : Int,
) -> PdfIndirectObject raise {
  let key = make_obj_key(obj_num, gen)
  let entry = match doc.xref.entries.get(key) {
    Some(e) => e
    None => raise ObjectNotFound(obj_num, gen)
  }

  if !entry.in_use {
    raise ObjectNotFound(obj_num, gen)
  }
  if entry.entry_type == 2 {
    return resolve_object_stream_entry(doc, obj_num, gen, entry)
  }
  let obj = parse_indirect_object_at(doc.bytes, entry.offset)
  normalize_stream_length_by_dict(doc, obj)
}

///|
fn resolve_object_stream_entry(
  doc : PdfDocument,
  obj_num : Int,
  gen : Int,
  entry : PdfXrefEntry,
) -> PdfIndirectObject raise {
  let objstm_obj_num = match entry.objstm_obj {
    Some(v) => v
    None => raise InvalidStructure("xref type-2 entry is missing ObjStm object")
  }
  let objstm = get_indirect_object(doc, objstm_obj_num, 0)
  let value = resolve_objstm_embedded_value(objstm, obj_num, entry.objstm_index)
  { obj_num, gen, value, stream: None }
}

///|
pub fn get_catalog_ref(doc : PdfDocument) -> (Int, Int) raise PdfParseError {
  match doc.trailer.get("Root") {
    Some(PdfValue::Ref(obj, gen)) => (obj, gen)
    Some(_) => raise TypeMismatch("trailer /Root must be an indirect reference")
    None => raise InvalidStructure("trailer /Root is missing")
  }
}

///|
pub fn get_page_tree_root_ref(doc : PdfDocument) -> (Int, Int) raise {
  let (catalog_obj, catalog_gen) = get_catalog_ref(doc)
  let catalog = get_indirect_object(doc, catalog_obj, catalog_gen)
  let dict = as_dict(catalog.value, "catalog")
  match dict.get("Pages") {
    Some(PdfValue::Ref(obj, gen)) => (obj, gen)
    Some(_) =>
      raise TypeMismatch("catalog /Pages must be an indirect reference")
    None => raise InvalidStructure("catalog /Pages is missing")
  }
}

///|
pub fn count_pages(doc : PdfDocument) -> Int raise {
  let (pages_obj, pages_gen) = get_page_tree_root_ref(doc)
  let pages = get_indirect_object(doc, pages_obj, pages_gen)
  let dict = as_dict(pages.value, "page tree root")
  match dict.get("Count") {
    Some(PdfValue::Int(c)) => c
    _ => raise TypeMismatch("page tree root /Count must be Int")
  }
}

///|
pub fn list_page_refs(doc : PdfDocument) -> Array[(Int, Int)] raise {
  let (root_obj, root_gen) = get_page_tree_root_ref(doc)
  collect_page_refs(doc, root_obj, root_gen)
}

///|
pub fn get_page_content_stream_bytes(
  doc : PdfDocument,
  page_obj : Int,
  page_gen : Int,
) -> Array[Bytes] raise {
  let page = get_indirect_object(doc, page_obj, page_gen)
  let dict = as_dict(page.value, "page")

  match dict.get("Contents") {
    Some(PdfValue::Ref(obj, gen)) => [read_stream_required(doc, obj, gen)]
    Some(PdfValue::Array(items)) => {
      let out : Array[Bytes] = []
      for v in items {
        match v {
          PdfValue::Ref(obj, gen) =>
            out.push(read_stream_required(doc, obj, gen))
          _ =>
            raise TypeMismatch(
              "/Contents array items must be indirect references",
            )
        }
      }
      out
    }
    Some(_) => raise TypeMismatch("page /Contents must be reference or array")
    None => []
  }
}

///|
fn collect_page_refs(
  doc : PdfDocument,
  node_obj : Int,
  node_gen : Int,
) -> Array[(Int, Int)] raise {
  let node = get_indirect_object(doc, node_obj, node_gen)
  let dict = as_dict(node.value, "page tree node")

  match dict.get("Type") {
    Some(PdfValue::Name(kind)) if kind == "Page" => [(node_obj, node_gen)]
    _ => {
      let kids = match dict.get("Kids") {
        Some(PdfValue::Array(arr)) => arr
        _ => raise TypeMismatch("/Kids must be array in page tree node")
      }
      let out : Array[(Int, Int)] = []
      for kid in kids {
        match kid {
          PdfValue::Ref(obj, gen) =>
            for r in collect_page_refs(doc, obj, gen) {
              out.push(r)
            }
          _ => raise TypeMismatch("/Kids item must be indirect reference")
        }
      }
      out
    }
  }
}

///|
fn read_stream_required(doc : PdfDocument, obj : Int, gen : Int) -> Bytes raise {
  let o = get_indirect_object(doc, obj, gen)
  match o.stream {
    Some(b) => maybe_decode_stream_by_filter(o.value, b)
    None =>
      raise TypeMismatch(
        "object is not a stream: " + obj.to_string() + " " + gen.to_string(),
      )
  }
}

///|
fn maybe_decode_stream_by_filter(
  dict_value : PdfValue,
  stream : Bytes,
) -> Bytes raise {
  let dict = match dict_value {
    PdfValue::Dict(d) => d
    _ => return stream
  }
  match dict.get("Filter") {
    Some(PdfValue::Name("FlateDecode")) => decode_pdf_flate_stream(stream)
    Some(PdfValue::Name("Fl")) => decode_pdf_flate_stream(stream)
    Some(PdfValue::Array(filters)) => {
      let mut out = stream
      for f in filters {
        match f {
          PdfValue::Name("FlateDecode") => out = decode_pdf_flate_stream(out)
          PdfValue::Name("Fl") => out = decode_pdf_flate_stream(out)
          _ => return stream
        }
      }
      out
    }
    _ => stream
  }
}

///|
fn decode_pdf_flate_stream(stream : Bytes) -> Bytes raise {
  let mut last_err = ""

  // PDF FlateDecode is usually zlib-wrapped deflate (CMF/FLG + Adler32).
  if stream.length() >= 6 {
    let wrapped_body = stream[2:stream.length() - 4].to_bytes()
    let raw_try = @zip.decompress(
      @zip.CompressionMethod::DeflateRaw,
      wrapped_body,
    ) catch {
      e => {
        last_err = e.to_string()
        Bytes::from_array([])
      }
    }
    if raw_try.length() > 0 || wrapped_body.length() == 0 {
      return raw_try
    }
  }

  // Fallback: some producers may already provide raw-deflate-like payload.
  let raw = @zip.decompress(@zip.CompressionMethod::DeflateRaw, stream) catch {
    e => {
      last_err = e.to_string()
      raise InvalidStructure(
        "failed to FlateDecode stream with zip backend: " + last_err,
      )
    }
  }
  raw
}

///|
fn normalize_stream_length_by_dict(
  doc : PdfDocument,
  obj : PdfIndirectObject,
) -> PdfIndirectObject raise {
  let stream = match obj.stream {
    Some(bs) => bs
    None => return obj
  }

  let expected_len = match obj.value {
    PdfValue::Dict(dict) =>
      match dict.get("Length") {
        Some(PdfValue::Int(v)) => Some(v)
        Some(PdfValue::Ref(lobj, lgen)) => resolve_length_ref(doc, lobj, lgen)
        _ => None
      }
    _ => None
  }

  match expected_len {
    Some(v) =>
      if v >= 0 && v <= stream.length() {
        { ..obj, stream: Some(stream[:v].to_bytes()) }
      } else {
        obj
      }
    None => obj
  }
}

///|
fn resolve_length_ref(
  doc : PdfDocument,
  obj_num : Int,
  gen : Int,
) -> Int? raise {
  let o = get_indirect_object(doc, obj_num, gen)
  match o.value {
    PdfValue::Int(v) => Some(v)
    _ => None
  }
}
