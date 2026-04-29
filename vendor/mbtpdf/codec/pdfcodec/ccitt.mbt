///|
fn append_bits(prefix : Array[Int], suffix : Array[Int]) -> Array[Int] {
  let out = Array::new(capacity=prefix.length() + suffix.length())
  for bit in prefix {
    out.push(bit)
  }
  for bit in suffix {
    out.push(bit)
  }
  out
}

///|
fn write_white_code(n : Int) -> Array[Int] raise CodecError {
  if n == -1 {
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  } else if n == 0 {
    [0, 0, 1, 1, 0, 1, 0, 1]
  } else if n == 1 {
    [0, 0, 0, 1, 1, 1]
  } else if n == 2 {
    [0, 1, 1, 1]
  } else if n == 3 {
    [1, 0, 0, 0]
  } else if n == 4 {
    [1, 0, 1, 1]
  } else if n == 5 {
    [1, 1, 0, 0]
  } else if n == 6 {
    [1, 1, 1, 0]
  } else if n == 7 {
    [1, 1, 1, 1]
  } else if n == 8 {
    [1, 0, 0, 1, 1]
  } else if n == 9 {
    [1, 0, 1, 0, 0]
  } else if n == 10 {
    [0, 0, 1, 1, 1]
  } else if n == 11 {
    [0, 1, 0, 0, 0]
  } else if n == 12 {
    [0, 0, 1, 0, 0, 0]
  } else if n == 13 {
    [0, 0, 0, 0, 1, 1]
  } else if n == 14 {
    [1, 1, 0, 1, 0, 0]
  } else if n == 15 {
    [1, 1, 0, 1, 0, 1]
  } else if n == 16 {
    [1, 0, 1, 0, 1, 0]
  } else if n == 17 {
    [1, 0, 1, 0, 1, 1]
  } else if n == 18 {
    [0, 1, 0, 0, 1, 1, 1]
  } else if n == 19 {
    [0, 0, 0, 1, 1, 0, 0]
  } else if n == 20 {
    [0, 0, 0, 1, 0, 0, 0]
  } else if n == 21 {
    [0, 0, 1, 0, 1, 1, 1]
  } else if n == 22 {
    [0, 0, 0, 0, 0, 1, 1]
  } else if n == 23 {
    [0, 0, 0, 0, 1, 0, 0]
  } else if n == 24 {
    [0, 1, 0, 1, 0, 0, 0]
  } else if n == 25 {
    [0, 1, 0, 1, 0, 1, 1]
  } else if n == 26 {
    [0, 0, 1, 0, 0, 1, 1]
  } else if n == 27 {
    [0, 1, 0, 0, 1, 0, 0]
  } else if n == 28 {
    [0, 0, 1, 1, 0, 0, 0]
  } else if n == 29 {
    [0, 0, 0, 0, 0, 0, 1, 0]
  } else if n == 30 {
    [0, 0, 0, 0, 0, 0, 1, 1]
  } else if n == 31 {
    [0, 0, 0, 1, 1, 0, 1, 0]
  } else if n == 32 {
    [0, 0, 0, 1, 1, 0, 1, 1]
  } else if n == 33 {
    [0, 0, 0, 1, 0, 0, 1, 0]
  } else if n == 34 {
    [0, 0, 0, 1, 0, 0, 1, 1]
  } else if n == 35 {
    [0, 0, 0, 1, 0, 1, 0, 0]
  } else if n == 36 {
    [0, 0, 0, 1, 0, 1, 0, 1]
  } else if n == 37 {
    [0, 0, 0, 1, 0, 1, 1, 0]
  } else if n == 38 {
    [0, 0, 0, 1, 0, 1, 1, 1]
  } else if n == 39 {
    [0, 0, 1, 0, 1, 0, 0, 0]
  } else if n == 40 {
    [0, 0, 1, 0, 1, 0, 0, 1]
  } else if n == 41 {
    [0, 0, 1, 0, 1, 0, 1, 0]
  } else if n == 42 {
    [0, 0, 1, 0, 1, 0, 1, 1]
  } else if n == 43 {
    [0, 0, 1, 0, 1, 1, 0, 0]
  } else if n == 44 {
    [0, 0, 1, 0, 1, 1, 0, 1]
  } else if n == 45 {
    [0, 0, 0, 0, 0, 1, 0, 0]
  } else if n == 46 {
    [0, 0, 0, 0, 0, 1, 0, 1]
  } else if n == 47 {
    [0, 0, 0, 0, 1, 0, 1, 0]
  } else if n == 48 {
    [0, 0, 0, 0, 1, 0, 1, 1]
  } else if n == 49 {
    [0, 1, 0, 1, 0, 0, 1, 0]
  } else if n == 50 {
    [0, 1, 0, 1, 0, 0, 1, 1]
  } else if n == 51 {
    [0, 1, 0, 1, 0, 1, 0, 0]
  } else if n == 52 {
    [0, 1, 0, 1, 0, 1, 0, 1]
  } else if n == 53 {
    [0, 0, 1, 0, 0, 1, 0, 0]
  } else if n == 54 {
    [0, 0, 1, 0, 0, 1, 0, 1]
  } else if n == 55 {
    [0, 1, 0, 1, 1, 0, 0, 0]
  } else if n == 56 {
    [0, 1, 0, 1, 1, 0, 0, 1]
  } else if n == 57 {
    [0, 1, 0, 1, 1, 0, 1, 0]
  } else if n == 58 {
    [0, 1, 0, 1, 1, 0, 1, 1]
  } else if n == 59 {
    [0, 1, 0, 0, 1, 0, 1, 0]
  } else if n == 60 {
    [0, 1, 0, 0, 1, 0, 1, 1]
  } else if n == 61 {
    [0, 0, 1, 1, 0, 0, 1, 0]
  } else if n == 62 {
    [0, 0, 1, 1, 0, 0, 1, 1]
  } else if n == 63 {
    [0, 0, 1, 1, 0, 1, 0, 0]
  } else if n >= 2560 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],
      write_white_code(n - 2560),
    )
  } else if n >= 2496 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0],
      write_white_code(n - 2496),
    )
  } else if n >= 2432 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1],
      write_white_code(n - 2432),
    )
  } else if n >= 2368 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0],
      write_white_code(n - 2368),
    )
  } else if n >= 2304 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1],
      write_white_code(n - 2304),
    )
  } else if n >= 2240 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0],
      write_white_code(n - 2240),
    )
  } else if n >= 2176 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1],
      write_white_code(n - 2176),
    )
  } else if n >= 2112 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0],
      write_white_code(n - 2112),
    )
  } else if n >= 2048 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1],
      write_white_code(n - 2048),
    )
  } else if n >= 1984 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0],
      write_white_code(n - 1984),
    )
  } else if n >= 1920 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1], write_white_code(n - 1920))
  } else if n >= 1856 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0], write_white_code(n - 1856))
  } else if n >= 1792 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], write_white_code(n - 1792))
  } else if n >= 1728 {
    append_bits([0, 1, 0, 0, 1, 1, 0, 1, 1], write_white_code(n - 1728))
  } else if n >= 1664 {
    append_bits([0, 1, 1, 0, 0, 0], write_white_code(n - 1664))
  } else if n >= 1600 {
    append_bits([0, 1, 0, 0, 1, 1, 0, 1, 0], write_white_code(n - 1600))
  } else if n >= 1536 {
    append_bits([0, 1, 0, 0, 1, 1, 0, 0, 1], write_white_code(n - 1536))
  } else if n >= 1472 {
    append_bits([0, 1, 0, 0, 1, 1, 0, 0, 0], write_white_code(n - 1472))
  } else if n >= 1408 {
    append_bits([0, 1, 1, 0, 1, 1, 0, 1, 1], write_white_code(n - 1408))
  } else if n >= 1344 {
    append_bits([0, 1, 1, 0, 1, 1, 0, 1, 0], write_white_code(n - 1344))
  } else if n >= 1280 {
    append_bits([0, 1, 1, 0, 1, 1, 0, 0, 1], write_white_code(n - 1280))
  } else if n >= 1216 {
    append_bits([0, 1, 1, 0, 1, 1, 0, 0, 0], write_white_code(n - 1216))
  } else if n >= 1152 {
    append_bits([0, 1, 1, 0, 1, 0, 1, 1, 1], write_white_code(n - 1152))
  } else if n >= 1088 {
    append_bits([0, 1, 1, 0, 1, 0, 1, 1, 0], write_white_code(n - 1088))
  } else if n >= 1024 {
    append_bits([0, 1, 1, 0, 1, 0, 1, 0, 1], write_white_code(n - 1024))
  } else if n >= 960 {
    append_bits([0, 1, 1, 0, 1, 0, 1, 0, 0], write_white_code(n - 960))
  } else if n >= 896 {
    append_bits([0, 1, 1, 0, 1, 0, 0, 1, 1], write_white_code(n - 896))
  } else if n >= 832 {
    append_bits([0, 1, 1, 0, 1, 0, 0, 1, 0], write_white_code(n - 832))
  } else if n >= 768 {
    append_bits([0, 1, 1, 0, 0, 1, 1, 0, 1], write_white_code(n - 768))
  } else if n >= 704 {
    append_bits([0, 1, 1, 0, 0, 1, 1, 0, 0], write_white_code(n - 704))
  } else if n >= 640 {
    append_bits([0, 1, 1, 0, 0, 1, 1, 1], write_white_code(n - 640))
  } else if n >= 576 {
    append_bits([0, 1, 1, 0, 1, 0, 0, 0], write_white_code(n - 576))
  } else if n >= 512 {
    append_bits([0, 1, 1, 0, 0, 1, 0, 1], write_white_code(n - 512))
  } else if n >= 448 {
    append_bits([0, 1, 1, 0, 0, 1, 0, 0], write_white_code(n - 448))
  } else if n >= 384 {
    append_bits([0, 0, 1, 1, 0, 1, 1, 1], write_white_code(n - 384))
  } else if n >= 320 {
    append_bits([0, 0, 1, 1, 0, 1, 1, 0], write_white_code(n - 320))
  } else if n >= 256 {
    append_bits([0, 1, 1, 0, 1, 1, 1], write_white_code(n - 256))
  } else if n >= 192 {
    append_bits([0, 1, 0, 1, 1, 1], write_white_code(n - 192))
  } else if n >= 128 {
    append_bits([1, 0, 0, 1, 0], write_white_code(n - 128))
  } else if n >= 64 {
    append_bits([1, 1, 0, 1, 1], write_white_code(n - 64))
  } else {
    raise CodecError::DecodeNotSupported("write_white_code: unknown")
  }
}

