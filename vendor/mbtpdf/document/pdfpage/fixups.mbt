///|
fn find_first_duplicate(values : Array[Int]) -> Int? {
  match values {
    [] | [_] => None
    [prev, .. rest] => {
      let mut last = prev
      for current in rest {
        if current == last {
          return Some(current)
        }
        last = current
      }
      None
    }
  }
}

///|
fn rewrite_first_kid(
  old_num : Int,
  new_num : Int,
  kids : Array[PdfObject],
) -> Array[PdfObject] {
  let out = Array::new(capacity=kids.length())
  let mut rewritten = false
  for kid in kids {
    match kid {
      Indirect(i) if i == old_num && !rewritten => {
        out.push(PdfObject::Indirect(new_num))
        rewritten = true
      }
      _ => out.push(kid)
    }
  }
  out
}

///|
fn rewrite_first_indirect(
  pdf : @pdf.Pdf,
  objnum : Int,
  obj : PdfObject,
  old_num : Int,
  new_num : Int,
) -> Bool raise {
  match pdf.lookup_direct("/Kids", obj) {
    Some(Array(kids)) => {
      let mut found = false
      for kid in kids {
        match kid {
          Indirect(i) if i == old_num => found = true
          _ => ()
        }
      }
      if found {
        let updated_kids = rewrite_first_kid(old_num, new_num, kids)
        let updated = obj.add_entry("/Kids", PdfObject::Array(updated_kids))
        pdf.addobj_given_num((objnum, updated))
        true
      } else {
        false
      }
    }
    _ => false
  }
}

///|
fn page_tree_nodes_not_pages_inner(
  pdf : @pdf.Pdf,
  pages_node : PdfObject,
  node_number : Int,
) -> Array[Int] {
  if pdf.lookup_direct("/Type", pages_node) is Some(Name(name)) &&
    name.equal_string_bytes("/Page") {
    []
  } else {
    match pdf.lookup_direct("/Kids", pages_node) {
      Some(Array(elts)) => {
        let out = Array::new()
        out.push(node_number)
        for elt in elts {
          match elt {
            Indirect(i) =>
              out.append(
                page_tree_nodes_not_pages_inner(pdf, pdf.direct(elt), i)[:],
              )
            _ => ()
          }
        }
        out
      }
      _ => []
    }
  }
}

///|
fn page_tree_nodes_not_pages(pdf : @pdf.Pdf) -> Array[Int] raise {
  let root = pdf.lookup_obj(pdf.root)
  let page_root_num = match root {
    Dictionary(d) =>
      match d.search_by(pair => pair.0 == "/Pages") {
        Some(index) =>
          match d[index].1 {
            Indirect(i) => i
            _ => raise @pdf.PdfError::Msg("No /Pages found in /Root")
          }
        None => raise @pdf.PdfError::Msg("No /Pages found in /Root")
      }
    _ => raise @pdf.PdfError::Msg("No /Pages found in /Root")
  }
  let pages_node = match pdf.lookup_direct("/Pages", root) {
    Some(p) => p
    None => raise @pdf.PdfError::Msg("No /Pages found in /Root")
  }
  page_tree_nodes_not_pages_inner(pdf, pages_node, page_root_num)
}

///|
fn rewrite_page_tree_first(
  nodes : Array[Int],
  pdf : @pdf.Pdf,
  old_num : Int,
) -> Unit raise {
  let new_num = pdf.addobj(pdf.lookup_obj(old_num))
  let mut rewritten = false
  for node in nodes {
    if !rewritten {
      rewritten = rewrite_first_indirect(
        pdf,
        node,
        pdf.lookup_obj(node),
        old_num,
        new_num,
      )
    }
  }
  if !rewritten {
    raise @pdf.PdfError::Msg("rewrite_page_tree_first: malformed page tree")
  }
}

///|
fn page_reference_numbers_unordered_inner(
  pdf : @pdf.Pdf,
  pages_node : PdfObject,
  node_number : Int,
  acc : Ref[Array[Int]],
) -> Unit {
  if pdf.lookup_direct("/Type", pages_node) is Some(Name(name)) &&
    name.equal_string_bytes("/Page") {
    acc.val.push(node_number)
  } else {
    match pdf.lookup_direct("/Kids", pages_node) {
      Some(Array(elts)) =>
        for elt in elts {
          match elt {
            Indirect(i) =>
              page_reference_numbers_unordered_inner(
                pdf,
                pdf.direct(elt),
                i,
                acc,
              )
            _ => ()
          }
        }
      _ => acc.val.push(node_number)
    }
  }
}

