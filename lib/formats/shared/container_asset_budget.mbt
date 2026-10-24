///|
/// A child receives only the unspent asset allowance. Its reporter translates
/// a cumulative failure back to the parent's byte domain before the parser's
/// source wrapper records the same failure in the shared input session.
pub fn parse_context_with_remaining_asset_bytes(
  context : @parser.ParseContext,
  admitted_bytes : Int64,
) -> @parser.ParseContext {
  if admitted_bytes <= 0L {
    return context
  }
  let total_limit = context.limits.max_total_asset_bytes
  let remaining = (total_limit - admitted_bytes).max(0L)
  let child = @parser.parse_context_with_asset_limits(
    context,
    context.limits.max_asset_bytes,
    remaining,
  )
  @parser.parse_context_with_resource_failure_reporter(child, failure => {
    let translated = match failure.kind {
      SingleAssetBytes | MimeNestingDepth | MimeMultipartParts => failure
      TotalAssetBytes => {
        let observed = if failure.observed >
          9223372036854775807L - admitted_bytes {
          9223372036854775807L
        } else {
          admitted_bytes + failure.observed
        }
        @input.make_resource_limit_failure(
          TotalAssetBytes,
          observed,
          total_limit,
        )
      }
    }
    (context.report_resource_limit_failure)(translated)
  })
}
