# Benchmark Architecture Guide

> Path: `docs/architecture/benchmark-architecture.md`
>
> This document complements
> [mb-markitdown-architecture.md](./mb-markitdown-architecture.md)
> and
> [optional-enhancement-architecture.md](./optional-enhancement-architecture.md)
> with focused rules for benchmark architecture, regression trust, product-path measurement, and comparison policy.

Recommended reading order:

1. Read the main architecture guide first.
2. Then read the optional enhancement guide if you need OCR / PDF accurate / audio details.
3. Then read this document to understand how benchmark runs measure the formal product path.
4. Finally read [../capabilities-and-limitations.md](../capabilities-and-limitations.md) for the public boundary.

---

## 0. Document Scope

This is a normative benchmark architecture document, not a one-off score report.

It answers:

1. what the formal benchmark system measures
2. what the benchmark system does not measure
3. how benchmark facts are layered across corpus, policy, execution, and trust
4. how the benchmark system proves it measured the real product path
5. how trust, gate, and route-coverage semantics should work over time

The benchmark system is part of the product validation system, not a separate toy script stack.

### 0.1 Product Positioning

The benchmark system exists to serve long-term product goals:

1. reproducible performance observation for the formal product path
2. auditable route and provenance evidence
3. one shared runtime base for internal performance work, external comparison, diagnostics, and contract checks
4. fail-closed trust gates instead of speed numbers without context

### 0.2 Vocabulary

This document uses the following fixed terms:

1. `bench root`: benchmark corpus root
2. `row`: one formal benchmark input declaration
3. `scenario`: a measurement task family such as `product`, `compare`, `diagnostic`, or `doctor`
4. `preset`: a named bundle of scenarios and default run settings
5. `tool`: a measured implementation such as `moonbit-cli`, `moonbit-engine`, or `markitdown`
6. `sample`: one actual measured run after warmup
7. `case`: the aggregation of several samples for one `scenario x tool x row`
8. `run`: one full benchmark execution with a unique `run_id`
9. `trust`: whether the MoonBit product path stayed trustworthy
10. `gate`: whether a comparison set is complete enough to be compared formally

### 0.3 Architecture Versus Implementation

This document defines the benchmark contract.

So:

1. runner implementations and scripts are downstream artifacts
2. manifests and policies are implementation expressions of this contract
3. a mismatch between implementation and this document should usually be fixed in code or operational docs
4. this document should change only when product goals or formal public promises change

---

## 1. Design Goal

The benchmark system should satisfy all of the following:

1. measure the real product path
2. keep results explainable
3. keep the benchmark corpus independent from the main repository source tree
4. separate internal, comparison, diagnostic, and contract-check views while sharing one base
5. evolve through policy and manifest changes instead of new benchmark side paths
6. fail closed when provenance, route fidelity, or semantic density evidence is missing

### 1.1 Five Rules to Remember First

If a reader remembers only five rules, they should be:

1. There should be one formal benchmark entry path.
2. Formal benchmark runs should measure release-grade product entry points.
3. Benchmark measures product truth and provenance, not only wall time.
4. `trust_status` and `gate_status` are not the same thing.
5. Benchmark growth should happen through shared manifest, policy, orchestrator, and result contracts.

---

## 2. Non-Negotiable Constraints

The formal benchmark system should keep these constraints:

1. it measures the same planner-driven product path used by the formal CLI or engine
2. it does not introduce benchmark-only parse shortcuts
3. it records enough provenance to explain route behavior
4. it fails closed when a result is not trustworthy
5. it keeps comparison gating separate from product-path trust

---

## 3. Top-Level Architecture

### 3.1 Layered Model

The benchmark architecture can be understood as:

```text
Corpus / Manifest
  -> Scenario / Preset Policy
  -> Tool Registry
  -> Benchmark Orchestrator
  -> Formal Product Entry
  -> Measurement
  -> Result Protocol
  -> Report / Trust / Gate
```

### 3.2 Three Fact Sources on the Benchmark Side

Benchmark truth comes from three categories of fact:

1. corpus facts: what was measured
2. execution facts: how it was measured
3. product facts: what route and output truth the product reported

### 3.3 Product-Side Contract

Benchmark only stays credible when the product emits enough diagnostics and provenance for:

- selected route
- effective mode behavior
- fallback behavior
- semantic density
- dependency failures

---

## 4. Stable Data Model

### 4.1 Bench Root and Corpus Identity

The benchmark corpus should stay outside the main repository's code ownership surface.

That keeps:

1. formal corpora independent
2. main-repo tests lighter
3. benchmark reproducibility more honest

### 4.2 Row

A row is one formal benchmark input declaration with enough metadata to identify:

- format
- tier
- scenario compatibility
- expected route or trust assumptions where applicable