///|
fn page_reference_numbers_unordered(pdf : @pdf.Pdf) -> Array[Int] raise {
  let acc : Ref[Array[Int]] = { val: [] }
  let root = pdf.lookup_obj(pdf.root)
  let pages_node = match pdf.lookup_direct("/Pages", root) {
    Some(p) => p
    None => raise @pdf.PdfError::Msg("No /Pages found in /Root")
  }
  page_reference_numbers_unordered_inner(pdf, pages_node, -1, acc)
  acc.val
}

///|
fn fixup_duplicate_pages_inner(
  nodes : Array[Int],
  pdf : @pdf.Pdf,
) -> Unit raise {
  let refs = page_reference_numbers_unordered(pdf)
  refs.sort()
  match find_first_duplicate(refs) {
    Some(n) => {
      rewrite_page_tree_first(nodes, pdf, n)
      fixup_duplicate_pages_inner(nodes, pdf)
    }
    None => ()
  }
}

///|
/// Ensure page tree does not contain duplicate page objects.
pub fn PdfPageDoc::fixup_duplicate_pages(self : PdfPageDoc) -> Unit raise {
  let pdf = self.pdf
  let nodes = page_tree_nodes_not_pages(pdf)
  fixup_duplicate_pages_inner(nodes, pdf)
}

///|
fn fixup_parents_inner(
  pdf : @pdf.Pdf,
  parent_objnum : Int,
  objnum : Int,
) -> Unit raise {
  let obj = pdf.lookup_obj(objnum)
  match pdf.indirect_number("/Parent", obj) {
    Some(_) => {
      let updated = obj.add_entry("/Parent", PdfObject::Indirect(parent_objnum))
      pdf.addobj_given_num((objnum, updated))
    }
    None => ()
  }
  match pdf.lookup_direct("/Kids", obj) {
    Some(Array(kids)) =>
      for kid in kids {
        match kid {
          Indirect(i) => fixup_parents_inner(pdf, objnum, i)
          _ => ()
        }
      }
    _ => ()
  }
}

///|
/// Rewrite /Parent links for page tree nodes.
pub fn PdfPageDoc::fixup_parents(self : PdfPageDoc) -> Unit raise {
  let pdf = self.pdf
  let root = pdf.lookup_obj(pdf.root)
  match pdf.indirect_number("/Pages", root) {
    Some(pagetreeroot) => fixup_parents_inner(pdf, 0, pagetreeroot)
    None => raise @pdf.PdfError::Msg("fixup_parents: no page tree root")
  }
}

///|
fn fixup_link(
  key : String,
  obj : PdfObject,
  assoc : Map[Int, Int],
) -> PdfObject raise {
  match obj.lookup_immediate(key) {
    Some(Indirect(i)) =>
      match assoc.get(i) {
        Some(t) => obj.add_entry(key, PdfObject::Indirect(t))
        None => obj
      }
    _ => obj
  }
}

///|
/// Duplicate shared annotations across pages.
pub fn PdfPageDoc::fixup_duplicate_annots(self : PdfPageDoc) -> Unit raise {
  let pdf = self.pdf
  let src = Ref::new(pdf.objects.max_obj_num)
  let pages = PdfPageDoc::new(pdf).pages_of_pagetree()
  let existing_annots = pages.map(page => match
    pdf.lookup_direct("/Annots", page.rest) {
    Some(Array(a)) =>
      a.filter_map(obj => match obj {
        Indirect(i) => Some(i)
        _ => None
      })
    _ => []
  })
  let seen : Map[Int, Unit] = Map::new()
  let to_copy : Array[(Int, Int)] = Array::new()
  let new_annots = existing_annots.map(annots => {
    let out = Array::new(capacity=annots.length())
    for i in annots {
      if seen.get(i) is None {
        out.push(i)
        seen.set(i, ())
      } else {
        src.val = src.val + 1
        let new_num = src.val
        to_copy.push((i, new_num))
        out.push(new_num)
        seen.set(new_num, ())
      }
    }
    out
  })
  for pair in to_copy {
    let (from, to) = pair
    pdf.addobj_given_num((to, pdf.lookup_obj(from)))
  }
  for i in 0..<existing_annots.length() {
    let old_annots = existing_annots[i]
    let updated_annots = new_annots[i]
    let assoc : Map[Int, Int] = Map::new(capacity=old_annots.length())
    for j in 0..<old_annots.length() {
      assoc.set(old_annots[j], updated_annots[j])
    }
    for annot_num in updated_annots {
      let obj = pdf.lookup_obj(annot_num)
      let obj = fixup_link("/Popup", obj, assoc)
      let obj = fixup_link("/Parent", obj, assoc)
      pdf.addobj_given_num((annot_num, obj))
    }
  }
  let pagerefnums = pdf.page_reference_numbers()
  for i in 0..<new_annots.length() {
    let annots = new_annots[i]
    let pagerefnum = pagerefnums[i]
    if annots.length() > 0 {
      let page_obj = pdf.lookup_obj(pagerefnum)
      match page_obj {
        Dictionary(_) => {
          let indirects = annots.map(n => PdfObject::Indirect(n))
          let updated = page_obj.add_entry(
            "/Annots",
            PdfObject::Array(indirects),
          )
          pdf.addobj_given_num((pagerefnum, updated))
        }
        _ => ()
      }
    }
  }
}

