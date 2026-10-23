///|
/// Export the registry, route profile, and parser contract as one stable
/// machine-readable product capability manifest.
pub fn capability_manifest_json() -> Json {
  let formats : Array[Json] = []
  for entry in capability_entries() {
    let profile = format_route_profile(entry.format)
    let contract = product_parser_contract_spec_by_format(entry.format)
    formats.push(
      Json::object({
        "format": Json(@input.detected_format_name(entry.format)),
        "group": Json(capability_group_name(entry.group)),
        "cli_supported": Json(entry.cli_supported),
        "canonical_route": Json(route_name(profile.canonical_route)),
        "canonical_parser_mode": Json(
          @parser.mode_name(profile.canonical_parser_mode),
        ),
        "canonical_ir_input_kind": Json(profile.canonical_ir_input_kind),
        "stream_supported": Json(profile.explicit_stream_supported),
        "stream_route": Json(
          profile.explicit_stream_route.map(route => route_name(route)),
        ),
        "large_route": Json(
          profile.over_limit_route.map(route => route_name(route)),
        ),
        "streaming_granularity": Json(
          @parser.streaming_granularity_name(profile.capability_granularity),
        ),
        "parser_contract": Json(contract.map(spec => spec.parser_name)),
        "current_state": Json(profile.current_state_label),
      }),
    )
  }
  Json::object({
    "schema_version": Json(1),
    "formats": Json(formats),
    "aliases": Json::array([
      Json::object({
        "alias": Json("msg"),
        "target": Json("eml"),
        "native_binary_support": Json(false),
      }),
    ]),
  })
}