///|
fn write_black_code(n : Int) -> Array[Int] raise CodecError {
  if n == -1 {
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
  } else if n == 0 {
    [0, 0, 0, 0, 1, 1, 0, 1, 1, 1]
  } else if n == 1 {
    [0, 1, 0]
  } else if n == 2 {
    [1, 1]
  } else if n == 3 {
    [1, 0]
  } else if n == 4 {
    [0, 1, 1]
  } else if n == 5 {
    [0, 0, 1, 1]
  } else if n == 6 {
    [0, 0, 1, 0]
  } else if n == 7 {
    [0, 0, 0, 1, 1]
  } else if n == 8 {
    [0, 0, 0, 1, 0, 1]
  } else if n == 9 {
    [0, 0, 0, 1, 0, 0]
  } else if n == 10 {
    [0, 0, 0, 0, 1, 0, 0]
  } else if n == 11 {
    [0, 0, 0, 0, 1, 0, 1]
  } else if n == 12 {
    [0, 0, 0, 0, 1, 1, 1]
  } else if n == 13 {
    [0, 0, 0, 0, 0, 1, 0, 0]
  } else if n == 14 {
    [0, 0, 0, 0, 0, 1, 1, 1]
  } else if n == 15 {
    [0, 0, 0, 0, 1, 1, 0, 0, 0]
  } else if n == 16 {
    [0, 0, 0, 0, 0, 1, 0, 1, 1, 1]
  } else if n == 17 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 0]
  } else if n == 18 {
    [0, 0, 0, 0, 0, 0, 1, 0, 0, 0]
  } else if n == 19 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1]
  } else if n == 20 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0]
  } else if n == 21 {
    [0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0]
  } else if n == 22 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1]
  } else if n == 23 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0]
  } else if n == 24 {
    [0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1]
  } else if n == 25 {
    [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0]
  } else if n == 26 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 0]
  } else if n == 27 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1, 1]
  } else if n == 28 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0]
  } else if n == 29 {
    [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 1]
  } else if n == 30 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0]
  } else if n == 31 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1]
  } else if n == 32 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0]
  } else if n == 33 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1]
  } else if n == 34 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 0]
  } else if n == 35 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 0, 1, 1]
  } else if n == 36 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0]
  } else if n == 37 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1]
  } else if n == 38 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0]
  } else if n == 39 {
    [0, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1]
  } else if n == 40 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0]
  } else if n == 41 {
    [0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1]
  } else if n == 42 {
    [0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 0]
  } else if n == 43 {
    [0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1]
  } else if n == 44 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0]
  } else if n == 45 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1]
  } else if n == 46 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0]
  } else if n == 47 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1]
  } else if n == 48 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0]
  } else if n == 49 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1]
  } else if n == 50 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0]
  } else if n == 51 {
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1]
  } else if n == 52 {
    [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0]
  } else if n == 53 {
    [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 1]
  } else if n == 54 {
    [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0]
  } else if n == 55 {
    [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1]
  } else if n == 56 {
    [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0]
  } else if n == 57 {
    [0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 0]
  } else if n == 58 {
    [0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1]
  } else if n == 59 {
    [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1]
  } else if n == 60 {
    [0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0]
  } else if n == 61 {
    [0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0]
  } else if n == 62 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0]
  } else if n == 63 {
    [0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1]
  } else if n >= 2560 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1],
      write_black_code(n - 2560),
    )
  } else if n >= 2496 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0],
      write_black_code(n - 2496),
    )
  } else if n >= 2432 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1],
      write_black_code(n - 2432),
    )
  } else if n >= 2368 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0],
      write_black_code(n - 2368),
    )
  } else if n >= 2304 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1],
      write_black_code(n - 2304),
    )
  } else if n >= 2240 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0],
      write_black_code(n - 2240),
    )
  } else if n >= 2176 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1],
      write_black_code(n - 2176),
    )
  } else if n >= 2112 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0],
      write_black_code(n - 2112),
    )
  } else if n >= 2048 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1],
      write_black_code(n - 2048),
    )
  } else if n >= 1984 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0],
      write_black_code(n - 1984),
    )
  } else if n >= 1920 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1], write_black_code(n - 1920))
  } else if n >= 1856 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0], write_black_code(n - 1856))
  } else if n >= 1792 {
    append_bits([0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0], write_black_code(n - 1792))
  } else if n >= 1728 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 1],
      write_black_code(n - 1728),
    )
  } else if n >= 1664 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0],
      write_black_code(n - 1664),
    )
  } else if n >= 1600 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1],
      write_black_code(n - 1600),
    )
  } else if n >= 1536 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0],
      write_black_code(n - 1536),
    )
  } else if n >= 1472 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1],
      write_black_code(n - 1472),
    )
  } else if n >= 1408 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0],
      write_black_code(n - 1408),
    )
  } else if n >= 1344 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 1],
      write_black_code(n - 1344),
    )
  } else if n >= 1280 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 1, 0],
      write_black_code(n - 1280),
    )
  } else if n >= 1216 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 1],
      write_black_code(n - 1216),
    )
  } else if n >= 1152 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0],
      write_black_code(n - 1152),
    )
  } else if n >= 1088 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1],
      write_black_code(n - 1088),
    )
  } else if n >= 1024 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 1, 0, 0],
      write_black_code(n - 1024),
    )
  } else if n >= 960 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1],
      write_black_code(n - 960),
    )
  } else if n >= 896 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0],
      write_black_code(n - 896),
    )
  } else if n >= 832 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 1],
      write_black_code(n - 832),
    )
  } else if n >= 768 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0],
      write_black_code(n - 768),
    )
  } else if n >= 704 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1],
      write_black_code(n - 704),
    )
  } else if n >= 640 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0],
      write_black_code(n - 640),
    )
  } else if n >= 576 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1],
      write_black_code(n - 576),
    )
  } else if n >= 512 {
    append_bits(
      [0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0],
      write_black_code(n - 512),
    )
  } else if n >= 448 {
    append_bits([0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 1], write_black_code(n - 448))
  } else if n >= 384 {
    append_bits([0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 0, 0], write_black_code(n - 384))
  } else if n >= 320 {
    append_bits([0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1], write_black_code(n - 320))
  } else if n >= 256 {
    append_bits([0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 1, 1], write_black_code(n - 256))
  } else if n >= 192 {
    append_bits([0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 1], write_black_code(n - 192))
  } else if n >= 128 {
    append_bits([0, 0, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0], write_black_code(n - 128))
  } else if n >= 64 {
    append_bits([0, 0, 0, 0, 0, 0, 1, 1, 1, 1], write_black_code(n - 64))
  } else {
    raise CodecError::DecodeNotSupported("write_black_code: unknown")
  }
}

