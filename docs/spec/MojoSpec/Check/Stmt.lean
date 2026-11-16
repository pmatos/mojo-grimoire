import VersoManual
import MojoGrimoire.Check.Stmt
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Stmt`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Statements and blocks: readable blocks" =>

:::moduleDocs (fingerprint := "8996524880192530108")
:::

:::readable MojoGrimoire.Check.partlyMovedDeinit MojoGrimoire.Check.cannotEnd MojoGrimoire.Check.checkEnd (fingerprint := "9586730624127733473")
*Rule: the end of a variable.* The compiler destroys a struct whole, so a
variable may not end with a field in $`M`, moved out and not assigned
again. Nor may it end with an uninitialized part below a struct that has a
destructor of its own, which needs the whole value. The `self` of
`__deinit__` is destroyed field by field: its own fields may stay moved
out, and its own type does not count, since its destructor is the one
running. Both errors are $`\mathsf{partiallyDestroyed}`.
:::

:::readable MojoGrimoire.Check.checkExit (fingerprint := "10417562916258413233")
*Rule: a return.* When a function returns, each `mut` parameter and the
`self` of `__init__` must be wholly initialized, since the caller holds
them, and every variable must be allowed to end.
:::

:::readable MojoGrimoire.Check.endScope (fingerprint := "5094446271499096283")
*Rule: the end of a scope.* The variables a block declared end with it,
each checked as above if the end of the block is reached, and leave the
set of invalidated references.
:::

:::readable MojoGrimoire.Check.joinUninit MojoGrimoire.Check.joinStates (fingerprint := "345539795275892427")
*Rule: joining branches.* After an `if`, a part is uninitialized when
either branch leaves it so, $`M` is the union of the branches' sets, and
a reference is invalidated when either branch invalidates it. A branch
that cannot reach its end, because it returned, does not count.
:::

:::readable MojoGrimoire.Check.checkLoop (fingerprint := "11393517602813983322")
*Rule: loops.* A loop body must leave initialized every part that was
initialized before the loop, and may not add a field to $`M`, or its next
iteration would use a moved value. As Mojo does, the checker reports such
a part as a use of an uninitialized value.
:::

:::readable MojoGrimoire.Check.checkPrintArg (fingerprint := "15869644014447858079")
*Rule: printing.* `print` takes string literals, and values of type
$`\mathsf{Int}` or $`\mathsf{Bool}`, which it reads as values.
:::

:::readable MojoGrimoire.Check.checkConstructed (fingerprint := "16962242353956809651")
*Rule: building into an element.* $`p = e` is rejected as
$`\mathsf{argumentExclusivity}` when $`p` is inside an element of a list,
and $`e` is a call that builds its result in place and is passed `mut`, or
`ref` when it may change it, the list or a place that holds it: the change
would invalidate $`p`. A call of a function or a method builds its result
in place unless it returns an $`\mathsf{Int}`, a $`\mathsf{Bool}` or a
reference, and so does a struct's `__init__`; a list method that gives an
element always does, since its result has a generic type in Mojo.
:::

:::readable MojoGrimoire.Check.checkReturnValue (fingerprint := "8211605308112301922")
*Rule: returned values.* `return x` moves the variable $`x` out when the
function owns it, as Mojo does; any other returned expression is checked as
an expression, so a place is copied implicitly.
:::

:::readable MojoGrimoire.Check.checkStmt MojoGrimoire.Check.checkScope MojoGrimoire.Check.checkBlock (fingerprint := "9919481853655389240")
*Rule: statements.*

* $`\mathsf{var}~x : t~(= e)^?` needs a declarable $`t` and an $`e`
  of type $`t`, and declares $`x`, initialized when $`e` is given; $`x`
  may not be the name of a variable in scope, so no variable hides another;
* $`\mathsf{ref}~x = e` binds $`x` to a reference, as the next section
  says; $`x` may not hide a variable in scope either;
* $`p = e` checks $`e` first, then needs $`p` of $`e`'s type, then
  that $`e` does not build its result into $`p` while changing the list
  that holds it, then needs a place the function may change; $`p` is changed as a
  whole, its old value ends, and $`p` is initialized. The old value may not end with a field in $`M` below
  $`p`, nor with a part moved out below a struct with a destructor of its
  own, as at the end of a variable. Assigning exactly a field in $`M`
  removes it from $`M`; assigning a part below that field does not.
  Through a reference or to an element, the old value is read first, so
  it must be initialized;
* an expression statement checks its expression;
* `print` checks its arguments as above, then that its place arguments are
  still initialized and not invalidated;
* `if` needs a $`\mathsf{Bool}` condition and joins its branches, each a
  scope of its own; `while` needs a $`\mathsf{Bool}` condition and a
  body that keeps what was initialized. When the body can reach its end
  and invalidates a reference, the condition and the body are checked once
  more with it invalidated, as the next iteration finds it, and it stays
  invalidated after the loop;
* `return` needs a value of the result type exactly when the result type
  is not $`\mathsf{None}`, checks the state at a return, and makes what
  follows unreachable; a function that returns a reference returns a
  location whose origins are all within its own origin;
* `drop p` transfers $`p` away.

A block checks its statements in order, and the changes recorded for
operands start afresh with each statement.
:::
