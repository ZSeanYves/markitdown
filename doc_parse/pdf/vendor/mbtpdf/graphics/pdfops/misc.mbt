///|
/// Given a colourspace and bits per component, return bytes per pixel.
pub fn Op::components(
  pdf : @pdf.Pdf,
  resources : @pdf.PdfObject,
  space : @pdf.PdfObject,
) -> Int raise {
  match space {
    Name(name) => {
      let name_s = name.to_string_bytes()
      if name_s == "/CalGray" || name_s == "/DeviceGray" || name_s == "/G" {
        return 1
      }
      if name_s == "/CalRGB" || name_s == "/DeviceRGB" || name_s == "/RGB" {
        return 3
      }
      if name_s == "/CalCMYK" || name_s == "/DeviceCMYK" || name_s == "/CMYK" {
        return 4
      }
      if name_s == "/Pattern" {
        raise @pdf.PdfError::Msg("Can't use /Pattern here")
      }
      match pdf.lookup_direct("/ColorSpace", resources) {
        Some(csdict) =>
          match pdf.lookup_direct(name_s, csdict) {
            Some(space_next) => Op::components(pdf, resources, space_next)
            None => raise @pdf.PdfError::Msg("ColorSpace not found")
          }
        None => raise @pdf.PdfError::Msg("ColorSpace dict not found")
      }
    }
    Array(items) => {
      if items.length() >= 2 {
        match items[0] {
          Name(name) =>
            match name.to_string_bytes() {
              "/Lab" => if items.length() == 2 { return 3 }
              "/ICCBased" =>
                if items.length() == 2 {
                  let iccstream = items[1]
                  match pdf.lookup_direct("/N", iccstream) {
                    Some(Integer(n)) => return n
                    _ => raise @pdf.PdfError::Msg("Bad iccstream")
                  }
                }
              "/DeviceN" =>
                match items[1] {
                  Array(names) => return names.length()
                  _ => ()
                }
              "/Separation" => if items.length() == 4 { return 1 }
              "/Indexed" => return 1
              "/I" => return 1
              "/CalRGB" => if items.length() == 2 { return 3 }
              "/CalCMYK" => if items.length() == 2 { return 4 }
              "/CalGray" => if items.length() == 2 { return 1 }
              "/Pattern" =>
                if items.length() == 2 {
                  return Op::components(pdf, resources, pdf.direct(items[1]))
                }
              _ => ()
            }
          _ => ()
        }
      }
      @pdfe.log("\{space.to_string()}\n")
      raise @pdf.PdfError::Msg("Unknown colourspace")
    }
    other => {
      @pdfe.log("\{other.to_string()}\n")
      raise @pdf.PdfError::Msg("Unknown colourspace")
    }
  }
}
