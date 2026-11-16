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

:::moduleDocs (fingerprint := "4802219020432241139")
:::

:::readable MojoGrimoire.Check.partlyMovedDeinit MojoGrimoire.Check.checkEnd (fingerprint := "17538961837886157612")
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

:::readable MojoGrimoire.Check.endScope (fingerprint := "18208149759164353378")
*Rule: the end of a scope.* The variables a block declared end with it,
each checked as above if the end of the block is reached.
:::

:::readable MojoGrimoire.Check.joinUninit MojoGrimoire.Check.joinMoved MojoGrimoire.Check.joinStates (fingerprint := "8423190426617035971")
*Rule: joining branches.* After an `if`, a part is uninitialized when
either branch leaves it so, and a field is moved out when either branch
leaves it so. A branch that cannot reach its end, because it
returned, does not count.
:::

:::readable MojoGrimoire.Check.checkLoop (fingerprint := "18258324302713265945")
*Rule: loops.* A loop body must leave initialized every part that was
initialized before the loop, or its next iteration would use a moved
value. As Mojo does, the checker reports such a part as a use of an
uninitialized value.
:::

:::readable MojoGrimoire.Check.checkPrintArg (fingerprint := "15869644014447858079")
*Rule: printing.* `print` takes string literals, and values of type
$`\mathsf{Int}` or $`\mathsf{Bool}`, which it reads as values.
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
* $`p = e` checks $`e` first, then needs $`p` of $`e`'s type and a
  place the function may change; the old value of $`p` ends, and $`p`
  is initialized. The old value may not end with a field in $`M` below
  $`p`, nor with a part moved out below a struct with a destructor of its
  own, as at the end of a variable. Assigning exactly a field in $`M`
  removes it from $`M`; assigning a part below that field does not;
* an expression statement checks its expression;
* `print` checks its arguments as above, then that its place arguments are
  still initialized;
* `if` needs a $`\mathsf{Bool}` condition and joins its branches, each a
  scope of its own; `while` needs a $`\mathsf{Bool}` condition and a
  body that keeps what was initialized;
* `return` needs a value of the result type exactly when the result type
  is not $`\mathsf{None}`, checks the state at a return, and makes what
  follows unreachable; a function that returns a reference returns a
  location whose origins are all within its own origin;
* `drop p` transfers $`p` away.
:::
