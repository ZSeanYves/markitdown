///|
pub(all) struct IntStats {
  count : Int
  total : Int
  min : Int
  p50 : Int
  p95 : Int
  max : Int
  avg : Int
}

///|
pub(all) struct Int64Stats {
  count : Int
  total : Int64
  min : Int64
  p50 : Int64
  p95 : Int64
  max : Int64
  avg : Int64
}

///|
pub fn sorted_int(values : Array[Int]) -> Array[Int] {
  let out : Array[Int] = []
  for value in values {
    out.push(value)
  }
  out.sort_by(fn(a, b) { if a == b { 0 } else if a < b { -1 } else { 1 } })
  out
}

///|
pub fn sorted_int64(values : Array[Int64]) -> Array[Int64] {
  let out : Array[Int64] = []
  for value in values {
    out.push(value)
  }
  out.sort_by(fn(a, b) { if a == b { 0 } else if a < b { -1 } else { 1 } })
  out
}

///|
pub fn percentile_int(sorted : Array[Int], pct : Int) -> Int {
  if sorted.length() == 0 {
    return 0
  }
  let idx = (sorted.length() * pct + 99) / 100 - 1
  let bounded = if idx < 0 {
    0
  } else if idx >= sorted.length() {
    sorted.length() - 1
  } else {
    idx
  }
  sorted[bounded]
}

///|
pub fn percentile_int64(sorted : Array[Int64], pct : Int) -> Int64 {
  if sorted.length() == 0 {
    return 0
  }
  let idx = (sorted.length() * pct + 99) / 100 - 1
  let bounded = if idx < 0 {
    0
  } else if idx >= sorted.length() {
    sorted.length() - 1
  } else {
    idx
  }
  sorted[bounded]
}

///|
pub fn summarize_int(values : Array[Int]) -> IntStats {
  let sorted = sorted_int(values)
  let count = sorted.length()
  let mut total = 0
  for value in sorted {
    total += value
  }
  {
    count,
    total,
    min: if count == 0 {
      0
    } else {
      sorted[0]
    },
    p50: percentile_int(sorted, 50),
    p95: percentile_int(sorted, 95),
    max: if count == 0 {
      0
    } else {
      sorted[count - 1]
    },
    avg: if count == 0 {
      0
    } else {
      total / count
    },
  }
}

///|
pub fn summarize_int64(values : Array[Int64]) -> Int64Stats {
  let sorted = sorted_int64(values)
  let count = sorted.length()
  let mut total : Int64 = 0
  for value in sorted {
    total += value
  }
  {
    count,
    total,
    min: if count == 0 {
      0
    } else {
      sorted[0]
    },
    p50: percentile_int64(sorted, 50),
    p95: percentile_int64(sorted, 95),
    max: if count == 0 {
      0
    } else {
      sorted[count - 1]
    },
    avg: if count == 0 {
      0
    } else {
      total / count.to_int64()
    },
  }
}
