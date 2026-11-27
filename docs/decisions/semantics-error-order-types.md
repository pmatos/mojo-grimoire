# Current decisions: semantics, the order of the type phase

This page continues [semantics-error-order.md](semantics-error-order.md)
with the order in which the type phase, the compiler's first pass,
reports a program's errors.

## The order of the type phase

The type phase follows the order of the compiler's first pass (#96 part
6, `checkTypes`), probed on the pin
(`order/type_*`, `tests/sweep/order6/`):

1. A struct of the name of another struct or of a function comes first.
2. Then the declarations in the order of the source. A free function's
   signature and body: `main`'s parameters and result are resolved, and
   then it must take nothing and return nothing, before its conventions
   and its body; a function of the name of an earlier one fails at its
   place. A struct's own declaration, resolved unless a struct before it
   resolved it already ([below](#resolving-a-structs-declaration)), and
   then no two of its methods may have one name.
3. Then each struct in the order of the declarations: its initializer,
   destructor and methods, signature and body, in their order. The copy
   initializer that the compiler synthesizes is checked right after
   `__init__`, and an implicit one there also meets a field on a cycle
   that the fixed compiler rejects, field by field. Otherwise such a cycle
   comes after the last member, and then the copy initializer of a struct
   that declares no `__init__`. A hidden type, `valueAsType`, takes its
   place in that order like any error (#193).

The compiler resolves a method's or a function's signature where a body
first refers to it, which the model does not follow yet (#231).

## Resolving a struct's declaration

The compiler resolves a struct's declaration, in step 2, in this order
(#358, `resolveStruct`), probed on the pin (`order/type_358_*`):

1. Its fields have distinct names, no method has a field's name, and the
   fields have declarable types.
2. Then, field by field, a field that is a list or an array of a struct,
   under any number of lists and arrays, resolves that struct's
   declaration at once, if it is not resolved yet, ahead of the
   declarations between the two. So `struct A: var bs: Array[B, 1]`
   reports `B`'s duplicate field before a function declared between
   them. A field of a struct type resolves nothing.
3. A struct that declares no `__deinit__`, nor a method `__del__`, the
   destructor's older name, which the pin takes as one (#364), gets one
   synthesized, which needs the type of each such field to be
   `Deinitable`. When the
   field's struct is still being resolved, the field closes a cycle and
   is rejected there: "field 'halves' has non-'Deinitable' type
   'Array[Pair, Int(2)]'", `recursiveStruct`. So `struct Pair: var
   halves: Array[Pair, 2]` comes before an earlier struct's field that
   cannot be copied, which the type phase reports in its step 3, and of `A: Array[B, 1]` and
   `B: Array[A, 1]` the error is at `B`'s field.
4. A struct that declares either goes on only through a field of
   lists or arrays of lists or arrays, such as `Array[Array[B, 1], 1]`,
   and is never rejected so. A struct that it resolves is rejected when
   it leads back to it.

A cycle that this resolution does not close, such as one with a field
by value, `var p: Pair`, or `struct Pair` with a `__deinit__` and `var
halves: Array[Pair, 2]`, is rejected in step 3, as before: the compiler says
"attempt to resolve a recursive reference to declaration", after the
earlier structs' members. Two methods of one name are reported after
the resolution, before a later declaration; where the compiler reports
two with an identical signature is #360.

A cycle through a list is accepted (D-0006). The pin rejects it in step
2, as it rejects a cycle of arrays, and the fixed compiler accepts it, so
the model goes on there as for a struct resolved already. The suite holds
none of these, since each would be a known disagreement.

Rejected: rejecting every cycle with no list edge at the resolution
(`rejectedCycle`), since the pin reports a cycle with a field by value or
a `__deinit__` in step 3; and resolving a struct's whole declaration from
another's field, which would also report its two methods of one name
there, where the pin does not.

The model does not yet resolve a struct from a list or array type in a
function's signature, where the pin does (#359).
