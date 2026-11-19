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

:::moduleDocs (fingerprint := "12058885147365312873")
:::

:::readable MojoGrimoire.Check.checkExprAs MojoGrimoire.Check.checkOperands MojoGrimoire.Check.checkIterableElems MojoGrimoire.Check.typeRangeArgs MojoGrimoire.Check.typeLiteral MojoGrimoire.Check.typeArg MojoGrimoire.Check.typeArgs MojoGrimoire.Check.readRangeArgs MojoGrimoire.Check.intMisfit MojoGrimoire.Check.readIntElems MojoGrimoire.Check.checkArgs MojoGrimoire.Check.checkIndices MojoGrimoire.Check.requireOwnOrigin MojoGrimoire.Check.typePlace MojoGrimoire.Check.checkExpr (fingerprint := "7657055534434236357")
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
* $`[e^*]_{\mathsf{Int}}` of any other length, converted, is rejected by
  `rejectIntLiteral` (#153, #154), with `intMisfit` giving the type of its
  first element that is no $`\mathsf{Int}`, nor such a literal, each typed
  as that rule says, a place by `typePlace`, and `readIntElems` reading
  its elements as
  $`\mathsf{Int}`s, a nested such literal's in turn. Passed to a
  parameter, it is rejected by the call's fit;
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
* $`\mathsf{List}[u](\mathsf{range}(e^*))`, when the program declares no
  function or struct `range` and no variable in scope is named `range`, is
  the standard library's range (#121), whose one to three arguments are
  checked in the compiler's order of passes. First `typeRangeArgs` types
  every argument, each in `State.typing`, and reports an unknown name or a
  misfit of a call inside any argument at once. An argument that holds a
  string or a call of `range` (`holdsStrOrRange`) is typed only in its
  other parts, by `typeArg`; an open literal's elements by `typeLiteral`;
  and an argument whose check gives an error of a later pass has its
  `lateElemTy`. Then the call is `noMatchingInit` $`\mathsf{List}[u]`:
  when an argument is not an $`\mathsf{Int}`, holds a string or a
  `range`, or is an open literal other than one of $`\mathsf{Int}`s, at
  any depth, whose first element is not an empty literal; when there are
  not one to three arguments; or when $`u` is not $`\mathsf{Int}`. In the
  state before the typing, `readRangeArgs` then reads the arguments in
  order, a literal's elements by `readIntElems`, and records the errors
  of later passes. The first use of an uninitialized or invalidated value
  comes first, also among the places read late; then such a literal of
  $`\mathsf{Int}`s, or an empty one, is `noMatchingInit`, as the compiler
  fails only when it instantiates the call; then a constant index out of
  range. `range` anywhere else is an unknown function: a range is not a
  value of its own;
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
Before that, $`p\,\hat{}` and each $`q\,\hat{}` in a place is rejected
when the value has no origin of its own, as $`\mathsf{transferFromElement}`,
once the place is typed as the compiler types it (#119): from its
variable outward, each field, each indexed place, but an
$`\mathsf{Int}` (#127), before its index, each index as an
$`\mathsf{Int}`, checked as an expression, whose own errors come first but for the later ones, and
each inner $`r\,\hat{}` as one that could transfer $`r`, initialized or
not, by the same rule and the `read` or `ref` parameter rule above,
unless $`r` is an $`\mathsf{Int}` or a $`\mathsf{Bool}`, which
$`r\,\hat{}` leaves in place. So a moved list, an uninitialized
or invalidated index, or a constant index out of range is not reported
for an element's transfer.
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
change (#81), with two exceptions: a $`q` with no origin of its own is
$`\mathsf{transferFromElement}`, as above, and any other $`q`, once it
has a type, whose variable is a `read` or `ref` parameter is
$`\mathsf{transferFromBorrowed}`, as the compiler reports them.
The numbers of arguments and parameters must be equal. A literal of an
expected type passed to a function or a method is converted to the
parameter's type, and one that does not fit, or holds such a literal, is a
type mismatch, as the compiler reports it. A literal $`[e]_{\mathsf{Int}}`
passed `mut` or `ref` is a value, read late as the operand $`e` would be,
so what $`e` reads is checked again with the other operands (#103).
Checking the arguments gives the mark of each.
:::
