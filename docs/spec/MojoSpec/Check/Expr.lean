import VersoManual
import MojoGrimoire.Check.Expr
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Expr`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Expressions and arguments: readable blocks" =>

:::moduleDocs (fingerprint := "13042083556400415133")
:::

:::readable MojoGrimoire.Check.lift MojoGrimoire.Check.expect (fingerprint := "8319086590657683010")
*Definition: helpers.* `lift` runs a lookup of the program's tables inside
the checker, and `expect` rejects a type other than the one expected.
:::

:::readable MojoGrimoire.Check.requireMutable (fingerprint := "10042303404005118453")
*Definition: requiring a place that may change.* A place that is assigned
to or passed `mut` must be one the function may change, and not reached
through $`q\,\hat{}`: the compiler borrows $`q` there as a value that
cannot be changed.
:::

:::readable MojoGrimoire.Check.copyPlace MojoGrimoire.Check.requireTransferable MojoGrimoire.Check.transferPlace (fingerprint := "6464575898280999177")
*Rule: reading and moving a place.* Using a place $`p` as a value copies it
implicitly: $`p` must be initialized, and its type implicitly copyable.
Transferring it, $`p\,\hat{}`, needs $`p` initialized and a variable
that the function may change, owned or held `mut`; afterwards $`p` is
uninitialized, and a field $`p` is added to $`M`. An element of a list or
an array, or a part of one, cannot be transferred out, nor can a value
through a reference. These conditions, without the move, are what
$`q\,\hat{}` before a field or a method needs of $`q`.
:::

:::readable MojoGrimoire.Check.binaryTy MojoGrimoire.Check.unaryTy (fingerprint := "17580043234083190239")
*Rule: operators.* Arithmetic takes two $`\mathsf{Int}` and gives an
$`\mathsf{Int}`; $`<`, $`\le`, $`>` and $`\ge` take two
$`\mathsf{Int}` and give a $`\mathsf{Bool}`; $`==` and $`!=` take
two values of the same type, $`\mathsf{Int}` or $`\mathsf{Bool}`, and
give a $`\mathsf{Bool}`; $`\mathsf{and}` and $`\mathsf{or}` take
and give $`\mathsf{Bool}`. Negation takes an $`\mathsf{Int}`, and
$`\mathsf{not}` a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Check.constInt (fingerprint := "5106496572261359333")
*Definition: constant indices.* An index made only of integer literals,
negation, $`+`, $`-`, $`\times`, `//` and `%` has a value that Mojo
computes when it compiles the program, with the same integer arithmetic
as a run.
:::

:::readable MojoGrimoire.Check.overlaps MojoGrimoire.Check.PassedLoc MojoGrimoire.Check.passedPlace MojoGrimoire.Check.locationArgs MojoGrimoire.Check.checkExclusive MojoGrimoire.Check.checkExclusive.go (fingerprint := "18358550950413267817")
*Rule: argument exclusivity.* Two places overlap when they have the same
variable and one path is a prefix of the other. The arguments of a call
that are passed as locations are the located operands whose parameters
are `read`, `mut` or `ref`, and the receiver of a method unless its
`self` is `var`, except a receiver $`q\,\hat{}` that a `var self`
consumes, which counts as $`q` passed `mut`; an $`\mathsf{Int}` or a $`\mathsf{Bool}` passed `read`
is copied instead. A call is rejected when a location passed `mut`, of
any type, overlaps another location of the same call. A reference, and a
call that returns one, overlaps what its origins overlap: `n(first(xs),
xs)` is rejected when `n` takes its second argument `mut`. The error names
the place passed, or a call's first origin.
:::

:::readable MojoGrimoire.Check.passPlace (fingerprint := "13823600396880481453")
*Rule: passing a place.* A place passed to a `read` or `ref` parameter
must be initialized and of the parameter's type; one passed `mut` must
also be a place the function may change; one passed `var` is copied
implicitly. No argument may be passed `out` or `deinit`.
:::

