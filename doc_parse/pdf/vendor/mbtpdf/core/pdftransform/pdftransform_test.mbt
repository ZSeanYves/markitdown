///|
fn assert_close(a : Double, b : Double) -> Unit raise {
  let diff = (a - b).abs()
  assert_true(diff < 0.000001)
}

///|
test "translate transform" {
  let tr = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Translate(1.0, 2.0),
  ])
  let (x, y) = tr.apply((3.0, 4.0))
  assert_close(x, 4.0)
  assert_close(y, 6.0)
}

///|
test "rotate transform" {
  let half_pi = 2.0 * @math.atan(1.0)
  let tr = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Rotate((0.0, 0.0), half_pi),
  ])
  let (x, y) = tr.apply((1.0, 0.0))
  assert_close(x, 0.0)
  assert_close(y, 1.0)
}

///|
test "invert translation matrix" {
  let m = @pdftransform.TransformMatrix::translate(5.0, -3.0)
  let inv = m.invert() catch { _ => fail("no inverse") }
  let (x, y) = inv.apply((5.0, 7.0))
  assert_close(x, 0.0)
  assert_close(y, 10.0)
}

///|
test "matrix_compose applies m then m_prime" {
  let translate = @pdftransform.TransformMatrix::translate(2.0, 3.0)
  let scale = @pdftransform.TransformMatrix::scale((0.0, 0.0), 2.0, 2.0)
  let composed = scale.compose(translate)
  let (x, y) = composed.apply((1.0, 1.0))
  assert_close(x, 6.0)
  assert_close(y, 8.0)
}

///|
test "matrix_of_transform composes in list order" {
  let tr = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Translate(2.0, 3.0),
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 3.0),
  ])
  let expected = @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 3.0)
    .to_matrix()
    .compose(
      @pdftransform.TransformOp::Translate(2.0, 3.0)
      .to_matrix()
      .compose(@pdftransform.TransformMatrix::identity()),
    )
  let actual = tr.to_matrix()
  assert_eq(actual.to_string(), expected.to_string())
}

///|
test "decompose and recompose translation" {
  let m = @pdftransform.TransformMatrix::translate(4.0, -1.0)
  let (scale, aspect, rotation, shear, tx, ty) = m.decompose()
  let recomposed = @pdftransform.TransformMatrix::recompose(
    scale, aspect, rotation, shear, tx, ty,
  )
  assert_eq(m.to_string(), recomposed.to_string())
}

///|
test "matrix_invert fails for zero scale" {
  let m = @pdftransform.TransformMatrix::scale((0.0, 0.0), 0.0, 1.0)
  let res : Result[@pdftransform.TransformMatrix, Error] = try? m.invert()
  match res {
    Err(_) => ()
    _ => fail("expected NonInvertable")
  }
}

///|
test "compose merges translation" {
  let tr = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Translate(1.0, 2.0),
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 2.0),
  ])
  let composed = tr.compose(@pdftransform.TransformOp::Translate(3.0, -1.0))
  match composed {
    {
      ops: [
        @pdftransform.TransformOp::Translate(dx, dy),
        @pdftransform.TransformOp::Scale(_, sx, sy),
      ],
    } => {
      assert_close(dx, 4.0)
      assert_close(dy, 1.0)
      assert_close(sx, 2.0)
      assert_close(sy, 2.0)
    }
    _ => fail("expected merged translation")
  }
}

///|
test "compose merges scale with same center" {
  let tr = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Scale((1.0, 1.0), 2.0, 3.0),
  ])
  let composed = tr.compose(
    @pdftransform.TransformOp::Scale((1.0, 1.0), 4.0, 5.0),
  )
  match composed {
    { ops: [@pdftransform.TransformOp::Scale((cx, cy), sx, sy)] } => {
      assert_close(cx, 1.0)
      assert_close(cy, 1.0)
      assert_close(sx, 8.0)
      assert_close(sy, 15.0)
    }
    _ => fail("expected merged scale")
  }
}

