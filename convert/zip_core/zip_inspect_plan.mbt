///|
priv struct PlannedEntry {
  raw_path : String
  path : String
  uncompressed_size : Int
  inspect_index : Int
}

///|
priv struct ZipConversionPlan {
  inspect : ZipInspectReport
  plans : Array[PlannedEntry]
}

///|
fn inspect_zip_archive(
  archive : @zipraw.ZipArchive,
  source_name : String,
) -> ZipInspectReport {
  build_zip_conversion_plan(archive, source_name).inspect
}

///|
fn build_zip_conversion_plan(
  archive : @zipraw.ZipArchive,
  source_name : String,
) -> ZipConversionPlan {
  let entries : Array[ZipInspectEntry] = []
  let visible : Array[PlannedEntry] = []
  let mut running_total = 0

  for meta in @zipraw.list_entries(archive) {
    let inspect_index = entries.length()
    let planned = inspect_entry(meta, inspect_index)
    entries.push(planned.0)
    match planned.1 {
      Some(plan) => visible.push(plan)
      None => ()
    }
  }

  let collision_notes = detect_normalized_collisions(visible)
  for collision in collision_notes {
    let idx = collision.0
    let note = collision.1
    let entry = entries[idx]
    entries[idx] = {
      ..entry,
      entry_kind: ZipInspectEntryKind::UnsafePath,
      action: ZipInspectAction::Fail,
      note: Some(note),
    }
  }

  visible.sort_by((a, b) => compare_zip_path(a.path, b.path))
  for i in 0..<visible.length() {
    let plan = visible[i]
    let entry = entries[plan.inspect_index]
    if entry.action == ZipInspectAction::Fail {
      continue
    }

    let upgraded = if i >= MAX_ZIP_ENTRIES {
      {
        ..entry,
        entry_kind: ZipInspectEntryKind::EntryLimitExceeded,
        action: ZipInspectAction::Warn,
        note: Some("entry count limit exceeded"),
      }
    } else if plan.uncompressed_size > MAX_SINGLE_ENTRY_BYTES {
      {
        ..entry,
        entry_kind: ZipInspectEntryKind::EntryTooLarge,
        action: ZipInspectAction::Warn,
        note: Some(
          "entry too large: " + plan.uncompressed_size.to_string() + " bytes",
        ),
      }
    } else if running_total + plan.uncompressed_size > MAX_TOTAL_ENTRY_BYTES {
      {
        ..entry,
        entry_kind: ZipInspectEntryKind::TotalDecodedLimitExceeded,
        action: ZipInspectAction::Warn,
        note: Some("total decoded size limit exceeded"),
      }
    } else {
      running_total += plan.uncompressed_size
      entry
    }
    entries[plan.inspect_index] = upgraded
  }

  let inspect = { source_name, entry_count: entries.length(), entries }
  { inspect, plans: visible }
}

