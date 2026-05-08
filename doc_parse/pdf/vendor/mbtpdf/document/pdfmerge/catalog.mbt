///|
fn catalog_items_from_original_documents(
  pdfs : Array[@pdf.Pdf],
) -> Array[(String, PdfObject)] raise {
  let out : Array[(String, PdfObject)] = Array::new()
  for pdf in pdfs {
    match pdf.catalog_of_pdf() {
      PdfObject::Dictionary(entries) =>
        for entry in entries {
          match out.search_by(existing => existing.0 == entry.0) {
            Some(i) => out[i] = entry
            None => out.push(entry)
          }
        }
      _ => raise @pdf.PdfError::Msg("catalog_items_from_original_documents")
    }
  }
  out
}

///|
fn merge_entries(
  pdf : @pdf.Pdf,
  name : String,
  dicts : Array[PdfObject],
) -> Array[PdfObject] {
  let out = Array::new()
  for dict in dicts {
    match pdf.lookup_direct(name, dict) {
      Some(PdfObject::Array(arr)) => out.append(arr[:])
      _ => ()
    }
  }
  out
}

///|
fn merge_default_dictionaries(
  pdf : @pdf.Pdf,
  dicts : Array[PdfObject],
) -> Array[(String, PdfObject)] {
  fn merge_empty_is_none(name : String) -> Array[(String, PdfObject)] {
    let arrays = Array::new(capacity=dicts.length())
    for dict in dicts {
      match pdf.lookup_direct(name, dict) {
        Some(PdfObject::Array(arr)) => arrays.push(arr)
        _ => ()
      }
    }
    if arrays.length() == 0 {
      []
    } else {
      [(name, PdfObject::Array(flatten(arrays)))]
    }
  }

  let merged_on = merge_empty_is_none("/ON")
  let merged_off = merge_empty_is_none("/OFF")
  let merged_order = merge_empty_is_none("/Order")
  let merged_rbgroups = merge_empty_is_none("/RBGroups")
  let keys : Array[String] = [
    "/Locked", "/ListMode", "/AS", "/Intent", "/BaseState", "/Creator", "/Name",
  ]
  let simple_copies = Array::new(capacity=keys.length())
  for key in keys {
    let mut found = None
    for dict in dicts {
      match pdf.lookup_direct(key, dict) {
        Some(obj) => {
          found = Some(obj)
          break
        }
        None => ()
      }
    }
    match found {
      Some(obj) => simple_copies.push((key, obj))
      None => ()
    }
  }
  let out = Array::new()
  out.append(merged_on[:])
  out.append(merged_off[:])
  out.append(merged_order[:])
  out.append(merged_rbgroups[:])
  out.append(simple_copies[:])
  out
}

///|
fn merge_optional_content_groups(
  pdf : @pdf.Pdf,
  pdfs : Array[@pdf.Pdf],
) -> Int? raise {
  let ocp_dicts = Array::new(capacity=pdfs.length())
  for src in pdfs {
    match src.lookup_direct("/OCProperties", src.catalog_of_pdf()) {
      Some(obj) => ocp_dicts.push(obj)
      None => ()
    }
  }
  if ocp_dicts.length() == 0 {
    return None
  }
  let merged_ocg_arrays = merge_entries(pdf, "/OCGs", ocp_dicts)
  let merged_config_arrays = merge_entries(pdf, "/Configs", ocp_dicts)
  let default_dicts = Array::new(capacity=ocp_dicts.length())
  for dict in ocp_dicts {
    match pdf.lookup_direct("/D", dict) {
      Some(obj) => default_dicts.push(obj)
      None => ()
    }
  }
  let merged_default_dictionary = merge_default_dictionaries(pdf, default_dicts)
  let entries = Array::new(capacity=3)
  entries.push(("/OCGs", PdfObject::Array(merged_ocg_arrays)))
  entries.push(("/D", PdfObject::Dictionary(merged_default_dictionary)))
  if merged_config_arrays.length() > 0 {
    entries.push(("/Configs", PdfObject::Array(merged_config_arrays)))
  }
  let new_ocproperties = PdfObject::Dictionary(entries)
  Some(pdf.addobj(new_ocproperties))
}

///|
fn merge_acroforms(pdf : @pdf.Pdf, pdfs : Array[@pdf.Pdf]) -> Int? raise {
  let form_dicts = Array::new()
  for src in pdfs {
    match src.lookup_direct("/AcroForm", src.catalog_of_pdf()) {
      Some(obj) => form_dicts.push(obj)
      None => ()
    }
  }
  if form_dicts.length() == 0 {
    return None
  }
  let merged_field_arrays = Array::new()
  for dict in form_dicts {
    match pdf.lookup_direct("/Fields", dict) {
      Some(PdfObject::Array(arr)) => merged_field_arrays.append(arr[:])
      _ => ()
    }
  }
  let mut merged_nonfield_items = PdfObject::Dictionary([])
  for dict in form_dicts {
    match dict {
      PdfObject::Dictionary(entries) =>
        for entry in entries {
          merged_nonfield_items = merged_nonfield_items.add_entry(
            entry.0,
            entry.1,
          )
        }
      _ => ()
    }
  }
  let new_dict = merged_nonfield_items.add_entry(
    "/Fields",
    PdfObject::Array(merged_field_arrays),
  )
  Some(pdf.addobj(new_dict))
}

///|
fn max_version_number(pdfs : Array[@pdf.Pdf]) -> (Int, Int) raise {
  match pdfs {
    [] => raise @pdf.PdfError::Msg("max_version_number: empty")
    [first, .. rest] => {
      let mut major = first.major
      let mut minor = first.minor
      for pdf in rest {
        if pdf.major > major || (pdf.major == major && pdf.minor > minor) {
          major = pdf.major
          minor = pdf.minor
        }
      }
      (major, minor)
    }
  }
}
