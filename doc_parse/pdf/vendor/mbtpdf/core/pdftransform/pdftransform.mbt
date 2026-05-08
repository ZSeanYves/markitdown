///|
/// A single transformation operation.
pub(all) enum TransformOp {
  Scale((Double, Double), Double, Double)
  Rotate((Double, Double), Double)
  Translate(Double, Double)
  ShearX((Double, Double), Double)
  ShearY((Double, Double), Double)
} derive(Debug)

///|
/// A list of transformations, stored with the most recent op at the head.
pub struct Transform {
  ops : Array[TransformOp]
} derive(Debug)

///|
/// A transformation matrix (a c e / b d f / 0 0 1).
pub(all) struct TransformMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Debug)

///|
/// The identity transform.
pub fn Transform::identity() -> Transform {
  { ops: [] }
}

///|
/// Create a transform from an array of ops.
pub fn Transform::new(ops : Array[TransformOp]) -> Transform {
  { ops, }
}

///|
/// The identity matrix.
pub fn TransformMatrix::identity() -> TransformMatrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
fn point_eq(a : (Double, Double), b : (Double, Double)) -> Bool {
  a.0 == b.0 && a.1 == b.1
}

///|
fn concat_ops(
  a : Array[TransformOp],
  b : Array[TransformOp],
) -> Array[TransformOp] {
  let out = Array::new(capacity=a.length() + b.length())
  for item in a {
    out.push(item)
  }
  for item in b {
    out.push(item)
  }
  out
}

///|
fn tail_ops(tr : Array[TransformOp]) -> Array[TransformOp] {
  let out = Array::new(
    capacity=if tr.length() > 0 { tr.length() - 1 } else { 0 },
  )
  let mut i = 1
  while i < tr.length() {
    out.push(tr[i])
    i = i + 1
  }
  out
}

///|
fn safe_float(value : Double) -> Double {
  if value == 0.0 || value.is_nan() || value.is_inf() {
    0.0
  } else {
    value
  }
}

///|
fn pi() -> Double {
  4.0 * @math.atan(1.0)
}

///|
fn string_of_op(op : TransformOp) -> String {
  match op {
    TransformOp::Scale((x, y), sx, sy) =>
      "Scale about (\{x}, \{y}) by \{sx} in x and \{sy} in y\n"
    TransformOp::Rotate((x, y), angle) =>
      "Rotate by \{angle} about (\{x}, \{y})\n"
    TransformOp::Translate(dx, dy) => "Translate by \{dx}, \{dy}\n"
    TransformOp::ShearX((x, y), factor) =>
      "Shear in X about (\{x}, \{y}), proportionality constant \{factor}\n"
    TransformOp::ShearY((x, y), factor) =>
      "Shear in Y about (\{x}, \{y}), proportionality constant \{factor}\n"
  }
}

///|
/// Make a string of a transform for debug purposes.
pub fn Transform::to_string(self : Transform) -> String {
  let sb = StringBuilder::new()
  for op in self.ops[:].rev_iter() {
    sb.write_string(string_of_op(op))
  }
  sb.to_string()
}

///|
/// String of a transformation matrix.
pub fn TransformMatrix::to_string(self : TransformMatrix) -> String {
  "\{self.a}, \{self.b}, \{self.c}, \{self.d}, \{self.e}, \{self.f}"
}

///|
/// Compose a transformation operation onto an existing transform.
pub fn Transform::compose(self : Transform, op : TransformOp) -> Transform {
  if self.ops.length() == 0 {
    return { ops: [op] }
  }
  let head = self.ops[0]
  match (head, op) {
    (TransformOp::Translate(dx, dy), TransformOp::Translate(dx2, dy2)) =>
      {
        ops: concat_ops(
          [TransformOp::Translate(dx + dx2, dy + dy2)],
          tail_ops(self.ops),
        ),
      }
    (TransformOp::Scale(p, sx, sy), TransformOp::Scale(p2, sx2, sy2)) =>
      if point_eq(p, p2) {
        {
          ops: concat_ops(
            [TransformOp::Scale(p, sx * sx2, sy * sy2)],
            tail_ops(self.ops),
          ),
        }
      } else {
        { ops: concat_ops([op], self.ops) }
      }
    (TransformOp::Rotate(p, a), TransformOp::Rotate(p2, a2)) =>
      if point_eq(p, p2) {
        {
          ops: concat_ops([TransformOp::Rotate(p, a + a2)], tail_ops(self.ops)),
        }
      } else {
        { ops: concat_ops([op], self.ops) }
      }
    (TransformOp::ShearX(p, a), TransformOp::ShearX(p2, a2)) =>
      if point_eq(p, p2) {
        {
          ops: concat_ops([TransformOp::ShearX(p, a + a2)], tail_ops(self.ops)),
        }
      } else {
        { ops: concat_ops([op], self.ops) }
      }
    (TransformOp::ShearY(p, a), TransformOp::ShearY(p2, a2)) =>
      if point_eq(p, p2) {
        {
          ops: concat_ops([TransformOp::ShearY(p, a + a2)], tail_ops(self.ops)),
        }
      } else {
        { ops: concat_ops([op], self.ops) }
      }
    _ => { ops: concat_ops([op], self.ops) }
  }
}

