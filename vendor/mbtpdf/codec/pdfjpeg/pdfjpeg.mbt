///|
/// JPEG data extraction helpers.

///|
pub struct PdfJpeg {
  unit : Unit
}

///|
pub fn PdfJpeg::new() -> PdfJpeg {
  { unit: () }
}

///|
/// Return JPEG data starting at the current input position, leaving the input
/// ready at the byte following the JPEG data.
pub fn PdfJpeg::get_jpeg_data(
  _self : PdfJpeg,
  input : @pdfio.Input,
) -> @pdfio.MutableBytes raise {
  let (output, data) = @pdfio.Output::of_bytes(4096)
  let mut fin = false
  let mut last = 0
  while !fin {
    let x = (input.input_byte)()
    if x == @pdfio.no_more {
      raise Failure::Failure("Could not read JPEG data - end of stream")
    }
    if x == 0xD9 {
      if last == 0xFF {
        fin = true
      } else {
        last = 0xD9
      }
      (output.output_byte)(0xD9)
    } else {
      last = x
      (output.output_byte)(x)
    }
  }
  output.extract_bytes(data)
}
