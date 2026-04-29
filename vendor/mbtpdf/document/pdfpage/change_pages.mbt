///|
fn position_1(value : Int, values : Array[Int]) -> Int? {
  match values[:].search(value) {
    Some(i) => Some(i + 1)
    None => None
  }
}

///|
fn matrix_is_identity(m : @pdftransform.TransformMatrix) -> Bool {
  m.a == 1.0 &&
  m.b == 0.0 &&
  m.c == 0.0 &&
  m.d == 1.0 &&
  m.e == 0.0 &&
  m.f == 0.0
}

///|
pub fn PdfPageDoc::pagenumber_of_target(
  self : PdfPageDoc,
  target : @pdfdest.Destination,
  fastrefnums? : Map[Int, Int],
) -> Int raise {
  let pdf = self.pdf
  match target {
    NullDestination | NamedDestination(_) | StringDestination(_) => 0
    Action(a) =>
      match pdf.lookup_direct("/S", a) {
        Some(@pdf.PdfObject::Name(name)) if name.equal_string_bytes("/GoTo") =>
          match pdf.lookup_direct("/D", a) {
            Some(dest) =>
              match fastrefnums {
                Some(table) =>
                  self.pagenumber_of_target(
                    @pdfdest.Destination::read(pdf, dest),
                    fastrefnums=table,
                  )
                None =>
                  self.pagenumber_of_target(
                    @pdfdest.Destination::read(pdf, dest),
                  )
              }
            None => 0
          }
        _ => 0
      }
    XYZ(tp, _, _, _)
    | Fit(tp)
    | FitH(tp, _)
    | FitV(tp, _)
    | FitR(tp, _, _, _, _)
    | FitB(tp)
    | FitBH(tp, _)
    | FitBV(tp, _) =>
      match (tp : @pdfdest.TargetPage) {
        OtherDocPageNumber(i) => i + 1
        PageObject(i) =>
          match fastrefnums {
            Some(table) =>
              match table.get(i) {
                Some(n) => n
                None => 0
              }
            None =>
              match position_1(i, pdf.page_reference_numbers()) {
                Some(n) => n
                None => 0
              }
          }
      }
  }
}

///|
/// For page processing without matrices, return the identity matrix.
pub fn[A, B, C] ppstub(
  f : (A, B) -> C raise?,
  n : A,
  p : B,
) -> (C, A, @pdftransform.TransformMatrix) raise? {
  (f(n, p), n, @pdftransform.TransformMatrix::identity())
}

///|
fn change_pages_find_matrix(
  dest : @pdfdest.Destination,
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
) -> @pdftransform.TransformMatrix {
  match dest {
    XYZ(tp, _, _, _)
    | FitH(tp, _)
    | FitV(tp, _)
    | FitR(tp, _, _, _, _)
    | FitBH(tp, _)
    | FitBV(tp, _) =>
      match (tp : @pdfdest.TargetPage) {
        PageObject(i) =>
          match refnumstable.get(i) {
            Some(pagenumber) =>
              match mattable.get(pagenumber) {
                Some(tr) => tr
                None => @pdftransform.TransformMatrix::identity()
              }
            None => @pdftransform.TransformMatrix::identity()
          }
        _ => @pdftransform.TransformMatrix::identity()
      }
    _ => @pdftransform.TransformMatrix::identity()
  }
}

