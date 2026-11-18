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

:::moduleDocs (fingerprint := "10800812994545232235")
:::

:::readable MojoGrimoire.Check.lift MojoGrimoire.Check.expect (fingerprint := "8319086590657683010")
*Definition: helpers.* `lift` runs a lookup of the program's tables inside
the checker, and `expect` rejects a type other than the one expected.
:::

:::readable MojoGrimoire.Check.requireMutable (fingerprint := "3665794792439843375")
*Definition: requiring a place that may change.* A place that is assigned
to or passed `mut` must be one the function may change, and not reached
through $`q\,\hat{}`: the compiler borrows $`q` there as a value that
cannot be changed. Passed `mut` to an initializer, such a place is
reported as the initializer's misfit.
:::

:::readable MojoGrimoire.Check.copyPlace MojoGrimoire.Check.requireNotThroughRef MojoGrimoire.Check.requireTransferable MojoGrimoire.Check.transferPlace (fingerprint := "3713637349590493988")
*Rule: reading and moving a place.* Using a place $`p` as a value copies it
implicitly: $`p` must be initialized, and its type implicitly copyable.
Transferring it, $`p\,\hat{}`, needs $`p` initialized and a variable
that the function may change, owned or held `mut`, not a `read` or `ref`
parameter (`transferFromBorrowed`); afterwards $`p` is uninitialized, and
a field $`p` is added to $`M`. An element of a list or an array, or a
part of one, cannot be transferred out, nor can a value through a
reference bound with `ref`, even one that may be changed: the compiler
rejects both alike (`transferFromElement`). A reference is rejected so
once its place has a type, before its origins are checked, even when
they are moved away or invalidated. These conditions, without the move, are what
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

:::readable MojoGrimoire.Check.constInt (fingerprint := "18142347407676829893")
*Definition: constant indices.* An index made only of integer literals,
negation, $`+`, $`-`, $`\times`, `//` and `%` has a value that Mojo
computes when it compiles the program, with the same integer arithmetic
as a run.
:::

:::readable MojoGrimoire.Check.overlaps MojoGrimoire.Check.PassedLoc MojoGrimoire.Check.passedPlace MojoGrimoire.Check.locationArgs MojoGrimoire.Check.checkExclusive MojoGrimoire.Check.checkExclusive.go (fingerprint := "8186378624982211006")
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

:::readable MojoGrimoire.Check.passPlace (fingerprint := "2500036056060291548")
*Rule: passing a place.* A place passed to a `read` or `ref` parameter
must be initialized and of the parameter's type; one passed `mut` must
also be a place the function may change; one passed `var` is copied
implicitly. No argument may be passed `out` or `deinit`. A misfit is
reported as the call's fit says.
:::

:::readable MojoGrimoire.Check.refResult MojoGrimoire.Check.checkExprAs MojoGrimoire.Check.checkOperands MojoGrimoire.Check.checkIterableElems MojoGrimoire.Check.checkArgs MojoGrimoire.Check.checkIndices MojoGrimoire.Check.checkExpr (fingerprint := "8390691729461900381")
*Rule: expressions.* An expression is checked from left to right, and has a
type:

* a literal has its type, but a string literal is rejected outside
  `print`;
* $`p` is copied implicitly, $`p\,\hat{}` transferred, and
  $`p.\mathsf{copy}()` needs an initialized place of a copyable type;
* $`f(e^*)` and $`p.m(e^*)` pass their arguments to the parameters of
  their signature, $`p` first, by the convention of the method's `self`,
  and have its result type; when $`f` names a struct, the call is an
  initializer, whose misfits are `noMatchingInit`; a receiver
  $`q\,\hat{}` of a method whose
  `self` is `var` is not copied: once the arguments are checked and read
  again, $`q` is transferred;
* operators have the types above;
* $`[e^*]_t`, with $`t` a list or an array of $`u` and $`u` a type a
  variable may have, initializes $`t`: it passes each element as to a `var`
  parameter of type $`u`, and an array must have as many elements as its
  type says, or the literal is `noMatchingInit` $`t`; with $`t` the type
  `None`, no type is expected, and the literal is an array of the type of
  its first element, whose other elements must have that type;
* $`[e]_{\mathsf{Int}}` has the type of $`e`, which must be an
  $`\mathsf{Int}` (#103). Passed to a parameter, a literal whose type is
  not a list or an array is checked as a value, as is any literal
  passed to an initializer;
* $`\mathsf{List}[u](e)` with one argument copies the elements of a list
  or an array (#103). Its argument is passed by `ref`, as `len` takes its
  list: a place is located, its type must fit by `iterableFits`, and then
  it must be initialized; a call that returns a reference and is a
  located operand is passed as a location, and any other expression is
  checked as a value, whose type must fit. A string fits no initializer.
  A literal with no type expected is checked by `checkIterableElems`, its
  elements as passed to `var` parameters, and typed by
  `iterableLiteralTy`: the compiler infers its type while it looks for an
  initializer, so a literal with no elements, or elements of different
  types, also inside a nested literal, fit none. A place passed so that
  may be changed, by the rule of `changedArgs` for a `ref` parameter, is
  recorded as changed. The expression is a $`\mathsf{List}[u]`;
* $`\mathsf{List}[u](e^+)` with more than one argument checks each
  argument on its own, locating a place without reading it, and is then
  rejected as `noMatchingInit` $`\mathsf{List}[u]`: no initializer of
  `List` takes its elements;
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
needs a place or such a call; passed $`q\,\hat{}`, it is
$`\mathsf{notAPlace}`, where the compiler reports a value that cannot
change (#81), with two exceptions once $`q` has a type, whatever its
indices: a $`q` reached through a reference bound with `ref` is
$`\mathsf{transferFromElement}`, and a $`q` whose
variable is a `read` or `ref` parameter, other than an element (#119), is
$`\mathsf{transferFromBorrowed}`, as the compiler reports them.
The numbers of arguments and parameters must be equal. A literal of an
expected type passed to a function or a method is converted to the
parameter's type, and one that does not fit, or holds such a literal, is a
type mismatch, as the compiler reports it. Checking the arguments gives the
mark of each.
:::
