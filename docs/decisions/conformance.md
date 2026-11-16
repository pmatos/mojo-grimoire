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

The conformance suite is `tests/conformance/` (#25): Mojo programs of the
Phase 1 subset, one per file, by area (basics, structs, ownership, lists,
references, and programs the compiler rejects). They are written in this
project's own terms, independently of the Isabelle formalisation's suite
([semantics.md](semantics.md#independence)). Its
[README](../../tests/conformance/README.md) says how to add a program.

Each program's expected result is recorded from the pinned compiler, beside
it as `NAME.json`, by `scripts/conformance.py record --mojo WRAPPER`, run
where the compiler is built. The compiler builds the program with
`mojo build`: a program it cannot build is rejected, and one it builds is
run, and finishes or fails by its exit status. A rejection's class is the
class of the model's `CheckError` that the compiler's first error matches in
`tests/conformance/diagnostics.json`; the classes, not the wording, are
compared. When that error only says that a function could not be
instantiated, the note naming the constraint that failed is added to it. A
failed run's assertion, which the runtime writes on standard output with
the program's absolute path, is how the run ended, not a printed line.

The `conformance` hook runs `scripts/conformance.py check` in CI. It
compares the model's executable with every recorded result: how the run
ended, the lines printed, and the class of a rejection. A run-time failure's
lines are compared, but not its kind, which the compiler does not name. A
disagreement passes only when `tests/conformance/known.json` lists the
program with its decision-log entry. The first results were recorded on
2026-11-16 (#25), with every program agreeing, and the hook no longer
passes `--allow-unrecorded`: a program with no recorded result fails it, so
a new program is recorded before it is committed.

Rejected: comparing the compiler's diagnostics word for word. Their wording
changes between releases and says nothing the class does not.
