///|
fn pad_int(value : Int, width : Int) -> String {
  let s = value.to_string()
  if s.length() >= width {
    s
  } else {
    "0".repeat(width - s.length()) + s
  }
}

///|
fn write_header(pdf : @pdf.Pdf, output : @pdfio.Output) -> Unit {
  (output.output_string)("%PDF-\{pdf.major}.\{pdf.minor}\n%")
  let bytes = [128, 129, 130, 131]
  for b in bytes {
    (output.output_byte)(b)
  }
  (output.output_char)('\n')
}

///|
fn bytes_required(value : Int) -> Int {
  if value <= 0 {
    return 1
  }
  let mut v = value
  let mut bytes = 0
  while v > 0 {
    bytes = bytes + 1
    v = v >> 8
  }
  bytes
}

///|
fn write_int_be(output : @pdfio.Output, value : Int, width : Int) -> Unit {
  for pos in (width - 1)>=..0 {
    let shift = pos * 8
    let byte = (value >> shift) & 0xff
    (output.output_byte)(byte)
  }
}

///|
fn build_xref_stream(
  pdf : @pdf.Pdf,
  size : Int,
  offsets : Array[Int],
  gens : Array[Int],
  used : Array[Bool],
  object_stream_entries : Map[Int, (Int, Int)],
) -> @pdf.PdfObject raise {
  let mut max_type = 1
  let mut max_field2 = 0
  let mut max_field3 = 0
  for i in 0..<size {
    let (typ, field2, field3) = match object_stream_entries.get(i) {
      Some((stream_id, index)) => (2, stream_id, index)
      None =>
        if i == 0 || !used[i] {
          (0, 0, 65535)
        } else {
          (1, offsets[i], gens[i])
        }
    }
    if typ > max_type {
      max_type = typ
    }
    if field2 > max_field2 {
      max_field2 = field2
    }
    if field3 > max_field3 {
      max_field3 = field3
    }
  }
  let w1 = bytes_required(max_type)
  let w2 = bytes_required(max_field2)
  let w3 = bytes_required(max_field3)
  let (output, buffer) = @pdfio.Output::of_bytes(256)
  for i in 0..<size {
    let (typ, field2, field3) = match object_stream_entries.get(i) {
      Some((stream_id, index)) => (2, stream_id, index)
      None =>
        if i == 0 || !used[i] {
          (0, 0, 65535)
        } else {
          (1, offsets[i], gens[i])
        }
    }
    write_int_be(output, typ, w1)
    write_int_be(output, field2, w2)
    write_int_be(output, field3, w3)
  }
  let data = output.extract_bytes(buffer)
  let dict_with_type = pdf.trailerdict.add_entry(
    "/Type",
    PdfObject::Name(@pdf.PdfName::of_string("/XRef")),
  )
  let dict_with_size = dict_with_type.add_entry(
    "/Size",
    PdfObject::Integer(size),
  )
  let dict_with_root = dict_with_size.add_entry(
    "/Root",
    PdfObject::Indirect(pdf.root),
  )
  let dict_with_w = dict_with_root.add_entry(
    "/W",
    PdfObject::Array([
      PdfObject::Integer(w1),
      PdfObject::Integer(w2),
      PdfObject::Integer(w3),
    ]),
  )
  let dict_with_length = dict_with_w.add_entry(
    "/Length",
    PdfObject::Integer(@pdfio.bytes_size(data)),
  )
  let stream_obj = PdfObject::Stream(
    Ref::new((dict_with_length, @pdf.Stream::Got(data))),
  )
  stream_obj
}

