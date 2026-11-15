# Agents wait for human rulings before changing agreed direction

Status: accepted
Tier: direction; area: process

## Decision

Every agent, including an orchestrator, follows this approval boundary:

- An unanswered direction question waits in a `human-ready` issue. A timeout
  or the human's absence never supplies an answer. Independent work goes on.
- Ambition means finishing the agreed ticket scope. Additional work is filed
  separately, and the human rules before a ticket widens.
- An agent asks before introducing new tooling or checking machinery,
  including hooks and verifiers, and before changing the roadmap.

Routine implementation choices, such as naming and test details, may proceed
within the ticket's scope and are recorded. [AGENTS.md](../../AGENTS.md) holds
these standing rules.

The human asked on 2026-11-15 for funk's practice to be adopted here.

## Why

With these rules, a cold-starting agent can tell a human ruling from an
implementation choice without treating silence as approval. In funk, agents
chose answers to direction questions while the human was away; recording a
choice afterward did not authorize it.

## Rejected alternatives

- **Decide, then record the choice afterward.** It is what went wrong in
  funk.
