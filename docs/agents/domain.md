# Domain Docs

How skills and agents consume this repo's domain documentation.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root: the glossary of the project's domain terms.
- **`docs/adrs/`**: the ADRs that touch the area you are about to work in.

If a file does not exist yet, proceed silently; don't create it upfront. The
`/domain-modeling` skill creates `CONTEXT.md` when terms get resolved, and
writes ADRs to **`docs/adrs/`** (plural; not `docs/adr/`) following
[`docs/adrs/README.md`](../adrs/README.md).

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor
proposal, a hypothesis, a test name), use the term as `CONTEXT.md` defines it.
Don't drift to synonyms the glossary avoids. If the concept you need is not in
the glossary, either you are inventing language the project doesn't use
(reconsider) or there is a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, say so explicitly rather than
silently overriding it:

> _Contradicts ADR-2026-11-15-1901 (file-size budget), but worth reopening because…_
