///|
/// Optional CLI profiling helpers for selected in-process converters.
///
/// This keeps environment gates, stage recording, and profile-log emission out
/// of the main conversion flow while preserving existing profile env vars,
/// stage names, and log filenames.
fn debug_profile_xlsx_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_XLSX") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn debug_profile_json_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_JSON") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn debug_profile_csv_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_CSV") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn debug_profile_txt_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_TXT") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn debug_profile_yaml_enabled() -> Bool {
  match @sys.get_env_var("MARKITDOWN_PROFILE_YAML") {
    Some(raw) => {
      let value = raw.trim().to_lower()
      value == "1" || value == "true" || value == "yes" || value == "on"
    }
    None => false
  }
}

///|
fn xlsx_profile_push_cli_stage(
  profile : @xlsx.XlsxProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @xlsx.xlsx_profile_add_stage(profile, name, elapsed_ms, detail)
}

///|
fn csv_profile_push_cli_stage(
  profile : @csv.CsvProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @csv.csv_profile_add_stage(profile, name, elapsed_ms, detail)
}

///|
fn json_profile_push_cli_stage(
  profile : @json.JsonProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @json.json_profile_add_stage(profile, name, elapsed_ms, detail)
}

///|
fn txt_profile_push_cli_stage(
  profile : @txt.TxtProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @txt.txt_profile_add_stage(profile, name, elapsed_ms, detail)
}

///|
fn yaml_profile_push_cli_stage(
  profile : @yaml.YamlProfileReport?,
  name : String,
  elapsed_ms : UInt64,
  detail : String?,
) -> Unit {
  @yaml.yaml_profile_add_stage(profile, name, elapsed_ms, detail)
}

///|
fn write_xlsx_profile_log_if_enabled(
  profile : @xlsx.XlsxProfileReport?,
  markdown_path : String,
  with_metadata : Bool,
) -> Unit raise @fs.IOError {
  match profile {
    None => ()
    Some(rep) => {
      let debug_dir = join_path(dirname_of_path(markdown_path), "debug")
      ensure_dir_tree(debug_dir)
      let profile_path = join_path(
        debug_dir,
        input_stem(markdown_path) + ".xlsx.profile.log",
      )
      let lines : Array[String] = [
        @xlsx.xlsx_profile_render_report(rep),
        "xlsx_profile cli markdown_output=" + markdown_path,
        "xlsx_profile cli metadata_enabled=" + with_metadata.to_string(),
      ]
      @fs.write_string_to_file(
        profile_path,
        lines.join("\n") + "\n",
        encoding="utf8",
      )
    }
  }
}

///|
fn write_csv_profile_log_if_enabled(
  profile : @csv.CsvProfileReport?,
  markdown_path : String,
  with_metadata : Bool,
) -> Unit raise @fs.IOError {
  match profile {
    None => ()
    Some(rep) => {
      let debug_dir = join_path(dirname_of_path(markdown_path), "debug")
      ensure_dir_tree(debug_dir)
      let profile_path = join_path(
        debug_dir,
        input_stem(markdown_path) + ".csv.profile.log",
      )
      let lines : Array[String] = [
        @csv.csv_profile_render_report(rep),
        "csv_profile cli markdown_output=" + markdown_path,
        "csv_profile cli metadata_enabled=" + with_metadata.to_string(),
      ]
      @fs.write_string_to_file(
        profile_path,
        lines.join("\n") + "\n",
        encoding="utf8",
      )
    }
  }
}

///|
fn write_json_profile_log_if_enabled(
  profile : @json.JsonProfileReport?,
  markdown_path : String,
  with_metadata : Bool,
) -> Unit raise @fs.IOError {
  match profile {
    None => ()
    Some(rep) => {
      let debug_dir = join_path(dirname_of_path(markdown_path), "debug")
      ensure_dir_tree(debug_dir)
      let profile_path = join_path(
        debug_dir,
        input_stem(markdown_path) + ".json.profile.log",
      )
      let lines : Array[String] = [
        @json.json_profile_render_report(rep),
        "json_profile cli markdown_output=" + markdown_path,
        "json_profile cli metadata_enabled=" + with_metadata.to_string(),
      ]
      @fs.write_string_to_file(
        profile_path,
        lines.join("\n") + "\n",
        encoding="utf8",
      )
    }
  }
}

///|
fn write_txt_profile_log_if_enabled(
  profile : @txt.TxtProfileReport?,
  markdown_path : String,
  with_metadata : Bool,
) -> Unit raise @fs.IOError {
  match profile {
    None => ()
    Some(rep) => {
      let debug_dir = join_path(dirname_of_path(markdown_path), "debug")
      ensure_dir_tree(debug_dir)
      let profile_path = join_path(
        debug_dir,
        input_stem(markdown_path) + ".txt.profile.log",
      )
      let lines : Array[String] = [
        @txt.txt_profile_render_report(rep),
        "txt_profile cli markdown_output=" + markdown_path,
        "txt_profile cli metadata_enabled=" + with_metadata.to_string(),
      ]
      @fs.write_string_to_file(
        profile_path,
        lines.join("\n") + "\n",
        encoding="utf8",
      )
    }
  }
}

///|
fn write_yaml_profile_log_if_enabled(
  profile : @yaml.YamlProfileReport?,
  markdown_path : String,
  with_metadata : Bool,
) -> Unit raise @fs.IOError {
  match profile {
    None => ()
    Some(rep) => {
      let debug_dir = join_path(dirname_of_path(markdown_path), "debug")
      ensure_dir_tree(debug_dir)
      let profile_path = join_path(
        debug_dir,
        input_stem(markdown_path) + ".yaml.profile.log",
      )
      let lines : Array[String] = [
        @yaml.yaml_profile_render_report(rep),
        "yaml_profile cli markdown_output=" + markdown_path,
        "yaml_profile cli metadata_enabled=" + with_metadata.to_string(),
      ]
      @fs.write_string_to_file(
        profile_path,
        lines.join("\n") + "\n",
        encoding="utf8",
      )
    }
  }
}
