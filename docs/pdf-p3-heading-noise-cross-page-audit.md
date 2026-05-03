# PDF P3 Heading / Noise / Cross-page Audit

This document records the first PDF P3 attribution pass after the current
`pdf_core` P1/P2 groundwork.

Scope for this round:

* inspect current guard samples with `normal` output and `debug pipeline`
* classify whether the current behavior depends on core signal, convert policy,
  or a deliberate conservative limit
* define the next implementation order without changing PDF output semantics

Important note:

* all listed guard samples currently match their checked-in expected output
* this round is therefore about responsibility attribution, not regression
  repair

## Sample Attribution Table

| Sample | Current output status | Core signal status | Convert behavior | Root cause class | Suggested next action |
| --- | --- | --- | --- | --- | --- |
| `heading_basic` | pass; chapter and section lines become headings | page-local line/block boundaries are clean, but all heading-like lines arrive as `Text` with `heading_candidate=false` | classifier promotes chapter-marker and numbered-section lines from neutral paragraphs | `convert_classify_policy + intentional_conservative_limit` | keep as heading guard; decide whether chapter/section heading-candidate generation belongs in `pdf_core` or should remain a converter policy |
| `pdf_heading_vs_short_sentence` | pass; real headings promoted, short sentences/caption/list intro stay non-heading | title and `Introduction` arrive as heading candidates; `Method`, `Key points:`, caption line, and concluding phrase arrive as plain text | classifier promotes true headings and preserves caption/list-intro/body lines as paragraphs | `convert_classify_policy` | keep this as the main short-sentence false-positive guard before any wider heading promotion |
| `pdf_heading_false_positive_phase15` | pass; all-caps and numbered body lines remain body text | only the top title arrives as heading candidate; all other risky short lines are neutral text | classifier avoids promoting all-caps, numbered, and short noisy body lines | `convert_classify_policy` | keep this as the primary negative heading guard; do not broaden all-caps or numbered-heading rules without stronger core signal |
| `pdf_page_noise_cleanup` | pass; repeated page labels are removed | repeated `第⻚1..4` lines arrive as plain text with `page_number_candidate=false` and `header_footer_candidate=false` | repeated-edge cleanup removes the first block on each page by normalized repetition and edge position | `core_missing_edge_signal + convert_noise_policy` | prioritize a reliable core page-number / edge-artifact candidate surface; keep repeated-edge string cleanup as fallback |
| `pdf_repeated_header_footer` | pass; repeated header/footer are removed, body preserved | repeated header/footer lines arrive as `HeadingCandidate`, not as header/footer or artifact signal | noise cleanup drops repeated top/bottom strings even when they look like headings | `core_missing_edge_signal + convert_noise_policy` | add top/bottom artifact or edge-region candidates in `pdf_core` so converter noise is not forced to remove repeated pseudo-headings |
| `pdf_repeated_header_footer_variants` | pass; repeated draft header removed, real report headings preserved | repeated draft header has no header/footer flag; intermediate section titles such as `Summary` / `Details` are not core heading candidates | classifier promotes real section headings, while repeated-edge cleanup removes repeated top noise | `core_missing_edge_signal + convert_classify_policy + convert_noise_policy` | separate edge-artifact detection from heading recovery; do not solve this only by adding more heading exceptions |
| `pdf_header_footer_variants_phase15` | pass; repeated top/bottom lines removed, body headings preserved | repeated header and footer both arrive as `HeadingCandidate`; no `header_footer_candidate` help is available | noise cleanup removes repeated edge headings, while current heading policy keeps the real body headings | `core_missing_edge_signal + convert_noise_policy` | make core edge/artifact signals trustworthy before widening converter noise rules |
| `pdf_cross_page_paragraph` | pass; cross-page paragraph merges, next section stays separate | page-local blocks are correct, but there is no explicit cross-page continuation label; continuation is inferred from geometry/text only | merge policy joins previous-page-last with next-page-first paragraph and keeps the later heading separate | `convert_merge_policy` | keep this as the broad cross-page baseline; next work should inspect whether existing wrapped/gap/indent signals can be consumed more systematically before adding new heuristics |
| `pdf_cross_page_should_merge_phase15` | pass; continuation merges into one paragraph | core gives correct page-local blocks; page 2 continuation starts with a lowercase continuation phrase but has no explicit core continuity marker | merge policy succeeds through text-continuation and layout-compatibility checks | `convert_merge_policy + convert_underuses_existing_signal` | first expose and audit current continuation-related line/block signals more directly before expanding merge text heuristics |
| `pdf_cross_page_should_not_merge_phase15` | pass; page 2 new section stays separate | page 2 starts with a heading candidate plus a numbered topic line, so non-merge cues are already visible | hard blockers prevent cross-page merge across new-section boundaries | `convert_merge_policy` | keep this as the hard negative guard for heading/list/page-start section boundaries |
| `pdf_two_column_negative_phase15` | pass; left/right pseudo-columns are not stitched together | core preserves distinct line geometry (`left_x` roughly `56` vs `320`) but has no reading-order or column model | current pipeline stays safe because it does not attempt aggressive within-page stitching or positive multi-column recovery | `intentional_conservative_limit + core_missing_geometry_signal` | treat this as the main negative guard; do not attempt positive two-column reading-order recovery until core exposes column or reading-order hints |

