///|
test "failed inflate step preserves physical output before clearing borrowed views" {
  for fixed_output in [false, true] {
    let inflater = Inflater()
    let input = b"\x00\x01\x00\xfe\xffA\x07"
    let output = FixedArray::make(8, b'\xcc')
    let failed = try {
      if fixed_output {
        ignore(inflater.step_into(input[:], output, end=true))
      } else {
        ignore(inflater.step(input[:], output.mut_view(), end=true))
      }
      false
    } catch {
      InflateError(Corrupt, _) => true
      _ => false
    }
    assert_true(failed)
    assert_eq(output[0], b'A')
    assert_eq(inflater.last_produced(), 1)
    assert_eq(inflater.last_consumed(), input.length())
    assert_eq(inflater.out_pos, 0)
    assert_eq(inflater.in_pos, 0)
    assert_eq(inflater.view.length(), 0)
    assert_eq(inflater.out.length(), 0)
    assert_true(inflater.fixed_out is None)
    let repeated = try {
      ignore(inflater.step(b""[:], output.mut_view(), end=true))
      false
    } catch {
      InflateError(Corrupt, _) => true
      _ => false
    }
    assert_true(repeated)
    assert_eq(inflater.last_produced(), 0)
    assert_eq(inflater.last_consumed(), 0)
    inflater.reset()
    assert_eq(inflater.last_produced(), 0)
    assert_eq(inflater.last_consumed(), 0)
    assert_true(
      inflater.step(b"\x01\x01\x00\xfe\xffZ"[:], output.mut_view(), end=true)
      is Done,
    )
    assert_eq(output[0], b'Z')
    assert_eq(inflater.last_produced(), 1)
  }
}

///|
test "physical EOF after partial output retains the produced count" {
  let inflater = Inflater()
  let output = FixedArray::make(8, b'\xcc')
  let failed = try {
    ignore(
      inflater.step(
        b"\x00\x01\x00\xfe\xffA\x00"[:],
        output.mut_view(),
        end=true,
      ),
    )
    false
  } catch {
    InflateError(Truncated, _) => true
    _ => false
  }
  assert_true(failed)
  assert_eq(output[0], b'A')
  assert_eq(inflater.last_produced(), 1)
  assert_eq(inflater.view.length(), 0)
  assert_eq(inflater.out.length(), 0)
}

///|
test "vendored valid streaming output status and counts match exact pinned upstream" {
  for
    payload in [
      b"",
      b"hello zip\n",
      Bytes::make(4096, b'A'),
      Bytes::makei(4096, i => i.to_byte()),
    ] {
    let compressed = @flate.deflate_all(payload)
    for input_size in [1, 7, 1024] {
      for output_size in [1, 17, 128] {
        let vendored = Inflater()
        let upstream = @flate.Inflater()
        let local_output = FixedArray::make(output_size, b'\x00')
        let upstream_output = FixedArray::make(output_size, b'\x00')
        let decoded = Buffer()
        let mut position = 0
        let mut steps = 0
        while true {
          steps += 1
          assert_true(steps < 100000)
          let end_ = position + (compressed.length() - position).min(input_size)
          let input = compressed[position:end_]
          let status = vendored.step(
            input,
            local_output.mut_view(),
            end=end_ == compressed.length(),
          )
          let reference = upstream.step(
            input,
            upstream_output.mut_view(),
            end=end_ == compressed.length(),
          )
          assert_eq(status is Done, reference is Done)
          assert_eq(status is NeedMoreInput, reference is NeedMoreInput)
          assert_eq(status is NeedMoreOutput, reference is NeedMoreOutput)
          assert_eq(vendored.last_consumed(), upstream.last_consumed())
          assert_eq(vendored.last_produced(), upstream.last_produced())
          for i in 0..<vendored.last_produced() {
            assert_eq(local_output[i], upstream_output[i])
            decoded.write_byte(local_output[i])
          }
          position += vendored.last_consumed()
          if status is Done {
            break
          }
        }
        assert_eq(position, compressed.length())
        assert_eq(decoded.to_bytes(), payload)
      }
    }
  }
}
