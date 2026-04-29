///|
fn clear_object_stream_ids(ids : Map[Int, Int]) -> Unit {
  ids.clear()
}

///|
fn split_into_groups(items : Array[Int], group_size : Int) -> Array[Array[Int]] {
  let groups = Array::new()
  let mut index = 0
  while index < items.length() {
    let group = Array::new()
    let mut i = 0
    while i < group_size && index < items.length() {
      group.push(items[index])
      index = index + 1
      i = i + 1
    }
    groups.push(group)
  }
  groups
}

///|
fn generate_object_stream_hints(
  pdf : @pdf.Pdf,
  preserve_existing : Bool,
  encrypting : Bool,
) -> Unit {
  if !preserve_existing {
    clear_object_stream_ids(pdf.objects.object_stream_ids)
  }
  let indirect_lengths : Map[Int, Bool] = Map::new(
    capacity=pdf.objects.objects.length(),
  )
  let entries = @pdf.pdfobjmap_bindings(pdf.objects.objects)
  for pair in entries {
    let objnum = pair.0
    let obj = pdf.lookup_obj(objnum)
    match obj {
      PdfObject::Stream(r) => {
        let (dict, _) = r.val
        match pdf.lookup_direct("/Length", dict) {
          Some(PdfObject::Indirect(i)) => indirect_lengths.set(i, true)
          _ => ()
        }
      }
      _ => ()
    }
  }
  let candidates = Array::new()
  for pair in entries {
    let objnum = pair.0
    if pdf.objects.object_stream_ids.get(objnum) is Some(_) {
      continue
    }
    if indirect_lengths.get(objnum) is Some(_) {
      continue
    }
    if encrypting && objnum == pdf.root {
      continue
    }
    let obj = pdf.lookup_obj(objnum)
    match obj {
      PdfObject::Stream(_) => ()
      _ => candidates.push(objnum)
    }
  }
  candidates.sort_by((a, b) => a - b)
  let groups = split_into_groups(candidates, 250)
  let mut stream_id = pdf.objects.max_obj_num + 1
  for group in groups {
    let this_id = stream_id
    stream_id = stream_id + 1
    for objnum in group {
      pdf.objects.object_stream_ids.set(objnum, this_id)
    }
  }
}

///|
fn build_object_stream_groups(pdf : @pdf.Pdf) -> Array[(Int, Array[Int])] {
  let groups : Map[Int, Array[Int]] = Map::new(
    capacity=pdf.objects.object_stream_ids.length(),
  )
  for pair in pdf.objects.object_stream_ids.to_array() {
    let objnum = pair.0
    let stream_id = pair.1
    if pdf.objects.objects.get(objnum) is None {
      pdf.objects.object_stream_ids.remove(objnum)
      continue
    }
    let obj = pdf.lookup_obj(objnum)
    match obj {
      PdfObject::Stream(_) => {
        pdf.objects.object_stream_ids.remove(objnum)
        continue
      }
      _ => ()
    }
    let list = match groups.get(stream_id) {
      Some(existing) => existing
      None => {
        let created = Array::new()
        groups.set(stream_id, created)
        created
      }
    }
    list.push(objnum)
  }
  let groups_array = groups.to_array()
  groups_array.sort_by((a, b) => a.0 - b.0)
  for pair in groups_array {
    pair.1.sort_by((a, b) => a - b)
  }
  groups_array
}

///|
fn bake_object_streams(
  pdf : @pdf.Pdf,
  compress : Bool,
  groups : Array[(Int, Array[Int])],
) -> Map[Int, (Int, Int)] raise {
  let entries : Map[Int, (Int, Int)] = Map::new(
    capacity=pdf.objects.object_stream_ids.length(),
  )
  for group in groups {
    let stream_id = group.0
    let objs = group.1
    if objs.length() == 0 {
      continue
    }
    let object_strings = Array::new()
    let offsets = Array::new()
    let mut offset = 0
    let mut index = 0
    for objnum in objs {
      let obj = pdf.lookup_obj(objnum)
      let s = PdfWrite::new().string_of_pdf(obj) + " "
      object_strings.push(s)
      offsets.push(offset)
      entries.set(objnum, (stream_id, index))
      pdf.objects.object_stream_ids.set(objnum, stream_id)
      offset = offset + s.length()
      index = index + 1
    }
    for objnum in objs {
      pdf.removeobj(objnum)
    }
    let header = StringBuilder::new()
    for i in 0..<objs.length() {
      header.write_string(objs[i].to_string())
      header.write_char(' ')
      header.write_string(offsets[i].to_string())
      header.write_char(' ')
    }
    let header_str = header.to_string()
    let first = header_str.length()
    let data_sb = StringBuilder::new()
    data_sb.write_string(header_str)
    for s in object_strings {
      data_sb.write_string(s)
    }
    let data = @pdfio.bytes_of_string(data_sb.to_string())
    let dict = PdfObject::Dictionary([
      ("/Type", PdfObject::Name(@pdf.PdfName::of_string("/ObjStm"))),
      ("/Length", PdfObject::Integer(@pdfio.bytes_size(data))),
      ("/N", PdfObject::Integer(objs.length())),
      ("/First", PdfObject::Integer(first)),
    ])
    let mut stream_obj = PdfObject::Stream(
      Ref::new((dict, @pdf.Stream::Got(data))),
    )
    if compress {
      let encoded = @pdfcodec.PdfCodec::new().encode_flate(data)
      if @pdfio.bytes_size(encoded) + 20 < @pdfio.bytes_size(data) {
        let dict_with_filter = dict.add_entry(
          "/Filter",
          PdfObject::Name(@pdf.PdfName::of_string("/FlateDecode")),
        )
        let dict_with_length = dict_with_filter.add_entry(
          "/Length",
          PdfObject::Integer(@pdfio.bytes_size(encoded)),
        )
        stream_obj = PdfObject::Stream(
          Ref::new((dict_with_length, @pdf.Stream::Got(encoded))),
        )
      }
    }
    pdf.addobj_given_num((stream_id, stream_obj))
  }
  entries
}
