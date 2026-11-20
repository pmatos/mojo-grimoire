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

:::moduleDocs (fingerprint := "7648077184085691593")
:::

:::readable MojoGrimoire.Interp.destroy MojoGrimoire.Interp.runBody MojoGrimoire.Interp.destroyOwned MojoGrimoire.Interp.placeRef MojoGrimoire.Interp.evalExpr MojoGrimoire.Interp.evalResult MojoGrimoire.Interp.dropPlace MojoGrimoire.Interp.dropAll MojoGrimoire.Interp.evalOperand MojoGrimoire.Interp.loadOperand MojoGrimoire.Interp.loadArgs MojoGrimoire.Interp.loadArg MojoGrimoire.Interp.evalLogic MojoGrimoire.Interp.evalArgs MojoGrimoire.Interp.evalPassed MojoGrimoire.Interp.callFun MojoGrimoire.Interp.evalCall MojoGrimoire.Interp.evalListArg MojoGrimoire.Interp.evalRef MojoGrimoire.Interp.execStmt MojoGrimoire.Interp.evalReturn MojoGrimoire.Interp.execBlock (fingerprint := "4479988210671575673")
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
  list's length; $`p\,\hat{}` names the reference of $`p`.
- *Expressions.* Literals are values, and $`[e]_{\mathsf{Int}}` is the value
  of $`e`; a place is read, a transfer takes its value out, leaving its
  blank behind, and `.copy()` reads it. `and` and `or`
  evaluate their right operand only when the left does not decide; on
  operands of a struct type they call its `__bool__` on the left one, by
  reference, and give the one that decides: the left one copied, or moved
  out of its temporary, which is destroyed when the right one decides
  (#191). Under $`\mathsf{drops}(e; p^*; q^*)`, the values in $`p^*`,
  which the left operand last uses, are destroyed once it is tested,
  after those in $`q^*` when it decides; the right operand destroys what
  it uses itself when it runs. A subscript read late on the left is tested
  with no drops, which follow when it does not decide; when it decides,
  its getter is called again, with them, for the result, before the
  values in $`q^*` that its arguments use; a temporary among its
  arguments dies once, after its last call. A value that is no struct is
  tested where it is, with no new location.
  The operands of an operator, the elements of a list literal and the
  values printed are evaluated left to right, and those that are places,
  or calls that return a reference, are read after the last one is
  evaluated; a subscript of a struct that is read late (`lateGetter`)
  has its arguments evaluated then, and calls its getter, with its drops,
  when it is read. An operator, a call, a construction and `print` call
  the getters of the subscripts read late among their operands before
  they read the others, but the copies into `var` parameters and into
  struct fields of a `@fieldwise_init` construction, which come first
  (`loadFirst`, #191); a list literal reads its
  elements in order. The operand of a unary operator, `and` or `or` is
  read at once.
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
  arguments. A method callee $`S.m` runs the method $`m` of $`S` as a
  function, its receiver first, its first two parameters swapped when it
  is reflected (`findCallee`, #191). A function's arguments are evaluated left to right by their
  parameters' conventions, and those passed by value are read when the
  call is made; the reference that a call returns is passed by reference
  to a `read`, `mut` or `ref` parameter, except an $`\mathsf{Int}` or a
  $`\mathsf{Bool}` passed `read`, which is read when the call is made, as
  it is for a `var` parameter, and a literal $`[e]_{\mathsf{Int}}` passed
  to any other parameter is $`e` passed by value, read when the call is
  made, into a temporary (#103); a subscript read late is read when the
  call is made, by value or into a temporary; temporaries are
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
  it, and destroys the old value. An expression statement destroys its
  result. `print` writes its arguments separated by spaces. `if` and
  `while` run their blocks in scopes of their own. `return x` of an owned
  variable takes it out. `drop p` takes the value out of $`p` and destroys
  it, as $`\mathsf{drops}` does for each of its places.
:::
