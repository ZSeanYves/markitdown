///|
pub fn validate_ooxml_package(
  pkg : OoxmlPackage,
  mode? : OoxmlValidationMode = OoxmlValidationMode::Strict,
) -> OoxmlValidationReport {
  let inventory = inspect_ooxml_inventory(pkg)
  let issues = collect_ooxml_validation_issues(pkg, mode~)
  let mut error_count = 0
  let mut warning_count = 0
  for issue in issues {
    match issue.severity {
      OoxmlValidationSeverity::Error => error_count = error_count + 1
      OoxmlValidationSeverity::Warning => warning_count = warning_count + 1
    }
  }
  {
    mode,
    part_count: inventory.part_count,
    relationship_part_count: inventory.relationship_part_count,
    issue_count: issues.length(),
    error_count,
    warning_count,
    issues,
  }
}

///|
pub fn collect_ooxml_validation_issues(
  pkg : OoxmlPackage,
  mode? : OoxmlValidationMode = OoxmlValidationMode::Strict,
) -> Array[OoxmlValidationIssue] {
  let issues : Array[OoxmlValidationIssue] = []
  if mode == OoxmlValidationMode::Compatible {
    return issues
  }

  let inventory = inspect_ooxml_inventory(pkg)
  for rels_part_name in inventory.relationship_parts {
    let source_part = source_part_for_rels_part(rels_part_name)
    let rels_xml = read_part_text(pkg, rels_part_name) catch { _ => continue }
    let tags = collect_start_tags(rels_xml, "Relationship")
    let seen_ids : Map[String, Int] = Map::new()

    for tag in tags {
      let attrs = parse_tag_attributes(tag)
      let rel_id = get_optional_attr(attrs, "Id").trim().to_owned()
      let rel_type = get_optional_attr(attrs, "Type").trim().to_owned()
      let target = get_optional_attr(attrs, "Target").trim().to_owned()
      let target_mode = parse_target_mode(
        get_optional_attr(attrs, "TargetMode"),
      )

      if rel_id == "" {
        issues.push(
          make_validation_issue(
            OoxmlValidationIssueKind::MissingRelationshipId,
            OoxmlValidationSeverity::Error,
            source_part,
            rels_part_name,
            None,
            if target == "" {
              None
            } else {
              Some(target)
            },
            "relationship is missing attribute: Id",
          ),
        )
      } else if seen_ids.contains(rel_id) {
        issues.push(
          make_validation_issue(
            OoxmlValidationIssueKind::DuplicateRelationshipId,
            OoxmlValidationSeverity::Error,
            source_part,
            rels_part_name,
            Some(rel_id),
            if target == "" {
              None
            } else {
              Some(target)
            },
            "duplicate relationship id: " + rel_id,
          ),
        )
      } else {
        seen_ids.set(rel_id, 1)
      }

      if rel_type == "" {
        issues.push(
          make_validation_issue(
            OoxmlValidationIssueKind::MissingRelationshipType,
            OoxmlValidationSeverity::Error,
            source_part,
            rels_part_name,
            if rel_id == "" {
              None
            } else {
              Some(rel_id)
            },
            if target == "" {
              None
            } else {
              Some(target)
            },
            "relationship is missing attribute: Type",
          ),
        )
      }

      if target == "" {
        issues.push(
          make_validation_issue(
            OoxmlValidationIssueKind::MissingRelationshipTarget,
            OoxmlValidationSeverity::Error,
            source_part,
            rels_part_name,
            if rel_id == "" {
              None
            } else {
              Some(rel_id)
            },
            None,
            "relationship is missing attribute: Target",
          ),
        )
      } else if target_mode == OoxmlTargetMode::External {
        issues.push(
          make_validation_issue(
            OoxmlValidationIssueKind::ExternalRelationship,
            OoxmlValidationSeverity::Warning,
            source_part,
            rels_part_name,
            if rel_id == "" {
              None
            } else {
              Some(rel_id)
            },
            Some(target),
            "external relationship is preserved but not fetched",
          ),
        )
      } else {
        let _resolved = resolve_target(
          source_part.unwrap_or(""),
          target,
          target_mode,
        ) catch {
          InvalidPartPath(_) => {
            issues.push(
              make_validation_issue(
                OoxmlValidationIssueKind::UnsafeRelationshipTarget,
                OoxmlValidationSeverity::Error,
                source_part,
                rels_part_name,
                if rel_id == "" {
                  None
                } else {
                  Some(rel_id)
                },
                Some(target),
                "unsafe relationship target: " + target,
              ),
            )
            ""
          }
          _ => ""
        }
        ignore(_resolved)
      }
    }
  }

  issues.sort_by(fn(a, b) { compare_validation_issue(a, b) })
  issues
}

///|
fn make_validation_issue(
  kind : OoxmlValidationIssueKind,
  severity : OoxmlValidationSeverity,
  source_part : String?,
  rels_part_name : String,
  relationship_id : String?,
  target : String?,
  message : String,
) -> OoxmlValidationIssue {
  {
    kind,
    severity,
    part_name: Some(rels_part_name),
    rels_part_name: Some(rels_part_name),
    source_part,
    relationship_id,
    target,
    message,
  }
}

///|
fn source_part_for_rels_part(rels_part_name : String) -> String? {
  if rels_part_name == "_rels/.rels" {
    None
  } else {
    let marker = "/_rels/"
    let idx = find_substring(rels_part_name, marker)
    if idx < 0 {
      None
    } else {
      let dir = rels_part_name[:idx].to_owned()
      let file = rels_part_name[idx + marker.length():].to_owned()
      if !file.has_suffix(".rels") || file.length() <= ".rels".length() {
        None
      } else {
        Some(dir + "/" + file[:file.length() - ".rels".length()].to_owned())
      }
    }
  }
}

///|
fn compare_validation_issue(
  a : OoxmlValidationIssue,
  b : OoxmlValidationIssue,
) -> Int {
  validation_issue_sort_key(a)[:].lexical_compare(
    validation_issue_sort_key(b)[:],
  )
}

///|
fn validation_issue_sort_key(issue : OoxmlValidationIssue) -> String {
  severity_text(issue.severity) +
  ":" +
  issue_kind_text(issue.kind) +
  ":" +
  issue.rels_part_name.unwrap_or("") +
  ":" +
  issue.relationship_id.unwrap_or("") +
  ":" +
  issue.target.unwrap_or("")
}

///|
fn severity_text(severity : OoxmlValidationSeverity) -> String {
  match severity {
    OoxmlValidationSeverity::Error => "0"
    OoxmlValidationSeverity::Warning => "1"
  }
}

///|
fn issue_kind_text(kind : OoxmlValidationIssueKind) -> String {
  match kind {
    OoxmlValidationIssueKind::ExternalRelationship => "ExternalRelationship"
    OoxmlValidationIssueKind::DuplicateRelationshipId =>
      "DuplicateRelationshipId"
    OoxmlValidationIssueKind::MissingRelationshipId => "MissingRelationshipId"
    OoxmlValidationIssueKind::MissingRelationshipType =>
      "MissingRelationshipType"
    OoxmlValidationIssueKind::MissingRelationshipTarget =>
      "MissingRelationshipTarget"
    OoxmlValidationIssueKind::UnsafeRelationshipTarget =>
      "UnsafeRelationshipTarget"
  }
}
