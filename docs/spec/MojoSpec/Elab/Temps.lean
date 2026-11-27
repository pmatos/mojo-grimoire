import VersoManual
import MojoGrimoire.Elab.Temps
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Temps`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Temporaries of returned references: readable blocks" =>

:::moduleDocs (fingerprint := "10291767331751514447")
:::

:::readable MojoGrimoire.Elab.envAfter (fingerprint := "3023937792142485577")
*Definition: the types after a statement.* The types of the variables
after a statement, which a declaration or a `ref` binding extends.
:::

:::readable MojoGrimoire.Elab.isTempArg MojoGrimoire.Elab.tempParams MojoGrimoire.Elab.Temps MojoGrimoire.Elab.wrapTemp (fingerprint := "7996426749286916715")
*Definition: a temporary origin argument.* An argument passed to a
parameter that the callee's origin names is a temporary when it is neither
a place nor a call of a function or a method that returns a reference. It
gets a hidden variable when the parameter's type is dropped: a struct, or a
list or an array of structs. Values of the other types cannot be seen being
destroyed. The `k`th temporary of a body is the place `tempName k`,
and `wrapTemp` replaces the argument with `temp (tempName k) a'`. Here `a'`
is the argument with its own temporaries named, and it records `k` and the
parameter's type.
:::

:::readable MojoGrimoire.Elab.tempPlace MojoGrimoire.Elab.tempExpr MojoGrimoire.Elab.tempArgs (fingerprint := "17395445834075381444")
*Definition: naming the temporaries of an expression.* The walk follows the
order of evaluation: a place's indices, the operands and arguments in
order, and inside each argument before the argument itself. A call or a
method call that returns a reference passes its arguments through
`wrapTemp` with the parameters that `tempParams` gives. A method call finds
its signature from the type of its receiver. Every other expression is
rebuilt as it is.
:::

:::readable MojoGrimoire.Elab.tempDecls MojoGrimoire.Elab.withTemps MojoGrimoire.Elab.tempStmt MojoGrimoire.Elab.tempBlock (fingerprint := "1520010703247369639")
*Definition: naming the temporaries of a body.* Each statement is preceded,
in its own block, by the declarations with no value of the hidden variables
of the temporaries in its expressions, in the order they are made. That
includes the condition of an `if` or a `while`. The blocks a statement holds
name their own temporaries. Numbers run on through the body, so that each
hidden variable is declared once. Each declaration kills its slot for
liveness. On each iteration of a loop the body declares its temporaries
again, so that none of them lives across the back edge.
:::

:::readable MojoGrimoire.Elab.tempsPlace MojoGrimoire.Elab.tempsIn MojoGrimoire.Elab.tempsList (fingerprint := "14347537281508658074")
*Definition: the temporaries of an expression.* These are the hidden
variables that the `temp` expressions in an expression name, including
those in the indices of its places. A `while` loop keeps the temporaries of
its condition out of the slots live at its head: each run of the condition
makes them and destroys them again.
:::
