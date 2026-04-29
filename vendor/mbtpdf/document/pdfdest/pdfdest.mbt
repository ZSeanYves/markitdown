///|
type PdfObject = @pdf.PdfObject

///|
/// Target pages for destinations.
pub(all) enum TargetPage {
  PageObject(Int)
  OtherDocPageNumber(Int)
} derive(Debug)

///|
/// Destinations (and actions).
pub(all) enum Destination {
  Action(PdfObject)
  NullDestination
  NamedDestination(@pdf.PdfName)
  StringDestination(String)
  XYZ(TargetPage, Double?, Double?, Double?)
  Fit(TargetPage)
  FitH(TargetPage, Double?)
  FitV(TargetPage, Double?)
  FitR(TargetPage, Double, Double, Double, Double)
  FitB(TargetPage)
  FitBH(TargetPage, Double?)
  FitBV(TargetPage, Double?)
}

///|
fn TargetPage::read(obj : PdfObject) -> TargetPage? {
  match obj {
    Indirect(i) => Some(PageObject(i))
    Integer(i) => Some(OtherDocPageNumber(i))
    _ => None
  }
}

///|
fn option_getnum(pdf : @pdf.Pdf, obj : PdfObject) -> Double? raise {
  match obj {
    Null => None
    _ => Some(pdf.getnum(obj))
  }
}

