///|
test "text markup asset paths preserve identity without traversal" {
  assert_eq(
    text_markup_asset_output_path("rst", "figures/local image.png"),
    "assets/rst-figures_2flocal_20image.png",
  )
  assert_eq(
    text_markup_asset_output_path("tex", "figures\\plot.jpg"),
    "assets/tex-figures_2fplot.jpg",
  )
  assert_true(
    text_markup_asset_output_path("asciidoc", "../secret.png").has_prefix(
      "assets/asciidoc-",
    ),
  )
}