## Core vs Convert Responsibility

### Heading precision

Current picture:

* `pdf_core` boundaries are already good enough on the guard corpus
* `pdf_core` heading-candidate coverage is inconsistent across heading styles
* `convert/pdf` currently carries the real promotion/demotion burden

Evidence:

* `heading_basic` headings arrive as plain `Text`, not `HeadingCandidate`
* `pdf_heading_vs_short_sentence` mixes true heading candidates with neutral
  heading-looking lines such as `Method`
* `pdf_heading_false_positive_phase15` is currently held by converter-side
  false-positive rules, not by richer core semantics

Judgment:

* near-term heading work is still mostly a convert responsibility
* however, any wider heading expansion should first decide whether additional
  heading-like candidate generation belongs in `pdf_core`

### Repeated edge noise

Current picture:

* successful cleanup depends mostly on convert-stage repeated-edge logic
* core top/bottom artifact signals are still too weak for this sample family

Evidence:

* `pdf_page_noise_cleanup` page labels have `page_number_candidate=false`
* `pdf_repeated_header_footer` and `pdf_header_footer_variants_phase15` repeated
  header/footer lines arrive as `HeadingCandidate`
* repeated lines do show up in convert debug via `pdf_edges/repeated_texts`,
  which means the converter can identify repetition after the fact

Judgment:

* the next real improvement should start in `pdf_core`
* converter noise logic is already useful, but it is compensating for missing
  edge/artifact signal instead of merely consuming one

### Cross-page merge

Current picture:

* page-local boundaries are usable on the guard corpus
* current cross-page success is mostly converter policy, not a rich core
  continuation model

Evidence:

* `pdf_cross_page_paragraph` and `pdf_cross_page_should_merge_phase15` both rely
  on page-boundary paragraph continuation, not on explicit core continuation
  labels
* `pdf_cross_page_should_not_merge_phase15` is protected by page 2 heading/list
  guards

Judgment:

* the next merge step can stay in `convert/pdf`
* but it should first make better use of already available layout signals
  rather than adding more text-only rules

### Two-column negative

Current picture:

* the current guard passes because the pipeline is conservative
* positive reading-order recovery is not present yet

Evidence:

* `pdf_two_column_negative_phase15` preserves left/right `left_x` separation in
  core and convert debug
* no column or reading-order model is exposed yet

Judgment:

* this remains a deliberate non-goal for the next short pass
* do not add positive two-column reordering before a stronger core geometry /
  ordering signal exists

## P3 Implementation Order

### P3.1 Heading precision

Order:

1. keep `heading_basic`, `pdf_heading_vs_short_sentence`,
   `pdf_heading_false_positive_phase15`, and `not_heading_sentence` as the
   required guard set
2. compare which real headings are missing from core candidate generation and
   which are already adequately recoverable in convert
3. only then adjust convert classify policy

Why:

* current failures are not about broken boundaries
* the main risk is over-promoting short lines, captions, and numbered body text

What should not be broken:

* short body sentences
* figure/table captions
* list-intro lines such as `Key points:`
* all-caps and numbered body sentences in `pdf_heading_false_positive_phase15`

