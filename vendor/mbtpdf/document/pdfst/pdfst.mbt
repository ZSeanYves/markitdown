///|
pub struct PdfStructTree {
  pdf : @pdf.Pdf
}

///|
pub fn PdfStructTree::new(pdf : @pdf.Pdf) -> PdfStructTree {
  { pdf, }
}

///|
pub struct PdfStructTrees {
  pdfs : Array[@pdf.Pdf]
}

///|
pub fn PdfStructTrees::new(pdfs : Array[@pdf.Pdf]) -> PdfStructTrees {
  { pdfs, }
}

///|
fn ilist(start : Int, finish : Int) -> Array[Int] {
  if finish < start {
    return []
  }
  let out = Array::new(capacity=finish - start + 1)
  for i in start..<=finish {
    out.push(i)
  }
  out
}

///|
fn setminus(full : Array[Int], remove : Array[Int]) -> Array[Int] {
  let remove_set = Map::new(capacity=remove.length())
  for v in remove {
    remove_set.set(v, ())
  }
  let out = Array::new(capacity=full.length())
  for v in full {
    if remove_set.get(v) is None {
      out.push(v)
    }
  }
  out
}

///|
fn set_of_ints(values : Array[Int]) -> Map[Int, Unit] {
  let out = Map::new(capacity=values.length())
  for v in values {
    out.set(v, ())
  }
  out
}

///|
fn dedup_ints(values : Array[Int]) -> Array[Int] {
  let set = set_of_ints(values)
  let out = Array::new(capacity=set.length())
  for key, _ in set {
    out.push(key)
  }
  out
}

