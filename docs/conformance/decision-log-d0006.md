# D-0006 in detail: a struct cycle through a list, rejected as non-'Deinitable'

This page holds the full entry of
[D-0006](decision-log.md#d-0006-a-struct-cycle-through-a-list-rejected-as-non-deinitable),
whose summary stays in the decision log, so that the log stays within the
file-size budget (ADR-2026-11-15-1901). It was moved out of the log on
2026-11-21, with each field of the entry as a section.

## Date

2026-11-19

## Mojo release and commit

1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868);
reproduces unchanged on the pinned nightly 1.3.0.dev2026111905 (D-0007)

## Programs

Under `tests/conformance/rejected/`: `recursive_list_field`, `recursive_list_cycle`,
`recursive_list_array_cycle`, `recursive_list_cycle_beside_mixed`,
`recursive_cycle_and_list_of_self`, `list_cycle_beside_self_loop_deinit`,
`list_of_self_deinit_off_cycle`, `list_of_arrays_cycle_deinit` and
`array_of_lists_cycle_deinit`.

## Compiler

Rejects a struct on a cycle of fields whose edges are lists
and arrays only, such as `struct Node: var children: List[Node]`, with
"field 'children' has non-'Deinitable' type 'List[Node]'". It accepts
the same cycle when some structs on it have a `__deinit__` of their own,
but not always: it still rejects it when a struct on the cycle with no
`__deinit__` holds a list of itself, or is held through two containers,
`List[Array[B, 1]]` or `Array[List[B], 1]`, by one that has one. The
`__deinit__` forms that it accepts are in `tests/conformance/structs/`,
from `list_of_self_deinit` to `array_of_lists_cycle_both_deinit`. A
cycle with a by-value edge and a list edge is accepted (D-0004 aside),
and a cycle with no list edge, of by-value or array fields, is rejected,
with or without `__deinit__`. The nightlies 1.3.0.dev2026111705 and
1.3.0.dev2026111905, checked on 2026-11-19, give the same results.

## Model

Accepts every struct cycle with a list edge, with or without
`__deinit__`, and rejects every cycle with no list edge
(`recursiveStruct`). Each of the nine programs runs. Given an empty
`__deinit__` on each struct, the workaround of modular/modular#7398,
1.2.0 compiles each of them and prints what the model prints.

## Classification

Compiler bug, ruled by the human on 2026-11-19 (#136).
The ruling is provisional until the human has discussed it with Modular.

## Decision and rationale

The fixed compiler accepts every struct cycle
with at least one list edge. The manual bases the ban on recursive
structs on layout, and a list field has a fixed size. Modular tracks the
rejection as modular/modular#7398, triaged by the Mojo compiler team:
the synthesized `__deinit__` rejects a struct that holds itself through
a conditionally `Deinitable` type, and a user-written `__deinit__` works
around it. modular/modular#7290 reports a struct that cannot hold a
`List` of itself. The D-0004 form with `B` declared first fails with the
same message, probably from the same cause.

## Upstream report

Modular/modular#7398 and modular/modular#7290, filed by
others; no new report is needed.
