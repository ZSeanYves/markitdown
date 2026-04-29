///|
fn remove_dict_entries(
  entries : Array[(String, PdfObject)],
) -> Array[(String, PdfObject)] {
  entries.filter(entry => {
    let key = entry.0
    let keep = key != "/Resources" &&
      key != "/Contents" &&
      key != "/MediaBox" &&
      key != "/Rotate" &&
      key != "/Parent" &&
      key != "/Type"
    keep
  })
}

///|
let last_mediabox_seen : Ref[PdfObject] = {
  val: PdfObject::Array([
    PdfObject::Integer(0),
    PdfObject::Integer(0),
    PdfObject::Integer(612),
    PdfObject::Integer(792),
  ]),
}

///|
fn find_pages(
  pages : PdfObject,
  pdf : @pdf.Pdf,
  resources : PdfObject?,
  mediabox : PdfObject?,
  rotate : Rotation,
) -> Array[Page] raise {
  match pages {
    Null => []
    _ => {
      let typ = pdf.lookup_direct("/Type", pages)
      match typ {
        None => {
          let kids = match
            pdf.lookup_fail("No /Kids in page tree", "/Kids", pages) {
            Array(values) => values
            _ => raise @pdf.PdfError::Msg("Malformed /Kids in page tree node")
          }
          let resources = match pdf.lookup_direct("/Resources", pages) {
            Some(x) => Some(x)
            None => resources
          }
          let mediabox = match pdf.lookup_direct("/MediaBox", pages) {
            Some(x) => Some(x)
            None => mediabox
          }
          let rotate = match pdf.lookup_direct("/Rotate", pages) {
            Some(Integer(r)) => Rotation::from_int(r)
            _ => rotate
          }
          let out = Array::new()
          for kid in kids {
            let kid_obj = match kid {
              Indirect(k) => {
                let obj = pdf.lookup_obj(k)
                match obj {
                  Null => raise @pdf.PdfError::Msg("missing kid")
                  _ => obj
                }
              }
              Dictionary(d) => PdfObject::Dictionary(d)
              _ => raise @pdf.PdfError::Msg("malformed kid")
            }
            out.append(find_pages(kid_obj, pdf, resources, mediabox, rotate)[:])
          }
          out
        }
        Some(Name(name)) if name.equal_string_bytes("/Pages") => {
          let kids = match
            pdf.lookup_fail("No /Kids in page tree", "/Kids", pages) {
            Array(values) => values
            _ => raise @pdf.PdfError::Msg("Malformed /Kids in page tree node")
          }
          let resources = match pdf.lookup_direct("/Resources", pages) {
            Some(x) => Some(x)
            None => resources
          }
          let mediabox = match pdf.lookup_direct("/MediaBox", pages) {
            Some(x) => Some(x)
            None => mediabox
          }
          let rotate = match pdf.lookup_direct("/Rotate", pages) {
            Some(Integer(r)) => Rotation::from_int(r)
            _ => rotate
          }
          let out = Array::new()
          for kid in kids {
            let kid_obj = match kid {
              Indirect(k) => {
                let obj = pdf.lookup_obj(k)
                match obj {
                  Null => raise @pdf.PdfError::Msg("missing kid")
                  _ => obj
                }
              }
              Dictionary(d) => PdfObject::Dictionary(d)
              _ => raise @pdf.PdfError::Msg("malformed kid")
            }
            out.append(find_pages(kid_obj, pdf, resources, mediabox, rotate)[:])
          }
          out
        }
        _ => {
          let resources = match pdf.lookup_direct("/Resources", pages) {
            Some(x) => Some(x)
            None => resources
          }
          let mediabox = match pdf.lookup_direct("/MediaBox", pages) {
            Some(x) => Some(x)
            None => mediabox
          }
          let contents = match pages {
            Dictionary(_) =>
              match pages.lookup_immediate("/Contents") {
                Some(Indirect(i)) =>
                  match pdf.lookup_obj(i) {
                    Array(a) => Some(PdfObject::Array(a))
                    _ => Some(PdfObject::Array([PdfObject::Indirect(i)]))
                  }
                _ => pdf.lookup_direct("/Contents", pages)
              }
            _ => raise @pdf.PdfError::Msg("Pages not a dictionary")
          }
          let rotate = match pdf.lookup_direct("/Rotate", pages) {
            Some(Integer(r)) => Rotation::from_int(r)
            _ => rotate
          }
          let content = match contents {
            None => []
            Some(Array(cs)) =>
              cs.filter_map(c => match pdf.direct(c) {
                Stream(_) => Some(c)
                _ => {
                  @pdfe.log("Page /Contents not a stream: ignoring.\n")
                  None
                }
              })
            Some(obj) =>
              match pdf.direct(obj) {
                Stream(_) => [obj]
                _ => {
                  @pdfe.log("Page /Contents not a stream: ignoring.\n")
                  []
                }
              }
          }
          let mediabox = match mediabox {
            Some(m) => {
              last_mediabox_seen.val = m
              m
            }
            None => {
              @pdfe.log(
                "Warning: missing mediabox. Using most recently seen.\n",
              )
              last_mediabox_seen.val
            }
          }
          let resources = match resources {
            Some(r) => r
            None => PdfObject::Dictionary([])
          }
          let rest = match pages {
            Dictionary(d) => PdfObject::Dictionary(remove_dict_entries(d))
            _ => raise @pdf.PdfError::Msg("Bad /Pages")
          }
          [{ resources, content, mediabox, rotate, rest }]
        }
      }
    }
  }
}