///|
fn dedup_pairs(
  values : Array[(Int, @pdf.PdfObject)],
) -> Array[(Int, @pdf.PdfObject)] {
  let set = Map::new(capacity=values.length())
  for pair in values {
    set.set(pair.0, pair.1)
  }
  let out = Array::new(capacity=set.length())
  for key, value in set {
    out.push((key, value))
  }
  out
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
/// Trim the structure tree to match a subset of pages.
pub fn PdfStructTree::trim_structure_tree(
  self : PdfStructTree,
  range : Array[Int],
) -> Unit raise {
  let pdf = self.pdf
  let objnums = pdf.page_reference_numbers()
  let total_pages = objnums.length()
  let pages_to_remove = setminus(ilist(1, total_pages), range)
  let page_objnums_to_remove = Array::new(capacity=pages_to_remove.length())
  for pnum in pages_to_remove {
    if pnum >= 1 && pnum <= objnums.length() {
      page_objnums_to_remove.push(objnums[pnum - 1])
    }
  }
  if page_objnums_to_remove.length() == 0 {
    return
  }
  let remove_set = set_of_ints(page_objnums_to_remove)
  let del : Ref[Array[Int]] = { val: [] }
  let replaceobjs : Ref[Array[(Int, @pdf.PdfObject)]] = { val: [] }
  pdf.objiter((n, o) => match pdf.direct(o) {
    @pdf.PdfObject::Dictionary(d) =>
      match @pdf.PdfObject::Dictionary(d).lookup_immediate("/Pg") {
        Some(@pdf.PdfObject::Indirect(i)) =>
          if remove_set.get(i) is Some(_) {
            del.val.push(n)
          }
        _ => ()
      }
    _ => ()
  })
  fn survives(obj : @pdf.PdfObject) -> Bool {
    match obj {
      @pdf.PdfObject::Indirect(i) => {
        if pdf.lookup_obj(i) is @pdf.PdfObject::Null {
          return false
        }
        match pdf.indirect_number("/Pg", @pdf.PdfObject::Indirect(i)) {
          Some(p) if remove_set.get(p) is Some(_) => false
          _ =>
            match pdf.indirect_number("/Obj", @pdf.PdfObject::Indirect(i)) {
              Some(p) if remove_set.get(p) is Some(_) => false
              _ => true
            }
        }
      }
      _ => true
    }
  }

  fn process(objs : Array[@pdf.PdfObject]) -> Array[@pdf.PdfObject]? {
    let out = Array::new()
    let mut changed = false
    for obj in objs {
      if survives(obj) {
        out.push(obj)
      } else {
        changed = true
      }
    }
    if !changed {
      None
    } else {
      Some(out)
    }
  }

  fn process_indirect(
    d : Array[(String, @pdf.PdfObject)],
    objs : Array[@pdf.PdfObject],
    n : Int,
  ) -> Unit raise {
    match process(objs) {
      None => ()
      Some(newlist) =>
        if newlist.length() == 0 {
          del.val.push(n)
        } else {
          let replacement = if newlist.length() == 1 {
            newlist[0]
          } else {
            @pdf.PdfObject::Array(newlist)
          }
          let updated = @pdf.PdfObject::Dictionary(d).replace_entry(
            "/K", replacement,
          )
          replaceobjs.val.push((n, updated))
        }
    }
  }

  while del.val.length() > 0 || replaceobjs.val.length() > 0 {
    for objnum in dedup_ints(del.val) {
      pdf.removeobj(objnum)
    }
    del.val = []
    for pair in dedup_pairs(replaceobjs.val) {
      pdf.addobj_given_num(pair)
    }
    replaceobjs.val = []
    pdf.objiter((n, o) => match pdf.direct(o) {
      @pdf.PdfObject::Dictionary(d) =>
        match @pdf.PdfObject::Dictionary(d).lookup_immediate("/K") {
          Some(@pdf.PdfObject::Integer(_)) => ()
          Some(@pdf.PdfObject::Indirect(i)) =>
            process_indirect(d, [@pdf.PdfObject::Indirect(i)], n)
          Some(@pdf.PdfObject::Array(objs)) => process_indirect(d, objs, n)
          _ => ()
        }
      _ => ()
    })
  }
}

///|
/// Renumber /ParentTree entries and update /StructParent(s) references.
pub fn PdfStructTrees::renumber_parent_trees(
  self : PdfStructTrees,
) -> Unit raise {
  let pdfs = self.pdfs
  if pdfs.length() <= 1 {
    return
  }
  let parent_trees = pdfs.map(pdf => match
    pdf.lookup_chain(pdf.trailerdict, [
      "/Root", "/StructTreeRoot", "/ParentTree",
    ]) {
    Some(tree) => @pdftree.PdfTree::new(pdf).read_number_tree(tree)
    None => []
  })
  let mut total_entries = 0
  for tree in parent_trees {
    total_entries = total_entries + tree.length()
  }
  let mapping : Map[(Int, Int), Int] = Map::new(capacity=total_entries)
  let mut next = 0
  for i, tree in parent_trees {
    let pdfn = i + 1
    for pair in tree {
      let key = @strconv.parse_int(pair.0)
      mapping.set((pdfn, key), next)
      next = next + 1
    }
  }
  fn rewrite(
    pdfn : Int,
    mapping : Map[(Int, Int), Int],
    obj : @pdf.PdfObject,
  ) -> @pdf.PdfObject {
    match obj {
      @pdf.PdfObject::Dictionary(entries) => {
        let out = Array::new(capacity=entries.length())
        for entry in entries {
          let key = entry.0
          let value = entry.1
          let replaced = if key == "/StructParent" || key == "/StructParents" {
            match value {
              @pdf.PdfObject::Integer(i) =>
                match mapping.get((pdfn, i)) {
                  Some(new_i) => @pdf.PdfObject::Integer(new_i)
                  None => @pdf.PdfObject::Integer(i)
                }
              _ => value
            }
          } else {
            value
          }
          out.push((key, rewrite(pdfn, mapping, replaced)))
        }
        @pdf.PdfObject::Dictionary(out)
      }
      @pdf.PdfObject::Array(items) =>
        @pdf.PdfObject::Array(items.map(item => rewrite(pdfn, mapping, item)))
      @pdf.PdfObject::Stream(r) => {
        let (dict, stream) = r.val
        let dict_updated = rewrite(pdfn, mapping, dict)
        r.val = (dict_updated, stream)
        @pdf.PdfObject::Stream(r)
      }
      _ => obj
    }
  }

  for i, pdf in pdfs {
    let pdfn = i + 1
    pdf.objselfmap(obj => rewrite(pdfn, mapping, obj))
  }
  let renumbered = Array::new(capacity=parent_trees.length())
  for i, tree in parent_trees {
    let pdfn = i + 1
    let out = Array::new(capacity=tree.length())
    for pair in tree {
      let key = @strconv.parse_int(pair.0)
      match mapping.get((pdfn, key)) {
        Some(new_key) => out.push((new_key.to_string(), pair.1))
        None =>
          raise @pdf.PdfError::Msg("renumber_parent_trees: missing mapping")
      }
    }
    renumbered.push(out)
  }
  fn update_struct_root(
    pdf : @pdf.Pdf,
    root_obj : @pdf.PdfObject,
    parent_tree : @pdf.PdfObject,
  ) -> (@pdf.PdfObject, Bool) raise {
    match root_obj {
      @pdf.PdfObject::Dictionary(_) | @pdf.PdfObject::Stream(_) =>
        match root_obj.lookup_immediate("/StructTreeRoot") {
          None => (root_obj, false)
          Some(@pdf.PdfObject::Indirect(struct_num)) => {
            let struct_obj = pdf.lookup_obj(struct_num)
            match struct_obj {
              @pdf.PdfObject::Dictionary(_) | @pdf.PdfObject::Stream(_) => {
                let updated = struct_obj.add_entry("/ParentTree", parent_tree)
                pdf.addobj_given_num((struct_num, updated))
                (root_obj, true)
              }
              _ => (root_obj, false)
            }
          }
          Some(struct_root) =>
            match struct_root {
              @pdf.PdfObject::Dictionary(_) | @pdf.PdfObject::Stream(_) => {
                let updated_struct = struct_root.add_entry(
                  "/ParentTree", parent_tree,
                )
                let updated_root = root_obj.add_entry(
                  "/StructTreeRoot", updated_struct,
                )
                (updated_root, true)
              }
              _ => (root_obj, false)
            }
        }
      _ => (root_obj, false)
    }
  }

  for i, pdf in pdfs {
    let parent_tree = @pdftree.PdfTree::new(pdf).build_name_tree(
      true,
      renumbered[i],
    )
    match pdf.trailerdict.lookup_immediate("/Root") {
      Some(@pdf.PdfObject::Indirect(root_num)) => {
        let root_obj = pdf.lookup_obj(root_num)
        let (updated_root, changed) = update_struct_root(
          pdf, root_obj, parent_tree,
        )
        if changed {
          pdf.addobj_given_num((root_num, updated_root))
        }
      }
      Some(root_obj) => {
        let (updated_root, changed) = update_struct_root(
          pdf, root_obj, parent_tree,
        )
        if changed {
          pdf.trailerdict = pdf.trailerdict.add_entry("/Root", updated_root)
        }
      }
      None => ()
    }
  }
}

///|
/// Merge structure tree roots, returning the merged root object number.
pub fn PdfStructTree::merge_structure_trees(
  self : PdfStructTree,
  pdfs : Array[@pdf.Pdf],
  add_toplevel_document? : Bool = false,
) -> Int? raise {
  let pdf = self.pdf
  fn get_all(
    struct_roots : Array[@pdf.PdfObject],
    name : String,
  ) -> Array[@pdf.PdfObject] {
    let out = Array::new()
    for root in struct_roots {
      match pdf.lookup_direct(name, root) {
        Some(obj) => out.push(obj)
        None => ()
      }
    }
    out
  }

  fn merge_dicts(dicts : Array[@pdf.PdfObject]) -> @pdf.PdfObject raise {
    let mut merged = @pdf.PdfObject::Dictionary([])
    for dict in dicts {
      match dict {
        @pdf.PdfObject::Dictionary(entries) =>
          for entry in entries {
            merged = merged.add_entry(entry.0, entry.1)
          }
        _ => @pdfe.log("merge_dicts: not a dict\n")
      }
    }
    merged
  }

  fn merge_arrays(arrays : Array[@pdf.PdfObject]) -> @pdf.PdfObject {
    let out = Array::new()
    for arr in arrays {
      match arr {
        @pdf.PdfObject::Array(items) => out.append(items[:])
        _ => @pdfe.log("merge_array: not an array\n")
      }
    }
    @pdf.PdfObject::Array(out)
  }

  fn mkarray(obj : @pdf.PdfObject) -> @pdf.PdfObject {
    match obj {
      @pdf.PdfObject::Array(items) => @pdf.PdfObject::Array(items)
      _ => @pdf.PdfObject::Array([obj])
    }
  }

  let struct_tree_roots = Array::new()
  let struct_tree_objnums = Array::new()
  for pdf_in in pdfs {
    let catalog = pdf_in.catalog_of_pdf()
    match pdf_in.lookup_direct("/StructTreeRoot", catalog) {
      None => ()
      Some(root) => {
        let objnum = match catalog.lookup_immediate("/StructTreeRoot") {
          Some(@pdf.PdfObject::Indirect(i)) => i
          _ => 0
        }
        struct_tree_roots.push(root)
        struct_tree_objnums.push(objnum)
      }
    }
  }
  if struct_tree_roots.length() == 0 {
    return None
  }
  if struct_tree_roots.length() == 1 {
    return Some(struct_tree_objnums[0])
  }
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  let merged_idtree = tree_ctx.merge_name_trees_no_clash(
    get_all(struct_tree_roots, "/IDTree"),
  )
  let merged_parenttree = tree_ctx.merge_number_trees_no_clash(
    get_all(struct_tree_roots, "/ParentTree"),
  )
  let merged_rolemap = merge_dicts(get_all(struct_tree_roots, "/RoleMap"))
  let merged_classmap = merge_dicts(get_all(struct_tree_roots, "/ClassMap"))
  let merged_namespaces = merge_arrays(
    get_all(struct_tree_roots, "/Namespaces"),
  )
  let merged_pronunciation_lexicon = merge_arrays(
    get_all(struct_tree_roots, "/PronunciationLexicon"),
  )
  let merged_af = merge_arrays(get_all(struct_tree_roots, "/AF"))
  let struct_tree_objnum = pdf.addobj(@pdf.PdfObject::Null)
  let existing_ks = flatten(
    struct_tree_roots.map(root => match root.lookup_immediate("/K") {
      Some(@pdf.PdfObject::Indirect(i)) => [@pdf.PdfObject::Indirect(i)]
      Some(@pdf.PdfObject::Array(items)) => items
      Some(obj) => [obj]
      None => []
    }),
  )
  let updated_ks = Array::new(capacity=existing_ks.length())
  for item in existing_ks {
    match item {
      @pdf.PdfObject::Indirect(i) => {
        let d = pdf.lookup_obj(i)
        let updated = d.add_entry(
          "/P",
          @pdf.PdfObject::Indirect(struct_tree_objnum),
        )
        pdf.addobj_given_num((i, updated))
        updated_ks.push(@pdf.PdfObject::Indirect(i))
      }
      @pdf.PdfObject::Dictionary(_) => {
        let updated = item.add_entry(
          "/P",
          @pdf.PdfObject::Indirect(struct_tree_objnum),
        )
        updated_ks.push(updated)
      }
      _ => updated_ks.push(item)
    }
  }
  let merged_k = mkarray(@pdf.PdfObject::Array(updated_ks))
  fn optional(
    name : String,
    obj : @pdf.PdfObject,
  ) -> Array[(String, @pdf.PdfObject)] {
    match obj {
      @pdf.PdfObject::Dictionary(entries) if entries.length() == 0 => []
      @pdf.PdfObject::Array(entries) if entries.length() == 0 => []
      _ => [(name, @pdf.PdfObject::Indirect(pdf.addobj(obj)))]
    }
  }

  let standard_entries = Array::new()
  standard_entries.push(
    ("/Type", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/StructTreeRoot"))),
  )
  standard_entries.append(optional("/IDTree", merged_idtree)[:])
  standard_entries.append(optional("/ParentTree", merged_parenttree)[:])
  standard_entries.append(optional("/RoleMap", merged_rolemap)[:])
  standard_entries.append(optional("/ClassMap", merged_classmap)[:])
  standard_entries.append(
    optional("/PronunciationLexicon", merged_pronunciation_lexicon)[:],
  )
  standard_entries.append(optional("/AF", merged_af)[:])
  if add_toplevel_document {
    let namespace_objnum = pdf.addobj(
      @pdf.PdfObject::Dictionary([
        ("/NS", @pdf.PdfObject::String("http://iso.org/pdf2/ssn")),
      ]),
    )
    let merged_namespaces = match merged_namespaces {
      @pdf.PdfObject::Array(items) => {
        let out = Array::new(capacity=items.length() + 1)
        out.push(@pdf.PdfObject::Indirect(namespace_objnum))
        out.append(items[:])
        @pdf.PdfObject::Array(out)
      }
      _ => merged_namespaces
    }
    let top_level_objnum = pdf.addobj(
      @pdf.PdfObject::Dictionary([
        ("/NS", @pdf.PdfObject::Indirect(namespace_objnum)),
        ("/S", @pdf.PdfObject::Name(@pdf.PdfName::of_string("/Document"))),
        ("/P", @pdf.PdfObject::Indirect(struct_tree_objnum)),
        ("/K", merged_k),
      ]),
    )
    let new_entries = Array::new()
    new_entries.append(standard_entries[:])
    new_entries.append(optional("/Namespaces", merged_namespaces)[:])
    new_entries.push(("/K", @pdf.PdfObject::Indirect(top_level_objnum)))
    pdf.addobj_given_num(
      (struct_tree_objnum, @pdf.PdfObject::Dictionary(new_entries)),
    )
    Some(struct_tree_objnum)
  } else {
    let new_entries = Array::new()
    new_entries.append(standard_entries[:])
    new_entries.append(optional("/Namespaces", merged_namespaces)[:])
    new_entries.append(optional("/K", merged_k)[:])
    pdf.addobj_given_num(
      (struct_tree_objnum, @pdf.PdfObject::Dictionary(new_entries)),
    )
    Some(struct_tree_objnum)
  }
}
