# Format Mode and Execution Profile Architecture Guide

> Path: `docs/architecture/format-mode-and-execution-profile-architecture.md`
>
> This document complements [mb-markitdown-architecture.md](./mb-markitdown-architecture.md).
> The main architecture guide defines the unified chain `detect -> probe -> planner -> parser -> pipeline -> renderer`.
> This document defines the stable abstractions for mode, route, profile, render path, and same-mode adaptation.

Recommended reading order:

1. Read the main architecture guide first.
2. Read this document to understand stable mode, route, planner, and profile contracts.
3. Then read [ocr-and-pdf-ocr-architecture.md](./ocr-and-pdf-ocr-architecture.md) for OCR-specific rules.
4. Finally read [../capabilities-and-limitations.md](../capabilities-and-limitations.md) for the public support boundary.

---

## 0. Document Scope

This is a normative architecture document, not a migration note or a temporary implementation summary.

It answers these questions:

1. What user-facing mode actually means.
2. How route, profile, and render path should be modeled in one system.
3. Where the planner is allowed to adapt automatically.
4. How new formats should enter one strategy model instead of adding new side paths.
5. What the renderer, diagnostics, and provenance are allowed to depend on.

This document follows four usage rules:

1. abstraction comes before convenience
2. contracts come before temporary implementation shortcuts
3. implementation drift should be treated as technical debt to converge
4. the capability document answers "what is formally supported", while this document answers "how those capabilities must be organized"

### 0.1 Product Positioning

This execution-strategy layer serves a product that is:

- multi-format
- engineering-oriented
- explicit about provenance
- designed for long-term maintenance

"Lightweight and mature" means:

1. high-confidence structure recovery matters more than speculative recovery
2. heavy models and hidden side paths are not the default product assumption
3. one planner, one renderer contract, and one profile system should support long-term iteration

### 0.2 Vocabulary

This document uses the following fixed terms:

1. `mode`: the user-visible strategy philosophy
2. `route`: the primary execution route chosen for parsing and runtime behavior
3. `profile`: runtime behavior tuning inside a chosen route
4. `planner`: the single layer that freezes the execution plan
5. `canonical`: the default formal route for a format in a mode, not the only possible implementation
6. `same-mode adaptive switch`: a switch that changes route, profile, or render path without changing mode

---

## 1. Non-Conflicting Constraints

This document and the main architecture guide share these hard constraints:

1. The only core user-facing modes are `Balanced`, `Accurate`, and `Stream`.
2. `Rag` and `Debug` are output views, not core modes.
3. Automatic switching is only allowed inside the same mode.
4. Large PDF does not automatically upgrade to OCR or deep layout routes.
5. Parsers do not directly generate final Markdown.
6. Renderers do not secretly re-plan routes or profiles.
7. All formal entry points should reuse the unified planner-driven chain.
8. Diagnostics and provenance must explain route and profile decisions.

---

## 2. Design Goal

The execution-strategy system should do all of the following at the same time:

1. keep the external contract stable
2. keep internal route and profile decisions unified
3. allow same-mode adaptation for large or heavy inputs
4. let new formats enter one strategy system
5. preserve explainability for every automatic switch
6. fail closed or fall back honestly when a capability is unsupported

### 2.1 Four Rules to Remember First

If a reader remembers only four things, they should be:

1. Users choose `Balanced`, `Accurate`, or `Stream`, not parser modes directly.
2. The planner is the only final route selector.
3. Automatic switches happen only inside the same mode.
4. The renderer consumes a plan; it does not invent one.

---

## 3. Stable Abstractions

### 3.1 User Mode

User mode expresses conversion philosophy, not implementation details.

Mode answers:

- what the product should prioritize

Mode does not answer:

- which parser implementation must be used
- whether a full document model must be built
- which renderer subtype will be chosen

### 3.2 Output View

Output view answers:

- how one internal result is projected into Markdown, RAG, or debug-oriented output

Output view does not change:

- strategy mode
- route selection principles
- parser and pipeline ownership boundaries

### 3.3 ExecutionIntent

