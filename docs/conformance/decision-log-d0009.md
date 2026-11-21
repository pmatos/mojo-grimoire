# D-0009 in detail: an index of an `Int` other than 0 is ignored

This page holds the programs and the evidence of
[D-0009](decision-log.md#d-0009-an-index-of-an-int-other-than-0-is-ignored-provisional),
whose summary stays in the decision log, so that the log stays within the
file-size budget.

## Programs

In `tests/conformance/basics/`, each listed in `known.json` under D-0009:

- `int_index_constant_out_of_bounds.mojo`: `print(k[1])` prints `7`; the
  model rejects it as `constantIndexOutOfBounds`;
- `int_index_negative.mojo`: `print(k[-1])` prints `7`; the model rejects it
  as `negativeIndex`;
- `int_index_store_out_of_bounds.mojo`: `k[1] = 5` then `print(k)` prints
  `5`; the model rejects it as `constantIndexOutOfBounds`;
- `int_index_computed_out_of_bounds.mojo`: `k[three()]`, with `three()`
  returning 3, prints `7`; the model prints the line before it, then fails
  at run time with `indexOutOfBounds`;
- `int_index_popped.mojo`: `k[xs.pop()]`, with `xs = [0, 2]`, prints `7`
  twice; the model fails at the first, which pops 2.

The programs on which the model agrees are `basics/int_index.mojo`, index 0
read and written through a variable, a field, an element of a list, another
index, `+=` and a `mut` argument, and four in `rejected/`: `int_index_bool`
(`typeMismatch`), `int_index_ref_binding` and `int_index_ref_return`
(`escapingReference`: "value of type 'Int' doesn't have a memory origin"),
and `int_index_ref_argument_immutable` (`immutablePlace`: `k[0]` passed to a
`ref` parameter is a temporary that cannot be changed).

## Compiler

The pinned nightly 1.3.0.dev2026111905 accepts every index of an `Int`, and
acts on its one element: `k[1]`, `k[-1]`, `k[1 - 2]`,
`k[9223372036854775807]` and `k[three()]` read `k`, and `k[1] = 5`,
`k[-1] = 5` and `k[three()] = 5` store into `k`. Building with `-O0` or with
`-D ASSERT=all` changes nothing (probed 2026-11-20 and 2026-11-21).

At `10c54f6f5b`, `SIMD.__getitem__(self, idx: Int)` (`std/simd.mojo:1193`)
and `SIMD.__setitem__(mut self, idx: Int, val)` (`std/simd.mojo:1209`) lower
to `pop.simd.extractelement` and `pop.simd.insertelement`, with no bounds
check. In LLVM an index at or beyond the vector's length gives a poison
value, so the result is undefined; on x86-64 it is element 0.

## Model

The model types an index of an `Int` as an `Int`, the `Int` itself, as the
compiler does, and checks the index as an array's of length 1: a constant
index, made only of integer literals and operators, is rejected when it is
negative (`negativeIndex`) or at least 1 (`constantIndexOutOfBounds`), and a
computed one other than 0 fails at run time (`indexOutOfBounds`). Both
rejections are reported late, as for an array, so an unknown name in the
statement comes first.

The element has no memory origin of its own: `ref r = k[0]`, and a
reference returned to `k[0]`, are `escapingReference`, and `k[0]` passed to
a `ref` parameter gives a reference that cannot be changed, as the compiler
does.

## Evidence

The array of one element on the pin, `var k = [7]`, gives the fixed
behaviour for every program above: `k[1]` and `k[1] = 5` are rejected with
"constraint failed: index is out of bounds", `k[-1]` and `k[1 - 2]` with
"constraint failed: negative indexing is not supported", and `k[three()]`,
`k[three()] = 5`, a computed `-1` and `k[xs.pop()]` fail at run time with
"index N is out of bounds, valid range is 0 to 0". `InlineArray` checks a
constant index with `comptime assert` and a computed one with
`check_bounds` (`std/collections/array.mojo`). A list gives the same
`negativeIndex` (`rejected/negative_index_expression`). Neither the docs nor
the compiler states a rule for an `Int`'s index, so the evidence is this
analogy, and the ruling is provisional.
