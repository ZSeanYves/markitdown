///|
pub struct PptxInspectReport {
  slide_count : Int
  object_count : Int
  shape_count : Int
  picture_count : Int
  table_count : Int
  unsupported_count : Int
  media_count : Int
  notes_count : Int
  comment_count : Int
  warning_count : Int
}

///|
pub fn inspect_pptx_document(doc : PptxDocument) -> PptxInspectReport {
  let object_count : Ref[Int] = { val: 0 }
  let shape_count : Ref[Int] = { val: 0 }
  let picture_count : Ref[Int] = { val: 0 }
  let table_count : Ref[Int] = { val: 0 }
  let unsupported_count : Ref[Int] = { val: 0 }
  let notes_count : Ref[Int] = { val: 0 }
  let comment_count : Ref[Int] = { val: 0 }
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
  object_count : Ref[Int],
  shape_count : Ref[Int],
  picture_count : Ref[Int],
  table_count : Ref[Int],
  unsupported_count : Ref[Int],
) -> Unit {
  for obj in objects {
    object_count.val += 1
    match obj {
      PptxObject::Shape(_) => shape_count.val += 1
      PptxObject::Picture(_) => picture_count.val += 1
      PptxObject::Table(_) => table_count.val += 1
      PptxObject::Unsupported(_) => unsupported_count.val += 1
      PptxObject::Group(group) =>
        count_objects(
          group.children,
          object_count,
          shape_count,
          picture_count,
          table_count,
          unsupported_count,
        )
      PptxObject::Chart(_)
      | PptxObject::SmartArt(_)
      | PptxObject::Ole(_)
      | PptxObject::Connector(_) => ()
    }
  }
}
