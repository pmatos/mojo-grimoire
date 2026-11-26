# Current decisions: semantics, an index of an `Int`

This page continues [semantics-lists.md](semantics-lists.md) with an
index of an `Int`, which reads its one element as an array's of length 1.

## An index of an `Int`

`Int` is `SIMD[DType.int, 1]`, whose `__getitem__` and `__setitem__` read
and write its one element. The human ruled on 2026-11-20 that indexing an
`Int` joins the subset (#127):

- `k[0]` is the `Int` `k` itself, read or assigned, also through a field,
  an element, a parameter, a reference, another index and `+=`. It is an
  element of `k` for initialization and for changes, as an array's is.
- Any other index is a compiler bug, since the nightly ignores the index
  ([D-0009](../conformance/decision-log.md), provisional): the model
  checks it as an array's of length 1. A constant index is rejected when
  it is negative (`negativeIndex`) or at least 1
  (`constantIndexOutOfBounds`), reported late as for an array; a computed
  one other than 0 fails at run time.
- An index must be an `Int`: `__getitem__` of an `Int` has one overload,
  so a `Bool` index is `typeMismatch`.
- The element has no memory origin: `ref r = k[0]` and a returned
  reference to it are `escapingReference`, as the compiler reports
  "doesn't have a memory origin". `k[i] = v` is `k.__setitem__(i, v)`: it
  locates `k` and evaluates `i` before `v`, where a list's element is
  located after its value (D-0002), and reads a place `i` last, as any
  argument. So `v` may invalidate neither `k` nor a place `i` is read
  from, and `k[i] = zero(i)` stores at the `i` that `zero` leaves.
  The interpreter decides this from the place's static type, never from
  what its lists hold.
- Not modelled yet (#222): the compiler passes `k[0]` to a `mut`
  parameter as a temporary that it writes back after the call, which
  argument exclusivity does not cover, and to a `ref` parameter as a
  temporary that a later change of `k` does not reach. Until then, a call
  of a function, a method or an operator method that passes `k[0]`, at any
  depth, to a `mut` or `ref` parameter keeps the result it had before
  #127, so that no rejection turns into a wrong run: `notAList`, checked
  after the indices as before, a constant out of the `Int`'s range
  included, also when another argument aliases `k`, since exclusivity is
  checked once the arguments are (#96 part 9), or an earlier error of the
  call. So is `k[0]` passed to a `read` parameter
  that the callee's origin names, a signature the compiler rejects. Passed
  `read` or owned otherwise, `k[0]` is copied, as the ruling allows.
- `p op= e` is read as `p = p op e`, which evaluates the indices of `p`
  twice where the compiler evaluates them once, a gap for list elements
  too (#198). Into the element of an `Int`, such an assignment keeps its
  result from before #127, `notAList`, unless every index of `p` is a
  constant or a variable, so that no index runs twice.
