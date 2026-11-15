# Current decisions: spec

This page says what holds today for the specification document. It is the
record: when this page and an ADR disagree, the page wins
(ADR-2026-11-15-1902).

## What the spec is

The spec is the Lean of `lean/MojoGrimoire` rendered with Verso, in the style
of the WebAssembly specification (ADR-2026-11-15-2030). The Lean definitions
are normative; the prose makes them readable. Each declaration is shown as a
readable block, prose with KaTeX math and grammar boxes, with its Lean one
click away under the block. The build fails when the Lean changes under a
block, through the block's pinned fingerprint. The human asked for funk's
approach on 2026-11-15.

`docs/spec/` is a Lake package that requires `lean/` by path and Verso at the
tag of the Lean toolchain. It holds the document, the readable documents of
each module and the checks that keep them true to the Lean. It adds no
definition that the semantics depends on.

Rejected: readable prose in `lean/`'s doc comments only. `lean/` has no Verso
dependency, so its doc comments cannot hold the checked directives.

## Every module, from the first

No Lean module of the model merges without its spec section, formal and
readable. Every module of `lean/MojoGrimoire` is in the spec, and CI builds
the document on every PR. Every push to `main` publishes it to GitHub Pages.

Rejected: writing the document once the model exists, which would leave a
backlog documented in a hurry.

## Status

The spec site is not built yet. Its port from funk is the first step of
Phase 1, before any module of the core calculus.
