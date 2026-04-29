///|
fn merge_bookmarks(
  changes : Array[(Int, Int)],
  pdfs : Array[@pdf.Pdf],
  ranges : Array[Array[Int]],
  pdf : @pdf.Pdf,
) -> @pdf.Pdf {
  try {
    let tree_ctx = @pdftree.PdfTree::new(pdf)
    let dest_nametree = {
      let catalog = pdf.catalog_of_pdf()
      let oldstyle = match pdf.lookup_direct("/Dests", catalog) {
        Some(d) => tree_ctx.read_name_tree(d)
        _ => []
      }
      let newstyle = match pdf.lookup_direct("/Names", catalog) {
        Some(d) =>
          match pdf.lookup_direct("/Dests", d) {
            Some(d2) => tree_ctx.read_name_tree(d2)
            _ => []
          }
        _ => []
      }
      let out = Array::new(capacity=oldstyle.length() + newstyle.length())
      out.append(oldstyle[:])
      out.append(newstyle[:])
      out
    }
    fn process_mark(
      oldnums : Array[Int],
      changes : Array[(Int, Int)],
      mark : @pdfmarks.Bookmark,
    ) -> @pdfmarks.Bookmark? raise {
      let changes_rev = changes.map(pair => (pair.1, pair.0))
      fn pageobjectnumber_of_target(t : @pdfdest.Destination) -> Int raise {
        match t {
          NullDestination => 0
          NamedDestination(name) => {
            // Spec-wise this resolves via the legacy catalog `/Dests` dictionary,
            // but some PDFs (and tests) effectively behave like the string-based
            // name tree. Be tolerant and fall back to the name tree if needed.
            let key = name.to_string_bytes()
            let direct_dest = match
              pdf.lookup_direct("/Dests", pdf.catalog_of_pdf()) {
              Some(dests) => pdf.lookup_direct(key, dests)
              None => None
            }
            match direct_dest {
              Some(dest) => {
                let r = pageobjectnumber_of_target(
                  @pdfdest.Destination::read(pdf, dest),
                )
                match lookup(r, changes_rev) {
                  Some(old) => old
                  None => r
                }
              }
              None =>
                match lookup(key, dest_nametree) {
                  Some(dest) =>
                    match pdf.lookup_direct("/D", dest) {
                      Some(dest_obj) => {
                        let r = pageobjectnumber_of_target(
                          @pdfdest.Destination::read(pdf, dest_obj),
                        )
                        match lookup(r, changes_rev) {
                          Some(old) => old
                          None => r
                        }
                      }
                      None => 0
                    }
                  None => 0
                }
            }
          }
          StringDestination(s) =>
            // String destinations resolve via the name tree at `/Names` `/Dests`.
            match lookup(s, dest_nametree) {
              Some(dest) =>
                match pdf.lookup_direct("/D", dest) {
                  Some(dest_obj) => {
                    let r = pageobjectnumber_of_target(
                      @pdfdest.Destination::read(pdf, dest_obj),
                    )
                    match lookup(r, changes_rev) {
                      Some(old) => old
                      None => r
                    }
                  }
                  None => 0
                }
              None => 0
            }
          Action(a) =>
            match pdf.lookup_direct("/S", a) {
              Some(PdfObject::Name(n)) if n.equal_string_bytes("/GoTo") =>
                match pdf.lookup_direct("/D", a) {
                  Some(PdfObject::String(s)) =>
                    match lookup(s, dest_nametree) {
                      Some(dest) =>
                        match pdf.lookup_direct("/D", dest) {
                          Some(dest_obj) => {
                            let r = pageobjectnumber_of_target(
                              @pdfdest.Destination::read(pdf, dest_obj),
                            )
                            match lookup(r, changes_rev) {
                              Some(old) => old
                              None => r
                            }
                          }
                          None => 0
                        }
                      None => 0
                    }
                  _ => 0
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
              OtherDocPageNumber(_) => 0
              PageObject(i) => i
            }
        }
      }

      let objnum = pageobjectnumber_of_target(mark.target)
      let is_null = (mark.target : @pdfdest.Destination) is NullDestination
      if contains_int(oldnums, objnum) || is_null {
        let change_targetpage = fn(
          target : @pdfdest.TargetPage,
          newnum : Int,
        ) -> @pdfdest.TargetPage {
          match target {
            OtherDocPageNumber(n) => OtherDocPageNumber(n)
            PageObject(_) => PageObject(newnum)
          }
        }
        let change_target_destinationpage = fn(
          target : @pdfdest.Destination,
          newnum : Int,
        ) -> @pdfdest.Destination {
          match target {
            Action(a) => Action(a)
            NullDestination => NullDestination
            NamedDestination(s) => NamedDestination(s)
            StringDestination(s) => StringDestination(s)
            XYZ(tp, a, b, c) => XYZ(change_targetpage(tp, newnum), a, b, c)
            Fit(tp) => Fit(change_targetpage(tp, newnum))
            FitH(tp, a) => FitH(change_targetpage(tp, newnum), a)
            FitV(tp, a) => FitV(change_targetpage(tp, newnum), a)
            FitR(tp, a, b, c, d) =>
              FitR(change_targetpage(tp, newnum), a, b, c, d)
            FitB(tp) => FitB(change_targetpage(tp, newnum))
            FitBH(tp, a) => FitBH(change_targetpage(tp, newnum), a)
            FitBV(tp, a) => FitBV(change_targetpage(tp, newnum), a)
          }
        }
        let new_target : @pdfdest.Destination = if is_null {
          NullDestination
        } else {
          let newnum = lookup_fail(
            objnum, changes, "merge_bookmarks: missing change",
          )
          change_target_destinationpage(mark.target, newnum)
        }
        Some({
          level: mark.level,
          text: mark.text,
          target: new_target,
          isopen: mark.isopen,
          colour: mark.colour,
          flags: mark.flags,
        })
      } else {
        None
      }
    }

    let bookmarks = Array::new()
    let mut offset = 0
    for i in 0..<pdfs.length() {
      let range = ranges[i]
      let subset_changes = slice(changes, offset, range.length())
      let subset_oldnums = subset_changes.map(pair => pair.0)
      let marks = @pdfmarks.PdfMarks::new(pdfs[i]).read_bookmarks(
        preserve_actions=true,
      )
      for mark in marks {
        match process_mark(subset_oldnums, subset_changes, mark) {
          Some(updated) => bookmarks.push(updated)
          None => ()
        }
      }
      offset = offset + range.length()
    }
    @pdfmarks.PdfMarks::new(pdf).add_bookmarks(bookmarks)
  } catch {
    _ => {
      @pdfe.log("failure in merge_bookmarks\n")
      pdf
    }
  }
}
