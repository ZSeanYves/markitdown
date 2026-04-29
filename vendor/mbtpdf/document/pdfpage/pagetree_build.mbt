///|
fn source(start : Int) -> () -> Int {
  let counter = Ref::new(start)
  fn() {
    counter.val = counter.val + 1
    counter.val
  }
}

///|
fn[T] array_slice(
  values : ArrayView[T],
  start : Int,
  len : Int,
) -> ArrayView[T] {
  values.sub(start~, end=start + len)
}

///|
/// Page tree node.
priv enum Ptree {
  Lf(ArrayView[Page], Int, Int)
  Br(ArrayView[Page], Ptree, Ptree, Int, Int)
}

///|
fn[T] split3(
  n : Int,
  values : ArrayView[T],
) -> (ArrayView[T], ArrayView[T], ArrayView[T]) raise {
  let len = values.length()
  if n > len - 2 {
    raise @pdf.PdfError::Msg("split3")
  }
  let leftlen = (len - n) / 2
  let left = array_slice(values, 0, leftlen)
  let middle = array_slice(values, leftlen, n)
  let right = array_slice(values, leftlen + n, len - leftlen - n)
  (left, middle, right)
}

///|
fn pagetree(
  objnumsource : () -> Int,
  pages : ArrayView[Page],
  parent : Int,
) -> Ptree raise {
  if pages.length() < 10 {
    Lf(pages, parent, objnumsource())
  } else {
    let (left, middle, right) = split3(5, pages)
    let this_num = objnumsource()
    let left_tree = pagetree(objnumsource, left, this_num)
    let right_tree = pagetree(objnumsource, right, this_num)
    Br(middle, left_tree, right_tree, parent, this_num)
  }
}

///|
fn mkpage(
  getobjnum : () -> Int,
  parent : Int,
  page : Page,
) -> (Int, PdfObject, Array[(Int, PdfObject)]) raise {
  let extras : Array[(Int, PdfObject)] = Array::new()
  let indirects : Array[PdfObject] = Array::new()
  for c in page.content {
    match c {
      Indirect(i) => indirects.push(Indirect(i))
      _ => {
        let objnum = getobjnum()
        indirects.push(Indirect(objnum))
        extras.push((objnum, c))
      }
    }
  }
  let entries : Array[(String, PdfObject)] = [
    ("/Type", PdfObject::Name(@pdf.PdfName::of_string("/Page"))),
    ("/Parent", PdfObject::Indirect(parent)),
    ("/Resources", page.resources),
    ("/MediaBox", page.mediabox),
  ]
  let rotation = page.rotate.to_int()
  if rotation != 0 {
    entries.push(("/Rotate", PdfObject::Integer(rotation)))
  }
  let rest_entries = match page.rest {
    Dictionary(d) => d
    _ => raise @pdf.PdfError::Msg("mkpage")
  }
  entries.append(rest_entries[:])
  if indirects.length() > 0 {
    entries.push(("/Contents", PdfObject::Array(indirects)))
  }
  let page_obj = PdfObject::Dictionary(entries)
  let objnum = getobjnum()
  (objnum, page_obj, extras)
}

///|
fn count_ptree(tree : Ptree) -> Int {
  match tree {
    Lf(pages, _, _) => pages.length()
    Br(pages, left, right, _, _) =>
      pages.length() + count_ptree(left) + count_ptree(right)
  }
}

///|
fn objnum_of_ptree(tree : Ptree) -> Int {
  match tree {
    Lf(_, _, this) => this
    Br(_, _, _, _, this) => this
  }
}

