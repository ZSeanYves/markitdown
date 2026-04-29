# pdftransform

2D affine transformation matrices for PDF graphics.

## Overview

The `pdftransform` package provides:

- Affine transformation matrices (translate, scale, rotate, shear)
- Matrix composition and inversion
- Transform points through matrices
- Decomposition and recomposition of transforms

## TransformMatrix

The 2D affine transformation matrix:

```mbt nocheck
///|
pub(all) struct TransformMatrix {
  a : Double // scale x
  b : Double // shear y
  c : Double // shear x
  d : Double // scale y
  e : Double // translate x
  f : Double // translate y
}
```

Represents the matrix:
```
| a  b  0 |
| c  d  0 |
| e  f  1 |
```

### Identity Matrix

```mbt check
///|
test "identity matrix" {
  let m = @pdftransform.TransformMatrix::identity()
  inspect(m.a, content="1")
  inspect(m.d, content="1")
  inspect(m.e, content="0")
}
```

## Creating Transforms

### Translation

```mbt check
///|
test "translate" {
  let m = @pdftransform.TransformMatrix::translate(10.0, 20.0)
  inspect(m.e, content="10")
  inspect(m.f, content="20")
}
```

### Scaling

```mbt nocheck
// Scale by (sx, sy) around center point

///|
let m = @pdftransform.TransformMatrix::scale((0.0, 0.0), 2.0, 2.0)
```

### Rotation

```mbt nocheck
// Rotate by angle (radians) around center point

///|
let m = @pdftransform.TransformMatrix::rotate((0.0, 0.0), 1.5708) // 90 degrees
```

### Shearing

```mbt nocheck
// Horizontal shear

///|
let m = @pdftransform.TransformMatrix::shear_x((0.0, 0.0), 0.5)

// Vertical shear

///|
let m = @pdftransform.TransformMatrix::shear_y((0.0, 0.0), 0.5)
```

## Transform Operations

### TransformOp Enum

```mbt nocheck
///|
pub(all) enum TransformOp {
  Scale((Double, Double), Double, Double) // center, sx, sy
  Rotate((Double, Double), Double) // center, angle
  Translate(Double, Double) // tx, ty
  ShearX((Double, Double), Double) // center, factor
  ShearY((Double, Double), Double) // center, factor
}
```

### Composing Operations

```mbt nocheck
// Build transform from operations

///|
let tr = @pdftransform.Transform::identity().compose(
  @pdftransform.TransformOp::Translate(100.0, 100.0),
)
```

### Appending Transforms

```mbt nocheck
///|
let combined = tr1.append(tr2)
```

## Matrix Operations

### Composition

```mbt check
///|
test "matrix compose" {
  let t1 = @pdftransform.TransformMatrix::translate(10.0, 0.0)
  let t2 = @pdftransform.TransformMatrix::translate(0.0, 20.0)
  let combined = t1.compose(t2)
  inspect(combined.e, content="10")
  inspect(combined.f, content="20")
}
```

### Inversion

```mbt nocheck
try {
  let inv = m.invert!()
  // Use inverted matrix...
} catch {
  @pdftransform.NonInvertable => println("Matrix not invertible")
}
```

### Converting Operations to Matrix

```mbt nocheck
///|
let op = @pdftransform.TransformOp::Translate(50.0, 50.0)

///|
let matrix = op.to_matrix()
```

## Transforming Points

### With Matrix

```mbt check
///|
test "matrix applies to point" {
  let m = @pdftransform.TransformMatrix::translate(10.0, 20.0)
  let (x, y) = m.apply((5.0, 5.0))
  inspect(x, content="15")
  inspect(y, content="25")
}
```

### With Transform

```mbt nocheck
let (new_x, new_y) = tr.apply((x, y))
```

## Decomposition

Extract scale, rotation, shear, and translation from a matrix:

```mbt nocheck
let (scale, aspect, rotation, shear, tx, ty) = m.decompose()
```

## Recomposition

Rebuild a matrix from components:

```mbt nocheck
///|
let m = @pdftransform.TransformMatrix::recompose(
  scale, aspect, rotation, shear, tx, ty,
)
```

## Debug Utilities

```mbt check
///|
test "matrix to_string" {
  let m = @pdftransform.TransformMatrix::identity()
  let s = m.to_string()
  assert_true(s.contains("1"))
}
```
