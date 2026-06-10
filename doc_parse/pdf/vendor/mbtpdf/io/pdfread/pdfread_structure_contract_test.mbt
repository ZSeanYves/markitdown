///|
fn structure_contract_concat_bytes(
  parts : Array[@pdfio.MutableBytes],
) -> @pdfio.MutableBytes {
  let mut total = 0
  for part in parts {
    total = total + @pdfio.bytes_size(part)
  }
  let out = @pdfio.mkbytes(total)
  let mut pos = 0
  for part in parts {
    let len = @pdfio.bytes_size(part)
    for i in 0..<len {
      @pdfio.bset_unsafe(out, pos, @pdfio.bget_unsafe(part, i))
      pos = pos + 1
    }
  }
  out
}

///|
fn structure_contract_xref_entry(
  typ : Int,
  field2 : Int,
  field3 : Int,
) -> Array[Int] {
  [typ, field2 / 256, field2 % 256, field3]
}

///|
fn structure_contract_xref_stream_pdf(
  truncated? : Bool = false,
) -> @pdfio.MutableBytes {
  let header = "%PDF-1.5\n"
  let obj1 = "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
  let obj2 = "2 0 obj\n<< /Type /Pages /Count 1 /Kids [3 0 R] >>\nendobj\n"
  let obj3 = "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] >>\nendobj\n"
  let offset1 = @pdfio.bytes_of_string(header).length()
  let offset2 = offset1 + @pdfio.bytes_of_string(obj1).length()
  let offset3 = offset2 + @pdfio.bytes_of_string(obj2).length()
  let offset4 = offset3 + @pdfio.bytes_of_string(obj3).length()
  let entries = []
  entries.append(structure_contract_xref_entry(0, 0, 0))
  entries.append(structure_contract_xref_entry(1, offset1, 0))
  entries.append(structure_contract_xref_entry(1, offset2, 0))
  entries.append(structure_contract_xref_entry(1, offset3, 0))
  entries.append(structure_contract_xref_entry(1, offset4, 0))
  let xref_data = if truncated {
    let truncated_entries = []
    for i in 0..<4 {
      truncated_entries.push(entries[i])
    }
    @pdfio.bytes_of_list(truncated_entries)
  } else {
    @pdfio.bytes_of_list(entries)
  }
  let xref_prefix = "4 0 obj\n<< /Type /XRef /Size 5 /Root 1 0 R /W [1 2 1] /Index [0 5] /Length " +
    @pdfio.bytes_size(xref_data).to_string() +
    " >>\nstream\n"
  let xref_suffix = "\nendstream\nendobj\nstartxref\n" +
    offset4.to_string() +
    "\n%%EOF\n"
  structure_contract_concat_bytes([
    @pdfio.bytes_of_string(header),
    @pdfio.bytes_of_string(obj1),
    @pdfio.bytes_of_string(obj2),
    @pdfio.bytes_of_string(obj3),
    @pdfio.bytes_of_string(xref_prefix),
    xref_data,
    @pdfio.bytes_of_string(xref_suffix),
  ])
}

///|
test "structure contract reads tiny xref stream pdf" {
  let bytes = structure_contract_xref_stream_pdf()
  let pdf = @pdfe.with_silenced_logs(fn() raise {
    @pdfread.PdfRead::new(logger=_ => ()).pdf_of_input(
      None,
      None,
      @pdfio.Input::of_bytes(bytes, source="xref-stream-contract"),
    )
  })
  assert_eq(pdf.root, 1)
  assert_true(pdf.was_linearized == false)
  assert_eq(@pdfpage.PdfPageDoc::new(pdf).endpage(), 1)
  match pdf.lookup_direct("/Type", pdf.lookup_obj(pdf.root)) {
    Some(Name(name)) if name.equal_string_bytes("/Catalog") => ()
    _ => fail("expected catalog root from xref stream")
  }
}

///|
test "structure contract fails closed on malformed xref stream and detects linearized flag" {
  let bad_bytes = structure_contract_xref_stream_pdf(truncated=true)
  let bad : Result[@pdf.Pdf, Error] = try
    @pdfe.with_silenced_logs(fn() raise {
      @pdfread.PdfRead::new(error_on_malformed=true, logger=_ => ()).pdf_of_input(
        None,
        None,
        @pdfio.Input::of_bytes(bad_bytes, source="bad-xref-stream-contract"),
      )
    })
    |> Ok
  catch {
    err => Err(err)
  }
  assert_true(bad is Err(_))
  let linearized = @pdfio.Input::of_string("%PDF-1.7\n<< /Linearized 1 >>")
  assert_true(@pdfread.PdfRead::new().is_linearized(linearized))
}
