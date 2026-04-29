///|
/// PdfObject alias.
type PdfObject = @pdf.PdfObject

///|
/// Bookmark entry.
pub(all) struct Bookmark {
  level : Int
  text : String
  target : @pdfdest.Destination
  isopen : Bool
  colour : (Double, Double, Double)
  flags : Int
}

///|
pub struct PdfMarks {
  pdf : @pdf.Pdf
}

///|
pub fn PdfMarks::new(pdf : @pdf.Pdf) -> PdfMarks {
  { pdf, }
}

///|
/// Pretty-print a bookmark for debugging.
pub fn Bookmark::to_string(self : Bookmark) -> String {
  let dest = self.target.to_pdf_object()
  let dest_string = dest.to_string()
  "\{self.level} \{self.text} \{dest_string} \{self.isopen}\n"
}

///|
/// Remove any existing /Outlines from the document.
pub fn PdfMarks::remove_bookmarks(self : PdfMarks) -> @pdf.Pdf raise {
  let pdf = self.pdf
  match pdf.lookup_direct("/Root", pdf.trailerdict) {
    None => raise @pdf.PdfError::Msg("remove_bookmarks: Bad PDF: no root")
    Some(catalog) => {
      let catalog_updated = catalog.remove_entry("/Outlines")
      let newcatalognum = pdf.addobj(catalog_updated)
      let trailerdict = pdf.trailerdict.add_entry(
        "/Root",
        PdfObject::Indirect(newcatalognum),
      )
      {
        major: pdf.major,
        minor: pdf.minor,
        root: newcatalognum,
        objects: pdf.objects,
        trailerdict,
        was_linearized: pdf.was_linearized,
        saved_encryption: pdf.saved_encryption,
      }
    }
  }
}

///|
priv enum Ntree {
  Br(Int, PdfObject, Array[Ntree], Bool)
}

///|
fn ntree_objnum(node : Ntree) -> Int {
  match node {
    Br(i, _, _, _) => i
  }
}

///|
fn ntree_obj(node : Ntree) -> PdfObject {
  match node {
    Br(_, obj, _, _) => obj
  }
}

///|
fn ntree_children(node : Ntree) -> Array[Ntree] {
  match node {
    Br(_, _, children, _) => children
  }
}

///|
fn ntree_isopen(node : Ntree) -> Bool {
  match node {
    Br(_, _, _, isopen) => isopen
  }
}

///|
fn[T] flatten(lists : Array[Array[T]]) -> Array[T] {
  let mut total = 0
  for list in lists {
    total = total + list.length()
  }
  let out = Array::new(capacity=total)
  for list in lists {
    out.append(list[:])
  }
  out
}

///|
fn[T] extremes(items : Array[T]) -> (T, T) raise {
  match items {
    [] => raise @pdf.PdfError::Msg("extremes: empty list")
    [only] => (only, only)
    [first, .., last] => (first, last)
  }
}

///|
fn fresh(source : Ref[Int], pdf : @pdf.Pdf) -> Int {
  source.val = source.val + 1
  pdf.objects.max_obj_num + source.val
}

///|
fn any_open_nodes(nodes : Array[Ntree]) -> Bool {
  for node in nodes {
    if ntree_isopen(node) || any_open_nodes(ntree_children(node)) {
      return true
    }
  }
  false
}

///|
fn total_visible(nodes : Array[Ntree]) -> Int {
  let mut total = 0
  for node in nodes {
    total = total + 1
    if ntree_isopen(node) {
      total = total + total_visible(ntree_children(node))
    }
  }
  total
}

///|
fn add_root_parent(root_objnum : Int, node : Ntree) -> Ntree raise {
  let obj = ntree_obj(node).add_entry(
    "/Parent",
    PdfObject::Indirect(root_objnum),
  )
  Br(ntree_objnum(node), obj, ntree_children(node), ntree_isopen(node))
}

