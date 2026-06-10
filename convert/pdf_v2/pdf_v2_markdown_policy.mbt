///|
pub(all) struct PdfV2MarkdownPolicy {
  preserve_uncertain_text : Bool
  emit_reason_tags : Bool
}

///|
pub fn default_pdf_v2_markdown_policy() -> PdfV2MarkdownPolicy {
  { preserve_uncertain_text: true, emit_reason_tags: false }
}

///|
pub fn pdf_v2_policy_keeps_uncertain_text(policy : PdfV2MarkdownPolicy) -> Bool {
  policy.preserve_uncertain_text
}