///|
fn read_array_destination(
  pdf : @pdf.Pdf,
  arr : Array[PdfObject],
) -> Destination? raise {
  match arr {
    [page, Name(name), left, top, zoom] if name.equal_string_bytes("/XYZ") =>
      match TargetPage::read(page) {
        Some(p) =>
          Some(
            XYZ(
              p,
              option_getnum(pdf, left),
              option_getnum(pdf, top),
              option_getnum(pdf, zoom),
            ),
          )
        None => None
      }
    [page, Name(name), left, top] if name.equal_string_bytes("/XYZ") =>
      match TargetPage::read(page) {
        Some(p) =>
          Some(XYZ(p, option_getnum(pdf, left), option_getnum(pdf, top), None))
        None => None
      }
    [page, Name(name), left] if name.equal_string_bytes("/XYZ") =>
      match TargetPage::read(page) {
        Some(p) => Some(XYZ(p, option_getnum(pdf, left), None, None))
        None => None
      }
    [page, Name(name), top] if name.equal_string_bytes("/FitH") =>
      match TargetPage::read(page) {
        Some(p) => Some(FitH(p, option_getnum(pdf, top)))
        None => None
      }
    [page, Name(name), left] if name.equal_string_bytes("/FitV") =>
      match TargetPage::read(page) {
        Some(p) => Some(FitV(p, option_getnum(pdf, left)))
        None => None
      }
    [page, Name(name), top] if name.equal_string_bytes("/FitBH") =>
      match TargetPage::read(page) {
        Some(p) => Some(FitBH(p, option_getnum(pdf, top)))
        None => None
      }
    [page, Name(name), left] if name.equal_string_bytes("/FitBV") =>
      match TargetPage::read(page) {
        Some(p) => Some(FitBV(p, option_getnum(pdf, left)))
        None => None
      }
    [page, Name(name)] if name.equal_string_bytes("/Fit") =>
      match TargetPage::read(page) {
        Some(p) => Some(Fit(p))
        None => None
      }
    [page, Name(name)] if name.equal_string_bytes("/FitB") =>
      match TargetPage::read(page) {
        Some(p) => Some(FitB(p))
        None => None
      }
    [page, Name(name), left, bottom, right, top] if name.equal_string_bytes(
        "/FitR",
      ) =>
      match TargetPage::read(page) {
        Some(p) =>
          Some(
            FitR(
              p,
              pdf.getnum(left),
              pdf.getnum(bottom),
              pdf.getnum(right),
              pdf.getnum(top),
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
/// Read a destination given a PDF and destination object.
pub fn Destination::read(
  pdf : @pdf.Pdf,
  pdfobject : PdfObject,
  shallow? : Bool = false,
) -> Destination raise {
  let resolved = pdf.direct(pdfobject)
  match resolved {
    Dictionary(_) =>
      match pdf.lookup_direct("/D", resolved) {
        Some(dest) => Destination::read(pdf, dest, shallow~)
        None => NullDestination
      }
    Array(arr) =>
      match read_array_destination(pdf, arr) {
        Some(dest) => dest
        None => {
          @pdfe.log(
            "Warning: Could not read destination \{resolved.to_string()}\n",
          )
          NullDestination
        }
      }
    Name(name) =>
      if shallow {
        NamedDestination(name)
      } else {
        match pdf.lookup_direct("/Root", pdf.trailerdict) {
          Some(catalog) =>
            match pdf.lookup_direct("/Dests", catalog) {
              Some(dests) =>
                match pdf.lookup_direct(name.to_string_bytes(), dests) {
                  Some(dest) => Destination::read(pdf, dest, shallow~)
                  None => NamedDestination(name)
                }
              None => NamedDestination(name)
            }
          None => raise @pdf.PdfError::Msg("read_destination: no catalog")
        }
      }
    String(s) =>
      if shallow {
        StringDestination(s)
      } else {
        let rootdict = pdf.lookup_obj(pdf.root)
        match pdf.lookup_direct("/Names", rootdict) {
          Some(namedict) =>
            match pdf.lookup_direct("/Dests", namedict) {
              Some(destsdict) =>
                match pdf.nametree_lookup(String(s), destsdict) {
                  None => StringDestination(s)
                  Some(dest) => Destination::read(pdf, dest, shallow~)
                }
              _ => StringDestination(s)
            }
          _ => StringDestination(s)
        }
      }
    _ => {
      @pdfe.log("Warning: Could not read destination \{resolved.to_string()}\n")
      NullDestination
    }
  }
}

///|
fn TargetPage::to_pdf_object(self : TargetPage) -> PdfObject {
  match self {
    PageObject(i) => Indirect(i)
    OtherDocPageNumber(i) => Integer(i)
  }
}

///|
fn pos_null(value : Double?) -> PdfObject {
  match value {
    None => Null
    Some(v) => Real(v)
  }
}

///|
/// Write a destination to a PdfObject.
pub fn Destination::to_pdf_object(self : Destination) -> PdfObject {
  match self {
    Action(a) => a
    NullDestination => Null
    NamedDestination(name) => Name(name)
    StringDestination(s) => String(s)
    XYZ(p, left, top, zoom) =>
      Array([
        p.to_pdf_object(),
        Name(@pdf.PdfName::of_string("/XYZ")),
        pos_null(left),
        pos_null(top),
        pos_null(zoom),
      ])
    Fit(p) => Array([p.to_pdf_object(), Name(@pdf.PdfName::of_string("/Fit"))])
    FitH(p, top) =>
      Array([
        p.to_pdf_object(),
        Name(@pdf.PdfName::of_string("/FitH")),
        pos_null(top),
      ])
    FitV(p, left) =>
      Array([
        p.to_pdf_object(),
        Name(@pdf.PdfName::of_string("/FitV")),
        pos_null(left),
      ])
    FitR(p, left, bottom, right, top) =>
      Array([
        p.to_pdf_object(),
        Name(@pdf.PdfName::of_string("/FitR")),
        Real(left),
        Real(bottom),
        Real(right),
        Real(top),
      ])
    FitB(p) =>
      Array([p.to_pdf_object(), Name(@pdf.PdfName::of_string("/FitB"))])
    FitBH(p, top) =>
      Array([
        p.to_pdf_object(),
        Name(@pdf.PdfName::of_string("/FitBH")),
        pos_null(top),
      ])
    FitBV(p, left) =>
      Array([
        p.to_pdf_object(),
        Name(@pdf.PdfName::of_string("/FitBV")),
        pos_null(left),
      ])
  }
}

///|
fn clip_pair(pair : (Double, Double)) -> (Double, Double) {
  let (a, b) = pair
  let clip = fn(v : Double) -> Double {
    if v < -32768.0 {
      -32768.0
    } else if v > 32768.0 {
      32768.0
    } else {
      v
    }
  }
  (clip(a), clip(b))
}

///|
/// Transform a destination by a matrix.
pub fn Destination::transform(
  self : Destination,
  pdf : @pdf.Pdf,
  t : @pdftransform.TransformMatrix,
) -> Destination raise {
  match self {
    FitH(PageObject(i), Some(top)) => {
      let (_, top) = clip_pair(t.apply((0.0, top)))
      FitH(PageObject(i), Some(top))
    }
    FitV(PageObject(i), Some(left)) => {
      let (left, _) = clip_pair(t.apply((left, 0.0)))
      FitV(PageObject(i), Some(left))
    }
    FitBH(PageObject(i), Some(top)) => {
      let (_, top) = clip_pair(t.apply((0.0, top)))
      FitBH(PageObject(i), Some(top))
    }
    FitBV(PageObject(i), Some(left)) => {
      let (left, _) = clip_pair(t.apply((left, 0.0)))
      FitBV(PageObject(i), Some(left))
    }
    XYZ(PageObject(i), Some(left), Some(top), zoom) => {
      let (left, top) = clip_pair(t.apply((left, top)))
      XYZ(PageObject(i), Some(left), Some(top), zoom)
    }
    XYZ(PageObject(i), None, Some(top), zoom) => {
      let (_, top) = clip_pair(t.apply((0.0, top)))
      XYZ(PageObject(i), None, Some(top), zoom)
    }
    XYZ(PageObject(i), Some(left), None, zoom) => {
      let (left, _) = clip_pair(t.apply((left, 0.0)))
      XYZ(PageObject(i), Some(left), None, zoom)
    }
    FitR(PageObject(i), left, bottom, right, top) => {
      let (left, top) = clip_pair(t.apply((left, top)))
      let (right, bottom) = clip_pair(t.apply((right, bottom)))
      FitR(PageObject(i), left, bottom, right, top)
    }
    Action(a) =>
      match (pdf.lookup_direct("/S", a), pdf.lookup_direct("/D", a)) {
        (Some(Name(name)), Some(d)) if name.equal_string_bytes("/GoTo") => {
          let transformed = Destination::read(pdf, d, shallow=true).transform(
            pdf, t,
          )
          Action(a.add_entry("/D", transformed.to_pdf_object()))
        }
        _ => Action(a)
      }
    _ => self
  }
}