///|
/// Append two transforms (perform b then a).
pub fn Transform::append(self : Transform, other : Transform) -> Transform {
  { ops: concat_ops(self.ops, other.ops) }
}

///|
/// Compose two matrices. Applying the result is equivalent to applying m then m'.
pub fn TransformMatrix::compose(
  self : TransformMatrix,
  m : TransformMatrix,
) -> TransformMatrix {
  {
    a: self.a * m.a + self.c * m.b,
    c: self.a * m.c + self.c * m.d,
    e: self.a * m.e + self.c * m.f + self.e,
    b: self.b * m.a + self.d * m.b,
    d: self.b * m.c + self.d * m.d,
    f: self.b * m.e + self.d * m.f + self.f,
  }
}

///|
/// Matrix inversion. Raises NonInvertable if no inverse.
pub fn TransformMatrix::invert(
  self : TransformMatrix,
) -> TransformMatrix raise NonInvertable {
  let divisor = self.a * self.d - self.b * self.c
  if divisor == 0.0 {
    raise NonInvertable::NonInvertable
  }
  let det = 1.0 / divisor
  if det == 0.0 || det.is_nan() || det.is_inf() {
    raise NonInvertable::NonInvertable
  }
  {
    a: det * self.d,
    b: det * -self.b,
    c: det * -self.c,
    d: det * self.a,
    e: det * (self.c * self.f - self.d * self.e),
    f: det * (self.b * self.e - self.a * self.f),
  }
}

///|
/// Make a translation matrix.
pub fn TransformMatrix::translate(tx : Double, ty : Double) -> TransformMatrix {
  { a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: tx, f: ty }
}

///|
/// Make a scale matrix about a center point.
pub fn TransformMatrix::scale(
  center : (Double, Double),
  sx : Double,
  sy : Double,
) -> TransformMatrix {
  let translate = TransformMatrix::translate(-center.0, -center.1)
  let translate_back = TransformMatrix::translate(center.0, center.1)
  let scale_matrix = { a: sx, b: 0.0, c: 0.0, d: sy, e: 0.0, f: 0.0 }
  translate_back.compose(scale_matrix.compose(translate))
}

///|
/// Make a rotation matrix about a center point.
pub fn TransformMatrix::rotate(
  center : (Double, Double),
  angle : Double,
) -> TransformMatrix {
  let translate = TransformMatrix::translate(-center.0, -center.1)
  let translate_back = TransformMatrix::translate(center.0, center.1)
  let rotation_matrix = {
    a: @math.cos(angle),
    b: @math.sin(angle),
    c: -@math.sin(angle),
    d: @math.cos(angle),
    e: 0.0,
    f: 0.0,
  }
  translate_back.compose(rotation_matrix.compose(translate))
}

///|
/// Matrix to shear in x about a point.
pub fn TransformMatrix::shear_x(
  center : (Double, Double),
  factor : Double,
) -> TransformMatrix {
  let translate = TransformMatrix::translate(-center.0, -center.1)
  let translate_back = TransformMatrix::translate(center.0, center.1)
  let shear_matrix = { a: 1.0, b: 0.0, c: factor, d: 1.0, e: 0.0, f: 0.0 }
  translate_back.compose(shear_matrix.compose(translate))
}