### 4.3 Scenario and Preset

Scenarios define what kind of run is happening.
Presets bundle several scenarios and defaults together.

Examples include:

- internal formal benchmark
- external comparison
- diagnostic inspection
- doctor-style contract checks

### 4.4 Tool

A tool is one measured implementation.

The architecture should keep tool-specific wiring isolated from scenario logic.

### 4.5 Sample, Case, and Run

The benchmark system should continue modeling:

- sample: one measured repeat
- case: aggregation for one tool and one row under one scenario
- run: the full benchmark execution and result directory

---

## 5. Main Execution Chain

### 5.1 Formal Execution Flow

The stable benchmark flow is:

```text
select preset or scenario
  -> load rows
  -> resolve tools
  -> invoke formal product entry
  -> collect timing, memory, diagnostics, provenance, output truth
  -> aggregate samples
  -> write result protocol
  -> regenerate reports
```

### 5.2 Measurement Policy

Measurement policy should cover:

- warmup
- repeat count
- timeout
- memory observation
- trust and gate evaluation

Wall time is important, but it is not enough by itself.

### 5.3 Process CLI and In-Process Engine

The benchmark system may compare:

- the formal CLI
- the in-process engine
- external comparison tools

But they should still be orchestrated through one benchmark language and one result protocol.

---

## 6. Truth Model and Trust Gate

### 6.1 Benchmark Measures More Than "Command Succeeded"

A successful exit code is not enough.

Formal benchmark truth should also ask:

1. Did the real product path run?
2. Did provenance remain complete enough?
3. Did the route match expectation?
4. Is the output semantically dense enough to be treated as meaningful?

### 6.2 Provenance Completeness Contract

The benchmark system should treat missing or broken provenance as a trust problem, not just as cosmetic metadata loss.

### 6.3 Route Expectation and Coverage

When a scenario expects a route family, benchmark should verify that expectation honestly.

### 6.4 Route Fidelity

Route fidelity means the measured result actually reflects the route the product claims it used.

This matters especially for:

- large-file adaptation
- stream fallback
- OCR and accurate fallback
- PDF native-text versus OCR behavior

### 6.5 Semantic Density Guard

A benchmark result can be fast and still be poor product truth.

Semantic density checks exist to catch obviously hollow output cases.

### 6.6 Trust and Gate Are Different

`trust_status` asks:

- was the MoonBit product path trustworthy?

`gate_status` asks:

- was the comparison set complete enough to compare formally?

One can fail while the other passes.

---

## 7. Result Protocol

### 7.1 Stable Result Directory

Every run should write to one stable result root keyed by `run_id`.

### 7.2 Three Formal Result Layers

At a minimum, the benchmark system should preserve:

1. raw per-sample facts
2. case-level aggregates
3. run-level summaries and reports

### 7.3 Summary Contract

Run summaries should continue exposing:

- scenario and preset identity
- tool identity
- timing and memory aggregates
- trust status
- gate status
- route coverage signals

### 7.4 Report Regeneration

Reports should be reproducible from stored result data instead of requiring reruns for every presentation update.

---

## 8. Official View Split

### 8.1 Internal Formal View

Internal formal benchmark focuses on:

- the MoonBit product path itself
- performance and memory evolution
- route and provenance trust

### 8.2 External Comparison View

External comparison focuses on:

- apples-to-apples comparison sets
- whether all compared tools formed enough valid cases
- whether the baseline can form a real comparable set

### 8.3 Diagnostic View

Diagnostic view exists to explain route or output behavior, not to publish headline scores.

### 8.4 Contract-Check View

Doctor- or contract-style benchmark views exist to catch environment, dependency, or trust regressions quickly.

---

## 9. Evolution and Extension Rule

### 9.1 Adding a New Format

Prefer:

1. new rows in the corpus
2. new or updated policy entries
3. tool registry support if needed
4. route- or trust-aware assertions

Avoid:

- adding a new benchmark path just for one format

### 9.2 Adding a New Tool

New comparison tools should plug into the same scenario and result protocol model.

### 9.3 Evolving the Result Protocol

Result protocol evolution should preserve:

- reproducibility
- route truth
- memory and timing comparability
- explicit versioning when needed

### 9.4 Documentation and Implementation Sync

Operational docs should explain how to reproduce a run.
This architecture doc explains what counts as a formal benchmark run.

---

## 10. Explicit Non-Goals

The benchmark system is not trying to be:

1. a random collection of microbenchmarks
2. a wall-time-only scoreboard
3. a benchmark-only shortcut around the product architecture

---

## 11. Convergence Principle

The benchmark system stays healthy when it keeps measuring the real product path, keeps timing and memory visible together, and treats provenance, route fidelity, and trust gates as first-class parts of benchmark truth.
