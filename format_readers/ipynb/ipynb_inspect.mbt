///|
pub fn inspect_ipynb_notebook(notebook : IpynbNotebook) -> IpynbInspectReport {
  let mut markdown_cell_count = 0
  let mut code_cell_count = 0
  let mut raw_cell_count = 0
  let mut output_count = 0
  let mut stream_output_count = 0
  let mut display_data_count = 0
  let mut execute_result_count = 0
  let mut error_output_count = 0
  let mut attachment_count = 0
  let mut mime_entry_count = 0
  let mut asset_candidate_count = 0
  let mut max_cell_source_chars = 0
  let mut max_output_text_chars = 0
  for cell in notebook.cells {
    match cell.kind {
      IpynbCellKind::Markdown => markdown_cell_count += 1
      IpynbCellKind::Code => code_cell_count += 1
      IpynbCellKind::Raw => raw_cell_count += 1
      _ => ()
    }
    if cell.source.length() > max_cell_source_chars {
      max_cell_source_chars = cell.source.length()
    }
    attachment_count += cell.attachments.length()
    for attachment in cell.attachments {
      mime_entry_count += attachment.mime_entries.length()
      for entry in attachment.mime_entries {
        if ipynb_mime_is_image(entry.mime_type) {
          asset_candidate_count += 1
        }
      }
    }
    output_count += cell.outputs.length()
    for output in cell.outputs {
      match output.kind {
        IpynbOutputKind::Stream => stream_output_count += 1
        IpynbOutputKind::DisplayData => display_data_count += 1
        IpynbOutputKind::ExecuteResult => execute_result_count += 1
        IpynbOutputKind::Error => error_output_count += 1
        _ => ()
      }
      if output.text is Some(text) && text.length() > max_output_text_chars {
        max_output_text_chars = text.length()
      }
      let traceback_text = output.traceback.join("")
      if traceback_text.length() > max_output_text_chars {
        max_output_text_chars = traceback_text.length()
      }
      mime_entry_count += output.mime_entries.length()
      for entry in output.mime_entries {
        if ipynb_mime_is_image(entry.mime_type) {
          asset_candidate_count += 1
        }
        match entry.text {
          Some(text) =>
            if text.length() > max_output_text_chars {
              max_output_text_chars = text.length()
            }
          None =>
            match entry.raw_json_text {
              Some(text) =>
                if text.length() > max_output_text_chars {
                  max_output_text_chars = text.length()
                }
              None => ()
            }
        }
      }
    }
  }
  {
    nbformat: notebook.summary.nbformat,
    nbformat_minor: notebook.summary.nbformat_minor,
    cell_count: notebook.cells.length(),
    markdown_cell_count,
    code_cell_count,
    raw_cell_count,
    output_count,
    stream_output_count,
    display_data_count,
    execute_result_count,
    error_output_count,
    attachment_count,
    mime_entry_count,
    asset_candidate_count,
    max_cell_source_chars,
    max_output_text_chars,
  }
}

///|
fn ipynb_mime_is_image(mime_type : String) -> Bool {
  mime_type == "image/png" ||
  mime_type == "image/jpeg" ||
  mime_type == "image/gif" ||
  mime_type == "image/svg+xml"
}