///|
fn change_pages_process_bookmarks(
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf raise {
  let bookmarks = @pdfmarks.PdfMarks::new(pdf).read_bookmarks(
    preserve_actions=true,
  )
  let updated = bookmarks.map(m => {
    let tr = change_pages_find_matrix(m.target, mattable, refnumstable)
    if matrix_is_identity(tr) {
      m
    } else {
      m.transform(pdf, tr)
    }
  })
  @pdfmarks.PdfMarks::new(pdf).add_bookmarks(updated)
}

///|
fn rewrite_dest(
  pdf : @pdf.Pdf,
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  dest : @pdf.PdfObject,
) -> Int? raise {
  let parsed_dest = @pdfdest.Destination::read(pdf, dest)
  let tr = change_pages_find_matrix(parsed_dest, mattable, refnumstable)
  if matrix_is_identity(tr) {
    None
  } else {
    let transformed = parsed_dest.transform(pdf, tr)
    let new_dest = transformed.to_pdf_object()
    Some(pdf.addobj(new_dest))
  }
}

///|
fn rewrite_action(
  pdf : @pdf.Pdf,
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  action : @pdf.PdfObject,
) -> @pdf.PdfObject? raise {
  match pdf.lookup_direct("/S", action) {
    Some(@pdf.PdfObject::Name(name)) if name.equal_string_bytes("/GoTo") =>
      match pdf.lookup_direct("/D", action) {
        Some(dest) =>
          match rewrite_dest(pdf, mattable, refnumstable, dest) {
            Some(objnum) =>
              Some(action.add_entry("/D", @pdf.PdfObject::Indirect(objnum)))
            None => None
          }
        None => None
      }
    _ => None
  }
}

///|
fn change_pages_process_annotations(
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  pdf : @pdf.Pdf,
) -> Unit raise {
  let pages = PdfPageDoc::new(pdf).pages_of_pagetree()
  let mut pnum = 0
  for page in pages {
    pnum = pnum + 1
    match pdf.lookup_direct("/Annots", page.rest) {
      Some(@pdf.PdfObject::Array(annots)) =>
        for annotobj in annots {
          match annotobj {
            @pdf.PdfObject::Indirect(i) => {
              let annot = pdf.lookup_obj(i)
              match pdf.lookup_direct("/Subtype", annot) {
                Some(@pdf.PdfObject::Name(name)) if name.equal_string_bytes(
                    "/Link",
                  ) =>
                  match pdf.lookup_direct("/Dest", annot) {
                    Some(dest) =>
                      match rewrite_dest(pdf, mattable, refnumstable, dest) {
                        Some(objnum) => {
                          let new_annot = annot.add_entry(
                            "/Dest",
                            @pdf.PdfObject::Indirect(objnum),
                          )
                          pdf.addobj_given_num((i, new_annot))
                        }
                        None => ()
                      }
                    None =>
                      match pdf.lookup_direct("/A", annot) {
                        Some(@pdf.PdfObject::Dictionary(_) as action) =>
                          match
                            rewrite_action(pdf, mattable, refnumstable, action) {
                            Some(updated_action) => {
                              let new_annot = annot.add_entry(
                                "/A", updated_action,
                              )
                              pdf.addobj_given_num((i, new_annot))
                            }
                            None => ()
                          }
                        _ => ()
                      }
                  }
                _ => ()
              }
            }
            _ =>
              @pdfe.log("change_pages_process_annotations: annotation direct\n")
          }
        }
      None => ()
      _ => @pdfe.log("change_pages_process_annotations: /Annots not an array\n")
    }
  }
}

///|
fn rewrite_openaction(pdf : @pdf.Pdf, action : @pdf.PdfObject) -> Unit raise {
  let catalog = pdf.catalog_of_pdf()
  let updated = catalog.add_entry("/OpenAction", action)
  pdf.addobj_given_num((pdf.root, updated))
}

///|
fn change_pages_process_openaction(
  mattable : Map[Int, @pdftransform.TransformMatrix],
  refnumstable : Map[Int, Int],
  pdf : @pdf.Pdf,
) -> Unit raise {
  match pdf.lookup_direct("/OpenAction", pdf.catalog_of_pdf()) {
    Some(@pdf.PdfObject::Array(dest)) =>
      match
        rewrite_dest(pdf, mattable, refnumstable, @pdf.PdfObject::Array(dest)) {
        Some(new_dest_objnum) =>
          rewrite_openaction(pdf, @pdf.PdfObject::Indirect(new_dest_objnum))
        None => ()
      }
    Some(@pdf.PdfObject::Dictionary(_) as action) =>
      match rewrite_action(pdf, mattable, refnumstable, action) {
        Some(updated_action) => rewrite_openaction(pdf, updated_action)
        None => ()
      }
    _ => ()
  }
}

///|
fn[K : Hash + Eq, V] map_of_pairs(pairs : Array[(K, V)]) -> Map[K, V] {
  let m = Map::new(capacity=pairs.length())
  for pair in pairs {
    m.set(pair.0, pair.1)
  }
  m
}

///|
fn copy_object_stream_ids(pdf : @pdf.Pdf, basepdf : @pdf.Pdf) -> Unit {
  pdf.objects.object_stream_ids.clear()
  for key, value in basepdf.objects.object_stream_ids {
    pdf.objects.object_stream_ids.set(key, value)
  }
}

///|
fn select_page_ref_change(refs : Array[Int], index_1 : Int) -> Int raise {
  if index_1 < 1 || index_1 > refs.length() {
    raise @pdf.PdfError::Msg("change_pages: bad serial number")
  }
  refs[index_1 - 1]
}

///|
/// Replace the page tree with new pages, optionally rewriting references.
pub fn PdfPageDoc::change_pages(
  self : PdfPageDoc,
  change_references : Bool,
  pages : Array[Page],
  matrices? : Array[(Int, @pdftransform.TransformMatrix)],
  changes? : Array[(Int, Int)],
) -> @pdf.Pdf raise {
  let basepdf = self.pdf
  let pdf = @pdf.Pdf::empty()
  basepdf.objiter((k, v) => pdf.addobj_given_num((k, v)))
  copy_object_stream_ids(pdf, basepdf)
  let (pdf, pagetree_num) = PdfPageDoc::new(pdf).add_pagetree(pages)
  let pdf : @pdf.Pdf = {
    major: basepdf.major,
    minor: basepdf.minor,
    root: pdf.root,
    objects: pdf.objects,
    trailerdict: basepdf.trailerdict,
    was_linearized: basepdf.was_linearized,
    saved_encryption: basepdf.saved_encryption,
  }
  let existing_root_entries = match basepdf.lookup_obj(basepdf.root) {
    @pdf.PdfObject::Dictionary(d) => d
    _ => []
  }
  let pdf = PdfPageDoc::new(pdf).add_root(pagetree_num, existing_root_entries)
  if !change_references {
    pdf
  } else {
    let old_page_numbers = basepdf.page_reference_numbers()
    let new_page_numbers = pdf.page_reference_numbers()
    let changes = match changes {
      None =>
        if old_page_numbers.length() == new_page_numbers.length() {
          Array::zip(old_page_numbers, new_page_numbers)
        } else {
          @pdfe.log("change_pages: No change supplied, and lengths differ\n")
          []
        }
      Some(cs) => {
        let out = Array::new(capacity=cs.length())
        for pair in cs {
          let (x, y) = pair
          let old_ref = select_page_ref_change(old_page_numbers, x)
          let new_ref = select_page_ref_change(new_page_numbers, y)
          out.push((old_ref, new_ref))
        }
        out
      }
    }
    let changes_map = map_of_pairs(changes)
    pdf.objselfmap(obj => pdf.renumber_object_parsed(changes_map, obj))
    match matrices {
      None => pdf
      Some(matpairs) => {
        let refnums = pdf.page_reference_numbers()
        let mattable = map_of_pairs(matpairs)
        let refnumstable = Map::new(capacity=refnums.length())
        for i in 0..<refnums.length() {
          refnumstable.set(refnums[i], i + 1)
        }
        let pdf = if old_page_numbers.length() == new_page_numbers.length() {
          change_pages_process_bookmarks(mattable, refnumstable, pdf)
        } else {
          @pdfe.log(
            "Pdfpage.change_pages: non-null matrices when lengths differ\n",
          )
          pdf
        }
        try
          change_pages_process_annotations(mattable, refnumstable, pdf)
        catch {
          _ => @pdfe.log("failure in change_pages_process_annotations\n")
        } noraise {
          _ => ()
        }
        try change_pages_process_openaction(mattable, refnumstable, pdf) catch {
          _ => @pdfe.log("failure in change_pages_process_openaction\n")
        } noraise {
          _ => ()
        }
        pdf
      }
    }
  }
}