///|
fn objects_of_ptree(
  getobjnum : () -> Int,
  extras : Ref[Array[(Int, PdfObject)]],
  tree : Ptree,
) -> Array[(Int, PdfObject)] raise {
  match tree {
    Lf(pages, parent, this) => {
      let page_objects : Array[(Int, PdfObject)] = Array::new()
      for page in pages {
        let (objnum, obj, extra) = mkpage(getobjnum, this, page)
        extras.val.append(extra[:])
        page_objects.push((objnum, obj))
      }
      let parent_entry = match parent {
        0 => []
        _ => [("/Parent", PdfObject::Indirect(parent))]
      }
      let kids = page_objects.map(pair => PdfObject::Indirect(pair.0))
      let node_entries : Array[(String, PdfObject)] = [
        ("/Type", PdfObject::Name(@pdf.PdfName::of_string("/Pages"))),
        ("/Kids", PdfObject::Array(kids)),
        ("/Count", PdfObject::Integer(pages.length())),
      ]
      node_entries.append(parent_entry[:])
      let node = PdfObject::Dictionary(node_entries)
      let result = Array::new(capacity=1 + page_objects.length())
      result.push((this, node))
      result.append(page_objects[:])
      result
    }
    Br(pages, left, right, parent, this) => {
      let objs_left = objects_of_ptree(getobjnum, extras, left)
      let objs_right = objects_of_ptree(getobjnum, extras, right)
      let left_num = objnum_of_ptree(left)
      let right_num = objnum_of_ptree(right)
      let count_left = count_ptree(left)
      let count_right = count_ptree(right)
      let page_objects : Array[(Int, PdfObject)] = Array::new()
      for page in pages {
        let (objnum, obj, extra) = mkpage(getobjnum, this, page)
        extras.val.append(extra[:])
        page_objects.push((objnum, obj))
      }
      let parent_entry = match parent {
        0 => []
        _ => [("/Parent", PdfObject::Indirect(parent))]
      }
      let kids = Array::new()
      kids.push(PdfObject::Indirect(left_num))
      kids.append(page_objects.map(pair => PdfObject::Indirect(pair.0))[:])
      kids.push(PdfObject::Indirect(right_num))
      let node_entries : Array[(String, PdfObject)] = [
        ("/Type", PdfObject::Name(@pdf.PdfName::of_string("/Pages"))),
        ("/Kids", PdfObject::Array(kids)),
        (
          "/Count",
          PdfObject::Integer(count_left + count_right + page_objects.length()),
        ),
      ]
      node_entries.append(parent_entry[:])
      let node = PdfObject::Dictionary(node_entries)
      let result = Array::new()
      result.push((this, node))
      result.append(page_objects[:])
      result.append(objs_left[:])
      result.append(objs_right[:])
      result
    }
  }
}

///|
/// Build a page tree and add it to the PDF.
pub fn PdfPageDoc::add_pagetree(
  self : PdfPageDoc,
  pages : Array[Page],
) -> (@pdf.Pdf, Int) raise {
  let pdf = self.pdf
  let extras : Ref[Array[(Int, PdfObject)]] = { val: [] }
  let getobjnum = source(pdf.objects.max_obj_num)
  let ptree = pagetree(getobjnum, pages, 0)
  let objects = objects_of_ptree(getobjnum, extras, ptree)
  match objects {
    [] => raise @pdf.PdfError::Msg("add_pagetree: empty page tree")
    _ => ()
  }
  for obj in objects {
    pdf.addobj_given_num(obj)
  }
  for extra in extras.val {
    pdf.addobj_given_num(extra)
  }
  match objects {
    [(objnum, _), ..] => (pdf, objnum)
    [] => raise @pdf.PdfError::Msg("add_pagetree: empty page tree")
  }
}

///|
/// Replace the root catalog with a new /Pages entry.
pub fn PdfPageDoc::add_root(
  self : PdfPageDoc,
  pageroot : Int,
  extras : Array[(String, PdfObject)],
) -> @pdf.Pdf raise {
  let pdf = self.pdf
  let existing_entries = match pdf.lookup_obj(pdf.root) {
    Dictionary(d) => d
    _ => []
  }
  let mut root = PdfObject::Dictionary(extras)
  for entry in existing_entries {
    root = root.add_entry(entry.0, entry.1)
  }
  root = root.add_entry(
    "/Type",
    PdfObject::Name(@pdf.PdfName::of_string("/Catalog")),
  )
  root = root.add_entry("/Pages", PdfObject::Indirect(pageroot))
  let rootnum = pdf.addobj(root)
  let trailerdict = match pdf.trailerdict {
    Dictionary(_) =>
      pdf.trailerdict.add_entry("/Root", PdfObject::Indirect(rootnum))
    _ => raise @pdf.PdfError::Msg("add_root: bad trailer dictionary")
  }
  {
    major: pdf.major,
    minor: pdf.minor,
    root: rootnum,
    objects: pdf.objects,
    trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
}
