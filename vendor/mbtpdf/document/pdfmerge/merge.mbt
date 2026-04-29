///|
/// Merge PDF files.
pub fn PdfMerger::merge_pdfs(
  self : PdfMerger,
  retain_numbering : Bool,
  do_remove_duplicate_fonts : Bool,
  process_struct_trees? : Bool = true,
  add_toplevel_document? : Bool = false,
) -> @pdf.Pdf raise {
  let names = self.names
  let pdfs = self.pdfs
  let ranges = self.ranges
  if process_struct_trees && setify_strings(names).length() < names.length() {
    @pdfe.log(
      "Warning: multiply-included files will not merge structure trees properly.\n",
    )
  }
  if process_struct_trees {
    for pair in combine(pdfs, ranges) {
      @pdfst.PdfStructTree::new(pair.0).trim_structure_tree(pair.1)
    }
    @pdfst.PdfStructTrees::new(pdfs).renumber_parent_trees()
  }
  let pdfs = merge_pdfs_renumber(names, pdfs)
  merge_pdfs_rename_name_trees(names, pdfs)
  let (major, minor) = max_version_number(pdfs)
  let pagelists = pdfs.map(pdf => @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree())
  let pdf = @pdf.Pdf::empty()
  fn select_pages(
    range : Array[Int],
    pagelist : Array[@pdfpage.Page],
  ) -> Array[@pdfpage.Page] raise {
    let out = Array::new(capacity=range.length())
    for n in range {
      if n <= 0 {
        raise @pdf.PdfError::Msg("merge_pdfs: page out of range")
      }
      match pagelist.get(n - 1) {
        Some(page) => out.push(page)
        None => raise @pdf.PdfError::Msg("merge_pdfs: page out of range")
      }
    }
    out
  }

  let pages = Array::new()
  for pair in combine(ranges, pagelists) {
    let selected = select_pages(pair.0, pair.1)
    pages.append(selected[:])
  }
  for src in pdfs {
    src.objiter((k, v) => pdf.addobj_given_num((k, v)))
  }
  let (pdf, pagetree_num) = @pdfpage.PdfPageDoc::new(pdf).add_pagetree(pages)
  let page_labels = if retain_numbering {
    @pdfpagelabels.PdfPageLabels::new().merge_pagelabels(pdfs, ranges)
  } else {
    []
  }
  let dests = new_dests(pdf, pdfs)
  let namedict = merge_namedicts(pdf, pdfs)
  let mut extra_catalog_entries = catalog_items_from_original_documents(pdfs)
  extra_catalog_entries = add_entry(
    extra_catalog_entries,
    "/Names",
    PdfObject::Indirect(namedict),
  )
  match dests {
    None => ()
    Some(num) =>
      extra_catalog_entries = add_entry(
        extra_catalog_entries,
        "/Dests",
        PdfObject::Indirect(num),
      )
  }
  extra_catalog_entries = try {
    match merge_optional_content_groups(pdf, pdfs) {
      None => extra_catalog_entries
      Some(ocgnum) =>
        add_entry(
          extra_catalog_entries,
          "/OCProperties",
          PdfObject::Indirect(ocgnum),
        )
    }
  } catch {
    _ => {
      @pdfe.log("Warning: failed to merge OCGs\n")
      extra_catalog_entries
    }
  }
  extra_catalog_entries = try {
    match merge_acroforms(pdf, pdfs) {
      None => extra_catalog_entries
      Some(formnum) =>
        add_entry(
          extra_catalog_entries,
          "/AcroForm",
          PdfObject::Indirect(formnum),
        )
    }
  } catch {
    _ => {
      @pdfe.log("Warning: failed to merge Acroforms\n")
      extra_catalog_entries
    }
  }
  let extra_catalog_entries = if !process_struct_trees {
    extra_catalog_entries
  } else {
    try {
      match
        @pdfst.PdfStructTree::new(pdf).merge_structure_trees(
          pdfs,
          add_toplevel_document~,
        ) {
        None => extra_catalog_entries
        Some(structnum) =>
          add_entry(
            extra_catalog_entries,
            "/StructTreeRoot",
            PdfObject::Indirect(structnum),
          )
      }
    } catch {
      _ => {
        @pdfe.log("Warning: failed to merge structure tree roots\n")
        extra_catalog_entries
      }
    }
  }
  let extra_catalog_entries = remove_entry(extra_catalog_entries, "/OpenAction")
  match pdfs {
    [first, ..] =>
      match first.lookup_direct("/Info", first.trailerdict) {
        None => ()
        Some(info) =>
          pdf.trailerdict = PdfObject::Dictionary([
            ("/Info", PdfObject::Indirect(pdf.addobj(info))),
          ])
      }
    [] => ()
  }
  let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(
    pagetree_num, extra_catalog_entries,
  )
  let old_page_numbers = {
    let page_nums = pdfs.map(p => p.page_reference_numbers())
    let out = Array::new()
    for pair in combine(ranges, page_nums) {
      let numbers = pair.1
      for n in pair.0 {
        if n <= 0 {
          raise @pdf.PdfError::Msg("merge_pdfs: page out of range")
        }
        match numbers.get(n - 1) {
          Some(value) => out.push(value)
          None => raise @pdf.PdfError::Msg("merge_pdfs: page out of range")
        }
      }
    }
    out
  }
  let new_page_numbers = pdf.page_reference_numbers()
  let changes = combine(old_page_numbers, new_page_numbers)
  let changes_map : Map[Int, Int] = Map::new(capacity=changes.length())
  for pair in changes {
    changes_map.set(pair.0, pair.1)
  }
  pdf.objselfmap(obj => pdf.renumber_object_parsed(
    changes_map,
    obj,
    preserve_order=false,
  ))
  let pdf : @pdf.Pdf = {
    major,
    minor,
    root: pdf.root,
    objects: pdf.objects,
    trailerdict: pdf.trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
  let pdf = merge_bookmarks(changes, pdfs, ranges, pdf)
  @pdfpagelabels.PageLabel::write_all(page_labels, pdf)
  if do_remove_duplicate_fonts {
    PdfMergeDoc::new(pdf).remove_duplicate_fonts()
  }
  pdf.change_id("")
  pdf
}