`ExecutionIntent` is the normalized internal view of public input options.

It exists to:

1. unify mode, output view, stream request, OCR request, and resource hints
2. remove duplicated meaning across entry points
3. give the planner one stable input shape

It should not contain format-private route decisions.

### 3.4 ProbeOutcome

`ProbeOutcome` is evidence, not product truth.

It should carry:

1. `probe_signals`
2. `prepared_source`
3. `probe_artifacts`
4. `probe_failures` and summaries

Probe is allowed to describe what it saw. Probe is not allowed to freeze `selected_route`.

### 3.5 ResolvedExecutionPlan

`ResolvedExecutionPlan` is the single source of execution truth.

Once the planner freezes it, parser, pipeline, renderer, finalize, diagnostics, and provenance all consume the same plan.

A complete plan should cover:

- detected format
- strategy mode
- output view
- stream request state
- selected route
- parser-mode intent
- render-path intent
- execution, lowering, and render profiles
- accurate or fidelity feature selection
- route reason
- execution-profile reason
- same-mode strategy switches
- probe signals, failures, artifacts, and prepared source

### 3.6 FormatStrategyPolicy

`FormatStrategyPolicy` is the single per-format strategy table.

Every formal format should have policy entries for:

1. balanced
2. accurate
3. stream

Each entry should describe:

- canonical route
- explicit stream support
- soft and hard limits
- route-level accurate upgrades
- execution, lowering, and render profiles
- allowed same-mode switches

The point is not that every format must have identical capabilities. The point is that every format should enter the same planner vocabulary.

---

## 4. User Mode Contract

### 4.1 Balanced

`Balanced` is the default product mode.

Its contract:

1. prefer mature and cost-controlled canonical routes
2. allow high-confidence semantic recovery
3. avoid implicit OCR or heavy hidden upgrades
4. allow same-mode adaptation where the format policy supports it

### 4.2 Accurate

`Accurate` is the quality-priority mode.

Its contract:

1. it may trigger route-level upgrades
2. it may also stay on the same route and strengthen semantics there
3. enhancements must remain explainable and regression-friendly
4. speculative or unverifiable behavior does not become a formal accurate promise

### 4.3 Stream

`Stream` is the low-peak-resource mode.

Its contract:

1. prefer lower-peak routes, profiles, and flushing strategies
2. remain honest when a format has no dedicated stream route
3. not every format is required to add a new parser route for stream support
4. unsupported stream requests must warn and fall back honestly or fail closed

### 4.4 Shared Mode Boundary

All three modes share these boundaries:

1. they are product-level strategies, not provider names
2. they do not bypass provenance
3. they do not bypass diagnostics
4. they do not allow hidden format-local route planners

---

## 5. Output Shape Contract

The product should keep at least three stable output views:

- Markdown
- RAG-oriented structured output
- debug-oriented structured output

All three should consume the same plan-driven main path.

---

## 6. Route and Planner Contract

### 6.1 Route Families

The current architecture vocabulary includes route families such as:

- `streaming_event`
- `block_streaming`
- `package_single_pass`
- `page_single_pass`
- `dom_ast_model`
- `layout_two_stage`
- `media_pipeline`
- `container_recursive`

### 6.2 Planner Decision Order

The planner should make decisions in a stable order:

1. detect format
2. normalize intent
3. gather probe evidence
4. consult format strategy policy
5. freeze selected route
6. freeze profiles and render path
7. record reasons and strategy switches

### 6.3 Unified Entry Constraint

All formal entry points should converge before planning:

- CLI
- in-process API
- benchmark orchestrator
- regression scripts

That keeps route fidelity measurable and easier to trust.

---

## 7. Profile System

Profiles exist to tune behavior inside a chosen route without collapsing route and mode into one concept.

### 7.1 ExecutionProfile

Execution profile can tune:

- resource windows
- batching
- parser runtime posture
- low-peak behavior

### 7.2 LoweringProfile

Lowering profile can tune:

- how aggressive structural recovery should be
- how hints are lowered into shared structures
- how much fidelity should be preserved for downstream renderers

