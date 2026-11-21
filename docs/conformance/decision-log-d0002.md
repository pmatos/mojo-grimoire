# D-0002 in detail: a store into a list element after a call that grows the list

This page holds the full entry of
[D-0002](decision-log.md#d-0002-a-store-into-a-list-element-after-a-call-that-grows-the-list),
whose summary stays in the decision log, so that the log stays within the
file-size budget (ADR-2026-11-15-1901). It was moved out of the log on
2026-11-21, with each field of the entry as a section.

## Date

2026-11-16

## Mojo release and commit

1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868);
reproduces unchanged on the pinned nightly 1.3.0.dev2026111905 (D-0007)

## Program

`tests/conformance/lists/store_after_grow.mojo`

## Compiler

Accepts `xs[0] = bump(xs)`, where `bump` appends to `xs` and
returns 5, and prints `1 3`. It locates `xs[0]` before it evaluates the
call, the call grows the list, and the store lands in a stale element, in
the buffer that the append replaced when it reallocated. When the list has capacity reserved
beforehand, so the append does not reallocate, the same program prints
`5 3`. When the call shrinks the list instead, as in
`xs[1] = shrink(xs)` where `shrink` pops twice from `[1, 2, 3]`, the
compiler stores past the new length with no error. The `ref` form,
`ref e = xs[0]; e = grow(xs)`, is accepted too, and its store also misses
the list.

## Model

Evaluates the value before it locates the element, so
`store_after_grow` prints `5 3`, and the shrink case fails at run time
with `indexOutOfBounds`. The `ref` form is rejected
(`invalidatedReference`): the call invalidates `e` before the store, and
running it could leave the interpreter stuck when the call shrinks the
list, since `e` would name an element that no longer exists.

## Classification

Compiler bug, ruled by the human on 2026-11-16 (#57).

## Decision and rationale

The model keeps its behaviour. A store into a
stale element writes to memory the list no longer owns, and whether the
store is lost depends on whether the call happened to reallocate the
list's buffer.

## Upstream report

Not filed yet. A draft on #57 awaits the human's
approval; its link goes here once it is filed.