///|
fn write_bits(output : @pdfio.BitstreamWrite, bits : Array[Int]) -> Unit {
  for bit in bits {
    output.putbit(bit)
  }
}

///|
fn read_run(maxcols : Int, input : @pdfio.Bitstream) -> (Bool, Int) raise {
  let mut nbits = 1
  let iswhite = input.getbit()
  let mut finished = false
  while nbits < maxcols && !finished {
    let pos = input.position()
    let newbit = input.getbit()
    if newbit == iswhite {
      nbits = nbits + 1
    } else {
      input.seek(pos)
      finished = true
    }
  }
  (iswhite, nbits)
}

///|
/// Encode data in CCITTDecode Group 3.
fn encode_ccitt(
  _columns : Int,
  _rows : Int,
  _data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let columns = _columns
  let rows = _rows
  let data = _data
  let input = @pdfio.Bitstream::of_input(@pdfio.Input::of_bytes(data))
  let output = @pdfio.BitstreamWrite::new()
  try {
    let mut rows_left = rows
    let mut cols_left = columns
    while rows_left > 0 {
      let (iswhite, length) = read_run(cols_left, input)
      let bits = if iswhite {
        write_white_code(length)
      } else {
        write_black_code(length)
      }
      if !iswhite && cols_left == columns {
        write_bits(output, write_white_code(0))
      }
      write_bits(output, bits)
      cols_left = cols_left - length
      if cols_left == 0 {
        input.align()
        cols_left = columns
        rows_left = rows_left - 1
      }
    }
    write_bits(output, write_white_code(-1))
    write_bits(output, write_white_code(-1))
    output.align()
    output.bytes()
  } catch {
    Failure::Failure(_) =>
      raise CodecError::CouldntDecodeStream("encode_ccitt: not enough data")
    _ => raise CodecError::CouldntDecodeStream("encode_ccitt: not enough data")
  }
}

