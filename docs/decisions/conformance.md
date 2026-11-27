# Current decisions: conformance

This page says what holds today for the differential tests against the Mojo
compiler. [conformance-classes.md](conformance-classes.md) continues it
with the classes of error that the compiler's diagnostics map to.

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

### Moving the pin

The pin moves forward to a newer nightly
([semantics.md](semantics.md#the-reference)) in one PR, which:

- updates `scripts/install-mojo.sh`, the decision log and
  [semantics.md](semantics.md#the-reference);
- records the whole suite again with `scripts/conformance.py record`;
- passes the [level sweep](#optimization-levels),
  `scripts/conformance.py levels`;
- builds each program of [the parse rejections](#rejections-made-while-parsing)
  again and compares its first error with their list.

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

The `conformance-test` hook classifies every recorded rejection again with
the current `diagnostics.json` and fails when a class differs from the
recorded one, so that a change to the patterns cannot move a recorded
result to another class unnoticed. It runs whenever a recorded result or
`diagnostics.json` changes. A PR that reclassifies a message on purpose
records the affected programs again in the same PR. The human ruled this
on 2026-11-22 (#219).

A loose pattern is searched for anywhere in the message, so a name of the
program's that holds its word, such as a `mut` parameter named
`uninitialized`, would send the message to the wrong class. Every pattern
for a message that quotes a name is therefore matched whole, with each
name a quoted `'[^']*'`, and placed above every loose pattern; only
recorded messages that quote no name reach the loose patterns below, and
where they need a wildcard they use `[^']*`, which cannot span a quoted
name. A test of the `conformance-test` hook fails when a pattern with a name slot, a
wildcard that can match a quoted name such as `'[^']*'`, `'.+'` or a bare
`.*`, is not a single `^...$` with no `|` outside a group, or sits below
a loose pattern, one that is not such a single `^...$`; and when a recorded message that quotes a name reaches a pattern without a
name slot first. The suite's `rejected/mut_argument_named_like_other_errors`
pins it. The dead `expected \d+ positional arguments?` pattern, which no
message of the pin matches, is gone. The human ruled this on 2026-11-22
(#271).

The loose fallbacks that #274 listed and that no recorded rejection
reached first, 19 of them, are gone too. The loose `recursiveStruct` pattern
"attempt to resolve a recursive reference to declaration" stays, since 4
recorded messages, which quote no name, reach it. A wording that the pin
has not shown records with no class unless a kept loose pattern matches
it, and a PR adds an anchored entry for it. The human ruled this on
2026-11-26 (#274).

That ruling also asked for an anchored entry for "invalid call to
'immutable': unexpected keyword argument 'uninitialized'". It waits for a
ruling on #274: no class of the model fits it, since the model does not
read keyword arguments, so such a program is outside its subset. Until
then the message is `immutablePlace`, by the loose `immutable` that its
callee's name holds. The same loose pattern takes a message whose name
holds both `'` and that word, such as "use of uninitialized value 'it's
immutable'", and the loose `value passed to mutable argument`, which no
recorded rejection reaches, stays outside the ruling's list.

Rejected: comparing the compiler's diagnostics word for word, since their
wording changes between releases and says nothing the class does not;
anchoring and reordering the patterns without a test; keeping the dead
pattern; keeping every fallback, since a new wording would get a class
that is wrong when the message quotes a name holding the fallback's word
(#274); and making `record` fail when a rejection has no class.

### Optimization levels

A recorded result comes from the default build, at `-O3`, but the optimizer
can change a program's result (#235). `record` also builds each program at
`-O0` and does not record it when the outcome, the lines printed or a
rejection's first error differ from the default build's. The exception is a
program that a ruled compiler bug names: `known.json`, or the
`suite_programs` of a bug in
[compiler-bugs.json](../conformance/compiler-bugs.json), lists it under an
entry of the decision log. A bug that shows only below `-O3` is named in
`compiler-bugs.json` alone, since the model agrees with the recorded result
and `check` refuses a `known.json` entry for a program that agrees. No other
list excuses a program. It is recorded from the default build, and
`record` says that it differs. Otherwise a program that differs is a
compiler bug, which the human rules on, a program to change, or one whose
first error is an order left undefined: a body that holds two errors of
the instantiation phase, or one and a call of a function that holds
another, whose first error differs between the levels. Such a program stays
unrecorded
([semantics-error-order.md](semantics-error-order.md#when-the-optimization-level-changes-the-order)).

`scripts/conformance.py levels --mojo WRAPPER` builds every program at
`-O0`, `-O1`, `-O2` and `-O3` and with `-D ASSERT=all`, lists each program
whose result differs between them with the ruled entry that names it, and
fails when a program that no ruled compiler bug names differs. It runs
whenever the pin moves ([moving the pin](#moving-the-pin)), by hand, where
the compiler is installed, on 4 programs at a time unless `--jobs N` says
otherwise. No hook or CI job runs it, since it needs the compiler and took
35 minutes on the 740 programs of 2026-11-21. A difference in which the
compiler crashed is checked by building that program again alone, with
`levels --mojo WRAPPER PROGRAM`, before it is reported: in the one-off
sweep of #242, one build crashed under parallel load and passed when built
again. The first run found only the programs of D-0003 that read a field
never set, whose output at `-O0` is uninitialized memory, and the program
of D-0010; the program of D-0013, swept on its own after it was added,
differs too, and so do the three of D-0014, which only `-O0` rejects.

Both refuse to run unless the wrapper builds and runs a trivial program and
each program named is a file. A build that fails with no `error:` line from
the compiler, such as a crash or a wrapper that cannot start, and a build or
run that times out are never recorded and always fail the sweep, whatever
names the program: a sweep that compared nothing must not pass.

Both compare the compiler's results as the runner reads them, through one
function in `scripts/conformance_compiler.py`. A failed assertion's line on standard output is how the run
ended, not a printed line, at every level. A failed instantiation whose
constraint note a build leaves out agrees with the noted one. A failed
run's detail is not compared, as `check` does not compare it. No program is skipped. The human ruled all of this on
2026-11-21 (#242), with the practice that an agent which finds the model
and the compiler disagreeing on output builds the program at `-O0` before
it changes the model, and stops and reports when the levels differ.

Rejected: the practice alone, and the practice with the check at recording
time but no sweep. Also rejected: a list of programs the sweep skips.

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
compiler and compare its first error with this list
([moving the pin](#moving-the-pin)).

| Program | Compiler's first error | Guard |
|---|---|---|
| `def f(read x: Int)` | 'read' was removed; use 'imm' | `Conventions.lean`: `withF "read x: Int"` |
| `def f(imm: Int)` | expected argument name | `Conventions.lean`: `withF "imm: Int"` |
| `def f(owned xs: Int)` | expected ')' in argument list | `Conventions.lean`: `withF "owned xs: Int"` |
| `var y = x^ * 2` | can't use starred expression here | `XorCaret.lean`: `withX "var y = x^ * 2"` |
| `var y = x^ == 3` | prefix '==' is only valid in a pattern | `XorCaret.lean`: `withX "var y = x^ == 3"` |
| `var break = 1` | unexpected token in expression | `Subset.lean`: `inMain ["var break = 1", "print(break)"]` |
| `def g(continue: Int)` | expected argument name | `Subset.lean`: `"def g(continue: Int):"` |
| `def break() -> Int` | 'break' cannot be used as a function name in this context | `Subset.lean`: `"def break() -> Int:"` |
| `var break: Int`, a field | expected name for 'var' declaration | `Subset.lean`: `"    var break: Int"` |
| `var pass = 1` | unexpected token in expression | `Subset.lean`: `inMain ["var pass = 1", "print(pass)"]` |
| `def pass() -> Int` | 'pass' cannot be used as a function name in this context | `Subset.lean`: `"def pass() -> Int:"` |
| `var True: Int`, a field | expected name for 'var' declaration | `Subset.lean`: `"    var True: Int"` |

The four rows for `break` and `continue` were probed against the
nightly alone, on 2026-11-22 (#268), and the last three on 2026-11-25
(#278).

`x^ + 1` and `x^ 5`, which #54 also pins as syntax errors, are not on the
list: the compiler builds them and prints `2` and `6`. They are outside the
subset, not rejections.

Rejected: changing `scripts/conformance.py` so that a model syntax error
agrees with a compiler parse error, and holding these programs in
`tests/conformance/rejected/` under a class of `diagnostics.json`. It
changes the checking machinery for programs that the guards already pin.

## The probe sweep

The parts of #96 change the order in which the model reports errors, and
the suite alone cannot show which programs that change moves: its
programs mostly hold one error each. The probe sweep, in `tests/sweep/`,
holds the probe programs of #96, most of them with two errors, each with
the pinned compiler's result recorded by `scripts/conformance.py record`.
`scripts/sweep.py --base MODEL --head MODEL` runs the model built from
`main` and the model built from a change on every program, and counts the
programs that agree on both, those that the change fixes, those that
disagree on both, and those that agreed on `main` and no longer do. Of
the last, a change of rejection class is allowed to a part of #96 whose PR
lists the program with the open issue of its wrong rejection
([process.md](process.md#one-issue-several-prs)); any other, such as a
run that becomes a rejection, fails the sweep. A run that times out or
cannot start counts as that build's error. A recorded rejection whose
diagnostic has no class yet (#319) agrees with any rejection that prints
the same lines. A part of #96 runs the sweep by hand and gives its counts
in the PR body. The human ruled on
2026-11-22 that the sweep is committed as a corpus and one script, run by
hand and not as a hook (#96, Q8).

Rejected: keeping the sweep in a session's scratchpad, which does not
last, and running it as a hook, which would rebuild the model twice for
every commit.

## The explorer

`scripts/explorer.py --mojo WRAPPER` (or `MOJO=WRAPPER`) serves a local
page, in the style of Compiler Explorer, that runs one program on the
compiler and on the model side by side (#370). The human asked for it on
2026-11-27. It shows each side's exit code, output, timings and class of
error, linked to its section of the rendered spec, and marks the
compiler's error line and column, and the model's syntax-error or
"outside the subset" line, in the editor. Its badge is the suite's
`compare`. For a suite program, whose text it recognises, it reads
`known.json` as `check` does. Its sweep compares the levels as `levels`
does. The suite's programs are its examples, each with its record and its
decision-log entry or ruled compiler bug.

The suite's runners return only a `Result`, and read a program's output
with no limit, so the explorer starts the processes itself. Its
`Result` comes from the same helpers, and its tests check that it equals
the runners' for each kind of run. The page links a token to the
declarations that `scripts/explorer-ui/tokens.json` names. Their anchors
come from the rendered HTML, and a name with no anchor is a warning at
start.

The server runs arbitrary code, on 127.0.0.1 only. Each API call needs
the session's token and the explorer's Host; a POST also needs its
Origin, and any Origin sent must be its own. The page keeps the token in
the tab's session storage. The spec, whose pages run outside scripts, is
served sandboxed on a port of its own, with no API, so that no link into
it can reach the API. Each run gets a fresh temporary directory, a
timeout, an output cap and resource limits, and a few run at once. Its
process group, its descendants and every process that carries its marker
in the environment are then killed. A descendant that leaves the tree and
clears its environment escapes, under the same limits.

Its tests, `scripts/test_explorer*.py`, are run by hand.
Running them as a hook waits on the human's ruling (#371), since a hook
adds checking machinery.
