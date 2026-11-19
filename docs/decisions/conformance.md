# Current decisions: conformance

This page says what holds today for the differential tests against the Mojo
compiler.

## The decision log

The model follows the compiler. A disagreement in which the model is wrong is
fixed in the model, and the PR that fixes it says what changed.
[The decision log](../conformance/decision-log.md) records only where the
model departs from the compiler. The only departure is a compiler bug, where
the model does exactly what the fixed compiler would do. The human ruled this
on 2026-11-16, and on 2026-11-19 ruled out spec decisions, where the
compiler's behaviour is incidental: "We cannot have a third option here." A
ruling is provisional until the human has discussed it with Modular
(ADR-2026-11-15-1907).

Rejected: spec decisions, which invent a behaviour that no fixed compiler
would have. Also rejected: logging every disagreement, model bugs included.
Their entries repeated what the fixing PR and the suite already record, and
hid the departures that matter. The reference is set on
[semantics.md](semantics.md#the-reference).

## The Phase 0 baseline

[phase0-baseline.md](../conformance/phase0-baseline.md) records gate G0, at
the pin of the time, Mojo 1.2.0 built from source. That compiler, and the
Isabelle formalisation, both reproduce that formalisation's recorded results.
Only our counts and summaries are kept here.

## Running the reference compiler

The reference compiler runs only through the wrapper that
`scripts/install-mojo.sh DIR` prints. The script installs the pinned nightly
wheel into a virtual environment under `DIR`, outside the repository, made
afresh on every run. It refuses the install unless the wheels of the
driver, the compiler and the standard library have their pinned sha256; the
human ruled the first two on 2026-11-19 (#160), and the third holds the
standard library, `std.mojoc`. Each other `mojo*` package must have the
pinned version, which the wheels' metadata pins exactly, and the wrapper
must report `Mojo 1.3.0.dev2026111905 (a549e6a6)`. Modular's nightly index
is searched before PyPI, so no package it holds comes from PyPI.

The wheel's `mojo` otherwise takes its package root and import path from
inherited `MODULAR_*` variables, and the driver reads the first
`modular.cfg` it finds, so that it links the programs it builds against
another install's runtime, with no error. The wrapper removes every
inherited `MODULAR_*` variable and gives the driver a home with an empty
`modular.cfg`. The script fails unless a test program built through the
wrapper, under a hostile config and environment, loads only libraries from
the installed wheels.

Rejected: printing the environment for callers to set. A caller that forgets
one variable gets results from the wrong runtime.

`scripts/install-mojo.sh` runs by hand, in about 15 seconds. No hook or CI
job runs it until the conformance suite needs the compiler in CI, by the
human's ruling of 2026-11-15.

## The suite

The conformance suite is `tests/conformance/` (#25): Mojo programs of the
Phase 1 subset, one per file, by area (basics, structs, ownership, lists,
arrays, references, and programs the compiler rejects). They are written in this
project's own terms, independently of the Isabelle formalisation's suite
([semantics.md](semantics.md#independence)). Its
[README](../../tests/conformance/README.md) says how to add a program.

Each program's expected result is recorded from the pinned compiler, beside
it as `NAME.json`, by `scripts/conformance.py record --mojo WRAPPER`, run
where the compiler is installed. The compiler builds the program with
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
program with its decision-log entry, a compiler bug. The first results were recorded on
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
`List[T](e1, …, en)` with arguments, but for one list or array of `T`
that can be copied (#103) and for `range(…)` with `T` an `Int` (#121). The model reports
all of them as one class, `noMatchingInit`, and `diagnostics.json` maps
that message, matched whole, to it alone. The human ruled this on
2026-11-16 (#46), following the precedent of `unknownAttribute`.

The compiler gives a second message for the same misfit when the one
argument has the type it initializes: "cannot construct 'T' with itself,
you can remove the constructor call". `List[T](xs)` from a `List[T]`
whose elements cannot be copied gives it, where an array or a literal
of them gives the first message. `diagnostics.json` maps the second
message, matched whole too, to `noMatchingInit` (#103), so that the
checker need not tell a list source from an array source. It is the first
pattern tried, since it holds a type name that a later pattern could
match, such as a struct named `immutable_box`.

The pinned nightly gives a third message for a literal of `Int`s of any
length but 1 where an `Int` is expected: "function instantiation failed",
with the note "constraint failed: expected N elements in the SIMD list
literal, found M" (D-0005). `diagnostics.json` maps it, matched whole with
its note, to `noMatchingInit` (#160); a failed instantiation with any other
note does not match it.

It gives a fourth for `List[T](range(…))` whose arguments fit no form of
the standard library's `range`, of any number or type: "no matching
function in call to 'range'". Which of the two messages a misfit gets
depends on whether every argument converts to the type of the first, which
the model does not follow. The human ruled on 2026-11-19 (#121) that
`diagnostics.json` maps it, matched whole, to `noMatchingInit`, so that
every `range` argument that does not fit is one class. Each of the four
messages still reaches only that class.

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

### Rejections made while parsing

A program that the compiler rejects while parsing, and that the model
rejects with a syntax error, is pinned by a `#guard` test in
`lean/MojoGrimoireTest/Parse/`, not by a suite program. The runner never
matches a model syntax error, exit 3, with a compiler result, so no suite
program can hold such a rejection. The human ruled this on 2026-11-18
(#104).

The rejections it covers are below, each with the compiler's first error,
probed against Mojo 1.2.0 on 2026-11-18 and again against the nightly
1.3.0.dev2026111905 on 2026-11-19, which gives the same first errors, and
the guard that pins the
model's side, named by its file and program. The guards run in every
build. When the Mojo pin moves, build each program again with the new
compiler and compare its first error with this list.

| Program | Compiler's first error | Guard |
|---|---|---|
| `def f(read x: Int)` | 'read' was removed; use 'imm' | `Conventions.lean`: `withF "read x: Int"` |
| `def f(imm: Int)` | expected argument name | `Conventions.lean`: `withF "imm: Int"` |
| `def f(owned xs: Int)` | expected ')' in argument list | `Conventions.lean`: `withF "owned xs: Int"` |
| `var y = x^ * 2` | can't use starred expression here | `XorCaret.lean`: `withX "var y = x^ * 2"` |
| `var y = x^ == 3` | prefix '==' is only valid in a pattern | `XorCaret.lean`: `withX "var y = x^ == 3"` |

`x^ + 1` and `x^ 5`, which #54 also pins as syntax errors, are not on the
list: the compiler builds them and prints `2` and `6`. They are outside the
subset, not rejections.

Rejected: changing `scripts/conformance.py` so that a model syntax error
agrees with a compiler parse error, and holding these programs in
`tests/conformance/rejected/` under a class of `diagnostics.json`. It
changes the checking machinery for five programs that the guards already
pin.

### Cycles of structs

The compiler rejects a struct that holds itself by value, directly or
through other structs, with "attempt to resolve a recursive reference to
declaration", as it does a struct on a cycle of arrays alone whose structs
have a `__deinit__`. It rejects a struct on a cycle made only of list and
array edges with "field … has non-'Deinitable' type", except in the cases
above and some of those whose structs have a `__deinit__` (D-0006).
`diagnostics.json` maps both to `recursiveStruct`; the rule is in
[semantics.md](semantics.md#the-static-checker) (#47). On a cycle with no
list edge, such as a struct that holds an array of itself, the model
agrees. On a cycle with a list edge, the second message is a compiler bug,
modular/modular#7398, and the model accepts the program (D-0006, #136);
`known.json` lists those programs under D-0006, or under D-0004 for its
`@fieldwise_init` form.

Mojo 1.2.0 gave two more messages for cycles with `@fieldwise_init` that
the model accepts, the compiler bug D-0004: "invalid implicit move" and
"invalid call to '__init__': no candidates found". The pinned nightly
compiles those forms, and rejects only the one with the holder declared
first, with the non-'Deinitable' message. The two messages have no
pattern, since no error of the model corresponds to them.

Rejected: mapping those two messages to `recursiveStruct`, which would
class a compiler bug as a rejection that the model agrees with.
