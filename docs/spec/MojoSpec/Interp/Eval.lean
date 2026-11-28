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

:::moduleDocs (fingerprint := "13284793829538770139")
:::

:::readable MojoGrimoire.Interp.destroy MojoGrimoire.Interp.runBody MojoGrimoire.Interp.destroyOwned MojoGrimoire.Interp.placeRef MojoGrimoire.Interp.evalExpr MojoGrimoire.Interp.evalResult MojoGrimoire.Interp.dropAll MojoGrimoire.Interp.evalOperand MojoGrimoire.Interp.loadOperand MojoGrimoire.Interp.loadGetter MojoGrimoire.Interp.loadArgs MojoGrimoire.Interp.loadArg MojoGrimoire.Interp.evalLogic MojoGrimoire.Interp.evalArgs MojoGrimoire.Interp.callFun MojoGrimoire.Interp.evalCall MojoGrimoire.Interp.evalListArg MojoGrimoire.Interp.evalRef MojoGrimoire.Interp.execStmt MojoGrimoire.Interp.evalReturn MojoGrimoire.Interp.execBlock (fingerprint := "15075027824867757263")
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
  evaluate their right operand only when the left does not decide. On
  structs of the same type they give the operand that decides, which its
  `__bool__` tests as a call would pass it, by reference, or a copy to a
  `var self`: a place is copied, and a temporary is
  moved out when it decides and destroyed when it does not (#191). A
  test of the left operand that inference made gives a `var self` a copy
  (`copiedTest`), and destroys a temporary once it is copied. What
  the left operand last uses dies once it is tested, after what the right
  one would have used when the left one decides. A subscript read late on
  the left is read at once, its getter called once, as one of a struct
  with no setter is; the compiler calls it twice there, a bug (D-0011,
  #211).
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
  arguments. A function's arguments are evaluated left to right by their
  parameters' conventions, and those passed by value are read when the
  call is made; the reference that a call returns is passed by reference
  to a `read`, `mut` or `ref` parameter, except an $`\mathsf{Int}` or a
  $`\mathsf{Bool}` passed `read`, which is read when the call is made, as
  it is for a `var` parameter, and a literal $`[e]_{\mathsf{Int}}` passed
  to any other parameter is $`e` passed by value, read when the call is
  made, into a temporary (#103); a subscript read late is read when the
  call is made, by value or into a temporary; temporaries are
  destroyed after the call. A temporary that elaboration names,
  $`\mathsf{temp}~x := e`, is not one of them: the value of $`e` is moved
  into the hidden variable $`x` (`fillTemp`), which is passed by
  reference and lives until elaboration drops it (#80). `append` adds a
  value at the end of a list, `pop()` removes the last element and gives
  it back, failing with $`\mathsf{indexOutOfBounds}` on an empty list,
  `pop(i)` evaluates $`i`, then removes the element at the position $`i`
  names and gives it back, failing with $`\mathsf{indexOutOfBounds}` when
  $`i` is negative or past the last element, and
  `len` gives the length of a list or an array, 1 for an $`\mathsf{Int}`
  (#190), and destroys its argument
  when that is neither a place nor a reference that a call returns. A
  method gets its receiver by reference, or a copy for a `var self`; a
  `var self` on $`q\,\hat{}` takes the value of $`q`, leaving its blank
  behind once the arguments are read.
- *References.* A `ref` binding, and the `return` of a function with an
  origin, give a reference: to a place, or the one a call returns. Used as
  a value, such a call's result is read where a place would be. A call gives what it returns, a
  reference or a value, and any other expression its value.
- *Statements.* A declaration puts its value, or the blank of its type
  when it has none, at a new location the function owns. An assignment evaluates the indices of its place,
  outermost first, locating each element once its index is evaluated, so
  that an index out of bounds stops the run before the value is evaluated
  (`fixIndices`, #205); then it evaluates the value, locates the element
  again, in the list as the value left it (D-0002), writes it, and
  destroys the old value; into the element of an $`\mathsf{Int}`,
  it locates the $`\mathsf{Int}` and evaluates the index as an operand
  first, then the value, and reads the index last and checks it against 1,
  as the arguments of `__setitem__` are (#127). Whether the base is an
  $`\mathsf{Int}` is decided from the place's static type, never from what
  its lists hold. An expression statement destroys its
  result. `print` writes its arguments separated by spaces. `if` and
  `while` run their blocks in scopes of their own. `return x` of an owned
  variable takes it out. `drop p` takes the value out of $`p` and destroys
  it, as $`\mathsf{drops}` does for each of its places.
:::