///|
fn was_nulled(pdf : @pdf.Pdf, pair : (String, PdfObject)) -> Bool {
  let (_, dest) = pair
  match pdf.direct(dest) {
    Array([Indirect(i), ..]) =>
      match pdf.lookup_obj(i) {
        Null => true
        _ => false
      }
    _ => false
  }
}

///|
/// Rewrite /Dests tree entries pointing at removed pages.
pub fn PdfPageDoc::fixup_destinations(self : PdfPageDoc) -> Unit raise {
  let pdf = self.pdf
  match pdf.lookup_chain(pdf.trailerdict, ["/Root", "/Names", "/Dests"]) {
    Some(t) => {
      let tree_ctx = @pdftree.PdfTree::new(pdf)
      let tree = tree_ctx.read_name_tree(t)
      let tree_updated = tree.filter(pair => !was_nulled(pdf, pair))
      let tree_obj = tree_ctx.build_name_tree(false, tree_updated)
      pdf.replace_chain(["/Root", "/Names", "/Dests"], tree_obj)
    }
    None => ()
  }
}

///|
fn replace_inherit_entry(
  pdf : @pdf.Pdf,
  objnum : Int,
  entry : String,
) -> Unit raise {
  let obj = pdf.lookup_obj(objnum)
  fn find_attribute(current : PdfObject) -> PdfObject? {
    match pdf.lookup_direct(entry, current) {
      Some(_) => None
      None =>
        match pdf.lookup_direct("/Parent", current) {
          Some(Dictionary(parent)) =>
            match PdfObject::Dictionary(parent).lookup_immediate(entry) {
              Some(value) => Some(value)
              None => find_attribute(PdfObject::Dictionary(parent))
            }
          Some(parent) => find_attribute(parent)
          None => None
        }
    }
  }

  match find_attribute(obj) {
    Some(replacement) => {
      let updated = obj.add_entry(entry, replacement)
      pdf.addobj_given_num((objnum, updated))
    }
    None => ()
  }
}

///|
/// For all pages in objnumbers, ensure inheritable attributes are present.
pub fn PdfPageDoc::replace_inherit(
  self : PdfPageDoc,
  objnumbers : Array[Int],
) -> Unit raise {
  let pdf = self.pdf
  for objnum in objnumbers {
    replace_inherit_entry(pdf, objnum, "/MediaBox")
    replace_inherit_entry(pdf, objnum, "/CropBox")
    replace_inherit_entry(pdf, objnum, "/Rotate")
    replace_inherit_entry(pdf, objnum, "/Resources")
  }
}

///|
/// Get page object number for a 1-based page index.
pub fn PdfPageDoc::page_object_number(
  self : PdfPageDoc,
  destpage : Int,
) -> Int? raise {
  let pdf = self.pdf
  let refs = pdf.page_reference_numbers()
  if destpage < 1 {
    return None
  }
  refs.get(destpage - 1)
}

///|
/// Build a Fit destination for a page number.
pub fn PdfPageDoc::target_of_pagenumber(
  self : PdfPageDoc,
  index : Int,
) -> @pdfdest.Destination raise {
  match self.page_object_number(index) {
    None => NullDestination
    Some(p) => Fit(PageObject(p))
  }
}
