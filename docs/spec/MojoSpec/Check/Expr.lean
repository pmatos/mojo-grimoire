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

:::moduleDocs (fingerprint := "16219433045883596312")
:::

:::readable MojoGrimoire.Check.checkExprAs MojoGrimoire.Check.checkOperands MojoGrimoire.Check.checkIterableElems MojoGrimoire.Check.typeRangeArgs MojoGrimoire.Check.typeLiteral MojoGrimoire.Check.typeArg MojoGrimoire.Check.typeArgs MojoGrimoire.Check.readRangeArgs MojoGrimoire.Check.intMisfit MojoGrimoire.Check.readIntElems MojoGrimoire.Check.checkArgs MojoGrimoire.Check.checkArg MojoGrimoire.Check.checkIndices MojoGrimoire.Check.checkIndex MojoGrimoire.Check.requireOwnOrigin MojoGrimoire.Check.typePlace MojoGrimoire.Check.checkExpr (fingerprint := "11572156575677018252")
*Rule: expressions.* An expression is checked from left to right, and has a
type:

* a literal has its type, but a string literal is rejected outside
  `print`;
* $`p` is copied implicitly, or read by reference where its location is
  used (`usePlace`), $`p\,\hat{}` transferred, and
  $`p.\mathsf{copy}()` needs an initialized place of a copyable type,
  other than $`\mathsf{None}`, which has no `.copy()`, as
  `rejectNoneCopy` reports before anything else (#131);
* $`f(e^*)` and $`p.m(e^*)` pass their arguments to the parameters of
  their signature, $`p` first, by the convention of the method's `self`,
  and have its result type; when $`f` names a struct, the call is an
  initializer, whose misfits are `noMatchingInit`; a method call is
  checked by `methodCall`, and the misfits of `pop`, which has several
  overloads, are `noMatchingMethod`; a receiver $`q\,\hat{}` of a method
  whose `self` is `var` is not copied: once the arguments are checked and
  read again, $`q` is transferred. When a variable in scope has the name
  $`f` and its type has no `__call__`, the call is rejected by
  `rejectCalledVar`, once its arguments are typed by `typeArgs` (#176).
  A call of a method callee $`S.m`, which inference makes of an operator
  or a call on a struct (#191), passes its receiver as its
  first argument; one of an in-place method needs a receiver that may
  change, once its indices are typed (`typePlace`), before anything else
  (`requireInPlace`), and one whose struct
  lacks the method is `missingMethod`, once its arguments are typed;
* operators have the types above, but a method that an operand's type
  lacks is `missingMethod` (#176): found from the operands' types
  (`operandTy`, `binaryMisfit`, `unaryMisfit`) before they are read, once
  both are typed by `typeArg`, and else from their checked types. The
  right operand of an operator whose left operand is an integer literal
  expression (`intLiteral`), but `and` and `or`, is passed as to a `read`
  $`\mathsf{Int}` parameter of a method with several overloads: one that
  is no $`\mathsf{Int}` is `noMatchingMethod` (#88). A comparison of
  two arrays is found from the operands' types too (`operandMisfit`), and
  an operand compared as an array, a place or a call that returns a
  reference, is read by reference, uncopied (`byRef`, #166);
* $`[e^*]_t`, with $`t` a list or an array of $`u` and $`u` a type a
  variable may have, initializes $`t`: it passes each element as to a `var`
  parameter of type $`u`, and an array must have as many elements as its
  type says, or the literal is `noMatchingInit` $`t`; with $`t` the type
  $`?`, no type is expected, and the literal is an array of the type of
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
  or an array (#103). First, a $`u` in which a variable hides a name is
  `valueAsType` (`rejectHidden`, #193), with any number of arguments. Its argument is passed by `ref`, as `len` takes its
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
  checked in the compiler's order of passes, as `rangeList` says; a
  function of the program named `range` is typed as any other. First `typeRangeArgs` types
  every argument, each in `State.typing`, and reports an unknown name or a
  misfit of a call inside any argument at once. An argument that holds a
  string or a call of `range` (`holdsStrOrRange`) is typed only in its
  other parts, by `typeArg`; an open literal's elements by `typeLiteral`;
  and an argument whose check gives an error that the compiler reports
  after its types, or after the misfit, an implicit copy of the value a
  call returns a reference to, has its `lateElemTy`. Then the call is `noMatchingInit` $`\mathsf{List}[u]`:
  when an argument is not an $`\mathsf{Int}`, holds a string or a
  `range`, or is an open literal other than one of $`\mathsf{Int}`s at
  any depth; when the first argument is an empty literal, or one whose
  first element, at any depth, is an empty literal; when there are not one
  to three arguments; or when $`u` is not $`\mathsf{Int}`. In the state
  before the typing, `readRangeArgs` then reads the arguments in order, a
  literal's elements each in turn, and records the errors of later
  passes. The first use of an uninitialized or invalidated value comes
  first, also among the places read late; then such a literal of
  $`\mathsf{Int}`s, or an empty one, or one of the wrong length nested in
  an argument, is `noMatchingInit`, as the compiler
  fails only when it instantiates the call; then a constant index out of
  range. `range` anywhere else is an unknown function, unless a variable
  hides it: a range is not a value of its own;
* $`\mathsf{List}[u](e^+)` with more than one argument checks each
  argument on its own, locating a place without reading it, and is then
  rejected as `noMatchingInit` $`\mathsf{List}[u]`: no initializer of
  `List` takes its elements;
* the methods of a list take it `mut`, so they need a list the function
  may change; `len(e)`, when the program declares no function or struct
  `len` and no variable hides it, takes one list, array or $`\mathsf{Int}`
  and gives an $`\mathsf{Int}`: a place
  argument, or a call that returns a reference that is a located
  operand, is read, not copied. A $`\mathsf{Bool}`, `None` or a struct,
  or another number of arguments, fits no overload of `len`:
  `noMatchingInit`, found by `lenCall` before any argument is read
  (#190);
* $`\mathsf{drops}(e; p^*; q^*)`, which only elaboration inserts, after
  checking, has the type of $`e`.

The place operands of a call, a method call, a binary operator other
than `and` and `or`, a list literal and `print`, and the origins of an
operand among them that is a call that returns a reference and is a
located operand, are checked again once every operand is, by
`recheckLocs`; then the call records what it changes.
A place through the element of an $`\mathsf{Int}` passed `mut` or `ref`
is rejected by `rejectIntElemArg`, once its indices are checked (#222).
Every index in a place is checked first, and must be an $`\mathsf{Int}`:
an index of a list or an array is an argument of `__getitem__`, which has
several overloads, checked by `checkArg`, so that a misfit is
`noMatchingMethod` (`checkIndex`, #169), and one of an $`\mathsf{Int}` a
type mismatch;
a constant index may not be negative, nor, into an array of $`n`
elements, $`n` or more, nor, into an $`\mathsf{Int}`, 1 or more (#127). Mojo locates $`q` in $`q[i]` before it
evaluates $`i`, so $`i` may not invalidate $`q`. Each $`q\,\hat{}` in a
place needs $`q` whole, as `p^` would, and a value that $`q\,\hat{}`
could transfer, by the conditions above.
Before that, $`p\,\hat{}` and each $`q\,\hat{}` in a place is rejected
when the value has no origin of its own, as $`\mathsf{transferFromElement}`,
once the place is typed as the compiler types it (#119): from its
variable outward, each field, each indexed place before its index,
each index as an
$`\mathsf{Int}`, checked as an expression, whose own errors come first but for the later ones, and
each inner $`r\,\hat{}` as one that could transfer $`r`, initialized or
not, by the same rule and the `read` or `ref` parameter rule above,
unless $`r` is an $`\mathsf{Int}`, a $`\mathsf{Bool}` or a
$`\mathsf{None}`, which $`r\,\hat{}` leaves in place. So a moved list, an uninitialized
or invalidated index, or a constant index out of range is not reported
for an element's transfer.
A call or a method call that returns a reference gives the value it
points to, which must be implicitly copyable, unless the call is bound
with `ref`, passed by reference, or read by `len` or `print`.

The arguments of a call are checked in order against the parameters, each
by `checkArg`, after the exclusivity rule; a string literal fits no
overload. A place is passed by `passPlace`; a call that returns a
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