///|
/// Matrix to shear in y about a point.
pub fn TransformMatrix::shear_y(
  center : (Double, Double),
  factor : Double,
) -> TransformMatrix {
  let translate = TransformMatrix::translate(-center.0, -center.1)
  let translate_back = TransformMatrix::translate(center.0, center.1)
  let shear_matrix = { a: 1.0, b: factor, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
  translate_back.compose(shear_matrix.compose(translate))
}

///|
/// Make a matrix from a single transformation operation.
pub fn TransformOp::to_matrix(self : TransformOp) -> TransformMatrix {
  match self {
    TransformOp::Scale(center, sx, sy) => TransformMatrix::scale(center, sx, sy)
    TransformOp::Rotate(center, angle) => TransformMatrix::rotate(center, angle)
    TransformOp::Translate(dx, dy) => TransformMatrix::translate(dx, dy)
    TransformOp::ShearX(center, factor) =>
      TransformMatrix::shear_x(center, factor)
    TransformOp::ShearY(center, factor) =>
      TransformMatrix::shear_y(center, factor)
  }
}

///|
/// Make a matrix from a transform.
pub fn Transform::to_matrix(self : Transform) -> TransformMatrix {
  let mut acc = TransformMatrix::identity()
  for op in self.ops {
    acc = op.to_matrix().compose(acc)
  }
  acc
}

///|
/// Transform a coordinate by a given transformation matrix.
pub fn TransformMatrix::apply(
  self : TransformMatrix,
  point : (Double, Double),
) -> (Double, Double) {
  let x = point.0
  let y = point.1
  (x * self.a + y * self.c + self.e, x * self.b + y * self.d + self.f)
}

///|
/// Transform a coordinate by a given transform.
pub fn Transform::apply(
  self : Transform,
  point : (Double, Double),
) -> (Double, Double) {
  let mut x = point.0
  let mut y = point.1
  for op in self.ops[:].rev_iter() {
    match op {
      TransformOp::Scale((cx, cy), sx, sy) => {
        let dx = x - cx
        let dy = y - cy
        x = dx * sx + cx
        y = dy * sy + cy
      }
      TransformOp::Rotate((cx, cy), angle) => {
        let cosine = @math.cos(angle)
        let sine = @math.sin(angle)
        let dx = x - cx
        let dy = y - cy
        let nx = dx * cosine + dy * -sine
        let ny = dx * sine + dy * cosine
        x = nx + cx
        y = ny + cy
      }
      TransformOp::Translate(dx, dy) => {
        x = x + dx
        y = y + dy
      }
      TransformOp::ShearX((cx, cy), factor) => {
        let dx = x - cx
        let dy = y - cy
        x = dx + dy * factor + cx
        y = dy + cy
      }
      TransformOp::ShearY((cx, cy), factor) => {
        let dx = x - cx
        let dy = y - cy
        x = dx + cx
        y = dx * factor + dy + cy
      }
    }
  }
  (x, y)
}

///|
/// Decompose a transformation matrix into scale, aspect, rotation, shear,
/// translation in x, translation in y.
pub fn TransformMatrix::decompose(
  self : TransformMatrix,
) -> (Double, Double, Double, Double, Double, Double) {
  let axb = self.a * self.d - self.c * self.b
  let moda = (self.a * self.a + self.b * self.b).sqrt()
  let modb = (self.c * self.c + self.d * self.d).sqrt()
  let adotb = self.a * self.c + self.b * self.d
  let scale = axb / moda
  let abs_scale = scale.abs()
  let aspect = if abs_scale == 0.0 { 1.0 } else { moda / abs_scale }
  let rotation = @math.atan2(self.b, self.a)
  let shear = if moda * modb == 0.0 {
    0.0
  } else {
    pi() / 2.0 - @math.acos(adotb / (moda * modb))
  }
  (
    safe_float(scale),
    safe_float(aspect),
    safe_float(rotation),
    safe_float(shear),
    safe_float(self.e),
    safe_float(self.f),
  )
}

///|
/// Recompose a matrix from components.
pub fn TransformMatrix::recompose(
  scale : Double,
  aspect : Double,
  rotation : Double,
  shear : Double,
  tx : Double,
  ty : Double,
) -> TransformMatrix {
  let scale_aspect_shear = {
    a: scale.abs() * aspect,
    b: 0.0,
    c: scale * @math.tan(shear),
    d: scale,
    e: 0.0,
    f: 0.0,
  }
  let rotated = TransformMatrix::rotate((0.0, 0.0), rotation).compose(
    scale_aspect_shear,
  )
  TransformMatrix::translate(tx, ty).compose(rotated)
}

///|
/// Exception raised if a matrix is non-invertible.
pub suberror NonInvertable {
  NonInvertable
}
