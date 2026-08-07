///|
pub fn inspect_eml_message(message : EmlMessage) -> EmlInspectReport {
  let state : EmlInspectState = {
    part_count: 0,
    multipart_count: 0,
    text_part_count: 0,
    html_part_count: 0,
    attachment_count: 0,
    inline_image_count: 0,
    nested_message_count: 0,
    max_depth: 1,
    max_part_chars: 0,
  }
  for part in message.children {
    inspect_eml_part(part, 1, state)
  }
  {
    part_count: state.part_count,
    multipart_count: state.multipart_count,
    text_part_count: state.text_part_count,
    html_part_count: state.html_part_count,
    attachment_count: state.attachment_count,
    inline_image_count: state.inline_image_count,
    nested_message_count: state.nested_message_count,
    max_depth: state.max_depth,
    max_part_chars: state.max_part_chars,
  }
}

///|
priv struct EmlInspectState {
  mut part_count : Int
  mut multipart_count : Int
  mut text_part_count : Int
  mut html_part_count : Int
  mut attachment_count : Int
  mut inline_image_count : Int
  mut nested_message_count : Int
  mut max_depth : Int
  mut max_part_chars : Int
}

///|
fn inspect_eml_part(
  part : EmlPart,
  depth : Int,
  state : EmlInspectState,
) -> Unit {
  state.part_count += 1
  if depth > state.max_depth {
    state.max_depth = depth
  }
  if part.raw_body.length() > state.max_part_chars {
    state.max_part_chars = part.raw_body.length()
  }
  if part.summary.media_type == "multipart" {
    state.multipart_count += 1
  }
  if part.summary.mime_type == "text/plain" {
    state.text_part_count += 1
  }
  if part.summary.mime_type == "text/html" {
    state.html_part_count += 1
  }
  for attachment in part.attachments {
    state.attachment_count += 1
    if eml_attachment_is_inline_image(attachment) {
      state.inline_image_count += 1
    }
  }
  match part.child_message {
    Some(child) => {
      state.nested_message_count += 1
      for nested in child.children {
        inspect_eml_part(nested, depth + 1, state)
      }
    }
    None => ()
  }
  for child in part.children {
    inspect_eml_part(child, depth + 1, state)
  }
}

///|
fn eml_attachment_is_inline_image(attachment : EmlAttachment) -> Bool {
  attachment.mime_type == "image/png" ||
  attachment.mime_type == "image/jpeg" ||
  attachment.mime_type == "image/gif" ||
  attachment.mime_type == "image/svg+xml"
}
