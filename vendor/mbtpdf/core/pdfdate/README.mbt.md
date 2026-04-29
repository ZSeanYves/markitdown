# @bobzhang/mbtpdf/core/pdfdate

PDF date string parsing and formatting.

## Overview

This package provides utilities for working with PDF date strings as defined in the PDF specification. PDF dates follow the format `D:YYYYMMDDHHmmSSOHH'mm'` where the timezone offset is indicated by `Z` (UTC), `+`, or `-`.

## Types

### Date

Represents a PDF date with all components:

```moonbit nocheck
///|
pub struct Date {
  year : Int // 0-9999
  month : Int // 1-12
  day : Int // 1-31
  hour : Int // 0-23
  minute : Int // 0-59
  second : Int // 0-59
  hour_offset : Int // -23 to +23 (timezone hours)
  minute_offset : Int // -59 to +59 (timezone minutes)
}
```

### BadDate

A suberror raised when parsing fails or date values are invalid.

```moonbit nocheck
///|
pub suberror BadDate
```

## Functions

### Date::of_pdf_string

Parses a PDF date string into a `Date` struct.

Accepts various formats:
- Full format: `D:20240102030405+05'30'`
- UTC: `D:20240102030405Z`
- Negative offset: `D:20240102030405-07'15'`
- Short forms: `D:2024`, `D:202401`, `D:20240102`, etc.
- Without prefix: `20240102030405Z`

Missing components default to sensible values (month/day to 1, time to 0, offset to 0).

**Example:**

```moonbit check
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
```

**Short form example:**

```moonbit check
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
```

### Date::to_pdf_string

Formats a `Date` struct into a PDF date string. Validates the date components and produces a canonical PDF date string.

**Example:**

```moonbit check
///|
test "Date::to_pdf_string roundtrip" {
  let dates = [
    "D:20240102030405Z", "D:20240102030405+05'30'", "D:20240102030405-07'15'",
  ]
  for date_str in dates {
    let date = @pdfdate.Date::of_pdf_string(date_str)
    let formatted = date.to_pdf_string()
    assert_eq(formatted, date_str)
  }
}
```

## Special Case: The 19100 Y2K Quirk

Some legacy PDF software from the Y2K era incorrectly computed the year as `1900 + year` instead of properly handling the century. This resulted in PDFs dated in the year 2000 being written as `D:19100` (1900 + 100 = 19100) instead of `D:2000`.

This parser recognizes the `19100` prefix as a special case and interprets it as year 2000 for compatibility with these malformed documents.

```moonbit check
///|
test "Date::of_pdf_string handles 19100 Y2K quirk" {
  // "19100" was a common Y2K bug: 1900 + 100 = 19100 instead of 2000
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
```

## Error Handling

Both methods raise `BadDate` on invalid input:

```moonbit check
///|
test "Date::of_pdf_string rejects invalid values" {
  // Invalid month (13)
  let bad_month : Result[@pdfdate.Date, Error] = try? @pdfdate.Date::of_pdf_string(
    "D:20241301",
  )
  assert_true(bad_month is Err(_))

  // Non-digit characters in date
  let bad_format : Result[@pdfdate.Date, Error] = try? @pdfdate.Date::of_pdf_string(
    "D:20A4",
  )
  assert_true(bad_format is Err(_))
}
```
