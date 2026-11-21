# D-0008 in detail: a range whose start and end lie 2^63 apart aborts (provisional)

This page holds the full entry of
[D-0008](decision-log.md#d-0008-a-range-whose-start-and-end-lie-263-apart-aborts-provisional),
whose summary stays in the decision log, so that the log stays within the
file-size budget (ADR-2026-11-15-1901). It was moved out of the log on
2026-11-21, with each field of the entry as a section.

## Date

2026-11-19

## Mojo release and commit

Nightly 1.3.0.dev2026111905 (D-0007); 1.2.0
(527d069ee11a41ac5320af1f9402db0a66b2b868) aborts the same way

## Programs

None in the suite. The runtime writes the abort on standard
output, and `scripts/conformance.py` records it as a printed line, with
the first line of the stack trace, which holds an address and a local
path, as the failure's detail. So the cases are pinned by `#guard` tests
in `lean/MojoGrimoireTest/Parse/ListRange.lean`, and the reproducer is
`print("before")` followed by
`print(List[Int](range(-1, 9223372036854775807, 9223372036854775807)))`.

## Compiler

`List[Int](range(start, end, step))` aborts at run time when
the range is not empty and `start - end` is ±2^63, such as
`range(-1, Int.MAX, Int.MAX)` or `range(0, Int.MIN, Int.MIN)`, with
``ABORT: Mojo/stdlib/std/memory/alloc.mojo:1021:18: Layout: `length`
must be >= 0`` (1.2.0: `alloc.mojo:888:14: alloc: Layout.count() must be
>= 0`). Lines printed before it are kept. At `10c54f6f5b` the
initializer of `List` from an iterable reserves the lower bound that
`bounds()` gives (`std/collections/list.mojo:548`), which
`_StridedRange._signed_count` computes from `abs(start - end)`
(`std/builtin/range.mojo:371`). That difference wraps to `Int.MIN`, the
count comes out negative, and the allocation aborts. The elements, from
`__next__`, are right, and every neighbour that does not abort, such as
`range(Int.MIN, Int.MAX, Int.MAX)`, gives the plain list. The boundary
is exact: a span above 2^63, as in `range(Int.MIN, Int.MAX, 2^62)`,
wraps to a small positive count, which only under-reserves, and builds
the right list (`lists/range_wide`). A `TODO` there
names the wrap, tracked internally as MSTDL-3087.

## Model

Builds the plain list, `[-1, 9223372036854775806]` for
`range(-1, Int.MAX, Int.MAX)`, so the reproducer prints `before` and
that list.

## Classification

Compiler bug, ruled by the human on 2026-11-19 (#121).
The ruling is provisional, until the human has discussed it with
Modular.

## Decision and rationale

The fixed compiler builds the range's elements,
each of which lies between `start` and `end`, so no element overflows;
only the reserved size does. The model builds the list that unbounded
arithmetic gives, as for every range that does not abort.

## Upstream report

Not filed yet. A draft on #121 awaits the human's
approval; its link goes here once it is filed.
