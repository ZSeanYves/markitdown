///|
priv enum PtreeObjnumbers {
  OLf(ArrayView[Int], Int, Int)
  OBr(ArrayView[Int], PtreeObjnumbers, PtreeObjnumbers, Int, Int)
}

///|
fn pagetree_with_objnumbers(
  toplevel : Bool,
  old_pagetree_root_num : Int,
  objnumsource : () -> Int,
  objnumbers : ArrayView[Int],
  parent : Int,
) -> PtreeObjnumbers raise {
  if objnumbers.length() < 10 {
    let this_num = if toplevel { old_pagetree_root_num } else { objnumsource() }
    PtreeObjnumbers::OLf(objnumbers, parent, this_num)
  } else {
    let (left, this, right) = split3(5, objnumbers)
    let this_num = if toplevel { old_pagetree_root_num } else { objnumsource() }
    let left_tree = pagetree_with_objnumbers(
      false, old_pagetree_root_num, objnumsource, left, this_num,
    )
    let right_tree = pagetree_with_objnumbers(
      false, old_pagetree_root_num, objnumsource, right, this_num,
    )
    PtreeObjnumbers::OBr(this, left_tree, right_tree, parent, this_num)
  }
}

///|
fn buildnode(kids : ArrayView[Int], parent : Int, count : Int) -> PdfObject {
  let kid_refs = Array::new()
  for kid in kids {
    kid_refs.push(PdfObject::Indirect(kid))
  }
  let entries : Array[(String, PdfObject)] = [
    ("/Type", PdfObject::Name(@pdf.PdfName::of_string("/Pages"))),
    ("/Kids", PdfObject::Array(kid_refs)),
    ("/Count", PdfObject::Integer(count)),
  ]
  if parent != 0 {
    entries.push(("/Parent", PdfObject::Indirect(parent)))
  }
  PdfObject::Dictionary(entries)
}

///|
fn objnumfrom(node : PtreeObjnumbers) -> Int {
  match node {
    PtreeObjnumbers::OLf(_, _, o) => o
    PtreeObjnumbers::OBr(_, _, _, _, o) => o
  }
}

///|
fn countof(node : PtreeObjnumbers) -> Int {
  match node {
    PtreeObjnumbers::OLf(objnumbers, _, _) => objnumbers.length()
    PtreeObjnumbers::OBr(objnumbers, left, right, _, _) =>
      objnumbers.length() + countof(left) + countof(right)
  }
}

///|
fn objects_of_ptree_objnumbers(pdf : @pdf.Pdf, node : PtreeObjnumbers) -> Unit {
  match node {
    PtreeObjnumbers::OLf(objnumbers, parent, objnum_leaf) =>
      pdf.addobj_given_num(
        (objnum_leaf, buildnode(objnumbers, parent, countof(node))),
      )
    PtreeObjnumbers::OBr(objnumbers, left, right, parent, objnum_branch) => {
      let kids = Array::new()
      kids.push(objnumfrom(left))
      kids.append(objnumbers[:])
      kids.push(objnumfrom(right))
      pdf.addobj_given_num(
        (objnum_branch, buildnode(kids, parent, countof(node))),
      )
      objects_of_ptree_objnumbers(pdf, left)
      objects_of_ptree_objnumbers(pdf, right)
    }
  }
}

///|
fn pdf_of_pages_build_pagetree(
  tree : PtreeObjnumbers,
  objnumbers : Array[Int],
  pdf : @pdf.Pdf,
) -> PdfObject {
  match tree {
    PtreeObjnumbers::OLf(_, parent, _) =>
      buildnode(objnumbers, parent, countof(tree))
    PtreeObjnumbers::OBr(_, left, right, parent, _) => {
      objects_of_ptree_objnumbers(pdf, left)
      objects_of_ptree_objnumbers(pdf, right)
      let kids = Array::new()
      kids.push(objnumfrom(left))
      kids.append(objnumbers[:])
      kids.push(objnumfrom(right))
      buildnode(kids, parent, countof(tree))
    }
  }
}

///|
fn select_page_ref(refs : Array[Int], index_1 : Int) -> Int raise {
  if index_1 < 1 {
    raise @pdf.PdfError::Msg("pdf_of_pages")
  }
  match refs.get(index_1 - 1) {
    Some(value) => value
    None => raise @pdf.PdfError::Msg("pdf_of_pages")
  }
}

///|
fn range_to_set(range : Array[Int]) -> Map[Int, Unit] {
  let out = Map::new(capacity=range.length())
  for page in range {
    out.set(page, ())
  }
  out
}

///|
fn build_fastrefnums(refnums : Array[Int]) -> Map[Int, Int] {
  let out = Map::new(capacity=refnums.length())
  for i in 0..<refnums.length() {
    out.set(refnums[i], i + 1)
  }
  out
}