///|
fn flatten_tree(
  source : Ref[Int],
  pdf : @pdf.Pdf,
  tree : Array[Ntree],
) -> (Array[(Int, PdfObject)], Int) raise {
  if tree.length() == 0 {
    let n = fresh(source, pdf)
    return ([(n, PdfObject::Dictionary([]))], n)
  }
  let root_objnum = fresh(source, pdf)
  let tree = tree.map(node => add_root_parent(root_objnum, node))
  fn really_flatten(node : Ntree) -> Array[(Int, PdfObject)] {
    let out = Array::new()
    out.push((ntree_objnum(node), ntree_obj(node)))
    let children = ntree_children(node)
    if children.length() > 0 {
      out.append(flatten(children.map(really_flatten))[:])
    }
    out
  }

  let all_but_top = flatten(tree.map(really_flatten))
  let (first_node, last_node) = extremes(tree)
  let entries : Array[(String, PdfObject)] = [
    ("/First", PdfObject::Indirect(ntree_objnum(first_node))),
    ("/Last", PdfObject::Indirect(ntree_objnum(last_node))),
  ]
  if any_open_nodes(tree) {
    entries.push(("/Count", PdfObject::Integer(total_visible(tree))))
  }
  let top = (root_objnum, PdfObject::Dictionary(entries))
  ([top] + all_but_top, root_objnum)
}

///|
fn add_counts(nodes : Array[Ntree]) -> Array[Ntree] raise {
  nodes.map(add_count)
}

///|
fn add_count(node : Ntree) -> Ntree raise {
  let children = ntree_children(node)
  let obj = if children.length() == 0 {
    ntree_obj(node)
  } else if ntree_isopen(node) {
    ntree_obj(node).add_entry(
      "/Count",
      PdfObject::Integer(total_visible(children)),
    )
  } else {
    ntree_obj(node).add_entry(
      "/Count",
      PdfObject::Integer(-total_visible(children)),
    )
  }
  Br(ntree_objnum(node), obj, add_counts(children), ntree_isopen(node))
}

///|
fn add_parent(parent : Int?, node : Ntree) -> Ntree raise {
  let obj = match parent {
    None => ntree_obj(node)
    Some(parent_num) =>
      ntree_obj(node).add_entry("/Parent", PdfObject::Indirect(parent_num))
  }
  let children = ntree_children(node).map(child => add_parent(
    Some(ntree_objnum(node)),
    child,
  ))
  Br(ntree_objnum(node), obj, children, ntree_isopen(node))
}

///|
fn add_firstlast(node : Ntree) -> Ntree raise {
  let children = ntree_children(node)
  match children {
    [] => node
    [only] => {
      let obj = ntree_obj(node)
        .add_entry("/First", PdfObject::Indirect(ntree_objnum(only)))
        .add_entry("/Last", PdfObject::Indirect(ntree_objnum(only)))
      Br(
        ntree_objnum(node),
        obj,
        children.map(add_firstlast),
        ntree_isopen(node),
      )
    }
    [first, .., last] => {
      let obj = ntree_obj(node)
        .add_entry("/First", PdfObject::Indirect(ntree_objnum(first)))
        .add_entry("/Last", PdfObject::Indirect(ntree_objnum(last)))
      Br(
        ntree_objnum(node),
        obj,
        children.map(add_firstlast),
        ntree_isopen(node),
      )
    }
  }
}

///|
fn add_next(node : Ntree) -> Ntree raise {
  let children = ntree_children(node)
  match children {
    [] => node
    [first, .. rest] => {
      fn link_next(
        current : Ntree,
        rest : ArrayView[Ntree],
      ) -> Array[Ntree] raise {
        match rest {
          [] => [add_next(current)]
          [next, .. tail] => {
            let obj = ntree_obj(current).add_entry(
              "/Next",
              PdfObject::Indirect(ntree_objnum(next)),
            )
            let updated = Br(
              ntree_objnum(current),
              obj,
              ntree_children(current),
              ntree_isopen(current),
            )
            [add_next(updated)] + link_next(next, tail)
          }
        }
      }

      Br(
        ntree_objnum(node),
        ntree_obj(node),
        link_next(first, rest),
        ntree_isopen(node),
      )
    }
  }
}

