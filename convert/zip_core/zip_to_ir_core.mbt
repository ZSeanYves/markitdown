///|
const MAX_ZIP_ENTRIES : Int = 200

///|
const MAX_SINGLE_ENTRY_BYTES : Int = 128 * 1024 * 1024

///|
const MAX_TOTAL_ENTRY_BYTES : Int = 256 * 1024 * 1024

///|
pub(all) enum ZipInspectEntryKind {
  Supported
  NestedArchive
  Unsupported
  Directory
  HiddenMetadata
  UnsafePath
  EntryLimitExceeded
  EntryTooLarge
  TotalDecodedLimitExceeded
} derive(Eq)

///|
pub(all) enum ZipInspectAction {
  Convert
  Skip
  Warn
  Fail
} derive(Eq)

///|
pub struct ZipInspectEntry {
  raw_name : String
  normalized_path : String?
  entry_kind : ZipInspectEntryKind
  action : ZipInspectAction
  compression_method : @zipraw.CompressionMethod
  compressed_size : Int
  uncompressed_size : Int
  flags : Int
  has_data_descriptor : Bool
  is_encrypted : Bool
  uses_zip64 : Bool
  local_header_offset : Int
  crc32 : Int
  dispatch_format : String?
  note : String?
}

///|
pub struct ZipInspectReport {
  source_name : String
  entry_count : Int
  entries : Array[ZipInspectEntry]
}

///|
pub fn inspect_zip(input_path : String) -> ZipInspectReport raise {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("zip: file not found: " + input_path)
  }

  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("zip: read failed: " + e.to_string())
  }
  let archive = @zipraw.open_zip(bytes) catch {
    e => raise @cor.AppError("zip: open failed: " + e.to_string())
  }

  inspect_zip_archive(archive, @cor.basename(input_path))
}

///|
pub async fn parse_zip(
  input_path : String,
  out_dir : String,
  max_heading : Int,
  parse_pdf_entry : async (String, String, Int) -> @cor.Document,
) -> @cor.Document {
  parse_zip_with_profile(input_path, out_dir, max_heading, parse_pdf_entry).0
}