///|
/// Write a PDF to an output.
pub fn PdfWrite::pdf_to_output(
  self : PdfWrite,
  preserve_objstm? : Bool = false,
  generate_objstm? : Bool = false,
  compress_objstm? : Bool = false,
  recrypt? : String,
  encryption : Encryption?,
  build_new_id : Bool,
  pdf : @pdf.Pdf,
  output : @pdfio.Output,
) -> Unit raise {
  let mut pdf = pdf
  if build_new_id {
    pdf.change_id("")
  }
  let recrypting = match recrypt {
    Some(_) => true
    None => false
  }
  let mut encryption_value = encryption
  if recrypting {
    encryption_value = Some(dummy_encryption)
  }
  let encrypting = match encryption_value {
    Some(_) => true
    None => false
  }
  if encrypting {
    pdf.objects.object_stream_ids.remove(pdf.root)
  }
  let mut object_stream_entries : Map[Int, (Int, Int)] = Map::new()
  if preserve_objstm || generate_objstm {
    if generate_objstm {
      generate_object_stream_hints(pdf, preserve_objstm, encrypting)
    }
    let groups = build_object_stream_groups(pdf)
    if groups.length() > 0 {
      object_stream_entries = bake_object_streams(pdf, compress_objstm, groups)
    }
  }
  if !preserve_objstm && !generate_objstm {
    match encryption_value {
      Some(enc) =>
        match enc.encryption_method {
          @pdfcrypt.EncryptionMethod::AlreadyEncrypted => ()
          _ => pdf = pdf.renumber(pdf.changes())
        }
      None => ()
    }
  }
  match recrypt {
    Some(password) =>
      pdf = @pdfcrypt.PdfCrypt::new().recrypt_pdf(
        pdf,
        password,
        renumber=!(preserve_objstm || generate_objstm),
      )
    None => ()
  }
  pdf = crypt_if_necessary(pdf, encryption_value)
  let use_xref_stream = preserve_objstm || generate_objstm
  write_header(pdf, output)
  let entries = @pdf.pdfobjmap_bindings(pdf.objects.objects)
  let objnums = entries.map(pair => pair.0)
  objnums.sort_by((a, b) => a - b)
  let max_obj = pdf.objects.max_obj_num
  let size = if use_xref_stream { max_obj + 2 } else { max_obj + 1 }
  let xref_objnum = max_obj + 1
  let offsets = Array::make(size, 0)
  let gens = Array::make(size, 0)
  let used = Array::make(size, false)
  for objnum in objnums {
    if objnum == 0 || (use_xref_stream && objnum == xref_objnum) {
      continue
    }
    match pdf.objects.objects.get(objnum) {
      None => ()
      Some((_obj_ref, gen)) => {
        let offset = (output.pos_out)()
        offsets[objnum] = offset
        gens[objnum] = gen
        used[objnum] = true
        (output.output_string)("\{objnum} \{gen} obj\n")
        let obj = pdf.lookup_obj(objnum)
        write_pdf_object_to_output(self, obj, output, true, false)
        (output.output_string)("\nendobj\n")
      }
    }
  }
  let xref_start = (output.pos_out)()
  if use_xref_stream {
    offsets[xref_objnum] = xref_start
    gens[xref_objnum] = 0
    used[xref_objnum] = true
    let xref_stream = build_xref_stream(
      pdf, size, offsets, gens, used, object_stream_entries,
    )
    (output.output_string)("\{xref_objnum} 0 obj\n")
    write_pdf_object_to_output(self, xref_stream, output, true, true)
    (output.output_string)("\nendobj\n")
    (output.output_string)("startxref\n")
    (output.output_string)("\{xref_start}\n%%EOF\n")
  } else {
    (output.output_string)("xref\n")
    (output.output_string)("0 \{size}\n")
    for i in 0..<size {
      if i == 0 || !used[i] {
        (output.output_string)("0000000000 65535 f \n")
      } else {
        let line = "\{pad_int(offsets[i], 10)} \{pad_int(gens[i], 5)} n \n"
        (output.output_string)(line)
      }
    }
    (output.output_string)("trailer\n")
    let trailerdict = pdf.trailerdict
      .add_entry("/Size", PdfObject::Integer(size))
      .add_entry("/Root", PdfObject::Indirect(pdf.root))
    write_pdf_object_to_output(self, trailerdict, output, false, true)
    (output.output_string)("\nstartxref\n")
    (output.output_string)("\{xref_start}\n%%EOF\n")
  }
}
