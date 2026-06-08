///|
/// Convert-owned entity decoding helper used by href and inline text policy.
fn html_unescape(s : String) -> String {
  @dphtml.decode_html_entities(s)
}
