///|
/// Prepend operators to a page.
pub fn Page::prepend_operators(
  self : Page,
  pdf : @pdf.Pdf,
  ops : Array[@pdfops.Op],
  fast? : Bool = false,
) -> Page raise {
  if fast {
    {
      content: [@pdfops.Op::stream_of_ops(ops)] + self.content,
      mediabox: self.mediabox,
      resources: self.resources,
      rotate: self.rotate,
      rest: self.rest,
    }
  } else {
    let old_ops = @pdfops.Op::parse_operators(pdf, self.resources, self.content)
    {
      content: [@pdfops.Op::stream_of_ops(ops + old_ops)],
      mediabox: self.mediabox,
      resources: self.resources,
      rotate: self.rotate,
      rest: self.rest,
    }
  }
}

///|
/// Add stack operators to a content stream to ensure it is composeable.
pub fn Page::protect_ops(ops : Array[@pdfops.Op]) -> Array[@pdfops.Op] {
  let mut qs = 0
  let mut bigqs = 0
  for op in ops {
    match (op : @pdfops.Op) {
      Opq => qs = qs + 1
      OpQ => bigqs = bigqs + 1
      _ => ()
    }
  }
  let deficit = if qs > bigqs { qs - bigqs } else { 0 }
  if deficit != 0 {
    @pdfe.log("Q Deficit was nonzero. Fixing. \{deficit}\n")
  }
  let result : Array[@pdfops.Op] = if deficit == 0 {
    []
  } else {
    Array::make(deficit, OpQ)
  }
  result
}

///|
/// Postpend operators to a page.
pub fn Page::postpend_operators(
  self : Page,
  pdf : @pdf.Pdf,
  ops : Array[@pdfops.Op],
  fast? : Bool = false,
) -> Page raise {
  if fast {
    let wrapped : Array[@pdfops.Op] = Array::new()
    wrapped.push(Opq)
    wrapped.append(ops[:])
    wrapped.push(OpQ)
    {
      content: self.content + [@pdfops.Op::stream_of_ops(wrapped)],
      mediabox: self.mediabox,
      resources: self.resources,
      rotate: self.rotate,
      rest: self.rest,
    }
  } else {
    let existing_ops = @pdfops.Op::parse_operators(
      pdf,
      self.resources,
      self.content,
    )
    if existing_ops.length() == 0 {
      {
        content: [@pdfops.Op::stream_of_ops(ops)],
        mediabox: self.mediabox,
        resources: self.resources,
        rotate: self.rotate,
        rest: self.rest,
      }
    } else {
      let protected_ops = Page::protect_ops(existing_ops)
      let combined : Array[@pdfops.Op] = Array::new()
      combined.push(Opq)
      combined.append(existing_ops[:])
      combined.append(protected_ops[:])
      combined.push(OpQ)
      combined.append(ops[:])
      {
        content: [@pdfops.Op::stream_of_ops(combined)],
        mediabox: self.mediabox,
        resources: self.resources,
        rotate: self.rotate,
        rest: self.rest,
      }
    }
  }
}
