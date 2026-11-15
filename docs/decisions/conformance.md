# Current decisions: conformance

This page says what holds today for the differential tests against the Mojo
compiler.

## The decision log

Every disagreement between the model and the compiler is recorded in
[the decision log](../conformance/decision-log.md) as a model bug, a compiler
bug or a spec decision. The reference is set on
[semantics.md](semantics.md#the-reference).

## The Phase 0 baseline

[phase0-baseline.md](../conformance/phase0-baseline.md) records gate G0. The
compiler built from the pinned commit by `scripts/build-mojo.sh`, and the
Isabelle formalisation, both reproduce that formalisation's recorded results.
Only our counts and summaries are kept here.

## Running the reference compiler

The reference compiler runs only through the wrapper that
`scripts/build-mojo.sh` prints. A source-built `mojo` otherwise reads an
installed Mojo's `modular.cfg` and `MODULAR_*` variables, and links the
programs it builds against that install's runtime, with no error. The script
fails unless a test program built through the wrapper loads only libraries
built from the pinned commit.

Rejected: printing the environment for callers to set. A caller that forgets
one variable gets results from the wrong runtime.

`scripts/build-mojo.sh` runs by hand. No hook or CI job runs it until the
conformance suite needs the compiler in CI, by the human's ruling of
2026-11-15. A full build takes about 25 minutes.

## The suite

The conformance suite does not exist yet; Phase 1 starts it. It is written
independently of the Isabelle formalisation's suite
([semantics.md](semantics.md#independence)).
