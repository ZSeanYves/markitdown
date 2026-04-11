///|
fn horizontal_gap(a : LayoutShape, b : LayoutShape) -> Int {
  if a.right < b.shape.x {
    b.shape.x - a.right
  } else if b.right < a.shape.x {
    a.shape.x - b.right
  } else {
    0
  }
}

///|
fn vertical_gap(a : LayoutShape, b : LayoutShape) -> Int {
  if a.bottom < b.shape.y {
    b.shape.y - a.bottom
  } else if b.bottom < a.shape.y {
    a.shape.y - b.bottom
  } else {
    0
  }
}

///|
fn horizontal_overlap(a : LayoutShape, b : LayoutShape) -> Int {
  let l = max_int(a.shape.x, b.shape.x)
  let r = min_int(a.right, b.right)
  let d = r - l
  if d > 0 {
    d
  } else {
    0
  }
}

///|
fn vertical_overlap(a : LayoutShape, b : LayoutShape) -> Int {
  let t = max_int(a.shape.y, b.shape.y)
  let bt = min_int(a.bottom, b.bottom)
  let d = bt - t
  if d > 0 {
    d
  } else {
    0
  }
}

///|
fn min_x(shapes : Array[LayoutShape]) -> Int {
  if shapes.length() == 0 {
    return 0
  }

  let mut v = shapes[0].shape.x
  for i in 1..<shapes.length() {
    if shapes[i].shape.x < v {
      v = shapes[i].shape.x
    }
  }
  v
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