///|
/// Build a PDF containing a subset of pages.
pub fn PdfPageDoc::pdf_of_pages(
  self : PdfPageDoc,
  range : Array[Int],
  retain_numbering? : Bool = false,
  process_struct_tree? : Bool = false,
) -> @pdf.Pdf raise {
  let basepdf = self.pdf
  match range {
    [] =>
      raise @pdf.PdfError::Msg("pdf_of_pages: cannot build PDF with no pages")
    _ => ()
  }
  let page_labels = if @pdfpagelabels.PageLabel::read_all(basepdf).length() == 0 {
    []
  } else if retain_numbering {
    @pdfpagelabels.PdfPageLabels::new().merge_pagelabels([basepdf], [range])
  } else {
    []
  }
  let marks = {
    let refnums = basepdf.page_reference_numbers()
    let fastrefnums = build_fastrefnums(refnums)
    let range_set = range_to_set(range)
    let mut first_index = -1
    let mut first_level = -1
    let mut index = -1
    let marks = @pdfmarks.PdfMarks::new(basepdf).read_bookmarks(
      preserve_actions=true,
    )
    let kept : Array[@pdfmarks.Bookmark] = Array::new(capacity=marks.length())
    for mark in marks {
      index = index + 1
      let page_num = PdfPageDoc::new(basepdf).pagenumber_of_target(
        mark.target,
        fastrefnums~,
      )
      if range_set.get(page_num) is Some(_) {
        if first_index == -1 {
          first_index = index
          first_level = mark.level
        }
        kept.push(mark)
      }
    }
    let prefix_rev : Array[@pdfmarks.Bookmark] = Array::new()
    if first_index != -1 {
      let mut level = first_level - 1
      for n in first_index>=..0 {
        if level > -1 && marks[n].level == level {
          prefix_rev.push(marks[n])
          level = level - 1
        }
      }
      prefix_rev.rev_in_place()
    }
    prefix_rev + kept
  }
  let pdf = @pdf.Pdf::empty()
  basepdf.objiter((k, v) => pdf.addobj_given_num((k, v)))
  let page_numbers = basepdf.page_reference_numbers()
  let pdf : @pdf.Pdf = {
    major: basepdf.major,
    minor: basepdf.minor,
    root: basepdf.root,
    objects: pdf.objects,
    trailerdict: basepdf.trailerdict,
    was_linearized: basepdf.was_linearized,
    saved_encryption: basepdf.saved_encryption,
  }
  if process_struct_tree {
    @pdfst.PdfStructTree::new(pdf).trim_structure_tree(range)
  }
  let existing_root_entries = match basepdf.lookup_obj(basepdf.root) {
    Dictionary(d) => d
    _ => []
  }
  let objnumbers : Array[Int] = Array::new(capacity=range.length())
  for page in range {
    objnumbers.push(select_page_ref(page_numbers, page))
  }
  let old_pagetree_root_num = match
    basepdf.lookup_direct("/Root", pdf.trailerdict) {
    Some(root) =>
      match basepdf.indirect_number("/Pages", root) {
        Some(i) => i
        None => raise @pdf.PdfError::Msg("pdf_of_pages")
      }
    None => raise @pdf.PdfError::Msg("pdf_of_pages")
  }
  PdfPageDoc::new(pdf).replace_inherit(objnumbers)
  let thetree = pagetree_with_objnumbers(
    true,
    old_pagetree_root_num,
    source(pdf.objects.max_obj_num),
    objnumbers,
    0,
  )
  let objnumbers_set = range_to_set(objnumbers)
  pdf.objiter((i, o) => match o {
    Dictionary(_) =>
      match pdf.lookup_direct("/Type", o) {
        Some(Name(name)) if name.equal_string_bytes("/Pages") =>
          pdf.removeobj(i)
        Some(Name(name)) if name.equal_string_bytes("/Page") =>
          if objnumbers_set.get(i) is None {
            pdf.removeobj(i)
          }
        _ => ()
      }
    _ => ()
  })
  let new_pagetree = pdf_of_pages_build_pagetree(thetree, objnumbers, pdf)
  pdf.addobj_given_num((old_pagetree_root_num, new_pagetree))
  let pdf = PdfPageDoc::new(pdf).add_root(
    old_pagetree_root_num, existing_root_entries,
  )
  @pdfpagelabels.PageLabel::write_all(page_labels, pdf)
  let pdf = @pdfmarks.PdfMarks::new(pdf).add_bookmarks(marks)
  PdfPageDoc::new(pdf).fixup_duplicate_pages()
  PdfPageDoc::new(pdf).fixup_parents()
  PdfPageDoc::new(pdf).fixup_destinations()
  try PdfPageDoc::new(pdf).fixup_duplicate_annots() catch {
    _ => @pdfe.log("warning: fixup_duplicate_annots\n")
  } noraise {
    _ => ()
  }
  pdf
}
