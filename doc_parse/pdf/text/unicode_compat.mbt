///|
/// Unicode 兼容字符归一化。
/// 这里只做“字符级兼容映射”，不做词边界恢复。
///
/// 分层约定：
/// - 通用低风险规则（NBSP / zero-width / soft hyphen / ligature / line ending）
///   由 shared core text normalization substrate 负责。
/// - 这里保留 PDF 更专属的兼容字形 fallback，例如 CJK compatibility glyph。
///
/// 不处理：
/// - con firm -> confirm
/// - This is -> Thisis / This is
/// - inter national -> international
/// 这些属于词边界恢复，不属于字符映射。
pub fn normalize_unicode_compat(text : String) -> String {
  @cor.normalize_text_with_profile(text, @cor.NormalizeProfile::PdfText)
}
