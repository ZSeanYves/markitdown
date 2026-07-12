///|
test "diagnostics builders retain modes traces metrics and dependencies" {
  let diagnostics = empty_diagnostics()
    |> diagnostics_with_parser(Some("fixture"), Some("streaming_event"))
    |> diagnostics_with_mode(
      Some("block_streaming"),
      Some("balanced"),
      fidelity_mode=Some("native"),
      output_mode=Some("markdown"),
    )
    |> diagnostics_with_input(Some("memory"), Some("json"))
    |> diagnostics_add_metric("rows", "3")
    |> diagnostics_add_warning("warning")
    |> diagnostics_add_error("error")
    |> diagnostics_add_degraded_feature("tables")
    |> diagnostics_add_same_mode_degradation("reduced_layout")
    |> diagnostics_add_same_mode_strategy_switch("stream_to_dom")
    |> diagnostics_add_fallback_trace("native->fallback")
    |> diagnostics_add_pass_trace("normalize")
  assert_true(diagnostics.parser_name == Some("fixture"))
  assert_true(diagnostics.parser_mode == Some("block_streaming"))
  assert_true(diagnostics.convert_mode == Some("balanced"))
  assert_true(diagnostics.fidelity_mode == Some("native"))
  assert_true(diagnostics.output_mode == Some("markdown"))
  assert_true(diagnostics.input_kind == Some("memory"))
  assert_true(diagnostics.detected_format == Some("json"))
  assert_true(diagnostics.metrics.get("rows") == Some("3"))
  assert_true(diagnostics.warnings == ["warning"])
  assert_true(diagnostics.errors == ["error"])
  assert_true(diagnostics.degraded_features == ["tables"])
  assert_true(diagnostics.same_mode_degradation == ["reduced_layout"])
  assert_true(diagnostics.same_mode_strategy_switches == ["stream_to_dom"])
  assert_true(diagnostics.fallback_trace == ["native->fallback"])
  assert_true(diagnostics.pass_trace == ["normalize"])

  let dependency = make_dependency_diagnostic(
    "binary",
    "pdftoppm",
    "optional PDF rendering",
    DependencyDiagnosticStatus::Degraded,
    ["brew install poppler"],
    ["apt-get install poppler-utils"],
    footer=Some("restart after installation"),
  )
  let with_dependency = diagnostics_add_dependency_diagnostic(
    diagnostics, dependency,
  )
  assert_eq(with_dependency.dependency_diagnostics.length(), 1)
  assert_eq(
    dependency_diagnostic_status_name(DependencyDiagnosticStatus::Missing),
    "missing",
  )
  assert_eq(
    dependency_diagnostic_status_name(DependencyDiagnosticStatus::Available),
    "available",
  )
  assert_eq(
    dependency_diagnostic_status_name(DependencyDiagnosticStatus::Degraded),
    "degraded",
  )
}

///|
test "debug JSON helpers escape control characters and optionals" {
  assert_eq(
    json_string("quote\" slash\\ line\nreturn\rtab\t"),
    "\"quote\\\" slash\\\\ line\\nreturn\\rtab\\t\"",
  )
  assert_eq(json_string_opt(None), "null")
  assert_eq(json_string_opt(Some("value")), "\"value\"")
  assert_eq(string_array_json(["a", "b"]), "[\"a\", \"b\"]")
  assert_eq(string_array_json_opt([]), "[]")
  assert_eq(array_json(["1", "2"]), "[1, 2]")
  assert_eq(object_json(["\"a\": 1", "\"b\": 2"]), "{\"a\": 1, \"b\": 2}")
}