:::readable MojoGrimoire.Check.mark MojoGrimoire.Check.changePlace MojoGrimoire.Check.changedArgs (fingerprint := "14499198542451593185")
*Rule: changes.* A call changes as a whole each place it is passed `mut`,
and each place it is passed `ref` that the function may change; for a
call that returns a reference passed so, its origins; `append` and `pop`
change their list. The checker records the change once the
call's operands are checked, and marks as invalidated every reference
bound with `ref` whose origin the change invalidates. The mark of an
operand is the number of changes recorded once it is checked.
:::

:::readable MojoGrimoire.Check.requireUnchanged MojoGrimoire.Check.recheckLocs MojoGrimoire.Check.lateLocs MojoGrimoire.Check.recheckPlaces (fingerprint := "9273576454733297125")
*Rule: places read late.* Mojo reads a place operand only once every
operand of its operation is evaluated, and a place passed by reference is
used during the call. So once the operands are checked, every operand that
is a place must still be initialized: `f(a.id, g(a^))` is a use of `a.id`
after its move. So must every origin of a call that returns a reference
and is a located operand, passed by reference, or read by value, which
Mojo also does only then: `two(first(xs), take(xs^))` and
`print(pick(a, b, True), eat(a^))` are rejected. It is also rejected as invalidated when a change recorded
after its mark invalidates it: in `print(xs[0], xs.pop())`, `pop` changes
the list that holds `xs[0]` before `xs[0]` is read. A place located once
$`k` changes were recorded is invalidated when a change recorded since
then invalidates it.
:::

:::readable MojoGrimoire.Check.refResult MojoGrimoire.Check.checkExprAs MojoGrimoire.Check.checkArgs MojoGrimoire.Check.checkIndices MojoGrimoire.Check.checkExpr (fingerprint := "17957713269632188338")
*Rule: expressions.* An expression is checked from left to right, and has a
type:

* a literal has its type, but a string literal is rejected outside
  `print`;
* $`p` is copied implicitly, $`p\,\hat{}` transferred, and
  $`p.\mathsf{copy}()` needs an initialized place of a copyable type;
* $`f(e^*)` and $`p.m(e^*)` pass their arguments to the parameters of
  their signature, $`p` first, by the convention of the method's `self`,
  and have its result type; a receiver $`q\,\hat{}` of a method whose
  `self` is `var` is not copied: once the arguments are checked and read
  again, $`q` is transferred;
* operators have the types above;
* $`[e^*]_t`, with $`t` a list or an array of $`u` and $`u` a type a
  variable may have, passes each element as to a `var` parameter of type
  $`u`; an array must have as many elements as its type says;
* the methods of a list take it `mut`, so they need a list the function
  may change; `len(e)`, when the program declares no function or struct
  `len`, takes one list or array and gives an $`\mathsf{Int}`: a place
  argument, or a call that returns a reference that is a located
  operand, is read, not copied;
* $`\mathsf{drops}(e; p^*; q^*)`, which only elaboration inserts, after
  checking, has the type of $`e`.

The place operands of a call, a method call, a binary operator other
than `and` and `or`, a list literal and `print`, and the origins of an
operand among them that is a call that returns a reference and is a
located operand, are checked again once every operand is, by
`recheckLocs`; then the call records what it changes.
Every index in a place is checked first, and must be an $`\mathsf{Int}`;
a constant index may not be negative, nor, into an array of $`n`
elements, $`n` or more. Mojo locates $`q` in $`q[i]` before it
evaluates $`i`, so $`i` may not invalidate $`q`. Each $`q\,\hat{}` in a
place needs $`q` whole, as `p^` would, and a value that $`q\,\hat{}`
could transfer, by the conditions above.
A call or a method call that returns a reference gives the value it
points to, which must be implicitly copyable, unless the call is bound
with `ref`, passed by reference, or read by `len` or `print`.

The arguments of a call are checked in order against the parameters, after
the exclusivity rule: a place by `passPlace`; a call that returns a
reference and is a located operand, passed to a `read`, `mut` or `ref`
parameter, as a location, which must be mutable for `mut`, or the call is
$`\mathsf{immutablePlace}`, named by its first origin; and any other
expression by its type, which must be the parameter's. A `mut` parameter
needs a place or such a call.
The numbers of arguments and parameters must be equal. Checking the
arguments gives the mark of each.
:::