///|
fn inspect_entry(
  meta : @zipraw.ZipEntryMeta,
  inspect_index : Int,
) -> (ZipInspectEntry, PlannedEntry?) {
  let base = base_inspect_entry(meta)
  match plan_entry(meta.name) {
    EntryPlan::Directory =>
      (
        {
          ..base,
          entry_kind: ZipInspectEntryKind::Directory,
          action: ZipInspectAction::Skip,
          note: Some("directory entry"),
        },
        None,
      )
    EntryPlan::Hidden =>
      (
        {
          ..base,
          normalized_path: normalize_zip_entry_path(meta.name),
          entry_kind: ZipInspectEntryKind::HiddenMetadata,
          action: ZipInspectAction::Skip,
          note: Some("hidden or macOS metadata entry"),
        },
        None,
      )
    EntryPlan::Unsafe(display) =>
      (
        {
          ..base,
          entry_kind: ZipInspectEntryKind::UnsafePath,
          action: ZipInspectAction::Fail,
          note: Some("unsafe archive path: " + display),
        },
        None,
      )
    EntryPlan::Visible(path) => {
      let ext = @cor.file_ext_lower(path)
      let entry_kind = if is_nested_archive_ext(ext) {
        ZipInspectEntryKind::NestedArchive
      } else if is_supported_entry_ext(ext) {
        ZipInspectEntryKind::Supported
      } else {
        ZipInspectEntryKind::Unsupported
      }
      let action = match entry_kind {
        ZipInspectEntryKind::Supported => ZipInspectAction::Convert
        ZipInspectEntryKind::NestedArchive => ZipInspectAction::Warn
        ZipInspectEntryKind::Unsupported => ZipInspectAction::Warn
        _ => ZipInspectAction::Skip
      }
      let note = match entry_kind {
        ZipInspectEntryKind::NestedArchive =>
          Some("nested archive is not supported: " + ext)
        ZipInspectEntryKind::Unsupported =>
          Some("unsupported file type: " + ext)
        _ => None
      }
      (
        {
          ..base,
          normalized_path: Some(path),
          entry_kind,
          action,
          dispatch_format: inspect_dispatch_format(ext),
          note,
        },
        Some({
          raw_path: meta.name,
          path,
          uncompressed_size: meta.uncompressed_size,
          inspect_index,
        }),
      )
    }
  }
}

///|
fn base_inspect_entry(meta : @zipraw.ZipEntryMeta) -> ZipInspectEntry {
  {
    raw_name: meta.name,
    normalized_path: None,
    entry_kind: ZipInspectEntryKind::Unsupported,
    action: ZipInspectAction::Skip,
    compression_method: meta.compression_method,
    compressed_size: meta.compressed_size,
    uncompressed_size: meta.uncompressed_size,
    flags: meta.flags,
    has_data_descriptor: meta.has_data_descriptor,
    is_encrypted: meta.is_encrypted,
    uses_zip64: meta.uses_zip64,
    local_header_offset: meta.local_header_offset,
    crc32: meta.crc32,
    dispatch_format: None,
    note: None,
  }
}

///|
fn detect_normalized_collisions(
  plans : Array[PlannedEntry],
) -> Array[(Int, String)] {
  let seen : Map[String, PlannedEntry] = Map([])
  let out : Array[(Int, String)] = []
  for plan in plans {
    match seen.get(plan.path) {
      Some(first) => {
        let note = "normalized path collision: " +
          plan.path +
          " (" +
          display_path(first.raw_path) +
          " vs " +
          display_path(plan.raw_path) +
          ")"
        out.push((first.inspect_index, note))
        out.push((plan.inspect_index, note))
      }
      None => seen.set(plan.path, plan)
    }
  }
  out
}

///|
fn fail_on_inspect_plan_errors(inspect : ZipInspectReport) -> Unit raise {
  for entry in inspect.entries {
    match entry.action {
      ZipInspectAction::Fail =>
        raise @cor.AppError(
          "zip: " + entry.note.unwrap_or("entry planning failed"),
        )
      _ => ()
    }
  }
}

///|
fn inspect_dispatch_format(ext : String) -> String? {
  match ext {
    "docx"
    | "pdf"
    | "xlsx"
    | "pptx"
    | "html"
    | "htm"
    | "csv"
    | "tsv"
    | "txt"
    | "xml"
    | "json"
    | "yaml"
    | "yml"
    | "md"
    | "markdown" => Some(ext)
    _ => None
  }
}

///|
priv enum EntryPlan {
  Directory
  Hidden
  Unsafe(String)
  Visible(String)
}

///|
fn plan_entry(raw_path : String) -> EntryPlan {
  if raw_path.has_suffix("/") || raw_path.has_suffix("\\") {
    return EntryPlan::Directory
  }
  match normalize_zip_entry_path(raw_path) {
    None => EntryPlan::Unsafe(display_path(raw_path))
    Some(path) =>
      if is_hidden_or_macos_metadata(path) {
        EntryPlan::Hidden
      } else {
        EntryPlan::Visible(path)
      }
  }
}
