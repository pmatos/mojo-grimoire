# D-0014 in detail: a wrong-length literal under a short-circuited `or`

This page holds the programs and the evidence for
[D-0014](decision-log.md#d-0014-a-wrong-length-literal-under-a-short-circuited-or-runs-at--o1-and-above-provisional).
The decision log keeps only the summary, so that it stays within the
file-size budget.

## Programs

Three suite programs in `tests/conformance/arrays/`, each listed in
`known.json` under D-0014. Each is recorded from the default build, `-O3`,
which runs it; the model rejects it as `-O0` does (`noMatchingInit`).

| Program | Right operand of `or` | `-O3` prints |
|---|---|---|
| `or_unevaluated_literal_length` | `[1] != [[1, 2, 3]]` | `True` |
| `or_unevaluated_literal_length_nested` | `aa == [[[x, x, 0], [2]], [[x, 0], [1, x]]]`, a list of lists | `True`, `1` |
| `or_unevaluated_literal_length_call` | `[f(2), 1] < [[2, 0], [2, 0]]`, where `f` prints | `True`, `end` |

The first is the minimal shape:

```mojo
def main():
    var t = True
    print(t or ([1] != [[1, 2, 3]]))
```

Ten programs of the random corpus of #260's review have the same shape,
`print(t or (…))` after `var t = True`, with a literal whose inner literal
has the wrong length where an `Int` is expected: `rand/b1/r1_00413`,
`rand/b1/r1_00882`, `rand/g1/r2_01091`, `rand/g1/r2_01131`,
`rand/g1/r2_03235`, `rand/g3/r3_01397`, `rand/g3/r3_04539`,
`rand/g3/r3_04826`, `rand/g3/r3_04950` and `rand/g3/r5_03926`. On
2026-11-26 each ran at `-O3` and printed `True` first, and each was
rejected at `-O0` with the constraint note below; the model rejects each
with `noMatchingInit`. They are not in the repository.

## Compiler

These runs were made on 2026-11-26 with the pinned nightly
1.3.0.dev2026111905, each program built with `mojo build` at `-O0`, `-O1`,
`-O2`, `-O3` and with no flag, the default, which is `-O3`.

| Body of `main` | `-O1`, `-O2`, `-O3` | `-O0` |
|---|---|---|
| `var t = True; print(t or ([1] != [[1, 2, 3]]))` | `True` | rejected |
| `print([1] != [[1, 2, 3]])` alone | rejected | rejected |
| `var t = False; print(t or ([1] != [[1, 2, 3]]))` | rejected | rejected |
| the three suite programs | run | rejected |

Each rejection is "function instantiation failed", with the note
"constraint failed: expected 1 elements in the SIMD list literal, found
3" (2 for some programs), at `std/simd.mojo:1094`. `mojo run` and
`-D ASSERT=all` run the first program and print `True`. In
`or_unevaluated_literal_length_call`, `f` is never called at `-O3`.

So the optimizer drops the right operand of `or`, once it knows that the
left one is `True`, before the operand's literal is instantiated, and
with it the error. Only an `-O0` build instantiates it.

Neighbours that the ruling does not name, asked on #346: a variable
that holds `False` on the left of `and`, and a dead branch of an `if`,
show the same level difference; a literal `True` on the left of `or`,
or `False` on the left of `and`, runs at every level, `-O0` included.

## Evidence

The fixed compiler rejects these programs at every level, with
`noMatchingInit`:
- that is the pin's own result at `-O0`;
- the comparison on its own is rejected at every level, and so is the
  same `or` when `t` holds `False`, so the literal is not valid Mojo;
- whether a program is valid should not depend on the optimization
  level.

So the human ruled on 2026-11-26 that the `-O3` result is a compiler bug
(#324). The rejected alternative was to follow `-O3`: the model would then
skip checking an operand of `or` that is never evaluated, and run these
programs. The ruling is provisional, until the human has discussed it
with Modular.