///|
pub async fn parse_zip_with_profile(
  input_path : String,
  out_dir : String,
  max_heading : Int,
  parse_pdf_entry : async (String, String, Int) -> @cor.Document,
) -> (@cor.Document, ZipProfileReport?) {
  if !@fs.path_exists(input_path) {
    raise @cor.AppError("zip: file not found: " + input_path)
  }

  let profile = if zip_profile_enabled() {
    Some(new_zip_profile_report(input_path))
  } else {
    None
  }
  let profile_active = zip_profile_active(profile)

  let open_started = zip_profile_now(profile)
  let bytes = @fs.read_file_to_bytes(input_path) catch {
    e => raise @cor.AppError("zip: read failed: " + e.to_string())
  }
  let archive = @zipraw.open_zip(bytes) catch {
    e => raise @cor.AppError("zip: open failed: " + e.to_string())
  }
  if profile_active {
    zip_profile_add_stage(
      profile,
      "zip_open",
      zip_profile_elapsed(profile, open_started),
      Some("archive_bytes=" + bytes.length().to_string()),
    )
  }

  let inspect_started = zip_profile_now(profile)
  let conversion_plan = build_zip_conversion_plan(
    archive, @cor.basename(input_path),
  )
  let inspect_elapsed = zip_profile_elapsed(profile, inspect_started)
  let inspect = conversion_plan.inspect

  let doc = @cor.new_document()
  let zip_name = inspect.source_name
  let tmp_root = allocate_archive_run_dir(zip_tmp_dir(input_path), "run")
  let staged_entries_root = tmp_root + "/entries"
  ensure_dir_tree(tmp_root) catch {
    e => raise @cor.AppError("zip: create temp dir failed: " + e.to_string())
  }
  let archive_out_dir = if out_dir.trim() == "" {
    tmp_root + "/archive-out"
  } else {
    out_dir
  }
  if out_dir.trim() != "" {
    defer ignore(try? cleanup_archive_run_dir(tmp_root))
  }
  ensure_dir_tree(archive_out_dir) catch {
    e =>
      raise @cor.AppError(
        "zip: create archive output dir failed: " + e.to_string(),
      )
  }
  ensure_dir_tree(staged_entries_root) catch {
    e =>
      raise @cor.AppError(
        "zip: create staged entries dir failed: " + e.to_string(),
      )
  }

  let filter_counts = if profile_active {
    Some(summarize_inspect_entries(inspect))
  } else {
    None
  }
  match filter_counts {
    Some(counts) =>
    zip_profile_add_summary(
      profile,
      "counts total_entries=" +
      inspect.entry_count.to_string() +
      " converted_entries=" +
      counts.converted_entries.to_string() +
      " skipped_entries=" +
      counts.skipped_entries.to_string() +
      " unsupported_entries=" +
      counts.unsupported_entries.to_string() +
      " nested_archive_entries=" +
      counts.nested_archive_entries.to_string(),
    )
    None => ()
  }
  if profile_active {
    zip_profile_add_stage(
      profile,
      "zip_list_entries",
      inspect_elapsed,
      Some("entries=" + inspect.entry_count.to_string()),
    )
  }

  let plan_started = zip_profile_now(profile)
  fail_on_inspect_plan_errors(inspect)
  let plans = conversion_plan.plans
  let plan_elapsed = zip_profile_elapsed(profile, plan_started)
  match filter_counts {
    Some(counts) =>
    zip_profile_add_stage(
      profile,
      "zip_filter_entries",
      plan_elapsed,
      Some(
        "plans=" +
        plans.length().to_string() +
        " convertible=" +
        counts.converted_entries.to_string(),
      ),
    )
    None => ()
  }
  if profile_active {
    zip_profile_add_stage(
      profile,
      "zip_sort_entries",
      0,
      Some("planned_entries_sorted=" + plans.length().to_string()),
    )
  }

  let final_md = StringBuilder::new()
  let used_ids : Map[String, Int] = Map([])
  let mut total_decoded = 0
  let mut converted_entries = 0
  let mut warning_entries = 0
  let mut asset_remap_entries = 0
  let extracted_root = tmp_root + "/extracted"
  let mut shared_extracted_ready = false
  let extract_elapsed : Ref[UInt64] = { val: 0 }
  let stage_elapsed : Ref[UInt64] = { val: 0 }
  let dispatch_elapsed : Ref[UInt64] = { val: 0 }
  let aggregate_elapsed : Ref[UInt64] = { val: 0 }
  let remap_elapsed : Ref[UInt64] = { val: 0 }
  let mut staged_input_entries = 0
  let mut shared_input_entries = 0
  let mut output_dir_entries = 0
  let entry_cache = new_zip_entry_byte_cache()

  for i in 0..<plans.length() {
    let plan = plans[i]
    if i >= MAX_ZIP_ENTRIES {
      if profile_active {
        warning_entries += 1
      }
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: entry count limit exceeded",
      )
      continue
    }

    let ext = @cor.file_ext_lower(plan.path)
    if is_nested_archive_ext(ext) {
      if profile_active {
        warning_entries += 1
      }
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: nested archive is not supported: " + ext,
      )
      continue
    }
    if !is_supported_entry_ext(ext) {
      if profile_active {
        warning_entries += 1
      }
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: unsupported file type: " + ext,
      )
      continue
    }
    if plan.uncompressed_size > MAX_SINGLE_ENTRY_BYTES {
      if profile_active {
        warning_entries += 1
      }
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: entry too large: " +
        plan.uncompressed_size.to_string() +
        " bytes",
      )
      continue
    }
    if total_decoded + plan.uncompressed_size > MAX_TOTAL_ENTRY_BYTES {
      if profile_active {
        warning_entries += 1
      }
      append_warning_entry(
        doc,
        final_md,
        zip_name,
        plan.path,
        "Skipped: total decoded size limit exceeded",
      )
      continue
    }

    let read_started = zip_profile_now(profile)
    let entry_bytes = read_entry_for_materialization(
      archive, plan, entry_cache,
    ) catch {
      e => {
        if profile_active {
          warning_entries += 1
        }
        append_warning_entry(
          doc,
          final_md,
          zip_name,
          plan.path,
          "Conversion failed: zip read failed: " + e.to_string(),
        )
        continue
      }
    }
    zip_entry_cache_put(entry_cache, plan.raw_path, entry_bytes)
    extract_elapsed.val = extract_elapsed.val +
      zip_profile_elapsed(profile, read_started)
    total_decoded += entry_bytes.length()

    let use_shared_extracted_input = is_html_entry_ext(ext) &&
      html_entry_has_local_image_refs(entry_bytes)
    if use_shared_extracted_input && !shared_extracted_ready {
      let shared_extract_started = zip_profile_now(profile)
      materialize_safe_archive_tree(
        archive, plans, extracted_root, entry_cache,
      ) catch {
        e => {
          if profile_active {
            warning_entries += 1
          }
          append_warning_entry(
            doc,
            final_md,
            zip_name,
            plan.path,
            "Conversion failed: " + e.to_string(),
          )
          continue
        }
      }
      extract_elapsed.val = extract_elapsed.val +
        zip_profile_elapsed(profile, shared_extract_started)
      shared_extracted_ready = true
    }

    let entry_id = unique_entry_id(plan.path, used_ids)
    let entry_out = if zip_entry_requires_output_dir(ext) {
      Some(tmp_root + "/out/" + entry_id)
    } else {
      None
    }
    let stage_started = zip_profile_now(profile)
    let dispatch_out_dir = match entry_out {
      Some(dir) => {
        ensure_dir_tree(dir) catch {
          e => {
            append_warning_entry(
              doc,
              final_md,
              zip_name,
              plan.path,
              "Conversion failed: create entry output dir failed: " +
              e.to_string(),
            )
            continue
          }
        }
        if profile_active {
          output_dir_entries += 1
        }
        dir
      }
      None => ""
    }
    let input_path = if use_shared_extracted_input {
      if profile_active {
        shared_input_entries += 1
      }
      extracted_entry_path(extracted_root, plan.path) catch {
        e => {
          if profile_active {
            warning_entries += 1
          }
          append_warning_entry(
            doc,
            final_md,
            zip_name,
            plan.path,
            "Conversion failed: " + e.to_string(),
          )
          continue
        }
      }
    } else {
      let uses_flat_staging = zip_entry_uses_flat_staging(ext)
      let entry_path = if uses_flat_staging {
        staged_entries_root + "/" + entry_id
      } else {
        staged_entries_root + "/" + entry_id + "/" + plan.path
      }
      if !uses_flat_staging {
        ensure_parent_dir(entry_path) catch {
          e => {
            append_warning_entry(
              doc,
              final_md,
              zip_name,
              plan.path,
              "Conversion failed: create temp path failed: " + e.to_string(),
            )
            continue
          }
        }
      }
      if profile_active {
        staged_input_entries += 1
      }
      @fs.write_bytes_to_file(entry_path, entry_bytes) catch {
        e => {
          if profile_active {
            warning_entries += 1
          }
          append_warning_entry(
            doc,
            final_md,
            zip_name,
            plan.path,
            "Conversion failed: write temp entry failed: " + e.to_string(),
          )
          continue
        }
      }
      entry_path
    }
    stage_elapsed.val = stage_elapsed.val +
      zip_profile_elapsed(profile, stage_started)

    let dispatch_started = zip_profile_now(profile)
    let subdoc = parse_supported_entry(
      input_path, ext, dispatch_out_dir, max_heading, parse_pdf_entry,
    ) catch {
      e => {
        if profile_active {
          warning_entries += 1
        }
        append_warning_entry(
          doc,
          final_md,
          zip_name,
          plan.path,
          "Conversion failed: " + e.to_string(),
        )
        continue
      }
    }
    dispatch_elapsed.val = dispatch_elapsed.val +
      zip_profile_elapsed(profile, dispatch_started)

    let remapped_subdoc = if doc_has_assets(subdoc) {
      let remap_started = zip_profile_now(profile)
      let remapped = remap_subdoc_assets(
        subdoc,
        entry_id,
        dispatch_out_dir,
        archive_out_dir,
        zip_name,
        plan.path,
      ) catch {
        e => {
          if profile_active {
            warning_entries += 1
          }
          append_warning_entry(
            doc,
            final_md,
            zip_name,
            plan.path,
            "Conversion failed: " + e.to_string(),
          )
          continue
        }
      }
      remap_elapsed.val = remap_elapsed.val +
        zip_profile_elapsed(profile, remap_started)
      if profile_active {
        asset_remap_entries += 1
      }
      remapped
    } else {
      subdoc
    }
    let aggregate_started = zip_profile_now(profile)
    append_converted_entry(
      doc,
      final_md,
      remapped_subdoc,
      zip_name,
      plan.path,
      @cor.emit_markdown(remapped_subdoc),
    )
    aggregate_elapsed.val = aggregate_elapsed.val +
      zip_profile_elapsed(profile, aggregate_started)
    if profile_active {
      converted_entries += 1
    }
  }

  if profile_active {
    zip_profile_add_summary(
      profile,
      "result total_entries=" +
      inspect.entry_count.to_string() +
      " converted_entries=" +
      converted_entries.to_string() +
      " warning_entries=" +
      warning_entries.to_string() +
      " total_decompressed_bytes=" +
      total_decoded.to_string() +
      " output_markdown_bytes=" +
      final_md.to_string().length().to_string() +
      " asset_count=" +
      doc.asset_origins.val.length().to_string(),
    )
    zip_profile_add_stage(
      profile,
      "zip_extract_entry_total",
      extract_elapsed.val,
      Some("total_decompressed_bytes=" + total_decoded.to_string()),
    )
    zip_profile_add_stage(
      profile,
      "zip_stage_entry_total",
      stage_elapsed.val,
      Some(
        "staged_input_entries=" +
        staged_input_entries.to_string() +
        " shared_input_entries=" +
        shared_input_entries.to_string() +
        " output_dir_entries=" +
        output_dir_entries.to_string(),
      ),
    )
    zip_profile_add_stage(
      profile,
      "zip_dispatch_entry_total",
      dispatch_elapsed.val,
      Some("converted_entries=" + converted_entries.to_string()),
    )
    zip_profile_add_stage(
      profile,
      "zip_markdown_aggregate",
      aggregate_elapsed.val,
      Some("markdown_bytes=" + final_md.to_string().length().to_string()),
    )
    zip_profile_add_stage(
      profile,
      "zip_asset_remap",
      remap_elapsed.val,
      Some("asset_entries=" + asset_remap_entries.to_string()),
    )
  }

  @cor.set_passthrough_markdown(doc, final_md.to_string())
  (doc, profile)
}