///|
test "compose keeps scale with different centers" {
  let tr = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 2.0),
  ])
  let composed = tr.compose(
    @pdftransform.TransformOp::Scale((1.0, 0.0), 3.0, 3.0),
  )
  match composed {
    {
      ops: [
        @pdftransform.TransformOp::Scale((cx, _), _, _),
        @pdftransform.TransformOp::Scale((cx2, _), _, _),
      ],
    } => {
      assert_close(cx, 1.0)
      assert_close(cx2, 0.0)
    }
    _ => fail("expected two scale ops")
  }
}

///|
test "append applies second transform first" {
  let a = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Translate(1.0, 2.0),
  ])
  let b = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 2.0),
  ])
  let combined = a.append(b)
  let (x, y) = combined.apply((1.0, 1.0))
  assert_close(x, 3.0)
  assert_close(y, 4.0)
}

///|
test "shear transforms via matrix and op" {
  let mx = @pdftransform.TransformMatrix::shear_x((0.0, 0.0), 2.0)
  let (x1, y1) = mx.apply((1.0, 1.0))
  assert_close(x1, 3.0)
  assert_close(y1, 1.0)
  let tr_x = @pdftransform.Transform::new([
    @pdftransform.TransformOp::ShearX((0.0, 0.0), 2.0),
  ])
  let (x2, y2) = tr_x.apply((1.0, 1.0))
  assert_close(x2, 3.0)
  assert_close(y2, 1.0)
  let my = @pdftransform.TransformMatrix::shear_y((0.0, 0.0), 2.0)
  let (x3, y3) = my.apply((1.0, 1.0))
  assert_close(x3, 1.0)
  assert_close(y3, 3.0)
  let tr_y = @pdftransform.Transform::new([
    @pdftransform.TransformOp::ShearY((0.0, 0.0), 2.0),
  ])
  let (x4, y4) = tr_y.apply((1.0, 1.0))
  assert_close(x4, 1.0)
  assert_close(y4, 3.0)
}

///|
test "string_of_transform orders operations" {
  let tr = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Translate(1.0, 2.0),
    @pdftransform.TransformOp::Scale((0.0, 0.0), 2.0, 2.0),
  ])
  let rendered = tr.to_string()
  let scale_idx = match rendered.find("Scale about") {
    Some(i) => i
    None => fail("expected scale line")
  }
  let translate_idx = match rendered.find("Translate by") {
    Some(i) => i
    None => fail("expected translate line")
  }
  assert_true(scale_idx < translate_idx)
}

///|
test "decompose handles zero scale" {
  let m = @pdftransform.TransformMatrix::scale((0.0, 0.0), 0.0, 0.0)
  let (scale, aspect, rotation, shear, tx, ty) = m.decompose()
  assert_close(scale, 0.0)
  assert_close(aspect, 0.0)
  assert_close(rotation, 0.0)
  assert_close(shear, 0.0)
  assert_close(tx, 0.0)
  assert_close(ty, 0.0)
}

///|
test "identity and empty compose" {
  let id = @pdftransform.Transform::identity()
  assert_eq(
    id.to_matrix().to_string(),
    @pdftransform.TransformMatrix::identity().to_string(),
  )
  let composed = id.compose(@pdftransform.TransformOp::Translate(1.0, 2.0))
  match composed {
    { ops: [@pdftransform.TransformOp::Translate(dx, dy)] } => {
      assert_close(dx, 1.0)
      assert_close(dy, 2.0)
    }
    _ => fail("expected single translate op")
  }
}

///|
test "compose merges rotate and shear when compatible" {
  let tr = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Rotate((0.0, 0.0), 1.0),
  ])
  let merged = tr.compose(@pdftransform.TransformOp::Rotate((0.0, 0.0), 2.0))
  match merged {
    { ops: [@pdftransform.TransformOp::Rotate((_, _), angle)] } =>
      assert_close(angle, 3.0)
    _ => fail("expected merged rotate")
  }
  let shearx = @pdftransform.Transform::new([
    @pdftransform.TransformOp::ShearX((1.0, 2.0), 1.0),
  ])
  let shearx2 = shearx.compose(
    @pdftransform.TransformOp::ShearX((1.0, 2.0), 3.0),
  )
  match shearx2 {
    { ops: [@pdftransform.TransformOp::ShearX((x, y), factor)] } => {
      assert_close(x, 1.0)
      assert_close(y, 2.0)
      assert_close(factor, 4.0)
    }
    _ => fail("expected merged shear-x")
  }
  let sheary = @pdftransform.Transform::new([
    @pdftransform.TransformOp::ShearY((1.0, 2.0), 1.0),
  ])
  let sheary2 = sheary.compose(
    @pdftransform.TransformOp::ShearY((1.0, 2.0), 3.0),
  )
  match sheary2 {
    { ops: [@pdftransform.TransformOp::ShearY((x, y), factor)] } => {
      assert_close(x, 1.0)
      assert_close(y, 2.0)
      assert_close(factor, 4.0)
    }
    _ => fail("expected merged shear-y")
  }
}

