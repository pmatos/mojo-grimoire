# The spec is Lean rendered with Verso, shown as readable blocks checked against the Lean, from the first module on

Status: accepted
Tier: direction; area: spec

## Decision

- The specification of Mojo that this project writes is a Verso document in
  `docs/spec/`, a Lake package that requires `lean/` by path and Verso at the
  tag named like the Lean toolchain. The Lean definitions in `lean/` are
  normative. `docs/spec/` adds no definition that the semantics depends on,
  and the rendered document is not committed.
- The default view follows the style of the WebAssembly specification. In
  place of each Lean declaration it shows a readable block: prose for a
  capable newcomer, with KaTeX math and grammar boxes. The Lean of the
  declarations, statements and proofs included, sits under the block in a
  `<details>`, one click away. Every line of a module is on the page.
- Drift between a block and its Lean fails the build. A block names the
  declarations it explains and pins a fingerprint of their terms, and of
  each definition its prose restates. A document explains every declaration
  of its module exactly once, and every module of `lean/MojoGrimoire` is in
  the spec.
- **From the first module on.** No Lean module of the model merges without
  its spec section, formal and readable. CI builds the document on every PR,
  and every push to `main` publishes it to GitHub Pages.
- The machinery is funk's spec site, ported: its readable blocks,
  fingerprints, grammar boxes, ADR appendix and Pages workflow.

The human asked on 2026-11-15 for funk's way of documenting the
specification, prose with boxed Lean code, from the very beginning.

## Why

The spec must be formal, so that proofs can use it, and readable, so that
people can learn Mojo's semantics from it. Written apart, the two drift. One
source built by CI, with a build that fails when the Lean changes under a
block, keeps them together. Starting with the first module avoids a backlog
of undocumented Lean.

## Rejected alternatives

- **Prose in `lean/`'s doc comments only.** `lean/` has no Verso dependency,
  so its doc comments cannot hold the checked directives, and doc comments
  alone read like Lean.
- **Write the document after the model.** A backlog of hundreds of
  declarations would be documented in a hurry, or not at all.
- **Pins that hash every reachable definition.** Almost any change to the
  interpreter would force re-pinning; funk rejected it for the same reason.