///|
priv struct ZipInspectCounts {
  converted_entries : Int
  skipped_entries : Int
  unsupported_entries : Int
  nested_archive_entries : Int
}

///|
fn summarize_inspect_entries(inspect : ZipInspectReport) -> ZipInspectCounts {
  let mut converted_entries = 0
  let mut skipped_entries = 0
  let mut unsupported_entries = 0
  let mut nested_archive_entries = 0

  for entry in inspect.entries {
    match entry.entry_kind {
      ZipInspectEntryKind::Supported =>
        if entry.action == ZipInspectAction::Convert {
          converted_entries += 1
        } else {
          skipped_entries += 1
        }
      ZipInspectEntryKind::NestedArchive => {
        nested_archive_entries += 1
        skipped_entries += 1
      }
      ZipInspectEntryKind::Unsupported => {
        unsupported_entries += 1
        skipped_entries += 1
      }
      ZipInspectEntryKind::Directory
      | ZipInspectEntryKind::HiddenMetadata
      | ZipInspectEntryKind::UnsafePath
      | ZipInspectEntryKind::EntryLimitExceeded
      | ZipInspectEntryKind::EntryTooLarge
      | ZipInspectEntryKind::TotalDecodedLimitExceeded => skipped_entries += 1
    }
  }

  {
    converted_entries,
    skipped_entries,
    unsupported_entries,
    nested_archive_entries,
  }
}

