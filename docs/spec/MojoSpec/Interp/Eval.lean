import VersoManual
import MojoGrimoire.Interp.Eval
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Interp.Eval`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Evaluation: readable blocks" =>

:::moduleDocs (fingerprint := "1946490137953697850")
:::

:::readable MojoGrimoire.Interp.Arg MojoGrimoire.Interp.bindParams (fingerprint := "14136961392570647166")
*Definition: arguments.* A call receives each argument as a place, passed
by reference to a `read`, `mut`, `ref` or `out` parameter; as a value,
moved or copied into a `var` parameter, which the callee owns, or copied
into a `read` parameter of type $`\mathsf{Int}` or $`\mathsf{Bool}`; or
as a temporary, a value passed to a borrowing parameter, which the caller
destroys after the call. The callee's parameters are bound to them, each
value at a new location.
:::

:::readable MojoGrimoire.Interp.Operand MojoGrimoire.Interp.Operand.load MojoGrimoire.Interp.Pending MojoGrimoire.Interp.Pending.loadAll (fingerprint := "3189860708977689654")
*Definition: operands read late.* An operand that is a place passed by
value, or the reference that a call returns, is first only located; it is read once every operand of its
operation has been evaluated, as Mojo does. A call's arguments wait in
the same way: those passed by value are read when the call is made. An
$`\mathsf{Int}` or a $`\mathsf{Bool}` passed to a `read` parameter is
passed by value.
:::

:::readable MojoGrimoire.Interp.asInt MojoGrimoire.Interp.asBool MojoGrimoire.Interp.lookupVar (fingerprint := "2000511689573242902")
*Definition: helpers.* An index is an $`\mathsf{Int}`, a condition a
$`\mathsf{Bool}`, and a variable is looked up in scope; anything else is
stuck.
:::

:::readable MojoGrimoire.Interp.destroy MojoGrimoire.Interp.runBody MojoGrimoire.Interp.destroyOwned MojoGrimoire.Interp.placeRef MojoGrimoire.Interp.evalExpr MojoGrimoire.Interp.evalResult MojoGrimoire.Interp.dropPlace MojoGrimoire.Interp.dropAll MojoGrimoire.Interp.evalOperand MojoGrimoire.Interp.evalArgs MojoGrimoire.Interp.callFun MojoGrimoire.Interp.evalCall MojoGrimoire.Interp.evalListArg MojoGrimoire.Interp.evalRef MojoGrimoire.Interp.execStmt MojoGrimoire.Interp.evalReturn MojoGrimoire.Interp.execBlock (fingerprint := "4644987595786742263")
*Definition: evaluation.* Every function below takes fuel and spends one
unit at each step; with none left, the run stops with `outOfFuel`.

- *Destruction.* A value that holds nothing, a blank included, needs
  nothing. A struct with some fields that hold nothing and others that hold
  a value is stuck: the checker rejects a program that would destroy one,
  however it came to be partly built (R, D-0003). Destroying a struct with a `__deinit__` runs
  it on the value; its elaborated body destroys the fields. A struct
  without one has its fields destroyed in order, and a list its elements;
  other values need nothing.
- *Bodies.* A body runs from its parameters until it returns or ends.
  Either way, every value the function still owns is destroyed, in order
  of declaration, after the returned value is computed.
- *Places.* A place names a reference: a variable's, then a field or an
  element on the way, whose index is evaluated and checked against the
  list's length; an index into an $`\mathsf{Int}`, its own one element,
  is checked against 1 and names the $`\mathsf{Int}` (#127);
  $`p\,\hat{}` names the reference of $`p`.
- *Expressions.* Literals are values, and $`[e]_{\mathsf{Int}}` is the value
  of $`e`; a place is read, a transfer takes its value out, leaving its
  blank behind, and `.copy()` reads it. `and` and `or`
  evaluate their right operand only when the left does not decide.
  The operands of an operator, the elements of a list literal and the
  values printed are evaluated left to right, and those that are places,
  or calls that return a reference, are read after the last one is
  evaluated. The operand of a unary operator, `and` or `or` is read at
  once.
  $`\mathsf{drops}(e; p^*; q^*)` evaluates $`e`, destroying the values in
  $`p^*` once a call's arguments are read, before it is made, and those in
  $`q^*` once $`e` is done; for an operation that is not a call, both once
  it is done. $`\mathsf{List}[u](e)` reads its argument as `len` reads its list, and
  is a list of the same elements: values are trees, so this copies each
  element; a temporary argument is destroyed first (#103).
  $`\mathsf{List}[u](e^+)` with more arguments, which the checker always
  rejects, gets stuck. $`\mathsf{range}(e^*)`, which the checker
  accepts only as the argument of $`\mathsf{List}[u]`, evaluates its
  arguments as `read` arguments of type $`\mathsf{Int}`, read when the
  call is made, and gives the list `rangeList` builds from them, with the
  call's fuel: the end alone counts from 0, and the step is 1 unless a
  third argument gives it (#121).
- *Calls.* A struct with `__init__` is built in a location holding the
  struct with blank fields, passed as `out self`; a `@fieldwise_init` struct from its
  arguments. A function's arguments are evaluated left to right by their
  parameters' conventions, and those passed by value are read when the
  call is made; the reference that a call returns is passed by reference
  to a `read`, `mut` or `ref` parameter, except an $`\mathsf{Int}` or a
  $`\mathsf{Bool}` passed `read`, which is read when the call is made, as
  it is for a `var` parameter, and a literal $`[e]_{\mathsf{Int}}` passed
  to any other parameter is $`e` passed by value, read when the call is
  made, into a temporary (#103); temporaries are
  destroyed after the call. `append` adds a
  value at the end of a list, `pop()` removes the last element and gives
  it back, failing with $`\mathsf{indexOutOfBounds}` on an empty list,
  `pop(i)` evaluates $`i`, then removes the element at the position $`i`
  names and gives it back, failing with $`\mathsf{indexOutOfBounds}` when
  $`i` is negative or past the last element, and
  `len` gives the length of a list or an array, and destroys its argument
  when that is neither a place nor a reference that a call returns. A
  method gets its receiver by reference, or a copy for a `var self`; a
  `var self` on $`q\,\hat{}` takes the value of $`q`, leaving its blank
  behind once the arguments are read.
- *References.* A `ref` binding, and the `return` of a function with an
  origin, give a reference: to a place, or the one a call returns. Used as
  a value, such a call's result is read where a place would be. A call gives what it returns, a
  reference or a value, and any other expression its value.
- *Statements.* A declaration puts its value, or the blank of its type
  when it has none, at a new location the function owns. An assignment evaluates its value, then its place, writes
  it, and destroys the old value; into the element of an $`\mathsf{Int}`,
  it evaluates the place, index included, first, as `__setitem__` takes
  the index before the value (#127). Whether the base is an
  $`\mathsf{Int}` is read from its value without evaluating its indices
  (`peekPlace`). An expression statement destroys its
  result. `print` writes its arguments separated by spaces. `if` and
  `while` run their blocks in scopes of their own. `return x` of an owned
  variable takes it out. `drop p` takes the value out of $`p` and destroys
  it, as $`\mathsf{drops}` does for each of its places.
:::