///|
fn ccittg4_transitions(
  input : @pdfio.Bitstream,
  columns : Int,
) -> Array[Int] raise {
  let transitions = Array::new(capacity=columns + 2)
  transitions.push(0)
  let mut prev_white = true
  for pos = 0; pos < columns; pos = pos + 1 {
    let is_white = input.getbit()
    if is_white != prev_white {
      transitions.push(pos)
      prev_white = is_white
    }
  }
  transitions.push(columns)
  input.align()
  transitions
}

///|
fn write_ccittg4_vertical(
  output : @pdfio.BitstreamWrite,
  diff : Int,
) -> Unit raise CodecError {
  match diff {
    0 => write_bits(output, [1])
    -1 => write_bits(output, [0, 1, 1])
    -2 => write_bits(output, [0, 0, 0, 0, 1, 1])
    -3 => write_bits(output, [0, 0, 0, 0, 0, 1, 1])
    1 => write_bits(output, [0, 1, 0])
    2 => write_bits(output, [0, 0, 0, 0, 1, 0])
    3 => write_bits(output, [0, 0, 0, 0, 0, 1, 0])
    _ =>
      raise CodecError::DecodeNotSupported(
        "bad vertical mode in CCITT G4 encoding",
      )
  }
}

///|
fn encode_ccittg4_line(
  columns : Int,
  coding : Array[Int],
  reference : Array[Int],
  output : @pdfio.BitstreamWrite,
) -> Unit raise CodecError {
  let mut a0 = 0
  let mut a0_run = 0
  let mut ref_run = 0
  while a0 < columns {
    while a0_run + 1 < coding.length() && a0 >= coding[a0_run + 1] {
      a0_run = a0_run + 1
    }
    while ref_run + 1 < reference.length() && a0 >= reference[ref_run + 1] {
      ref_run = ref_run + 1
    }
    let a0_iswhite = a0_run % 2 == 0
    let a1 = if a0_run + 1 < coding.length() {
      coding[a0_run + 1]
    } else {
      columns
    }
    let a2 = if a0_run + 2 < coding.length() {
      coding[a0_run + 2]
    } else {
      columns
    }
    let b1_index = ref_run + 1
    let b1 = if b1_index < reference.length() {
      reference[b1_index]
    } else {
      columns
    }
    let b2 = if b1_index + 1 < reference.length() {
      reference[b1_index + 1]
    } else {
      columns
    }
    if b2 < a1 {
      write_bits(output, [0, 0, 0, 1])
      a0 = b2
      continue
    }
    let diff = a1 - b1
    if diff >= -3 && diff <= 3 {
      write_ccittg4_vertical(output, diff)
      a0 = a1
      continue
    }
    write_bits(output, [0, 0, 1])
    let run1 = a1 - a0
    let run2 = a2 - a1
    if a0_iswhite {
      write_bits(output, write_white_code(run1))
      write_bits(output, write_black_code(run2))
    } else {
      write_bits(output, write_black_code(run1))
      write_bits(output, write_white_code(run2))
    }
    a0 = a2
  }
}