///|
/// Given a pdf, return a list of page objects.
pub fn PdfPageDoc::pages_of_pagetree(self : PdfPageDoc) -> Array[Page] raise {
  let pdf = self.pdf
  let document_catalog = pdf.lookup_obj(pdf.root)
  match document_catalog {
    Null => raise @pdf.PdfError::Msg("/Root entry is incorrect")
    _ => {
      let pages = pdf.lookup_fail(
        "No or malformed /Pages", "/Pages", document_catalog,
      )
      find_pages(pages, pdf, None, None, Rotate0)
    }
  }
}

///|
fn find_pages_quick(
  count : Int,
  pages : PdfObject,
  pdf : @pdf.Pdf,
  stack : Map[Int, Bool],
) -> Int raise {
  if count == 10000 {
    raise @pdf.PdfError::Msg("cycle in page tree")
  }
  let mut resolved = pages
  let mut objnum : Int? = None
  match pages {
    Indirect(k) => {
      if stack.contains(k) {
        raise @pdf.PdfError::Msg("cycle in page tree")
      }
      stack.set(k, true)
      objnum = Some(k)
      let resolved_obj = pdf.lookup_obj(k)
      match resolved_obj {
        Null => raise @pdf.PdfError::Msg("missing kid")
        _ => resolved = resolved_obj
      }
    }
    _ => ()
  }
  let total = match resolved {
    Null => 0
    _ => {
      let typ = pdf.lookup_direct("/Type", resolved)
      match typ {
        None => {
          let kids = match
            pdf.lookup_fail("No /Kids in page tree", "/Kids", resolved) {
            Array(values) => values
            _ => raise @pdf.PdfError::Msg("Malformed /Kids in page tree node")
          }
          let mut total = 0
          for kid in kids {
            match kid {
              Indirect(_) | Dictionary(_) =>
                total = total + find_pages_quick(count + 1, kid, pdf, stack)
              _ => raise @pdf.PdfError::Msg("malformed kid")
            }
          }
          total
        }
        Some(Name(name)) if name.equal_string_bytes("/Pages") => {
          let kids = match
            pdf.lookup_fail("No /Kids in page tree", "/Kids", resolved) {
            Array(values) => values
            _ => raise @pdf.PdfError::Msg("Malformed /Kids in page tree node")
          }
          let mut total = 0
          for kid in kids {
            match kid {
              Indirect(_) | Dictionary(_) =>
                total = total + find_pages_quick(count + 1, kid, pdf, stack)
              _ => raise @pdf.PdfError::Msg("malformed kid")
            }
          }
          total
        }
        _ => 1
      }
    }
  }
  match objnum {
    Some(k) => stack.remove(k)
    None => ()
  }
  total
}

///|
/// Count pages in the page tree quickly.
pub fn PdfPageDoc::pages_of_pagetree_quick(self : PdfPageDoc) -> Int raise {
  let pdf = self.pdf
  let document_catalog = pdf.lookup_obj(pdf.root)
  match document_catalog {
    Null => raise @pdf.PdfError::Msg("/Root entry is incorrect")
    _ => {
      let pages = pdf.lookup_fail(
        "No or malformed /Pages", "/Pages", document_catalog,
      )
      let stack : Map[Int, Bool] = Map::new()
      find_pages_quick(0, pages, pdf, stack)
    }
  }
}

///|
/// The last page number.
pub fn PdfPageDoc::endpage(self : PdfPageDoc) -> Int raise {
  self.pages_of_pagetree_quick()
}

///|
/// Fast page count from the top /Count.
pub fn PdfPageDoc::endpage_fast(self : PdfPageDoc) -> Int raise {
  let pdf = self.pdf
  let document_catalog = pdf.lookup_obj(pdf.root)
  match document_catalog {
    Null => raise @pdf.PdfError::Msg("/Root entry is incorrect")
    _ => {
      let pages = pdf.lookup_fail(
        "No or malformed /Pages", "/Pages", document_catalog,
      )
      match pdf.lookup_direct("/Count", pages) {
        Some(Integer(i)) => i
        _ => 0
      }
    }
  }
}

// Note: no global cross-package hooks; call PdfPageDoc::endpage* directly.