///|
test "compose keeps rotate/shear when centers differ" {
  let rotate = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Rotate((0.0, 0.0), 1.0),
  ])
  let rotate2 = rotate.compose(
    @pdftransform.TransformOp::Rotate((1.0, 0.0), 2.0),
  )
  match rotate2 {
    {
      ops: [
        @pdftransform.TransformOp::Rotate((1.0, 0.0), _),
        @pdftransform.TransformOp::Rotate((0.0, 0.0), _),
      ],
    } => ()
    _ => fail("expected two rotate ops")
  }
  let shearx = @pdftransform.Transform::new([
    @pdftransform.TransformOp::ShearX((0.0, 0.0), 1.0),
  ])
  let shearx2 = shearx.compose(
    @pdftransform.TransformOp::ShearX((1.0, 0.0), 2.0),
  )
  match shearx2 {
    {
      ops: [
        @pdftransform.TransformOp::ShearX((1.0, 0.0), _),
        @pdftransform.TransformOp::ShearX((0.0, 0.0), _),
      ],
    } => ()
    _ => fail("expected two shear-x ops")
  }
  let sheary = @pdftransform.Transform::new([
    @pdftransform.TransformOp::ShearY((0.0, 0.0), 1.0),
  ])
  let sheary2 = sheary.compose(
    @pdftransform.TransformOp::ShearY((1.0, 0.0), 2.0),
  )
  match sheary2 {
    {
      ops: [
        @pdftransform.TransformOp::ShearY((1.0, 0.0), _),
        @pdftransform.TransformOp::ShearY((0.0, 0.0), _),
      ],
    } => ()
    _ => fail("expected two shear-y ops")
  }
}

///|
test "compose preserves ops for incompatible kinds" {
  let tr = @pdftransform.Transform::new([
    @pdftransform.TransformOp::Translate(1.0, 2.0),
  ])
  let composed = tr.compose(@pdftransform.TransformOp::Rotate((0.0, 0.0), 1.0))
  match composed {
    {
      ops: [
        @pdftransform.TransformOp::Rotate(_, _),
        @pdftransform.TransformOp::Translate(_, _),
      ],
    } => ()
    _ => fail("expected rotate to be prepended")
  }
}

///|
test "to_matrix and to_string include rotate and shear" {
  let rotate = @pdftransform.TransformOp::Rotate((0.0, 0.0), 1.0)
  let _ = rotate.to_matrix()
  let shear_x = @pdftransform.TransformOp::ShearX((0.0, 0.0), 1.0)
  let _ = shear_x.to_matrix()
  let shear_y = @pdftransform.TransformOp::ShearY((0.0, 0.0), 1.0)
  let _ = shear_y.to_matrix()
  let tr = @pdftransform.Transform::new([rotate, shear_x, shear_y])
  let s = tr.to_string()
  assert_true(s.contains("Rotate by"))
  assert_true(s.contains("Shear in X"))
  assert_true(s.contains("Shear in Y"))
}

///|
test "matrix_invert fails when determinant is NaN" {
  let nan = 0.0 / 0.0
  let m : @pdftransform.TransformMatrix = {
    a: nan,
    b: 0.0,
    c: 0.0,
    d: 1.0,
    e: 0.0,
    f: 0.0,
  }
  let res : Result[@pdftransform.TransformMatrix, Error] = try? m.invert()
  match res {
    Err(_) => ()
    _ => fail("expected NonInvertable")
  }
}
