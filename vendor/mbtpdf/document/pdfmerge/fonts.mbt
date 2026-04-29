///|
fn stream_compare(pdf : @pdf.Pdf, x : Int, y : Int) -> Int {
  try {
    let xobj = pdf.lookup_obj(x)
    let yobj = pdf.lookup_obj(y)
    xobj.getstream()
    yobj.getstream()
    match (xobj, yobj) {
      (PdfObject::Stream(rx), PdfObject::Stream(ry)) => {
        let (dict, stream_x) = rx.val
        let (dict2, stream_y) = ry.val
        match (stream_x, stream_y) {
          (@pdf.Stream::Got(bytes), @pdf.Stream::Got(bytes2)) => {
            let dict_s = dict.to_string()
            let dict_s2 = dict2.to_string()
            let cmp = String::compare(dict_s, dict_s2)
            if cmp != 0 {
              cmp
            } else {
              compare_bytes(bytes, bytes2)
            }
          }
          _ => 0
        }
      }
      _ => 0
    }
  } catch {
    _ => 0
  }
}

///|
/// Remove duplicate fonts from a PDF.
pub fn PdfMergeDoc::remove_duplicate_fonts(self : PdfMergeDoc) -> Unit {
  let pdf = self.pdf
  let streamobjs = Array::new(capacity=pdf.objects.objects.length())
  pdf.objiter((objnum, obj) => match obj {
    PdfObject::Stream(_) => streamobjs.push(objnum)
    _ => ()
  })
  let sorted = streamobjs
  sorted.sort_by((a, b) => stream_compare(pdf, a, b))
  let groups = collate(sorted, (a, b) => stream_compare(pdf, a, b))
  let toprocess = groups.filter(group => group.length() > 1)
  if toprocess.length() == 0 {
    return
  }
  let mut current = pdf
  for group in toprocess {
    match group {
      [keep, .. rest] => {
        let changetable : Map[Int, Int] = Map::new(capacity=rest.length())
        for item in rest {
          changetable.set(item, keep)
        }
        current = current.renumber(changetable)
      }
      _ => ()
    }
  }
  let existing = pdf.objects.objects.to_array()
  for entry in existing {
    pdf.objects.objects.remove(entry.0)
  }
  for entry in current.objects.objects {
    pdf.objects.objects.set(entry.0, entry.1)
  }
  let existing_ids = pdf.objects.object_stream_ids.to_array()
  for entry in existing_ids {
    pdf.objects.object_stream_ids.remove(entry.0)
  }
  for entry in current.objects.object_stream_ids {
    pdf.objects.object_stream_ids.set(entry.0, entry.1)
  }
  pdf.objects.max_obj_num = current.objects.max_obj_num
  pdf.trailerdict = current.trailerdict
}
