///|
test "pdf detect repeated header/footer noise and normalize digits" {
  let pages = [
    "Quarterly Report 2024\nBody A\nPage 1",
    "Quarterly Report 2025\nBody B\nPage 2",
    "Quarterly Report 2026\nBody C\nPage 3",
  ]

  let (heads, tails) = detect_repeated_page_noise(pages)

  assert_eq(
    contains_string(heads, normalize_noise_key("Quarterly Report 9999")),
    true,
  )
  assert_eq(contains_string(tails, normalize_noise_key("Page 7")), true)
}

///|
test "pdf cross-page merge continuation prefers lowercase continuation" {
  assert_eq(
    should_merge_across_page_break(
      "This paragraph continues",
      "across pages without punctuation",
    ),
    true,
  )

  assert_eq(
    should_merge_across_page_break("This sentence is complete.", "Next section"),
    false,
  )
}

///|
test "pdf heading heuristic keeps short sentence as paragraph" {
  assert_eq(guess_heading_level("This is a normal short sentence."), 0)
  assert_eq(guess_heading_level("Chapter 1 Introduction"), 1)
}
