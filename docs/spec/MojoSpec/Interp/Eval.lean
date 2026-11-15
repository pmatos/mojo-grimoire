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

:::moduleDocs (fingerprint := "6816877235410116858")
:::

:::readable MojoGrimoire.Interp.Arg MojoGrimoire.Interp.bindParams (fingerprint := "35485823105497894")
*Definition: arguments.* A call receives each argument as a place, passed
by reference to a `read`, `mut` or `ref` parameter; as a value, moved or
copied into a `var` parameter, which the callee owns; or as a temporary,
a value passed to a borrowing parameter, which the caller destroys after
the call. The callee's parameters are bound to them, each value at a new
location.
:::

:::readable MojoGrimoire.Interp.asInt MojoGrimoire.Interp.asBool MojoGrimoire.Interp.lookupVar (fingerprint := "14008624707944704668")
*Definition: helpers.* An index is an $`\mathsf{Int}`, a condition a
$`\mathsf{Bool}`, and a variable is looked up in scope; anything else is
stuck.
:::

:::readable MojoGrimoire.Interp.destroy MojoGrimoire.Interp.runBody MojoGrimoire.Interp.destroyOwned MojoGrimoire.Interp.placeRef MojoGrimoire.Interp.evalExpr MojoGrimoire.Interp.evalArgs MojoGrimoire.Interp.callFun MojoGrimoire.Interp.evalCall MojoGrimoire.Interp.evalListArg MojoGrimoire.Interp.evalRef MojoGrimoire.Interp.execStmt MojoGrimoire.Interp.evalReturn MojoGrimoire.Interp.execBlock (fingerprint := "5898987111092227884")
*Definition: evaluation.* Every function below takes fuel and spends one
unit at each step; with none left, the run stops with `outOfFuel`.

- *Destruction.* Destroying a struct with a `__deinit__` runs it on the
  value; its elaborated body destroys the fields. A struct without one has
  its fields destroyed in order, and a list its elements; other values
  need nothing.
- *Bodies.* A body runs from its parameters until it returns or ends.
  Either way, every value the function still owns is destroyed, in order
  of declaration, after the returned value is computed.
- *Places.* A place names a reference: a variable's, then a field or an
  element on the way, whose index is evaluated and checked against the
  list's length.
- *Expressions.* Literals are values; a place is read, a transfer reads it
  and leaves $`\bot` behind, and `.copy()` reads it. `and` and `or`
  evaluate their right operand only when the left does not decide.
  Operands and arguments are evaluated left to right.
- *Calls.* A struct with `__init__` is built in a location holding the
  empty struct, passed as `out self`; a `@fieldwise_init` struct from its
  arguments. A function's arguments are evaluated by their parameters'
  conventions; temporaries are destroyed after the call. `append` adds a
  value at the end of a list, and `len` gives its length. A method gets its
  receiver by reference, or a copy for a `var self`.
- *References.* A `ref` binding, and the `return` of a function with an
  origin, give a reference: to a place, or the one a call returns. Used as
  a value, such a call's result is read.
- *Statements.* A declaration puts its value at a new location the
  function owns. An assignment evaluates its value, then its place, writes
  it, and destroys the old value. An expression statement destroys its
  result. `print` writes its arguments separated by spaces. `if` and
  `while` run their blocks in scopes of their own. `return x` of an owned
  variable moves it out. `drop p` takes the value out of $`p` and destroys
  it.
:::
