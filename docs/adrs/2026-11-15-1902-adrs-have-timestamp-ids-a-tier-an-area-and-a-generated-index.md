# ADRs have timestamp ids, a tier and an area, a generated index, and area pages are the record

Status: accepted
Tier: direction; area: process

## Decision

- An ADR is `docs/adrs/YYYY-MM-DD-HHMM-slug.md`, named by the UTC minute it
  was written, with seconds added when that minute is taken. It is cited as
  `ADR-` and that timestamp. The `adr-ids` hook rejects a misnamed ADR, two
  ADRs with one id, and the reuse of a removed id.
- Its form is Decision, Why and Rejected alternatives, in about 300 words.
  The status paragraph ends with `Tier: TIER; area: AREA`. The tier is
  `direction` or `implementation`; the area is one of `semantics`,
  `lean-model`, `conformance` and `process`.
- Each area has a page, `docs/decisions/AREA.md`, that says what holds today
  and cites the ADRs it rests on. The page is the record: when a page and an
  ADR disagree, the page wins, and the ADR is fixed or deleted.
- An ADR is edited in place when its decision changes. There are no refining
  ADRs and no `superseded` status. A deleted ADR gets a row in
  `docs/adrs/removed/AREA.json`, and every citation of it is rewritten.
- `scripts/adr_index.py --write` generates `docs/adrs/INDEX.md`. The
  `adr-index` hook fails when it is stale or an ADR has no tier, area or page.
  The `adr-citations` hook fails on a citation of an ADR that does not exist.
- An ADR is written only for a direction decision that binds more than one
  module. CI warns when a pull request adds more than two.

This is funk's scheme, which the human asked on 2026-11-15 to be adopted here.
`docs/adrs/README.md` has the details.

## Why

An agent starting cold must find the decisions that bind it, and what holds
today, without reading a history. Timestamps let parallel agents name ADRs
without colliding on "the next number".

## Rejected alternatives

- **Sequence numbers.** Concurrent pull requests pick the same number.
- **Immutable ADRs with `superseded by` chains.** In funk they grew chains no
  one read; git already keeps the history.
