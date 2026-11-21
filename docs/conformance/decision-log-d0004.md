# D-0004 in detail: `@fieldwise_init` inside a cycle of structs through a list

This page holds the full entry of
[D-0004](decision-log.md#d-0004-fieldwiseinit-inside-a-cycle-of-structs-through-a-list),
whose summary stays in the decision log, so that the log stays within the
file-size budget (ADR-2026-11-15-1901). It was moved out of the log on
2026-11-21, with each field of the entry as a section.

## Date

2026-11-18, reduced 2026-11-19 at the move to the nightly (D-0007)

## Mojo release and commit

1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868);
nightly 1.3.0.dev2026111905 since D-0007

## Program

`tests/conformance/structs/cycle_fieldwise_init_holder_first.mojo`

## Compiler

Accepts a cycle of structs with a list edge and a plain
by-value edge, such as `A` holding a `List[B]` and `B` holding an `A`,
when each initializer is written by hand, in either declaration order
(`structs/cycle_through_list` and `cycle_through_list_holder_first`).
With `@fieldwise_init` on `B`, the struct that holds the other by value,
and `B` declared first, it rejects the program with "field 'bs' has
non-'Deinitable' type 'List[B]'". With `@fieldwise_init` on `A` alone it
compiles (`cycle_fieldwise_init_list_holder`).

## Model

Accepts it, as it accepts the hand-written form, and prints `1`.
It still rejects a struct on a cycle with no list edge
(`recursiveStruct`), as the compiler does.

## Classification

Compiler bug, ruled by the human on 2026-11-18 (#47).

## Decision and rationale

The decorator is documented to produce the
initializer that is written by hand, which compiles. The error is the
one of D-0006, modular/modular#7398, which probably has the same cause.

## Fixed by the nightly

Mojo 1.2.0 also rejected the decorated forms with
`A` declared first, `cycle_fieldwise_init` with "invalid implicit move:
unexpected keyword argument 'move'": the synthesized initializer of `B`
called `A.__init__(move=...)`, not synthesized yet inside the cycle,
which resolved against `A`'s own `__init__`; and `cycle_fieldwise_init_both`,
with both structs decorated, with "invalid call to '__init__': no
candidates found". The nightly 1.3.0.dev2026111905 compiles both, and
each prints `1`, as the model does; `known.json` no longer lists them.

## Upstream report

Not filed yet. A draft on #47 awaits the human's
approval; its link goes here once it is filed.