///|
fn encode_ccittg4_pure(
  columns : Int,
  rows : Int,
  data : @pdfio.MutableBytes,
) -> @pdfio.MutableBytes raise CodecError {
  let input = @pdfio.Bitstream::of_input(@pdfio.Input::of_bytes(data))
  let output = @pdfio.BitstreamWrite::new()
  try {
    let mut rows_left = rows
    let mut reference = Array::new(capacity=2)
    reference.push(0)
    reference.push(columns)
    while rows_left > 0 {
      let coding = ccittg4_transitions(input, columns)
      encode_ccittg4_line(columns, coding, reference, output)
      reference = coding
      rows_left = rows_left - 1
    }
    write_bits(output, [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    ])
    output.align()
    output.bytes()
  } catch {
    Failure::Failure(_) =>
      raise CodecError::CouldntDecodeStream("encode_ccittg4: not enough data")
    _ =>
      raise CodecError::CouldntDecodeStream("encode_ccittg4: not enough data")
  }
}

///|
/// Encode data in CCITTDecode Group 4.
fn encode_ccittg4(
  _columns : Int,
  _rows : Int,
  _data : @pdfio.MutableBytes,
  im? : String,
) -> @pdfio.MutableBytes raise CodecError {
  let columns = _columns
  let rows = _rows
  let data = _data
  match im {
    None => encode_ccittg4_pure(columns, rows, data)
    Some(_) =>
      raise CodecError::DecodeNotSupported(
        "encode_ccittg4: use encode_ccittg4_async for imagemagick path",
      )
  }
}