### 7.3 RenderProfile

Render profile can tune:

- Markdown formatting behavior
- chunk boundaries
- debug verbosity

Profiles should never silently replace planner route ownership.

---

## 8. Stream Support Strategy

Formats fall into several broad categories:

### 8.1 Naturally Streaming Canonical

These formats already have a stable streaming route:

- plain text
- subtitle text
- delimited text
- line-delimited structured text

### 8.2 Explicit Stream Route

Some formats support an explicit stream route that differs from their default route:

- some markup inputs
- some workbook-like inputs
- some package-like inputs

### 8.3 Canonical Only

Some formats do not have a separate stream-native route yet.

For those, explicit `--stream` should warn honestly and either fall back to the canonical route or fail closed, depending on policy.

### 8.4 Paged and OCR-Heavy Formats

Paged and OCR-heavy formats should be especially conservative. Stream support must not silently weaken OCR, provenance, or route honesty.

---

## 9. Same-Mode Adaptation

Same-mode adaptation is allowed, but it must stay explicit and explainable.

### 9.1 Soft Limit

Soft limits may trigger a same-mode route or profile adjustment when that behavior is formally supported.

### 9.2 Hard Limit

Hard limits may force a safer same-mode route or a fail-closed outcome.

### 9.3 Forbidden Switches

The system should never:

- silently change `Balanced` into `Accurate`
- silently enter OCR because a file is simply large
- silently drop provenance or diagnostics to keep a route alive

---

## 10. Format Strategy Catalog

Each formally supported format should keep one strategy definition that answers:

1. what the canonical route is
2. whether explicit stream is supported
3. whether accurate has a real stronger contract
4. which same-mode switches are allowed
5. which diagnostics and provenance facts must remain visible

This is how the project stays maintainable while adding formats over time.

---

## 11. Normalize Hints and Renderer Boundary

Normalization hints are allowed.

Renderer-side re-planning is not.

Renderers may receive:

- heading hints
- list hints
- table hints
- reading-order hints
- cleanup signals

But they must still remain consumers of planner-approved structures.

---

## 12. Diagnostics and Provenance Contract

The execution-strategy layer should always expose:

- what mode was requested
- what route was selected
- why that route was selected
- which same-mode switches happened
- whether a fallback happened
- whether an accurate request stayed accurate, fell back, or was unsupported

This is essential for:

- product trust
- regression review
- benchmark credibility
- debugging hard inputs

---

## 13. Accurate Capability Boundary

### 13.1 What Accurate May Enable

Accurate may enable:

- OCR or layout route upgrades where formally supported
- stronger semantics on the same route
- more detailed diagnostics and provenance
- more structured recovery when evidence supports it

### 13.2 What Accurate Must Not Mean

Accurate must not mean:

- speculative AI behavior without typed evidence
- macro or script execution
- silent provider switching
- pretending unsupported formats have accurate support

### 13.3 Accurate Implementation Rule

Prefer typed hooks, explicit policy, and regression coverage over scattered raw `if accurate then ...` conditionals.

---

## 14. Maturity Standard

### 14.1 Usable

The route is formally available, but semantic depth or confidence is still limited.

### 14.2 Mature

The canonical path is stable, explainable, and well covered by regression tests.

### 14.3 Strong Mature

The format is not only mature, but also shows stronger confidence under complex, high-pressure, or accurate-related scenarios.

The public capability document decides which formal level each format currently belongs to.

---

## 15. Evolution Rule

### 15.1 Changes That Need Architecture Review

These changes should be treated as architecture-level changes:

- introducing a new route family
- redefining mode meaning
- silently broadening accurate behavior
- changing provenance truth sources

### 15.2 Changes That Can Iterate Faster

These can usually evolve faster:

- thresholds
- per-format tuning
- more regression coverage
- stronger typed hints inside an existing route

---

## 16. Conclusion

The project stays healthier when users only choose `Balanced`, `Accurate`, or `Stream`, while the planner remains the single owner of route and profile truth and the renderer stays a consumer of that truth.
