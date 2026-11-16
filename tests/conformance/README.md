# The conformance suite

Mojo programs on which the Lean model is compared with the pinned Mojo
compiler ([docs/decisions/conformance.md](../../docs/decisions/conformance.md#the-suite)).

- `AREA/NAME.mojo` is one program, with a `main`. It stays inside the subset
  that the model covers: what the parser reads is listed in
  [semantics-parser.md](../../docs/decisions/semantics-parser.md#the-parser-and-the-driver).
- `AREA/NAME.json` is its expected result, recorded from the compiler. Do
  not write it by hand.
- `diagnostics.json` maps the compiler's first error to a class of error.
- `known.json` lists the programs on which the model departs from the
  compiler, a compiler bug or a spec decision, by an entry of the
  [decision log](../../docs/conformance/decision-log.md).

The programs are written for this project. Never copy a program or an
expected output from the Isabelle formalisation's suite
(ADR-2026-11-15-1908).

## Running it

```sh
scripts/conformance.py check            # the model against the recorded results
scripts/conformance.py record --mojo "$(scripts/build-mojo.sh ../modular)" [PROGRAM...]
```

`record` needs the compiler, built from a checkout of `modular/modular` at the
pinned commit by `scripts/build-mojo.sh`. It writes one `NAME.json` per
program and lists every diagnostic that no pattern of `diagnostics.json`
classifies. A new program is recorded before it is committed, so that `check`
compares it.
