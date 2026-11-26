# Current decisions: conformance, classes of error

This page continues [conformance.md](conformance.md) with the classes of
the model's `CheckError` that the compiler's diagnostics map to, by the
patterns of `tests/conformance/diagnostics.json`. Every pattern for a
message that quotes a name of the program's is matched whole and comes
before every loose pattern ([conformance.md](conformance.md#the-suite), #271).

## Unknown fields and methods

The compiler gives one error, "'T' value has no attribute 'a'", for a field
and for a method that the type `T` lacks, whatever `T` is. The model
reports both as one class, `unknownAttribute`, and the suite compares it
exactly, as every other class (#42).

Rejected: keeping `unknownField` and `unknownMethod` in the model and
letting the suite accept either for that error. It changes how the suite
compares, and a program would agree even when the model rejects it for the
other reason. Also rejected: keeping both classes in the checker and
giving them one name in the driver. The class that the checker reports
would then differ from the one the suite compares, and the Lean tests would
pin a distinction that the compiler does not make.

## Initializations that fit no initializer

The compiler gives one error, "no matching function in initialization",
for every initialization whose arguments fit none of the type's
initializers: it tries each one and reports only that none fits. That
covers a construction `S(…)` with a wrong number of arguments, a wrong
one, or a value that is not a place, or cannot change, passed to a `mut`
parameter, whether `S` is `@fieldwise_init` or has its own `__init__`; a
literal whose length or elements do not fit the list or array it
initializes, or that initializes a struct or a `Bool`; and
`List[T](e1, …, en)` with arguments, but for one list or array of `T`
that can be copied (#103) and for `range(…)` of `Int` arguments with `T`
an `Int` (#121). The model reports
all of them as one class, `noMatchingInit`, and `diagnostics.json` maps
that message, matched whole, to it alone. The human ruled this on
2026-11-16 (#46), following the precedent of `unknownAttribute`.

The compiler gives a second message for the same misfit when the one
argument has the type it initializes: "cannot construct 'T' with itself,
you can remove the constructor call". `List[T](xs)` from a `List[T]`
whose elements cannot be copied gives it, where an array or a literal
of them gives the first message. `diagnostics.json` maps the second
message, matched whole too, to `noMatchingInit` (#103), so that the
checker need not tell a list source from an array source. It is the first
pattern tried, since it holds a type name that a later pattern could
match, such as a struct named `immutable_box`.

The pinned nightly gives a third message for a literal of `Int`s of any
length but 1 where an `Int` is expected: "function instantiation failed",
with the note "constraint failed: expected N elements in the SIMD list
literal, found M" (D-0005). `diagnostics.json` maps it, matched whole with
its note, to `noMatchingInit` (#160); a failed instantiation with any other
note does not match it. The nightly gives it in every position, a
converted argument or operand too, so the model reports `noMatchingInit`
there as well (#154); a literal whose elements are not all `Int`s gives
the first message where it initializes the `Int`, and "cannot be converted
from list literal" where it is converted (#153). The table of positions is
on [semantics-lists.md](semantics-lists.md).

It gives a fourth, "no matching function in call to 'NAME'", for a call
that fits no overload of a function, a wrong number of arguments
included: `List[T](range(…))` whose arguments fit no form of `range`,
and `len` of a `Bool`, `None` or a struct without `Sized`. Which of the two
messages a `range` misfit gets depends on whether every argument
converts to the first's type, which the model does not follow. The human
ruled on 2026-11-19 (#121) that `diagnostics.json` maps it, matched
whole, to `noMatchingInit`, and on 2026-11-20 widened it to any name
(#190). It is tried first, as the name could match a later pattern. Each
of the four messages reaches only that class.

Ordinary calls keep their classes, since the compiler names the misfit
there: `typeMismatch` and `arityMismatch`. So does a literal passed to a
function or a method, which the compiler converts and reports as "cannot
be converted from list literal", and a literal with no expected type whose
elements differ, which it reports as "not compatible". An ownership
error, such as `implicitCopy` or `uninitializedUse`, keeps its class, and
so does an error inside an argument that the model checks before it finds
the misfit. Where the order still differs from the compiler's is in
[semantics-error-order.md](semantics-error-order.md#calls-and-initializers).

Rejected: leaving the message unclassified, which the suite counts as a
disagreement, so that these programs could never be compared; and letting
one message accept several classes, which loosens the comparison.

## Calls that fit no overload, and methods a type lacks

The compiler gives "no matching method in call to 'NAME'" for a call of
a method or an operator with several overloads that none fits, whatever
the misfit, a wrong number of arguments included. On the pinned nightly
these are an operator whose left operand is an integer literal, or an
expression made only of them (`1 + True`, `(2 * 3) // b`, `1 + s`), an
index of a list or an array that is no `Int` (`xs[True]`, `a[b]`, also
as the target of an assignment), and a list's `pop` (`xs.pop(True)`,
`xs.pop(0, 1)`, and `pop` of a list that may not change, such as a `read`
parameter or `xs^`). A method with one overload names the misfit, "invalid
call ... cannot be converted", and keeps `typeMismatch`: `append`, a
struct's method, an operator of an `Int` that is not a literal, an
operator of a `Bool`, and an index of an `Int`. `diagnostics.json` maps
the message, matched whole, to `noMatchingMethod`, and the model reports
it for each of these calls. The human ruled this on 2026-11-20 (#88,
#169), as #46 did for `noMatchingInit`. A literal of `Int`s of the wrong
length still fails SIMD's constraint first, `noMatchingInit` (#169).

The compiler gives "'T' does not implement the '__X__' method" for an
operator whose operand's type lacks its method: `+`, `-`, `*`, `//`,
`%` and negation of a `Bool`, of an array or of `None`; `-`, `//`, `%`,
ordering and negation of a list; every operator of a struct that neither
declares the method nor gets it from a trait; and `__bool__` of a struct,
an array or `None` under `not`, `and` or `or`, either operand of the last
two. It gives the same for a call of a variable, whose type lacks
`__call__`: within its scope a variable or a parameter named like a
function, `len`, `range`, `print` or a struct hides it in a call, and the
arguments are typed without the hidden function's signature.
`diagnostics.json` maps the message, matched whole, to `missingMethod`,
and the model reports it in each of these cases. The human ruled this on
2026-11-20 (#176).

A struct that declares the method is called instead, and so is the
`__call__` of a variable's struct, which hides a function, `len`, `range`,
`print` or a struct of its name (#191,
[semantics-operators.md](semantics-operators.md)): a misfit of its
arguments is reported as an ordinary call reports it, and the suite's
`structs/operator_method_*`, `structs/call_method*` and
`rejected/operator_method_*` and `rejected/call_method_*` programs pin
it. A call that leaves out a required argument, of a function, a method
or `__call__`, is `arityMismatch`: `diagnostics.json` maps the
compiler's "missing required argument", matched whole, to it. The human
ruled this on 2026-11-20 (#209). A call with more positional arguments
than its callee takes is `arityMismatch` too: the compiler's "invalid call
to 'F': unexpected argument" is matched whole and placed with it, above
the loose patterns, since a callee's name such as `immutable` would match
one of them. The suite's `rejected/unexpected_argument_named_like_other_errors`
pins it. The human ruled this on 2026-11-22 (#219). An operator method
declared with the wrong number of operands, `self` among them, such as
`__add__(self)` or `__bool__(self, k: Int)`, is `arityMismatch` too:
`diagnostics.json` maps "'__X__' requires N operands", matched whole and
accepting "operand", to it. The human ruled this on 2026-11-21 (#214).

The model does not yet follow one case of the same rules. The operator
methods that `Equatable` and `Comparable` supply by default (`a == b` on a
struct that conforms to `Equatable`) are not modelled: the model reports
`missingMethod` where the compiler accepts (#194). A variable also hides
a type of its name in a type, as the next section says.

Both patterns come first in `diagnostics.json`, since each message holds
a name of the program's, a type or a method, that a later pattern could
match. The compiler finds both errors when it types the operands, before
any read. The model's order is in
[semantics-error-order.md](semantics-error-order.md#calls-and-initializers).

A temporary bridge keeps `main`'s results for the struct tests that part
2 of #191 accepts, until #96 part 4
([semantics-operators.md](semantics-operators.md#methods-that-a-struct-declares)
says how).

Rejected: mapping either message to an existing class, `noMatchingInit`,
`typeMismatch` or `unknownAttribute`, which would merge errors that the
compiler tells apart.

## Violated constraints

The compiler gives "invalid call to 'NAME': violated constraint" for a
call whose constraint on the parameters of the callee's type fails, with
a note that names the trait, such as "expected 'conforms_to(T,
Equatable)'". Two arrays compared whose element type does not conform to
`Equatable`, or to `Comparable` to order them, give it: arrays of `None`,
of a list ordered, and of a struct without the conformance; so does `==`
on lists of such a struct. `diagnostics.json` maps the message, matched
whole and first, to one class, `violatedConstraint`, from the message
alone. The human ruled this on 2026-11-20 (#166, option A). The model reports it for arrays of `None` and arrays of lists
ordered, from the operands' types before it reads them
([semantics-comparisons.md](semantics-comparisons.md#comparisons-of-arrays-and-lists));
arrays and lists of structs come with part 3 of #166, after #194, and
lists of `None` with `None` as a type (#183).

Rejected: one class per trait. The runner keeps a note only for
"function instantiation failed", so a pattern cannot see which trait is
missing, and the human did not approve a runner change.

## Types that a variable hides

Within its scope, a variable or a parameter hides a type of its name in a
type too, as in a call. The compiler gives "cannot use a dynamic value in
type specification" for a whole type, and "cannot use a dynamic value in
a parameter list" for a type inside `List[...]` or `Array[...]`, at any
depth. The name is `Int`, `Bool`, a struct of the program, or any other
name used as a type. It is hidden in a variable's annotation, with an
initializer or not, a parameter's type, a result, `-> ref[a] T` included,
and `List[T]()` and `List[T](...)` wherever they stand. A parameter hides
the types of the parameters after it, the result and the body, not an
earlier parameter's type or its own; a variable, also bound with `ref`,
uninitialized or moved out, hides from after its declaration to the end
of its block, not in its own type. A field hides nothing, and a literal's
type, which the program does not write, is not hidden. `diagnostics.json`
maps both messages, matched whole, to `valueAsType`, and the model reports
it: the parser marks each hidden name before `Self` is resolved and
before inference (`MojoGrimoire.Parse.HiddenTypes`). A call of the
variable stays `missingMethod`. The human ruled this on 2026-11-20 (#193).

The model reports the error in program order: after an earlier error in
the body, and before the declaration's initializer, its reuse of a name
and the arguments of `List[T](...)`, as the compiler does. Among the
declarations, it takes its place in the type phase's order
([semantics-error-order.md](semantics-error-order.md#the-order-of-the-type-phase)).
The compiler also resolves a function's or a method's
signature where a body first refers to it, and a struct's `__init__`
signature with the struct, in declaration order, where the model checks a
signature with its body (#231). And
`ref r = List[T]()` stays `notAReference`, and `List[T]()` passed to a
`mut` parameter `notAPlace`, since the model rejects what is not a
location there before it checks the expression.

A variable named `List` or `Array` makes `List[...]` a subscript of the
variable, which the compiler reports with other errors. The model does
not mark those names, and keeps its result on `main` until #232 is ruled.

Rejected: `invalidType`, which maps no compiler message, and treating the
programs as outside the subset, exit 3, which would hide a real
disagreement, since the compiler rejects them.

## Subscripts of types that cannot be indexed

A subscript, read or assigned, of a `Bool`, of `None` or of a struct
that declares neither `__getitem__` nor `__setitem__` is "'T' is not
subscriptable, it does not implement the `__getitem__`/`__setitem__`
methods". `diagnostics.json` maps it, matched whole and first, to
`notAList`, as the model reports it. The human ruled this on 2026-11-20
(#182). The compiler reports it before any error in the index or in the
assigned value, which the model reports first (#227).

A subscript, read or assigned, of a struct that declares `__setitem__`
but not `__getitem__` is "'T' has '__setitem__' but no '__getitem__'
method", reported once its receiver is typed, before its index, the
assigned value and a later pass's errors. `diagnostics.json` maps it,
matched whole, to `missingMethod`. The human ruled this on 2026-11-25
(#296); a class of its own and leaving it unclassed were rejected. The
model reports it for `p[i] = v` and `p[i] op= v`; a read of such a
subscript is still `notAList` in the model (#298).

## Copyable structs whose fields cannot be copied

The compiler synthesizes the copy initializer of a struct that declares
`Copyable` from its fields, and rejects the struct at its declaration,
even when nothing copies it, when a field cannot be copied: "cannot
synthesize copy constructor because field 'F' has non-copyable type
'T'". For `ImplicitlyCopyable` it rejects a field that cannot be copied
implicitly, such as a `List[Int]` or a `Copyable` struct: "cannot
synthesize implicit copy constructor because field 'F' has
non-implicitly-copyable type 'T'". The error points at the first such
field. A struct's copyability is what it declares, so a struct that holds
a rejected struct is not rejected for it, and a method `copy` that the
struct writes changes nothing. `diagnostics.json` maps both messages,
matched whole, to `uncopyableField`. The human ruled this on 2026-11-20
(#164). A hand-written copy initializer, `__init__(out self, *, copy:
Self)`, which the compiler accepts, is not yet parsed (#184).

Where this error comes among the compiler's is in
[semantics-error-order.md](semantics-error-order.md#the-order-of-the-type-phase).

Rejected: an existing class, `notCopyable` or `implicitCopy`, which would
merge an error at a struct's declaration with an error at a copy.

## Cycles of structs

The compiler rejects a struct that holds itself by value, directly or
through other structs, with "attempt to resolve a recursive reference to
declaration", as it does a struct on a cycle of arrays alone whose structs
have a `__deinit__`. It rejects a struct on a cycle made only of list and
array edges with "field … has non-'Deinitable' type", except in the cases
above and some of those whose structs have a `__deinit__` (D-0006).
`diagnostics.json` maps both to `recursiveStruct`; the rule is in
[semantics.md](semantics.md#the-static-checker) (#47). On a cycle with no
list edge, such as a struct that holds an array of itself, the model
agrees. On a cycle with a list edge, the second message is a compiler bug,
modular/modular#7398, and the model accepts the program (D-0006, #136);
`known.json` lists those programs under D-0006, or under D-0004 for its
`@fieldwise_init` form.

Mojo 1.2.0 gave two more messages for cycles with `@fieldwise_init` that
the model accepts, the compiler bug D-0004: "invalid implicit move" and
"invalid call to '__init__': no candidates found". The pinned nightly
compiles those forms, and rejects only the one with the holder declared
first, with the non-'Deinitable' message. The two messages have no
pattern, since no error of the model corresponds to them.

Rejected: mapping those two messages to `recursiveStruct`, which would
class a compiler bug as a rejection that the model agrees with.
