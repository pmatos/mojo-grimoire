# The probe sweep

The probe programs of #96, with the pinned compiler's result of each,
which `scripts/sweep.py` runs against two builds of the model
([conformance.md](../../docs/decisions/conformance.md#the-probe-sweep)).
Each `GROUP/NAME.mojo` has its result in `GROUP/NAME.json`, recorded
with `scripts/conformance.py record --mojo WRAPPER` from the nightly
1.3.0.dev2026111905.

- `pairs/`: the matrix of the ruling of 2026-11-20 on #96. Each program
  holds two errors of different classes, in either order of the text, in
  one function, in two functions or at the top level.
- `pairs2/`: the matrix's pairs with an escaping reference or a missing
  return, an error of a declaration, beside each other class.
- `nested/`: one error inside the construct of another, such as an
  argument of a call that does not fit.
- `siblings/`: two errors in two arguments of one call.
- `singles/`: each class of the matrix alone.
- `p96/`: the probes of #96's plan, named as in its section 1.
- `samecall/`, `samecall2/`, `icprobe/`, `icprobe2/`, `instprobe/`,
  `instprobe2/`, `mrprobe/`, `dlprobe/` and `extras/`: the ruling's
  probes of two errors in one call, of implicit copies, of instantiation
  errors, of missing returns and of declarations.
- `order6/`: Part 6's probes of the type phase's order whose compiler
  diagnostic has no class yet (#319), or whose unknown type the model
  classes `invalidType` (#237), so that the suite cannot hold them.
- `order7/`: Part 7's probes of the instantiation phase's order whose
  result differs at `-O0`, unrecorded, or that the model rejects for
  another reason: a struct's `__bool__` in a condition (#195), the
  destructor of a struct never used (#264), and a constant array index in
  a struct test that #191's bridge replaces (#323).
- `corpus/`: random programs of #260's review whose class Part 4 of #96
  changed, each listed on its PR with the open issue of its rejection,
  named `GROUP_NAME` after their place in that corpus.

A program that the compiler's result differs on at `-O0` is not recorded,
as in the suite, and the sweep lists it as unrecorded.
