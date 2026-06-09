///|
pub(all) struct PdfV2ConvertReportTemplate {
  name : String
  lane : String
  reason_tags_required : Bool
  notes : String
}

///|
pub fn pdf_v2_convert_report_templates() -> Array[PdfV2ConvertReportTemplate] {
  [
    {
      name: "classifier_gate_summary",
      lane: "contract-fast",
      reason_tags_required: true,
      notes: "records confidence, abstain, blocked reason, and reason_tags",
    },
    {
      name: "quality_lab_bridge",
      lane: "quality-lab-bridge",
      reason_tags_required: true,
      notes: "placeholder for external training/eval reports; no runtime file reads",
    },
    {
      name: "performance_smoke",
      lane: "performance-smoke",
      reason_tags_required: false,
      notes: "placeholder for latency, memory, and closure budgets",
    },
    {
      name: "dispatcher_experimental_route",
      lane: "dispatcher-smoke",
      reason_tags_required: true,
      notes: "records PDF dispatcher routing to v2 without v1 fallback",
    },
  ]
}