///|
fn add_prev(node : Ntree) -> Ntree raise {
  let children = ntree_children(node)
  fn link_prev(prev : Ntree?, items : ArrayView[Ntree]) -> Array[Ntree] raise {
    match items {
      [] => []
      [first, .. rest] => {
        let updated = match prev {
          None => first
          Some(prev_node) => {
            let obj = ntree_obj(first).add_entry(
              "/Prev",
              PdfObject::Indirect(ntree_objnum(prev_node)),
            )
            Br(
              ntree_objnum(first),
              obj,
              ntree_children(first),
              ntree_isopen(first),
            )
          }
        }
        [add_prev(updated)] + link_prev(Some(updated), rest)
      }
    }
  }

  match children {
    [] => node
    _ =>
      Br(
        ntree_objnum(node),
        ntree_obj(node),
        link_prev(None, children),
        ntree_isopen(node),
      )
  }
}

///|
fn node_of_line(
  _pdf : @pdf.Pdf,
  title : String,
  target : @pdfdest.Destination,
  colour : (Double, Double, Double),
  flags : Int,
) -> PdfObject {
  let entries : Array[(String, PdfObject)] = [
    ("/Title", PdfObject::String(title)),
  ]
  let dest = target.to_pdf_object()
  match (dest : PdfObject) {
    Null => ()
    _ =>
      match (target : @pdfdest.Destination) {
        Action(action) => entries.push(("/A", action))
        _ => entries.push(("/Dest", dest))
      }
  }
  let (r, g, b) = colour
  if !(r == 0.0 && g == 0.0 && b == 0.0) {
    entries.push(
      (
        "/C",
        PdfObject::Array([
          PdfObject::Real(r),
          PdfObject::Real(g),
          PdfObject::Real(b),
        ]),
      ),
    )
  }
  if flags != 0 {
    entries.push(("/F", PdfObject::Integer(flags)))
  }
  PdfObject::Dictionary(entries)
}

///|
fn make_outline_ntree(
  source : Ref[Int],
  pdf : @pdf.Pdf,
  marks : ArrayView[Bookmark],
) -> Array[Ntree] {
  match marks {
    [] => []
    [head, .. rest] => {
      let mut split = 0
      while split < rest.length() && rest[split].level > head.level {
        split = split + 1
      }
      let lower = rest.sub(start=0, end=split)
      let remaining = rest.sub(start=split)
      let node = node_of_line(
        pdf,
        head.text,
        head.target,
        head.colour,
        head.flags,
      )
      let tree = make_outline_ntree(source, pdf, lower)
      let current = Br(fresh(source, pdf), node, tree, head.isopen)
      let out = Array::new(capacity=1 + remaining.length())
      out.push(current)
      out.append(make_outline_ntree(source, pdf, remaining)[:])
      out
    }
  }
}

///|
/// Add bookmarks to the document.
pub fn PdfMarks::add_bookmarks(
  self : PdfMarks,
  parsed : Array[Bookmark],
) -> @pdf.Pdf raise {
  let pdf = self.pdf
  if parsed.length() == 0 {
    self.remove_bookmarks()
  } else {
    let source = Ref::new(0)
    let tree = make_outline_ntree(source, pdf, parsed[:])
    let tree = tree.map(add_firstlast)
    let tree = match add_next(add_prev(Br(0, PdfObject::Null, tree, false))) {
      Br(_, _, children, _) => children
    }
    let tree = add_counts(tree.map(node => add_parent(None, node)))
    let (pairs, tree_root_num) = flatten_tree(source, pdf, tree)
    for pair in pairs {
      pdf.addobj_given_num(pair)
    }
    match pdf.lookup_direct("/Root", pdf.trailerdict) {
      None => raise @pdf.PdfError::Msg("Bad PDF: no root")
      Some(catalog) => {
        let catalog_updated = catalog.add_entry(
          "/Outlines",
          PdfObject::Indirect(tree_root_num),
        )
        let newcatalognum = pdf.addobj(catalog_updated)
        let trailerdict = pdf.trailerdict.add_entry(
          "/Root",
          PdfObject::Indirect(newcatalognum),
        )
        {
          major: pdf.major,
          minor: pdf.minor,
          root: newcatalognum,
          objects: pdf.objects,
          trailerdict,
          was_linearized: pdf.was_linearized,
          saved_encryption: pdf.saved_encryption,
        }
      }
    }
  }
}

