///|
fn apply_namechanges_to_destination_nametree(
  pdf : @pdf.Pdf,
  changes : Array[(String, String)],
) -> Unit raise {
  let changes_map : Map[String, String] = Map::new(capacity=changes.length())
  for pair in changes {
    changes_map.set(pair.0, pair.1)
  }
  fn rewrite_string(s : String) -> String {
    match changes_map.get(s) {
      Some(r) => r
      None => {
        @pdfe.log(
          "apply_namechanges_to_destination_nametree: destination not found: \{s}\n",
        )
        s
      }
    }
  }

  fn pairs_of_array(
    values : Array[PdfObject],
  ) -> Array[(PdfObject, PdfObject)]? {
    if values.length() % 2 == 1 {
      return None
    }
    let out = Array::new(capacity=values.length() / 2)
    for i = 0; i + 1 < values.length(); i = i + 2 {
      out.push((values[i], values[i + 1]))
    }
    Some(out)
  }

  fn rewrite(dict : PdfObject) -> PdfObject {
    let entries = match dict {
      PdfObject::Dictionary(e) => e
      _ => return dict
    }
    let mut updated = entries
    match lookup("/Names", updated) {
      Some(PdfObject::Array(values)) =>
        match pairs_of_array(values) {
          Some(pairs) => {
            let updated_pairs = pairs.map(pair => match pair {
              (PdfObject::String(s), obj) =>
                (PdfObject::String(rewrite_string(s)), obj)
              _ => pair
            })
            let rebuilt = Array::new(capacity=values.length())
            for pair in updated_pairs {
              rebuilt.push(pair.0)
              rebuilt.push(pair.1)
            }
            updated = add_entry(updated, "/Names", PdfObject::Array(rebuilt))
          }
          None => @pdfe.log("Warning: malformed /Names")
        }
      _ => ()
    }
    match lookup("/Limits", updated) {
      Some(PdfObject::Array([PdfObject::String(a), PdfObject::String(b)])) =>
        updated = add_entry(
          updated,
          "/Limits",
          PdfObject::Array([
            PdfObject::String(rewrite_string(a)),
            PdfObject::String(rewrite_string(b)),
          ]),
        )
      _ => ()
    }
    match lookup("/Kids", updated) {
      Some(PdfObject::Array(kids)) =>
        for kid in kids {
          match kid {
            PdfObject::Indirect(i) =>
              pdf.addobj_given_num(
                (i, rewrite(pdf.direct(PdfObject::Indirect(i)))),
              )
            _ => ()
          }
        }
      _ => ()
    }
    PdfObject::Dictionary(updated)
  }

  let catalog = pdf.catalog_of_pdf()
  match pdf.lookup_direct("/Names", catalog) {
    Some(PdfObject::Dictionary(d)) =>
      match lookup("/Dests", d) {
        Some(PdfObject::Dictionary(dest_dict)) => {
          let newdest = rewrite(PdfObject::Dictionary(dest_dict))
          let newcatalog = catalog.add_entry("/Dests", newdest)
          pdf.addobj_given_num((pdf.root, newcatalog))
        }
        Some(PdfObject::Indirect(i)) =>
          pdf.addobj_given_num((i, rewrite(pdf.direct(PdfObject::Indirect(i)))))
        _ => ()
      }
    _ => ()
  }
}

///|
fn apply_namechanges_at_destination_callsites(
  pdf : @pdf.Pdf,
  changes : Array[(String, String)],
  allchanges : Array[(String, String)],
) -> Unit {
  let changes_map : Map[String, String] = Map::new(capacity=changes.length())
  for pair in changes {
    changes_map.set(pair.0, pair.1)
  }
  let allchanges_map : Map[String, String] = Map::new(
    capacity=allchanges.length(),
  )
  for i in (allchanges.length() - 1)>=..0 {
    let pair = allchanges[i]
    allchanges_map.set(pair.0, pair.1)
  }
  fn rewrite_string(s : String) -> String {
    match changes_map.get(s) {
      Some(r) => r
      None =>
        match allchanges_map.get(s) {
          Some(r) => r
          None => s
        }
    }
  }

  fn f(obj : PdfObject) -> PdfObject {
    match obj {
      PdfObject::Dictionary(entries) => {
        let updated = Array::new(capacity=entries.length())
        for entry in entries {
          updated.push((entry.0, f(entry.1)))
        }
        let updated = match lookup("/S", updated) {
          Some(PdfObject::Name(n)) if n.equal_string_bytes("/GoTo") =>
            match lookup("/D", updated) {
              Some(PdfObject::String(s)) =>
                add_entry(updated, "/D", PdfObject::String(rewrite_string(s)))
              _ => updated
            }
          _ => updated
        }
        match lookup("/Dest", updated) {
          Some(PdfObject::String(s)) =>
            PdfObject::Dictionary(
              add_entry(updated, "/Dest", PdfObject::String(rewrite_string(s))),
            )
          _ => PdfObject::Dictionary(updated)
        }
      }
      PdfObject::Array(values) => @pdf.recurse_array(f, values)
      _ => obj
    }
  }

  pdf.objselfmap(f)
  pdf.trailerdict = f(pdf.trailerdict)
}

///|
fn merge_pdfs_rename_name_trees(
  names : Array[String],
  pdfs : Array[@pdf.Pdf],
) -> Unit raise {
  let pairs = combine(names, pdfs)
  pairs.sort_by((a, b) => String::compare(a.0, b.0))
  let groups = collate(pairs, (a, b) => String::compare(a.0, b.0))
  let unique_pdfs = groups.map(group => match group {
    [(_, pdf), ..] => pdf
    [] => raise @pdf.PdfError::Msg("merge_pdfs_rename_name_trees: empty group")
  })
  let pdfs_and_nametrees = unique_pdfs.map(pdf => {
    let catalog = pdf.catalog_of_pdf()
    match pdf.lookup_direct("/Names", catalog) {
      Some(d) =>
        match pdf.lookup_direct("/Dests", d) {
          Some(PdfObject::Dictionary(dict)) =>
            (pdf, Some(PdfObject::Dictionary(dict)))
          _ => (pdf, None)
        }
      _ => (pdf, None)
    }
  })
  let name_lists = pdfs_and_nametrees.map(pair => match pair.1 {
    Some(tree) =>
      (pair.0, @pdftree.PdfTree::new(pair.0).read_name_tree(tree).map(p => p.0))
    None => (pair.0, [])
  })
  fn worked(values : Array[(@pdf.Pdf, Array[(String, String)])]) -> Bool {
    let all = flatten(values.map(pair => pair.1.map(item => item.1)))
    setify_strings(all).length() == all.length()
  }

  let mut num = -1
  let mut renamed = name_lists.map(pair => (
    pair.0,
    pair.1.map(name => (name, name)),
  ))
  while !worked(renamed) {
    num = num + 1
    let indexes = ilist(num, num + renamed.length() - 1)
    let updated = Array::new(capacity=renamed.length())
    for entry in combine(indexes, renamed) {
      let (index, pair) = entry
      let suffix = "-f" + index.to_string()
      let mapped = pair.1.map(item => (item.0, item.0 + suffix))
      updated.push((pair.0, mapped))
    }
    renamed = updated
  }
  for pair in renamed {
    apply_namechanges_to_destination_nametree(pair.0, pair.1)
  }
  let allchanges = flatten(renamed.map(pair => pair.1))
  for pair in renamed {
    apply_namechanges_at_destination_callsites(pair.0, pair.1, allchanges)
  }
}
