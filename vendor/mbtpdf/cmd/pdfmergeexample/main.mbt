///|
fn merge_pdfs(pdfs : Array[@pdf.Pdf]) -> @pdf.Pdf raise {
  let renumbered = @pdf.renumber_pdfs(pdfs)
  let mut max_minor = 0
  for pdf in renumbered {
    if pdf.minor > max_minor {
      max_minor = pdf.minor
    }
  }
  let pages = Array::new()
  for pdf in renumbered {
    let pagelist = @pdfpage.PdfPageDoc::new(pdf).pages_of_pagetree()
    pages.append(pagelist[:])
  }
  let pdf = @pdf.Pdf::empty()
  for src in renumbered {
    src.objiter((k, v) => pdf.addobj_given_num((k, v)))
  }
  let (pdf, pagetree_num) = @pdfpage.PdfPageDoc::new(pdf).add_pagetree(pages)
  let pdf = @pdfpage.PdfPageDoc::new(pdf).add_root(pagetree_num, [])
  pdf.remove_unreferenced()
  let pdf : @pdf.Pdf = {
    major: 1,
    minor: max_minor,
    root: pdf.root,
    objects: pdf.objects,
    trailerdict: pdf.trailerdict,
    was_linearized: pdf.was_linearized,
    saved_encryption: pdf.saved_encryption,
  }
  pdf
}

///|
async fn main {
  run(@env.args())
}

///|
pub async fn run(args : Array[String], quiet? : Bool = false) -> Unit {
  let argc = args.length()
  if argc < 3 {
    if !quiet {
      println("Syntax: pdfmerge <inputs> <output>")
    }
    return
  }
  let out_name = args[argc - 1]
  let in_names = Array::new()
  for i, name in args {
    if i == 0 || i == argc - 1 {
      continue
    }
    in_names.push(name)
  }
  try {
    let pdfs = Array::new()
    for name in in_names {
      pdfs.push(@pdfreadfs.PdfReadFs::new().pdf_of_file(None, None, name))
    }
    let merged = merge_pdfs(pdfs)
    @pdfwritefs.PdfWriteFs::new().pdf_to_file(merged, out_name)
  } catch {
    err =>
      if !quiet {
        println("Failed to merge files.")
        println(err)
      }
  }
}