///|
async fn parse_supported_entry(
  input_path : String,
  ext : String,
  out_dir : String,
  max_heading : Int,
  parse_pdf_entry : async (String, String, Int) -> @cor.Document,
) -> @cor.Document {
  match ext {
    "docx" => @doc.parse_docx(input_path, out_dir, max_heading)
    "pdf" => parse_pdf_entry(input_path, out_dir, max_heading)
    "xlsx" => @xlsx.parse_xlsx(input_path, out_dir, max_heading)
    "pptx" => @pptx.parse_pptx(input_path, out_dir, max_heading)
    "html" => @html.parse_html(input_path, out_dir, max_heading)
    "htm" => @html.parse_html(input_path, out_dir, max_heading)
    "csv" => @csv.parse_csv(input_path, out_dir, max_heading)
    "tsv" => @csv.parse_tsv(input_path, out_dir, max_heading)
    "txt" => @txt.parse_txt(input_path, out_dir, max_heading)
    "xml" => @xml.parse_xml(input_path, out_dir, max_heading)
    "json" => @json.parse_json(input_path, out_dir, max_heading)
    "yaml" => @yaml.parse_yaml(input_path, out_dir, max_heading)
    "yml" => @yaml.parse_yaml(input_path, out_dir, max_heading)
    "md" => @md.parse_markdown(input_path, out_dir, max_heading)
    "markdown" => @md.parse_markdown(input_path, out_dir, max_heading)
    _ => raise @cor.AppError("unsupported zip entry type: " + ext)
  }
}
