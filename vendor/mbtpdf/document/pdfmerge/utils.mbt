///|
/// Compare two byte arrays lexicographically.
fn compare_bytes(left : ArrayView[Byte], right : ArrayView[Byte]) -> Int {
  // `Compare for Array[T]` is shortlex (length-first). For bytes we want the
  // traditional lexicographical order: compare element-by-element first, and
  // only compare lengths if all compared elements are equal.
  let left_len = left.length()
  let right_len = right.length()
  let min_len = if left_len < right_len { left_len } else { right_len }
  for i in 0..<min_len {
    let a = left[i]
    let b = right[i]
    if a != b {
      return a.to_int() - b.to_int()
    }
  }
  left_len - right_len
}

///|
fn[T] flatten(lists : Array[Array[T]]) -> Array[T] {
  let mut total = 0
  for list in lists {
    total = total + list.length()
  }
  let out = Array::new(capacity=total)
  for list in lists {
    out.append(list[:])
  }
  out
}

///|
fn ilist(start : Int, finish : Int) -> Array[Int] {
  if finish < start {
    return []
  }
  let out = Array::new(capacity=finish - start + 1)
  for i in start..<=finish {
    out.push(i)
  }
  out
}

///|
fn contains_int(values : Array[Int], value : Int) -> Bool {
  values[:].contains(value)
}

///|
fn[T] slice(values : Array[T], start : Int, count : Int) -> Array[T] raise {
  if start < 0 || count < 0 || start + count > values.length() {
    raise @pdf.PdfError::Msg("slice: out of bounds")
  }
  values[:].sub(start~, end=start + count).to_array()
}

///|
fn[K : Eq, V] lookup(key : K, pairs : Array[(K, V)]) -> V? {
  match pairs.search_by(pair => pair.0 == key) {
    Some(i) => Some(pairs[i].1)
    None => None
  }
}

///|
fn[K : Eq, V] lookup_fail(
  key : K,
  pairs : Array[(K, V)],
  err : String,
) -> V raise {
  match lookup(key, pairs) {
    Some(value) => value
    None => raise @pdf.PdfError::Msg(err)
  }
}

///|
fn[A, B] combine(left : Array[A], right : Array[B]) -> Array[(A, B)] raise {
  if left.length() != right.length() {
    raise @pdf.PdfError::Msg("combine: length mismatch")
  }
  let out = Array::new(capacity=left.length())
  for i in 0..<left.length() {
    out.push((left[i], right[i]))
  }
  out
}

///|
fn[T] collate(items : Array[T], cmp : (T, T) -> Int) -> Array[Array[T]] {
  let out = Array::new()
  let mut i = 0
  while i < items.length() {
    let group = Array::new()
    group.push(items[i])
    let mut j = i + 1
    while j < items.length() && cmp(items[i], items[j]) == 0 {
      group.push(items[j])
      j = j + 1
    }
    out.push(group)
    i = j
  }
  out
}

///|
fn setify_strings(values : Array[String]) -> Array[String] {
  let seen = Map::new(capacity=values.length())
  let out = Array::new()
  for value in values {
    if seen.get(value) is None {
      seen.set(value, ())
      out.push(value)
    }
  }
  out
}

///|
fn remove_entry(
  entries : Array[(String, PdfObject)],
  key : String,
) -> Array[(String, PdfObject)] {
  entries.filter(entry => entry.0 != key)
}

///|
fn add_entry(
  entries : Array[(String, PdfObject)],
  key : String,
  value : PdfObject,
) -> Array[(String, PdfObject)] {
  match entries.search_by(entry => entry.0 == key) {
    None => {
      let out = entries[:].to_array()
      out.push((key, value))
      out
    }
    Some(_) =>
      entries.map(entry => if entry.0 == key { (key, value) } else { entry })
  }
}