P3.1 status:

* completed as an attribution-driven pass in `convert/pdf`
* heading promotion/demotion still primarily belongs to converter classify
  policy
* `pdf_core` heading candidate remains a useful positive hint, but not yet a
  stable primary signal
* classify and `pipeline_debug` now share a common heading-decision helper so
  promotion and demotion can be explained by explicit reason tags
* P4.1 then hardens heading policy on top of the same attribution surface:
  strong structured/contextual evidence now drives promotion more explicitly,
  while weak short-line/page-lead/font-only cases continue to stay paragraphs
  unless they clear the existing guards

### P3.2 Repeated edge noise

Order:

1. add or strengthen core page-edge / page-number / artifact candidate signal
2. keep converter repeated-string cleanup as the safety net
3. only after that decide whether converter noise rules should be simplified or
   widened

Why:

* current success depends on convert-side repetition cleanup
* repeated header/footer lines can still arrive as heading candidates

What must stay conservative:

* do not remove unique first/last page content just because it is short
* do not drop legitimate repeated report titles that are part of the document
  structure unless they clearly function as page-edge noise

P3.2 status:

* completed as a page-edge / artifact evidence pass
* repeated-edge removal policy is still conservative and remains converter-side
* `pipeline_debug` now exposes shared edge/noise evidence and drop/keep reasons
* this round does not widen deletion scope; it makes current repeated-edge and
  page-number decisions auditable
* P4.2 then hardens repeated-edge removal on top of the same attribution
  surface: strong repeated header/footer and page-number evidence now triggers
  drop more explicitly, while body-like, caption-like, annotation-nearby, and
  two-column side-marker guards still win over deletion

### P3.3 Cross-page merge

Current merge inputs:

* paragraph-only requirement
* sentence-ending blockers
* new-section/list-start blockers
* font-size compatibility
* indent compatibility
* alignment compatibility
* first-line gap check
* wrapped / same-paragraph-with-prev candidates

Order:

1. make current continuation-related signals easier to inspect in a compact
   audit-oriented view
2. review whether merge is underusing existing wrapped/gap/indent evidence
3. only then add any new merge policy

Why:

* the current positive and negative guards already pass
* the main danger is false merges, not under-merging on this guard set

What must not be broken:

* `pdf_cross_page_should_not_merge_phase15`
* section-start headings on a new page
* numbered-list starts after a page break

P3.3 status:

* completed as a cross-page merge attribution pass
* cross-page merge policy remains narrow: previous-page-last paragraph to
  current-page-first paragraph only
* `pipeline_debug` now exposes shared merge/keep-split evidence and reasons
* this round does not widen cross-page merge scope; it makes current
  continuation and split guards auditable
* P4.3 then hardens cross-page merge on top of the same attribution surface:
  strong continuity combinations now drive merge more explicitly, while
  heading/list/table/image/noise/caption/page-number/two-column guards still
  win over merge

### P3.4 Two-column negative

Order:

1. keep `pdf_two_column_negative_phase15` as a hard blocker sample
2. do not add positive multi-column reading-order recovery in the next short
   pass
3. if multi-column work is revisited later, start from core ordering/column
   signal first

Why:

* current success comes from conservative behavior
* positive two-column recovery without stronger core guidance would be a large
  risk

Temporary non-goal:

* no full multi-column reading-order engine in the next PDF pass

## Guard Samples

### Heading guards

* `heading_basic`
* `pdf_heading_vs_short_sentence`
* `pdf_heading_false_positive_phase15`
* `not_heading_sentence`

### Noise guards

* `pdf_page_noise_cleanup`
* `pdf_repeated_header_footer`
* `pdf_repeated_header_footer_variants`
* `pdf_header_footer_variants_phase15`

### Cross-page guards

* `pdf_cross_page_paragraph`
* `pdf_cross_page_should_merge_phase15`
* `pdf_cross_page_should_not_merge_phase15`

### Layout-negative guard

* `pdf_two_column_negative_phase15`

## Non-goals

* no new PDF output semantics in this round
* no blind expansion of heading rules without attribution
* no bigger repeated-edge deletion policy before core edge signal improves
* no positive two-column reading-order recovery yet
* no OCR-default or vision/LLM PDF path
