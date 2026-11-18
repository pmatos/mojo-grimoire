# Current decisions: conformance

This page says what holds today for the differential tests against the Mojo
compiler.

## The decision log

The model follows the compiler. A disagreement in which the model is wrong is
fixed in the model, and the PR that fixes it says what changed.
[The decision log](../conformance/decision-log.md) records only where the
model departs from the compiler: a compiler bug, where the compiler is
broken, or a spec decision, where its behaviour is incidental. The human
ruled this on 2026-11-16.

Rejected: logging every disagreement, model bugs included. Their entries
repeated what the fixing PR and the suite already record, and hid the
departures that matter. The reference is set on
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
arrays, references, and programs the compiler rejects). They are written in this
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
program with its decision-log entry, a compiler bug or a spec decision. The first results were recorded on
2026-11-16 (#25), with every program agreeing, and the hook no longer
passes `--allow-unrecorded`: a program with no recorded result fails it, so
a new program is recorded before it is committed.

Rejected: comparing the compiler's diagnostics word for word. Their wording
changes between releases and says nothing the class does not.

### Unknown fields and methods

The compiler gives one error, "'T' value has no attribute 'a'", for a field
and for a method that the type `T` lacks, whatever `T` is. The model
reports both as one class, `unknownAttribute`, and the suite compares it
exactly, as every other class (#42).

Rejected: keeping `unknownField` and `unknownMethod` in the model and
letting the suite accept either for that error. It changes how the suite
compares, and a program would agree even when the model rejects it for the
other reason. Also rejected: keeping both classes in the checker and
giving them one name in the driver. The class that the checker reports
would then differ from the one the suite compares, and the Lean tests would
pin a distinction that the compiler does not make.

### Initializations that fit no initializer

The compiler gives one error, "no matching function in initialization",
for every initialization whose arguments fit none of the type's
initializers: it tries each one and reports only that none fits. That
covers a construction `S(…)` with a wrong number of arguments, a wrong
one, or a value that is not a place, or cannot change, passed to a `mut`
parameter, whether `S` is `@fieldwise_init` or has its own `__init__`; a
literal whose length or elements do not fit the list or array it
initializes, or that initializes a struct or a `Bool`; and
`List[T](e1, …, en)` with arguments. The model reports
all of them as one class, `noMatchingInit`, and `diagnostics.json` maps
that message, matched whole, to it alone. The human ruled this on
2026-11-16 (#46), following the precedent of `unknownAttribute`.

Ordinary calls keep their classes, since the compiler names the misfit
there: `typeMismatch` and `arityMismatch`. So does a literal passed to a
function or a method, which the compiler converts and reports as "cannot
be converted from list literal", and a literal with no expected type whose
elements differ, which it reports as "not compatible". An ownership
error, such as `implicitCopy` or `uninitializedUse`, keeps its class, and
so does an error inside an argument that the model checks before it finds
the misfit. The order still differs from the compiler's in two ways. The
compiler checks every argument before it looks for an initializer, so an
error in a later argument, `P(True, nope)`, comes first there, where the
model reports the misfit, as it does for an ordinary call (#89). And the
compiler reports ownership errors only after every type error, so
`P(b)` with `b` an uninitialized `Bool` is `noMatchingInit` there, where
the model, which checks in program order, reports `uninitializedUse`
(#96).

Rejected: leaving the message unclassified, which the suite counts as a
disagreement, so that these programs could never be compared; and letting
one message accept several classes, which loosens the comparison.

### Cycles of structs

The compiler rejects a struct that holds itself by value, directly or
through other structs, with "attempt to resolve a recursive reference to
declaration", and a struct on a cycle made only of list and array edges
with "field … has non-'Deinitable' type". `diagnostics.json` maps both to
`recursiveStruct`. A cycle with a list edge and a plain by-value edge,
such as `A` holding a `List[B]` and `B` holding an `A`, is accepted by
both (#47).

When the struct that holds the other by value is `@fieldwise_init`, the
compiler rejects the cycle with messages that depend on the declaration
order: "invalid implicit move: unexpected keyword argument 'move'",
"invalid call to '__init__': no candidates found", or the non-'Deinitable'
one. The human ruled this a compiler bug on 2026-11-18 (D-0004): the model
accepts these programs, and `known.json` lists them. The first two
messages have no pattern, since no error of the model corresponds to
them, and only these programs give them in the suite.

Rejected: mapping those two messages to `recursiveStruct`, which would
class a compiler bug as a rejection that the model agrees with.
