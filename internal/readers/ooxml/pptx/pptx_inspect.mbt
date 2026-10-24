///|
pub struct PptxInspectReport {
  slide_count : Int32
  object_count : Int32
  shape_count : Int32
  picture_count : Int32
  table_count : Int32
  unsupported_count : Int32
  media_count : Int32
  notes_count : Int32
  comment_count : Int32
  warning_count : Int32
}

///|
pub fn inspect_pptx_document(doc : PptxDocument) -> PptxInspectReport {
  let object_count : Ref[Int32] = { val: 0, }
  let shape_count : Ref[Int32] = { val: 0, }
  let picture_count : Ref[Int32] = { val: 0, }
  let table_count : Ref[Int32] = { val: 0, }
  let unsupported_count : Ref[Int32] = { val: 0, }
  let notes_count : Ref[Int32] = { val: 0, }
  let comment_count : Ref[Int32] = { val: 0, }
  for slide in doc.slides {
    count_objects(
      slide.objects,
      object_count,
      shape_count,
      picture_count,
      table_count,
      unsupported_count,
    )
    match slide.notes {
      Some(_) => notes_count.val += 1
      None => ()
    }
    comment_count.val += slide.comments.length()
  }
  {
    slide_count: doc.slides.length(),
    object_count: object_count.val,
    shape_count: shape_count.val,
    picture_count: picture_count.val,
    table_count: table_count.val,
    unsupported_count: unsupported_count.val,
    media_count: doc.media.length(),
    notes_count: notes_count.val,
    comment_count: comment_count.val,
    warning_count: doc.warnings.length(),
  }
}

///|
fn count_objects(
  objects : Array[PptxObject],
  object_count : Ref[Int32],
  shape_count : Ref[Int32],
  picture_count : Ref[Int32],
  table_count : Ref[Int32],
  unsupported_count : Ref[Int32],
) -> Unit {
  for obj in objects {
    object_count.val += 1
    match obj {
      Shape(_) => shape_count.val += 1
      Picture(_) => picture_count.val += 1
      Table(_) => table_count.val += 1
      Unsupported(_) => unsupported_count.val += 1
      Group(group) =>
        count_objects(
          group.children,
          object_count,
          shape_count,
          picture_count,
          table_count,
          unsupported_count,
        )
      Chart(_) | SmartArt(_) | Ole(_) | Connector(_) => ()
    }
  }
}
