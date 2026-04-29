///|
test "Date::to_pdf_string formats offsets(roundtrip)" {
  let dates = [
    "D:20240102030405Z", "D:20240102030405+05'30'", "D:20240102030405-07'15'",
  ]
  for date_str in dates {
    let date = @pdfdate.Date::of_pdf_string(date_str)
    let formatted = date.to_pdf_string()
    // assert_eq(formatted, date_str)
    if formatted != date_str {
      fail("Expected '\{date_str}' but got '\{formatted}'")
    }
  }
}

///|
test "Date::of_pdf_string parses full dates" {
  let parsed = @pdfdate.Date::of_pdf_string("D:20240203040506-07'15'")
  debug_inspect(
    parsed,
    content=(
      #|{
      #|  year: 2024,
      #|  month: 2,
      #|  day: 3,
      #|  hour: 4,
      #|  minute: 5,
      #|  second: 6,
      #|  hour_offset: -7,
      #|  minute_offset: -15,
      #|}
    ),
  )
}

///|
test "Date::of_pdf_string parses short forms" {
  let parsed = @pdfdate.Date::of_pdf_string("2024")
  debug_inspect(
    parsed,
    content=(
      #|{
      #|  year: 2024,
      #|  month: 1,
      #|  day: 1,
      #|  hour: 0,
      #|  minute: 0,
      #|  second: 0,
      #|  hour_offset: 0,
      #|  minute_offset: 0,
      #|}
    ),
  )
}

///|
test "Date::of_pdf_string handles special 19100 year" {
  let parsed = @pdfdate.Date::of_pdf_string("D:19100")
  debug_inspect(
    parsed,
    content=(
      #|{
      #|  year: 2000,
      #|  month: 1,
      #|  day: 1,
      #|  hour: 0,
      #|  minute: 0,
      #|  second: 0,
      #|  hour_offset: 0,
      #|  minute_offset: 0,
      #|}
    ),
  )
}

///|
test "Date::of_pdf_string rejects invalid values" {
  let bad_month : Result[@pdfdate.Date, Error] = try? @pdfdate.Date::of_pdf_string(
    "D:20241301",
  )
  // FIXME: upstream Error:Debug
  // debug_inspect(bad_month)
  assert_true(bad_month is Err(_))
  let bad_format : Result[@pdfdate.Date, Error] = try? @pdfdate.Date::of_pdf_string(
    "D:20A4",
  )
  assert_true(bad_format is Err(_))
}

///|
test "Date::of_pdf_string rejects too-short strings" {
  let r1 : Result[@pdfdate.Date, Error] = try? @pdfdate.Date::of_pdf_string(
    "D:",
  )
  assert_true(r1 is Err(_))
  let r2 : Result[@pdfdate.Date, Error] = try? @pdfdate.Date::of_pdf_string(
    "202",
  )
  assert_true(r2 is Err(_))
}

///|
test "Date::of_pdf_string accepts incomplete day digits as short form" {
  let parsed = @pdfdate.Date::of_pdf_string("D:2024010")
  assert_eq(parsed.year, 2024)
  assert_eq(parsed.month, 1)
  assert_eq(parsed.day, 1)
}

///|
test "Date::of_pdf_string parses Z when it appears early" {
  let parsed = @pdfdate.Date::of_pdf_string("D:2024Z")
  assert_eq(parsed.year, 2024)
  assert_eq(parsed.month, 1)
  assert_eq(parsed.day, 1)
  assert_eq(parsed.hour_offset, 0)
  assert_eq(parsed.minute_offset, 0)
}

///|
test "Date::of_pdf_string rejects malformed trailing timezone/junk" {
  let bad1 : Result[@pdfdate.Date, Error] = try? @pdfdate.Date::of_pdf_string(
    "D:20241301020304+",
  )
  assert_true(bad1 is Err(_))
  let bad2 : Result[@pdfdate.Date, Error] = try? @pdfdate.Date::of_pdf_string(
    "D:20241301020304X",
  )
  assert_true(bad2 is Err(_))
}
