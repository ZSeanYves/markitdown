# Platform Operations Handbook

Edition 2026.2 & validated on checked-in synthetic-realistic fixtures.

- [Overview](#overview)
- [Deployment](#deployment)
- [Observability](#observability)
- [Appendix](#appendix)

Search

Pricing

Careers

## Overview

This handbook describes the operational baseline for a multi-format
            document conversion platform. It focuses on repeatable execution,
            readable output, bounded fallbacks, and evidence-driven change
            control rather than pixel-perfect visual reproduction.

Readers who only need the release checklist can jump to the
            [appendix](#appendix), while implementers should also
            review the [external runbook](https://example.com/runbooks)
            and the [deployment contract](guide.html#deployment-contract).

> Stable structure beats optimistic heuristics when the source format
            mixes headings, links, images, and noisy side material.

Info. The platform ships a native-first validation path and a
            documented fallback path for developer environments.

## Documentation Shape

The typical conversion package contains at least five interacting structures:

- top-level headings and local anchor links
- nested procedures
  1. prepare sample assets
  1. run native validation
  1. review output and metadata
- inline code such as moon build --target native
- tables with external references and operator notes
- local figures and caption-like explanations

Warning. Ignore javascript links
            and data links during conversion.

Failure-mode checklist

Check malformed links, repeated navigation, entity decoding, and preformatted text boundaries.

## Deployment

Production deployment uses a staged rollout. Teams publish a frozen
            build, update the registry cache, run a validation suite, and only
            then fan out to scheduled batch jobs.

```
moon build --target native
moon check
moon test
./samples/check.sh
./samples/check.sh --real-world --tags complex
```

On Windows hosts, the core native target is supported, but shell
            validation remains easier under WSL or another POSIX-like runtime.

| Stage | Owner | Reference | Notes |
| --- | --- | --- | --- |
| Build | Release engineering | [build policy](https://example.com/build-policy) | Prefer native CLI over wrapper timing. |
| Validate | Format owners | [observability section](#observability) | Capture metadata sidecars and asset refs. |
| Promote | Operations | [promotion guide](guide.html#promotion) | Document deviations and explicit non-goals. |

## Observability

A good conversion trace keeps structure readable even when the input
            mixes dense lists, escaped entities like <sample>, and repeated
            section wrappers.

![System overview diagram](assets/image01.jpg)
*Overview diagram*
Figure 1. Release-path overview with assets, metadata, and contracts.

The support bundle also includes a second visual artifact for chart
            references and a compact reminder that real-world samples do not
            imply broader performance claims.

![Metrics trend chart](assets/image02.jpg)
*Trend chart*
Figure 2. Trend chart for smoke validation and contract stability.

## Appendix

### Deployment Contract

Every release record should answer these questions:

1. Which checked-in corpora passed?
1. Which assets were emitted and where are they referenced?
1. Which format-specific boundaries remain explicit non-goals?

See also [the overview](#overview),
            [quality records](https://example.com/quality-records),
            and [ops@example.com](mailto:ops@example.com).

## Sidebar

Navigation and repeated site chrome should not dominate the extracted article body.

Last reviewed 2026-05-08. Synthetic-realistic complex HTML sample for markitdown-mb.
