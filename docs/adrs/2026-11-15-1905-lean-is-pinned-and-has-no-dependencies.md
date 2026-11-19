# The Lean model is pinned to a stable Lean release, has no dependencies, and is built by one script

Status: accepted
Tier: direction; area: lean-model

## Decision

- **One pin.** `lean/lean-toolchain` names a stable Lean release, today
  `v4.35.0`. No nightlies and no release candidates. A toolchain bump is one
  PR, which fixes every warning the new release raises.
- **`lean/` is one Lake package, `mojo-grimoire`, with no dependencies:** no
  Mathlib, no Lean-MLIR. Adding one means editing this ADR first, with the
  human's ruling. The spec document in `docs/spec/` is a separate package
  that requires Verso (ADR-2026-11-15-2030); `lean/` never does.
- **Four libraries and an executable.** `MojoGrimoire` is the model,
  `MojoGrimoireTest` its tests, whose root imports every module, and
  `MojoGrimoireCheck` runs the axiom check (ADR-2026-11-15-1906). The
  executable `mojo-grimoire` has the root module `MojoGrimoireCli`, which is
  also declared as a library, so that `MojoGrimoireTest` can import it and
  Lake builds it first. The human approved that library on 2026-11-18
  (#100).
- **One build command.** Every Lake run in `lean/`, in hooks, CI or by hand,
  goes through `scripts/build-lean.sh` or applies its guards: it unsets each
  variable that `git rev-parse --local-env-vars` lists, sets
  `GIT_CEILING_DIRECTORIES` to `lean/.lake/packages`, and unsets `GH_TOKEN`
  and `GITHUB_TOKEN`.

The human chose Lean 4.35.0 on 2026-11-15.

## Why

One pin makes the build reproducible. The roadmap's first phases need only
core Lean. In funk, Lake's git calls inside a package clone rewrote the
repository's `origin` when run from a hook, which the guards prevent.
Lakefiles and elaboration can run arbitrary code, so the build holds no
tokens.

## Rejected alternatives

- **Depend on Mathlib now.** Nothing needs it yet, and it adds thousands of
  modules and a cache to keep working. It can come later at the same pin.
- **`leanprover/lean-action` in CI.** A checksummed elan tarball needs no
  third-party action.
