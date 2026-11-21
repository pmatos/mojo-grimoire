# The conformance suite

Mojo programs on which the Lean model is compared with the pinned Mojo
compiler ([docs/decisions/conformance.md](../../docs/decisions/conformance.md#the-suite)).

- `AREA/NAME.mojo` is one program, with a `main`. It stays inside the subset
  that the model covers: what the parser reads is listed in
  [semantics-parser.md](../../docs/decisions/semantics-parser.md#the-parser-and-the-driver),
  less the constructs [outside the subset](../../docs/decisions/semantics-parser.md#outside-the-subset),
  which end with exit 3, a result the suite cannot compare.
- `AREA/NAME.json` is its expected result, recorded from the compiler. Do
  not write it by hand.
- `diagnostics.json` maps the compiler's first error to a class of error.
- `known.json` lists the programs on which the model departs from the
  compiler, each a compiler bug, by an entry of the
  [decision log](../../docs/conformance/decision-log.md).

The programs are written for this project. Never copy a program or an
expected output from the Isabelle formalisation's suite
(ADR-2026-11-15-1908).

## Running it

```sh
scripts/conformance.py check            # the model against the recorded results
scripts/conformance.py record --mojo "$(scripts/install-mojo.sh ../mojo-reference)" [PROGRAM...]
scripts/conformance.py levels --mojo WRAPPER [--jobs N] [PROGRAM...]   # whenever the pin moves
```

`record` needs the compiler: the pinned nightly wheel, installed outside this
repository by `scripts/install-mojo.sh`. It writes one `NAME.json` per
program and lists every diagnostic that no pattern of `diagnostics.json`
classifies. A new program is recorded before it is committed, so that `check`
compares it. `record` also builds each program at `-O0`, and refuses to record
one whose result differs there, unless a ruled compiler bug names it, in
`known.json` or in `docs/conformance/compiler-bugs.json`; `levels` builds
every program at each optimization level
([conformance.md](../../docs/decisions/conformance.md#optimization-levels)).
