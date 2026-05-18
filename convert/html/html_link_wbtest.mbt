///|
test "html sanitize unwraps bing click redirect hrefs" {
  assert_eq(
    sanitize_html_href(
      "https://www.bing.com/ck/a?!&&p=abc&u=a1aHR0cHM6Ly9leGFtcGxlLmNvbS9kb2Nz&ntb=1",
    ).unwrap_or(""),
    "https://example.com/docs",
  )
}

///|
test "html sanitize keeps safe non-wrapper hrefs unchanged" {
  assert_eq(
    sanitize_html_href("https://example.com/basic?x=1&y=2").unwrap_or(""),
    "https://example.com/basic?x=1&y=2",
  )
}

///|
test "html anchor attr reader plus sanitize unwraps bing click redirect hrefs" {
  let tag =
    "<a href=\"https://www.bing.com/ck/a?!&&amp;p=abc&amp;u=a1aHR0cHM6Ly9leGFtcGxlLmNvbS9kb2Nz&amp;ntb=1\">"
  let href = sanitize_html_href(read_html_attr_value(tag, "href").unwrap_or(""))
  assert_eq(href.unwrap_or(""), "https://example.com/docs")
}

///|
test "html_unescape decodes amp entities inside href-like strings" {
  assert_eq(
    html_unescape("https://www.bing.com/ck/a?!&&amp;p=abc&amp;u=test"),
    "https://www.bing.com/ck/a?!&&p=abc&u=test",
  )
}
