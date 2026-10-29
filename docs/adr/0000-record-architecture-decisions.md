# 0. Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-10-29

## Context

This project involves a number of technical choices (frameworks, libraries, data modeling, deployment) where reasonable alternatives exist. The reasoning behind a choice is easy to forget and hard to reconstruct later from code alone.

## Decision

We will record significant architecture decisions as short Architecture Decision Records (ADRs), following the format described by Michael Nygard.

- One Markdown file per decision in `docs/adr/`, named `NNNN-short-title.md`, numbered sequentially.
- An ADR is immutable once accepted. If a decision changes, write a new ADR that supersedes the old one and update the old one's status to `Superseded by NNNN`.
- Keep each ADR short (about one page). Write one when choosing between real alternatives, not for every small detail.

## Consequences

- The reasoning behind decisions is preserved and easy to find.
- There is a small amount of writing overhead per decision.
- ADRs double as material for the README and for explaining the project's design to others.

---

## Template for new ADRs

Copy everything below this line into a new file `docs/adr/NNNN-short-title.md`.

```markdown
# N. Title of the decision

- **Status:** Proposed | Accepted | Deprecated | Superseded by NNNN
- **Date:** YYYY-MM-DD

## Context

What is the problem or situation? What forces are at play (requirements,
constraints, trade-offs)? Which alternatives were considered?

## Decision

What did we decide? State it in full sentences, starting with "We will ...".

## Consequences

What becomes easier or harder as a result? Include both positive and
negative effects, and any follow-up work.
```

## Planned ADRs

Likely candidates, to be written as the decisions are made:

- Data access library (JDBI vs Spring Data JDBC)
- OpenAPI: code-first vs spec-first
- Identity provider for OIDC
- LLM framework (Spring AI vs LangChain4j)
- Unit and quantity modeling
- Embedding model and dimensions
