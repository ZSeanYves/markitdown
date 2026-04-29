///|
fn funtype_of_function(fun : PdfFunction) -> Int {
  match fun.func {
    PdfFunctionKind::Interpolation(_) => 2
    PdfFunctionKind::Stitching(_) => 3
    PdfFunctionKind::Sampled(_) => 0
    PdfFunctionKind::Calculator(_) => 4
  }
}

///|
fn max_value_for_bits(bits : Int) -> Int {
  let mut value = 0
  for _ in 0..<bits {
    value = (value << 1) | 1
  }
  value
}

///|
fn write_bits(
  data : @pdfio.MutableBytes,
  bit_pos : Ref[Int],
  bits : Int,
  value : Int,
) -> Unit {
  if bits <= 0 {
    return
  }
  let mut i = bits - 1
  while true {
    let bit = (value >> i) & 1
    if bit == 1 {
      let byte_index = bit_pos.val / 8
      let bit_index = 7 - bit_pos.val % 8
      let existing = @pdfio.bget_unsafe(data, byte_index)
      @pdfio.bset_unsafe(data, byte_index, existing | (1 << bit_index))
    }
    bit_pos.val = bit_pos.val + 1
    if i == 0 {
      break
    }
    i = i - 1
  }
}

///|
fn sampled_bytes(samples : Array[Int], bits : Int) -> @pdfio.MutableBytes {
  if bits <= 0 {
    return @pdfio.mkbytes(0)
  }
  let total_bits = samples.length() * bits
  let byte_len = if total_bits == 0 { 0 } else { (total_bits + 7) / 8 }
  let data = @pdfio.mkbytes(byte_len)
  let bit_pos = Ref::new(0)
  let max_value = max_value_for_bits(bits)
  for sample in samples {
    let clamped = if sample < 0 {
      0
    } else if sample > max_value {
      max_value
    } else {
      sample
    }
    write_bits(data, bit_pos, bits, clamped)
  }
  data
}

///|
fn entries_of_interpolation(i : Interpolation) -> Array[(String, PdfObject)] {
  [
    ("/C0", PdfObject::Array(i.c0.map(x => @pdf.ToPdfNumber::to_pdf_number(x)))),
    ("/C1", PdfObject::Array(i.c1.map(x => @pdf.ToPdfNumber::to_pdf_number(x)))),
    ("/N", @pdf.ToPdfNumber::to_pdf_number(i.n)),
  ]
}

///|
fn entries_of_stitching(
  pdf : @pdf.Pdf,
  s : Stitching,
) -> Array[(String, PdfObject)] {
  let numbers = s.functions.map(fun => PdfObject::Indirect(
    pdf.addobj(fun.to_pdf_object(pdf)),
  ))
  [
    ("/Functions", PdfObject::Array(numbers)),
    (
      "/Bounds",
      PdfObject::Array(s.bounds.map(x => @pdf.ToPdfNumber::to_pdf_number(x))),
    ),
    (
      "/Encode",
      PdfObject::Array(
        s.stitch_encode.map(x => @pdf.ToPdfNumber::to_pdf_number(x)),
      ),
    ),
  ]
}

///|
fn extra_entries_of_function(
  pdf : @pdf.Pdf,
  fun : PdfFunction,
) -> Array[(String, PdfObject)] {
  match fun.func {
    PdfFunctionKind::Interpolation(i) => entries_of_interpolation(i)
    PdfFunctionKind::Stitching(s) => entries_of_stitching(pdf, s)
    PdfFunctionKind::Sampled(_) => []
    PdfFunctionKind::Calculator(_) => []
  }
}
