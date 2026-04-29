///|
fn new_dests(pdf : @pdf.Pdf, pdfs : Array[@pdf.Pdf]) -> Int? raise {
  let dests = Array::new(capacity=pdfs.length())
  for src in pdfs {
    let catalog = src.catalog_of_pdf()
    match src.lookup_direct("/Dests", catalog) {
      Some(PdfObject::Dictionary(d)) => dests.push(d)
      _ => ()
    }
  }
  match dests {
    [] => None
    _ => {
      let merged = PdfObject::Dictionary(flatten(dests))
      Some(pdf.addobj(merged))
    }
  }
}

///|
fn merge_pdfs_renumber(
  names : Array[String],
  pdfs : Array[@pdf.Pdf],
) -> Array[@pdf.Pdf] raise {
  if names.length() != pdfs.length() {
    raise @pdf.PdfError::Msg("merge_pdfs_renumber: length mismatch")
  }
  let table : Map[String, @pdf.Pdf] = Map::new(capacity=names.length())
  for i in 0..<names.length() {
    table.set(names[i], pdfs[i])
  }
  let unique_names = Array::new(capacity=table.length())
  let unique_pdfs = Array::new(capacity=table.length())
  for name, pdf in table {
    unique_names.push(name)
    unique_pdfs.push(pdf)
  }
  let renumbered = @pdf.renumber_pdfs(unique_pdfs)
  let mapping : Map[String, @pdf.Pdf] = Map::new(capacity=unique_names.length())
  for i, name in unique_names {
    mapping.set(name, renumbered[i])
  }
  let out = Array::new(capacity=names.length())
  for name in names {
    match mapping.get(name) {
      Some(pdf) => out.push(pdf)
      None => raise @pdf.PdfError::Msg("merge_pdfs_renumber: missing mapping")
    }
  }
  out
}

///|
fn merge_namedicts(pdf : @pdf.Pdf, pdfs : Array[@pdf.Pdf]) -> Int raise {
  let names : Array[String] = [
    "/Dests", "/AP", "/JavaScript", "/Pages", "/Templates", "/IDS", "/URLS", "/EmbeddedFiles",
    "/AlternatePresentations", "/Renditions",
  ]
  let trees = Array::new(capacity=names.length())
  for name in names {
    let trees_for_name = Array::new(capacity=pdfs.length())
    for src in pdfs {
      let catalog = src.catalog_of_pdf()
      match src.lookup_direct("/Names", catalog) {
        Some(dict) =>
          match src.lookup_direct(name, dict) {
            Some(tree) => trees_for_name.push(tree)
            None => ()
          }
        None => ()
      }
    }
    if trees_for_name.length() > 0 {
      trees.push((name, trees_for_name))
    }
  }
  let new_entries = Array::new(capacity=trees.length())
  let tree_ctx = @pdftree.PdfTree::new(pdf)
  for pair in trees {
    let merged = tree_ctx.merge_name_trees_no_clash(pair.1)
    let num = pdf.addobj(merged)
    new_entries.push((pair.0, PdfObject::Indirect(num)))
  }
  let newdict = PdfObject::Dictionary(new_entries)
  pdf.addobj(newdict)
}
