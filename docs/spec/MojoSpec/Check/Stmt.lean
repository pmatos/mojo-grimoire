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

:::moduleDocs (fingerprint := "594572333912498623")
:::

:::readable MojoGrimoire.Check.partlyMovedDeinit MojoGrimoire.Check.checkEnd (fingerprint := "1166979457985264311")
*Rule: the end of a variable.* A variable may end with parts moved out, and
the rest is destroyed field by field. It is rejected when a part with a
field moved out has a destructor of its own, which needs the whole value.
For the `self` of `__deinit__`, its own type does not count, since its
destructor is the one running.
:::

:::readable MojoGrimoire.Check.checkExit (fingerprint := "17439205243064497503")
*Rule: a return.* When a function returns, each `mut` parameter and the
`self` of `__init__` must be wholly initialized, since the caller holds
them, and every variable must be allowed to end.
:::

:::readable MojoGrimoire.Check.endScope (fingerprint := "18208149759164353378")
*Rule: the end of a scope.* The variables a block declared end with it,
each checked as above if the end of the block is reached.
:::

:::readable MojoGrimoire.Check.joinUninit MojoGrimoire.Check.joinStates (fingerprint := "1984114305602601151")
*Rule: joining branches.* After an `if`, a part is uninitialized when
either branch leaves it so. A branch that cannot reach its end, because it
returned, does not count.
:::

:::readable MojoGrimoire.Check.checkLoop (fingerprint := "11654448109731135871")
*Rule: loops.* A loop body must leave initialized every part that was
initialized before the loop, or its next iteration would use a moved
value.
:::

:::readable MojoGrimoire.Check.checkPrintArg (fingerprint := "15869644014447858079")
*Rule: printing.* `print` takes string literals, and values of type
$`\mathsf{Int}` or $`\mathsf{Bool}`, which it reads as values.
:::

:::readable MojoGrimoire.Check.checkReturnValue (fingerprint := "5588174264810524070")
*Rule: returned values.* `return x` moves the variable $`x` out when the
function owns it, as Mojo does; any other returned expression is checked as
an expression, so a place is copied implicitly.
:::

:::readable MojoGrimoire.Check.checkStmt MojoGrimoire.Check.checkScope MojoGrimoire.Check.checkBlock (fingerprint := "1662019130430316959")
*Rule: statements.*

* $`\mathsf{var}~x : t~(= e)^?` needs a declarable $`t` and an $`e`
  of type $`t`, and declares $`x`, initialized when $`e` is given; $`x`
  may not be the name of a variable in scope, so no variable hides another;
* $`p = e` checks $`e` first, then needs $`p` of $`e`'s type and a
  place the function may change; the old value of $`p` ends, and $`p`
  is initialized;
* an expression statement checks its expression;
* `print` checks its arguments as above;
* `if` needs a $`\mathsf{Bool}` condition and joins its branches, each a
  scope of its own; `while` needs a $`\mathsf{Bool}` condition and a
  body that keeps what was initialized;
* `return` needs a value of the result type exactly when the result type
  is not $`\mathsf{None}`, checks the state at a return, and makes what
  follows unreachable;
* `drop p` transfers $`p` away.
:::