///|
fn traverse_outlines_lb(
  pdf : @pdf.Pdf,
  outlines : PdfObject,
  indent : Ref[Int],
  preserve_actions : Bool,
  out : Ref[Array[Bookmark]],
) -> Unit raise {
  match pdf.lookup_direct("/First", outlines) {
    None => ()
    Some(first) =>
      do_until_no_next_lb(pdf, first, indent, preserve_actions, out)
  }
}

///|
fn do_until_no_next_lb(
  pdf : @pdf.Pdf,
  outline : PdfObject,
  indent : Ref[Int],
  preserve_actions : Bool,
  out : Ref[Array[Bookmark]],
) -> Unit raise {
  let title = match pdf.lookup_direct("/Title", outline) {
    Some(PdfObject::String(s)) => s
    _ => {
      @pdfe.log(
        "/Title not a string or not present in document outline entry. Using the empty string.\n",
      )
      ""
    }
  }
  let page : @pdfdest.Destination = match pdf.lookup_direct("/Dest", outline) {
    Some(PdfObject::String(stringdest)) if preserve_actions =>
      StringDestination(stringdest)
    Some(dest) =>
      @pdfdest.Destination::read(pdf, dest, shallow=preserve_actions)
    None =>
      match pdf.lookup_direct("/A", outline) {
        None => NullDestination
        Some(action) =>
          if preserve_actions {
            match pdf.lookup_direct("/D", action) {
              Some(PdfObject::Array(_) as dest) =>
                @pdfdest.Destination::read(pdf, dest, shallow=preserve_actions)
              _ => Action(pdf.direct(action))
            }
          } else {
            match pdf.lookup_direct("/D", action) {
              None => Action(pdf.direct(action))
              Some(dest) =>
                @pdfdest.Destination::read(pdf, dest, shallow=preserve_actions)
            }
          }
      }
  }
  let opn = match pdf.lookup_direct("/Count", outline) {
    Some(PdfObject::Integer(i)) if i > 0 => true
    _ => false
  }
  let colour = try {
    match pdf.lookup_direct("/C", outline) {
      Some(PdfObject::Array([a, b, c])) =>
        (pdf.getnum(a), pdf.getnum(b), pdf.getnum(c))
      _ => (0.0, 0.0, 0.0)
    }
  } catch {
    _ => (0.0, 0.0, 0.0)
  }
  let flags = match pdf.lookup_direct("/F", outline) {
    Some(PdfObject::Integer(i)) => i
    _ => 0
  }
  out.val.push({
    level: indent.val,
    text: title,
    target: page,
    isopen: opn,
    colour,
    flags,
  })
  indent.val = indent.val + 1
  traverse_outlines_lb(pdf, outline, indent, preserve_actions, out)
  if indent.val > 0 {
    indent.val = indent.val - 1
  }
  match pdf.lookup_direct("/Next", outline) {
    None => ()
    Some(next) => do_until_no_next_lb(pdf, next, indent, preserve_actions, out)
  }
}

///|
/// Read all bookmarks from the document.
pub fn PdfMarks::read_bookmarks(
  self : PdfMarks,
  preserve_actions? : Bool = false,
) -> Array[Bookmark] raise {
  let pdf = self.pdf
  match pdf.lookup_direct("/Root", pdf.trailerdict) {
    None => raise @pdf.PdfError::Msg("read_bookmarks - Bad PDF: no root")
    Some(catalog) =>
      match pdf.lookup_direct("/Outlines", catalog) {
        None => []
        Some(outlines) => {
          let out = Ref::new(Array::new())
          traverse_outlines_lb(
            pdf,
            outlines,
            Ref::new(0),
            preserve_actions,
            out,
          )
          out.val
        }
      }
  }
}

///|
/// Transform a bookmark destination.
pub fn Bookmark::transform(
  self : Bookmark,
  pdf : @pdf.Pdf,
  tr : @pdftransform.TransformMatrix,
) -> Bookmark raise {
  {
    level: self.level,
    text: self.text,
    target: self.target.transform(pdf, tr),
    isopen: self.isopen,
    colour: self.colour,
    flags: self.flags,
  }
}
