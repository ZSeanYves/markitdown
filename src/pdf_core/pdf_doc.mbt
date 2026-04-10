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
  parse_indirect_object_at(doc.bytes, entry.offset)
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
    Some(b) => b
    None =>
      raise TypeMismatch(
        "object is not a stream: " + obj.to_string() + " " + gen.to_string(),
      )
  }
}

///|
fn as_dict(
  v : PdfValue,
  ctx : String,
) -> Map[String, PdfValue] raise PdfParseError {
  match v {
    PdfValue::Dict(dict) => dict
    _ => raise TypeMismatch(ctx + " must be dictionary")
  }
}
