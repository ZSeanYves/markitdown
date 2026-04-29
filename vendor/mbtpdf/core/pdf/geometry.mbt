///|
/// Return a float from a PDF number.
pub fn Pdf::getnum(self : Pdf, obj : PdfObject) -> Double raise {
  match obj {
    Real(a) => a
    Integer(a) => Double::from_int(a)
    Indirect(i) => self.getnum(self.lookup_obj(i))
    _ => raise PdfError::Msg("getnum: not a number")
  }
}

///|
/// Parse a PDF rectangle structure into min x, min y, max x, max y.
pub fn Pdf::parse_rectangle(
  self : Pdf,
  obj : PdfObject,
) -> (Double, Double, Double, Double) raise {
  match obj {
    Array(vals) =>
      if vals.length() == 4 {
        let x = self.getnum(vals[0])
        let y = self.getnum(vals[1])
        let x2 = self.getnum(vals[2])
        let y2 = self.getnum(vals[3])
        let min_x = if x < x2 { x } else { x2 }
        let min_y = if y < y2 { y } else { y2 }
        let max_x = if x > x2 { x } else { x2 }
        let max_y = if y > y2 { y } else { y2 }
        (min_x, min_y, max_x, max_y)
      } else {
        raise PdfError::Msg("parse_rectangle: expected 4 elements")
      }
    _ => raise PdfError::Msg("parse_rectangle: not an array")
  }
}

///|
/// Parse a transform matrix, or return the identity if missing.
pub fn Pdf::parse_matrix(
  self : Pdf,
  key : String,
  dict : PdfObject,
) -> @pdftransform.TransformMatrix raise {
  match self.lookup_direct(key, dict) {
    None | Some(Null) => @pdftransform.TransformMatrix::identity()
    Some(Array(vals)) =>
      if vals.length() != 6 {
        raise PdfError::Msg("Malformed matrix")
      } else {
        let a = self.getnum(vals[0])
        let b = self.getnum(vals[1])
        let c = self.getnum(vals[2])
        let d = self.getnum(vals[3])
        let e = self.getnum(vals[4])
        let f = self.getnum(vals[5])
        { a, b, c, d, e, f }
      }
    _ => raise PdfError::Msg("Malformed matrix")
  }
}

///|
/// Build a matrix object.
pub fn make_matrix(tr : @pdftransform.TransformMatrix) -> PdfObject {
  Array([Real(tr.a), Real(tr.b), Real(tr.c), Real(tr.d), Real(tr.e), Real(tr.f)])
}

///|
fn fmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn fmax(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Transform a rectangle by a matrix, returning the bounding rectangle.
pub fn Pdf::transform_rect(
  self : Pdf,
  transform : @pdftransform.TransformMatrix,
  rect : PdfObject,
) -> PdfObject raise {
  let (minx, miny, maxx, maxy) = self.parse_rectangle(rect)
  let (x0, y0) = transform.apply((minx, miny))
  let (x1, y1) = transform.apply((maxx, maxy))
  let (x2, y2) = transform.apply((minx, maxy))
  let (x3, y3) = transform.apply((maxx, miny))
  let minx = fmin(fmin(x0, x1), fmin(x2, x3))
  let miny = fmin(fmin(y0, y1), fmin(y2, y3))
  let maxx = fmax(fmax(x0, x1), fmax(x2, x3))
  let maxy = fmax(fmax(y0, y1), fmax(y2, y3))
  Array([Real(minx), Real(miny), Real(maxx), Real(maxy)])
}

///|
fn Pdf::transform_quadpoint_single(
  self : Pdf,
  transform : @pdftransform.TransformMatrix,
  qp : Array[PdfObject],
) -> Array[PdfObject] raise {
  if qp.length() != 8 {
    @pdfe.log("Malformed /QuadPoints format: must be a multiple of 8 entries\n")
    return qp
  }
  let x1 = self.getnum(qp[0])
  let y1 = self.getnum(qp[1])
  let x2 = self.getnum(qp[2])
  let y2 = self.getnum(qp[3])
  let x3 = self.getnum(qp[4])
  let y3 = self.getnum(qp[5])
  let x4 = self.getnum(qp[6])
  let y4 = self.getnum(qp[7])
  let (x1, y1) = transform.apply((x1, y1))
  let (x2, y2) = transform.apply((x2, y2))
  let (x3, y3) = transform.apply((x3, y3))
  let (x4, y4) = transform.apply((x4, y4))
  [
    Real(x1),
    Real(y1),
    Real(x2),
    Real(y2),
    Real(x3),
    Real(y3),
    Real(x4),
    Real(y4),
  ]
}

///|
fn[T] split_into(values : Array[T], size : Int) -> Array[Array[T]] {
  let out = Array::new(capacity=(values.length() + size - 1) / size)
  for i = 0; i < values.length(); i = i + size {
    let part = Array::new(capacity=size)
    for j in 0..<size {
      if i + j < values.length() {
        part.push(values[i + j])
      }
    }
    out.push(part)
  }
  out
}

///|
/// Transform quadpoints by a matrix.
pub fn Pdf::transform_quadpoints(
  self : Pdf,
  transform : @pdftransform.TransformMatrix,
  qp : PdfObject,
) -> PdfObject raise {
  match qp {
    Array(qps) => {
      let out = Array::new(capacity=qps.length())
      for chunk in split_into(qps, 8) {
        out.append(self.transform_quadpoint_single(transform, chunk))
      }
      Array(out)
    }
    _ => {
      @pdfe.log("Unknown or malformed /QuadPoints format\n")
      qp
    }
  }
}
