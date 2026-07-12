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
        "format": @input.detected_format_name(entry.format).to_json(),
        "group": capability_group_name(entry.group).to_json(),
        "cli_supported": entry.cli_supported.to_json(),
        "canonical_route": route_name(profile.canonical_route).to_json(),
        "canonical_parser_mode": @parser.mode_name(
          profile.canonical_parser_mode,
        ).to_json(),
        "canonical_ir_input_kind": profile.canonical_ir_input_kind.to_json(),
        "stream_supported": profile.explicit_stream_supported.to_json(),
        "stream_route": profile.explicit_stream_route
        .map(route => route_name(route).to_json())
        .unwrap_or((None : String?).to_json()),
        "large_route": profile.over_limit_route
        .map(route => route_name(route).to_json())
        .unwrap_or((None : String?).to_json()),
        "streaming_granularity": @parser.streaming_granularity_name(
          profile.capability_granularity,
        ).to_json(),
        "parser_contract": contract
        .map(spec => spec.parser_name.to_json())
        .unwrap_or((None : String?).to_json()),
        "current_state": profile.current_state_label.to_json(),
      }),
    )
  }
  Json::object({
    "schema_version": (1).to_json(),
    "formats": formats.to_json(),
    "aliases": Json::array([
      Json::object({
        "alias": "msg".to_json(),
        "target": "eml".to_json(),
        "native_binary_support": false.to_json(),
      }),
    ]),
  })
}
