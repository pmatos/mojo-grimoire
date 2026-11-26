# D-0005 in detail: a list literal of any length but 1 that initializes an `Int`

This page holds the full entry of
[D-0005](decision-log.md#d-0005-a-list-literal-of-any-length-but-1-that-initializes-an-int),
whose summary stays in the decision log, so that the log stays within the
file-size budget (ADR-2026-11-15-1901). It was moved out of the log on
2026-11-21, with each field of the entry as a section.

## Date

2026-11-19; resolved the same day at the move to the nightly (D-0007)

## Mojo release and commit

1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)

## Programs

In `tests/conformance/basics/`: `int_literal_length_two`,
`int_literal_length_three` and `int_literal_length_evaluated`.

## Compiler

`Int` is `SIMD[DType.int, 1]`, and a literal where an `Int`
is expected calls SIMD's `__list_literal__` initializer. The stdlib
documents that the number of elements must equal the vector's size, 1,
but 1.2.0 checked it only with an `assert`, which a default build leaves
out. So it accepted `var x: Int = [e1, …, en]` for every n, in every
position probed on 2026-11-19: an assignment, a `return`, a function
argument, a field of `@fieldwise_init`, `append` on a `List[Int]`, an
operand `x + [2, 3]`, and an element of a literal of `Int`s. For n ≥ 2
it evaluated every element and kept `e1`, so `[1, 2]` printed `1`; for
n = 0 the program crashed with a segmentation fault. With
`-D ASSERT=all` the program built, then trapped at run time: "mismatch
in the number of elements in the SIMD variadic constructor".

## Model

Rejects a literal of `Int`s of every length but 1, n = 0
included, in every position: `noMatchingInit` once its elements are
read (#154, ruled 2026-11-19).

## Classification

Compiler bug, ruled by the human on 2026-11-19 (#122).
The ruling is provisional, until the human has discussed it with
Modular.

## Decision and rationale

The model rejects these literals, as the stdlib
documents.

## Resolved at the nightly

1.3.0.dev2026111905 rejects every length but 1,
in every position above, with "function instantiation failed" and the
note "constraint failed: expected 1 elements in the SIMD list literal,
found N" (`std/simd.mojo:1094` at `10c54f6f5b`), which
`diagnostics.json` classes as `noMatchingInit`. The three programs agree
with the model, and `known.json` no longer lists them. The model
rejects them in every position (#154), and the suite holds an
argument, `append` and an operand (`rejected/int_literal_length_*`,
`rejected/int_literal_empty_append`). The nightly does not reject them
in an operand that it never instantiates. At `-O1` and above it drops
the right operand of `or` after a variable that holds `True`, which
D-0014 records as a compiler bug. It also drops the neighbours that #346
asks about, among them the operand after a literal `True or`, at every
level.

## Upstream report

None needed, since the nightly fixes it.
