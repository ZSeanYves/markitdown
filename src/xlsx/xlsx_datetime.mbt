///|
fn format_excel_datetime(raw : String, num_fmt_id : Int) -> String {
  let parsed = parse_excel_serial(raw)
  match parsed {
    None => raw
    Some((days, frac_num, frac_den)) => {
      let (carry, hh, mm, ss) = frac_to_hms(frac_num, frac_den)
      let serial_day = days + carry

      if numfmt_is_time_only(num_fmt_id) {
        return pad2(hh) + ":" + pad2(mm) + ":" + pad2(ss)
      }

      let (y, m, d) = excel_serial_to_ymd(serial_day)

      if numfmt_is_date_only(num_fmt_id) {
        return pad4(y) + "-" + pad2(m) + "-" + pad2(d)
      }

      if numfmt_is_datetime(num_fmt_id) {
        let date_part = pad4(y) +
          "-" +
          pad2(m) +
          "-" +
          pad2(d) +
          " " +
          pad2(hh) +
          ":" +
          pad2(mm) +
          ":" +
          pad2(ss)
        return date_part
      }

      raw
    }
  }
}

///|
/// parse non-negative decimal like:
/// 45292
/// 45292.5
/// 0.75
/// return (days, frac_num, frac_den)
fn parse_excel_serial(s : String) -> (Int, Int, Int)? {
  let t = @cor.trim_string(s)
  if t == "" {
    return None
  }

  let cs = t.to_array()
  let mut i = 0
  let n = cs.length()

  // disallow sign in v1
  if i < n && (cs[i] == '-' || cs[i] == '+') {
    return None
  }

  let mut days = 0
  let mut has_int = false

  while i < n {
    let ch = cs[i]
    if ch >= '0' && ch <= '9' {
      days = days * 10 + (ch.to_int() - '0'.to_int())
      has_int = true
      i += 1
    } else {
      break
    }
  }

  if i == n {
    if has_int {
      return Some((days, 0, 1))
    } else {
      return None
    }
  }

  if cs[i] != '.' {
    return None
  }

  i += 1

  let mut frac_num = 0
  let mut frac_den = 1
  let mut has_frac = false

  while i < n {
    let ch = cs[i]
    if ch >= '0' && ch <= '9' {
      frac_num = frac_num * 10 + (ch.to_int() - '0'.to_int())
      frac_den = frac_den * 10
      has_frac = true
      i += 1
    } else {
      return None
    }
  }

  if !has_int && !has_frac {
    return None
  }

  Some((days, frac_num, frac_den))
}

///|
/// return (day_carry, hh, mm, ss)
fn frac_to_hms(frac_num : Int, frac_den : Int) -> (Int, Int, Int, Int) {
  if frac_den <= 0 {
    return (0, 0, 0, 0)
  }

  // round to nearest second
  let mut total_seconds = (frac_num * 86400 + frac_den / 2) / frac_den
  let mut carry = 0

  if total_seconds >= 86400 {
    total_seconds = total_seconds - 86400
    carry = 1
  }

  let hh = total_seconds / 3600
  let mm = total_seconds % 3600 / 60
  let ss = total_seconds % 60

  (carry, hh, mm, ss)
}

///|
/// Excel 1900 date system:
/// serial 1  -> 1900-01-01
/// serial 60 -> 1900-02-29 (Excel compatibility)
fn excel_serial_to_ymd(serial : Int) -> (Int, Int, Int) {
  if serial <= 0 {
    return (1899, 12, 30)
  }

  if serial == 60 {
    return (1900, 2, 29)
  }

  let mut y = 1900
  let mut m = 1
  let mut d = 1

  let mut days_left = if serial < 60 {
    serial - 1
  } else {
    // skip Excel's fake 1900-02-29
    serial - 2
  }

  while true {
    let diy = if is_leap_year(y) { 366 } else { 365 }
    if days_left >= diy {
      days_left = days_left - diy
      y = y + 1
    } else {
      break
    }
  }

  while true {
    let dim = days_in_month(y, m)
    if days_left >= dim {
      days_left = days_left - dim
      m = m + 1
    } else {
      break
    }
  }

  d = d + days_left
  (y, m, d)
}

///|
fn is_leap_year(y : Int) -> Bool {
  if y % 400 == 0 {
    true
  } else if y % 100 == 0 {
    false
  } else {
    y % 4 == 0
  }
}

///|
fn days_in_month(y : Int, m : Int) -> Int {
  if m == 1 {
    31
  } else if m == 2 {
    if is_leap_year(y) {
      29
    } else {
      28
    }
  } else if m == 3 {
    31
  } else if m == 4 {
    30
  } else if m == 5 {
    31
  } else if m == 6 {
    30
  } else if m == 7 {
    31
  } else if m == 8 {
    31
  } else if m == 9 {
    30
  } else if m == 10 {
    31
  } else if m == 11 {
    30
  } else {
    31
  }
}

///|
fn pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn pad4(n : Int) -> String {
  if n < 10 {
    "000" + n.to_string()
  } else if n < 100 {
    "00" + n.to_string()
  } else if n < 1000 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}
