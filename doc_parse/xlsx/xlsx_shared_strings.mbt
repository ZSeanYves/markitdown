// ============================
// sharedStrings.xml parsing
// ============================
//
// Common:
// <si><t>hello</t></si>
// Rich text:
// <si><r><t>he</t></r><r><t>llo</t></r></si>
// MVP: concat all <t> contents inside <si>

///|
fn parse_shared_strings(
  ss_xml : String,
) -> (Array[String], Array[XlsxValidationIssue]) {
  let out : Array[String] = []
  let issues : Array[XlsxValidationIssue] = []
  let mut pos = 0
  let mut total_text_bytes = 0
  let mut count_truncated = false
  let mut bytes_truncated = false
  let mut item_truncated = false

  while true {
    let si0 = find_sub(ss_xml, "<si", pos)
    match si0 {
      None => break
      Some(si_start) => {
        let si_end0 = find_sub(ss_xml, "</si>", si_start)
        match si_end0 {
          None => break
          Some(si_end) => {
            let chunk = ss_xml[si_start:si_end].to_owned()

            let mut tpos = 0
            let mut acc = ""
            while true {
              let t0 = find_sub(chunk, "<t", tpos)
              match t0 {
                None => break
                Some(t_start) => {
                  let ttag_end = find_sub(chunk, ">", t_start)
                  match ttag_end {
                    None => break
                    Some(t_end_tag) => {
                      let content_start = t_end_tag + 1
                      let t1 = find_sub(chunk, "</t>", content_start)
                      match t1 {
                        None => break
                        Some(t_end) => {
                          let content = chunk[content_start:t_end].to_owned()
                          acc = acc + xml_unescape(content)
                          tpos = t_end + 4
                        }
                      }
                    }
                  }
                }
              }
            }

            if acc.length() > xlsx_max_shared_string_chars_per_item() {
              acc = acc[
                :xlsx_max_shared_string_chars_per_item()
              ].to_owned()
              if !item_truncated {
                issues.push(
                  workbook_issue(
                    XlsxValidationIssueKind::LargeSharedStrings,
                    XlsxValidationSeverity::Warning,
                    Some("xl/sharedStrings.xml"),
                    "shared string item truncated at hard cap: " +
                    xlsx_max_shared_string_chars_per_item().to_string(),
                  ),
                )
                item_truncated = true
              }
            }
            total_text_bytes += acc.length()
            if total_text_bytes > xlsx_max_shared_string_bytes() {
              if !bytes_truncated {
                issues.push(
                  workbook_issue(
                    XlsxValidationIssueKind::LargeSharedStrings,
                    XlsxValidationSeverity::Warning,
                    Some("xl/sharedStrings.xml"),
                    "sharedStrings text bytes truncated at hard cap: " +
                    xlsx_max_shared_string_bytes().to_string(),
                  ),
                )
                bytes_truncated = true
              }
              break
            }
            out.push(acc)
            if out.length() >= xlsx_max_shared_strings() {
              if !count_truncated {
                issues.push(
                  workbook_issue(
                    XlsxValidationIssueKind::LargeSharedStrings,
                    XlsxValidationSeverity::Warning,
                    Some("xl/sharedStrings.xml"),
                    "sharedStrings count truncated at hard cap: " +
                    xlsx_max_shared_strings().to_string(),
                  ),
                )
                count_truncated = true
              }
              break
            }
            pos = si_end + 5
          }
        }
      }
    }
  }

  (out, issues)
}
